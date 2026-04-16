const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const { WebSocket } = require('ws');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createConversationService } = require('../src/conversations/conversation-service');
const { createRunService } = require('../src/runs/run-service');
const { createApp } = require('../src/http/app');
const { attachWebSocketServer } = require('../src/realtime/ws-server');
const { EventBroker } = require('../src/realtime/event-broker');

const daemonRoot = path.join(__dirname, '..');
const entryPath = path.join(daemonRoot, 'src', 'index.js');

function getJson(port, pathname, { headers } = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port,
      path: pathname,
      method: 'GET',
      headers,
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body: JSON.parse(data) });
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function postJson(port, pathname, body, { headers } = {}) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const req = http.request({
      hostname: '127.0.0.1',
      port,
      path: pathname,
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'content-length': Buffer.byteLength(payload),
        ...headers,
      },
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body: JSON.parse(data) });
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

test('daemon exposes a health endpoint', async () => {
  const child = spawn(process.execPath, [entryPath], {
    cwd: daemonRoot,
    env: {
      ...process.env,
      PORT: '4311',
      WORKSPACE_ROOT: '/tmp/code',
      DAEMON_DATA_DIR: '/tmp/agent-workbench',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let stderr = '';

  child.stderr.on('data', (chunk) => {
    stderr += chunk.toString();
  });

  await new Promise((resolve, reject) => {
    child.stdout.on('data', (chunk) => {
      if (chunk.toString().includes('[daemon] listening')) resolve();
    });
    child.once('error', reject);
    child.once('close', (code) => reject(new Error(`daemon exited with ${code}\n${stderr}`)));
  });

  const response = await getJson(4311, '/health');
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.ok, true);
  assert.equal(response.body.product, 'android-agent-workbench-daemon');

  child.kill('SIGTERM');
});

test('daemon requires a bearer token when auth is configured', async () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'daemon-auth-'));
  const db = openDatabase({ daemonDataDir: path.join(tempRoot, 'data') });
  migrate(db);

  const app = createApp({
    projectService: { listProjects: () => [] },
    conversationService: createConversationService({ db }),
    runService: createRunService({ db, codexBin: process.execPath }),
    authToken: 'top-secret',
  });
  const server = await new Promise((resolve) => {
    const started = app.listen(0, '127.0.0.1', () => resolve(started));
  });
  const port = server.address().port;

  const unauthorized = await getJson(port, '/health');
  assert.equal(unauthorized.statusCode, 401);
  assert.equal(unauthorized.body.error, 'Unauthorized');

  const authorized = await getJson(port, '/health', {
    headers: { authorization: 'Bearer top-secret' },
  });
  assert.equal(authorized.statusCode, 200);
  assert.equal(authorized.body.ok, true);

  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

test('websocket rejects missing tokens and accepts the configured token', async () => {
  const server = http.createServer((_, res) => {
    res.writeHead(404);
    res.end();
  });
  const eventBroker = new EventBroker();
  attachWebSocketServer(server, eventBroker, { authToken: 'ws-secret' });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  const unauthorizedResult = await new Promise((resolve) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}/ws`);
    socket.on('unexpected-response', (_request, response) => {
      resolve(response.statusCode);
    });
    socket.on('error', () => {});
  });
  assert.equal(unauthorizedResult, 401);

  const authorizedMessage = await new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}/ws?token=ws-secret`);
    socket.on('open', () => {
      eventBroker.publish({ kind: 'run.started', runId: 'run-1' });
    });
    socket.on('message', (message) => {
      socket.close();
      resolve(JSON.parse(message.toString()));
    });
    socket.on('error', reject);
  });
  assert.equal(authorizedMessage.kind, 'run.started');

  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

test('daemon exposes conversation event snapshots over http', async () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'daemon-http-'));
  const fakeCodex = path.join(tempRoot, 'fake-codex.sh');
  fs.writeFileSync(fakeCodex, [
    '#!/usr/bin/env bash',
    'printf \'{"type":"action","name":"reading files"}\\n\'',
    'printf \'{"type":"assistant","text":"done"}\\n\'',
  ].join('\n'));
  fs.chmodSync(fakeCodex, 0o755);

  const db = openDatabase({ daemonDataDir: path.join(tempRoot, 'data') });
  migrate(db);

  const conversationService = createConversationService({ db });
  const conversation = conversationService.createConversation({
    projectId: tempRoot,
    title: 'live route test',
    openingMessage: 'start',
  });
  const runService = createRunService({ db, codexBin: fakeCodex });
  await runService.startRun({
    conversationId: conversation.id,
    cwd: tempRoot,
    prompt: 'start',
  });
  await waitFor(() => runService.listConversationEvents(conversation.id).length > 0);

  const app = createApp({
    projectService: { listProjects: () => [] },
    conversationService,
    runService,
  });
  const server = await new Promise((resolve) => {
    const started = app.listen(0, '127.0.0.1', () => resolve(started));
  });
  const port = server.address().port;

  const response = await getJson(port, `/conversations/${conversation.id}/events`);
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.events[0].kind, 'run.action');
  assert.equal(response.body.events[0].payload.label, 'reading files');

  await new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
});

test('http run creation responds immediately with a running snapshot', async () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'daemon-http-run-'));
  const fakeCodex = path.join(tempRoot, 'fake-codex.sh');
  fs.writeFileSync(fakeCodex, [
    '#!/usr/bin/env bash',
    'sleep 0.5',
    'printf \'{"type":"assistant","text":"done"}\\n\'',
  ].join('\n'));
  fs.chmodSync(fakeCodex, 0o755);

  const db = openDatabase({ daemonDataDir: path.join(tempRoot, 'data') });
  migrate(db);

  const conversationService = createConversationService({ db });
  const conversation = conversationService.createConversation({
    projectId: tempRoot,
    title: 'run route test',
    openingMessage: 'start',
  });
  const runService = createRunService({ db, codexBin: fakeCodex });

  const app = createApp({
    projectService: { listProjects: () => [] },
    conversationService,
    runService,
  });
  const server = await new Promise((resolve) => {
    const started = app.listen(0, '127.0.0.1', () => resolve(started));
  });
  const port = server.address().port;

  const startedAt = Date.now();
  const response = await postJson(
    port,
    `/conversations/${conversation.id}/runs`,
    { cwd: tempRoot, prompt: 'start' },
  );
  const elapsedMs = Date.now() - startedAt;

  assert.equal(response.statusCode, 201);
  assert.equal(response.body.run.status, 'running');
  assert.ok(elapsedMs < 300, `expected immediate response, got ${elapsedMs}ms`);

  await new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
});

async function waitFor(predicate, { timeoutMs = 2000, intervalMs = 20 } = {}) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (predicate()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  throw new Error('Timed out waiting for predicate to pass.');
}
