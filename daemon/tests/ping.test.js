const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createConversationService } = require('../src/conversations/conversation-service');
const { createRunService } = require('../src/runs/run-service');
const { createApp } = require('../src/http/app');

const daemonRoot = path.join(__dirname, '..');
const entryPath = path.join(daemonRoot, 'src', 'index.js');

function getJson(port, pathname) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port,
      path: pathname,
      method: 'GET',
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
