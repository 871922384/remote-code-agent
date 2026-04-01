const test = require('node:test');
const assert = require('node:assert/strict');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const net = require('node:net');
const { spawn } = require('node:child_process');
const { DatabaseSync } = require('node:sqlite');

const projectRoot = path.join(__dirname, '..');
const serverPath = path.join(projectRoot, 'server.js');

function listenOnce(server, port) {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => {
      server.removeListener('error', reject);
      resolve(server.address());
    });
  });
}

function closeOnce(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}

async function getFreePort() {
  const blocker = net.createServer();
  const address = await listenOnce(blocker, 0);
  await closeOnce(blocker);
  return address.port;
}

function startServer(envOverrides) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [serverPath], {
      cwd: projectRoot,
      env: { ...process.env, ...envOverrides },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    let settled = false;

    const timeout = setTimeout(() => {
      if (settled) return;
      settled = true;
      child.kill();
      reject(new Error(`server did not start\nstdout:\n${stdout}\nstderr:\n${stderr}`));
    }, 10000);

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
      if (!settled && stdout.includes('[Agent] Listening on')) {
        settled = true;
        clearTimeout(timeout);
        resolve({ child });
      }
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    child.once('error', (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      reject(error);
    });

    child.once('close', (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      reject(new Error(`server exited early with code ${code}\nstdout:\n${stdout}\nstderr:\n${stderr}`));
    });
  });
}

async function stopChild(child) {
  if (!child || child.killed || child.exitCode !== null) {
    return;
  }

  child.kill();
  await new Promise((resolve) => child.once('close', resolve));
}

function httpJson({ port, token, method, pathname, body }) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port,
      path: pathname,
      method,
      headers: {
        'content-type': 'application/json',
        'x-auth-token': token,
      },
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          body: data ? JSON.parse(data) : null,
        });
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

function postSse({ port, token, body }) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port,
      path: '/api/chat',
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-auth-token': token,
      },
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body: data });
      });
    });

    req.on('error', reject);
    req.write(JSON.stringify(body));
    req.end();
  });
}

test('server persists projects, threads, and messages for the codex-style UI model', async () => {
  const tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'remote-agent-state-'));
  const codexScriptPath = path.join(tempDir, 'codex.cmd');
  await fsp.writeFile(codexScriptPath, [
    '@echo off',
    'echo Stored reply from fake codex',
  ].join('\r\n'));

  const dataDir = path.join(tempDir, 'state');
  const isolatedCodexHome = path.join(tempDir, 'empty-codex');
  await fsp.mkdir(isolatedCodexHome, { recursive: true });
  const port = await getFreePort();
  const token = 'test-token';
  const server = await startServer({
    AUTH_TOKEN: token,
    PORT: String(port),
    CODEX_BIN: codexScriptPath,
    AGENT_DATA_DIR: dataDir,
    CODEX_HOME: isolatedCodexHome,
  });

  try {
    const createProject = await httpJson({
      port,
      token,
      method: 'POST',
      pathname: '/api/projects',
      body: { name: 'Alpha Workspace', cwd: 'D:\\remote-agent' },
    });

    assert.equal(createProject.statusCode, 201);
    assert.equal(createProject.body.project.name, 'Alpha Workspace');

    const createThread = await httpJson({
      port,
      token,
      method: 'POST',
      pathname: '/api/threads',
      body: {
        projectId: createProject.body.project.id,
        title: 'First thread',
        engine: 'codex',
      },
    });

    assert.equal(createThread.statusCode, 201);
    assert.equal(createThread.body.thread.projectId, createProject.body.project.id);

    const chat = await postSse({
      port,
      token,
      body: {
        engine: 'codex',
        prompt: 'hello world',
        cwd: 'D:\\remote-agent',
        threadId: createThread.body.thread.id,
      },
    });

    assert.equal(chat.statusCode, 200);
    assert.match(chat.body, /Stored reply from fake codex/);

    const threads = await httpJson({
      port,
      token,
      method: 'GET',
      pathname: '/api/threads',
    });

    assert.equal(threads.statusCode, 200);
    assert.equal(threads.body.threads.length, 1);
    assert.equal(threads.body.threads[0].messageCount, 2);

    const messages = await httpJson({
      port,
      token,
      method: 'GET',
      pathname: `/api/threads/${createThread.body.thread.id}/messages`,
    });

    assert.equal(messages.statusCode, 200);
    assert.equal(messages.body.messages[0].role, 'user');
    assert.equal(messages.body.messages[0].text, 'hello world');
    assert.equal(messages.body.messages[1].role, 'assistant');
    assert.match(messages.body.messages[1].text, /Stored reply from fake codex/);

    const persisted = JSON.parse(
      await fsp.readFile(path.join(dataDir, 'agent-state.json'), 'utf8')
    );

    assert.equal(persisted.projects.length, 1);
    assert.equal(persisted.threads.length, 1);
    assert.equal(persisted.messages.length, 2);
  } finally {
    await stopChild(server.child);
    await fsp.rm(tempDir, { recursive: true, force: true });
  }
});

test('server mirrors Codex workspace roots, threads, and rollout messages when Codex state is available', async () => {
  const tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'remote-agent-codex-sync-'));
  const codexHome = path.join(tempDir, '.codex');
  const sessionsDir = path.join(codexHome, 'sessions', '2026', '04', '01');
  await fsp.mkdir(sessionsDir, { recursive: true });

  const rolloutPath = path.join(
    sessionsDir,
    'rollout-2026-04-01T08-04-57-019d465b-8876-7f30-8812-3a4a3cd597e1.jsonl'
  );

  await fsp.writeFile(
    path.join(codexHome, '.codex-global-state.json'),
    JSON.stringify({
      'electron-saved-workspace-roots': ['D:\\remote-agent', 'D:\\ji_paiban'],
      'active-workspace-roots': ['D:\\ji_paiban'],
      'project-order': ['D:\\remote-agent', 'D:\\ji_paiban'],
      'thread-workspace-root-hints': {
        '019d465b-8876-7f30-8812-3a4a3cd597e1': 'D:\\remote-agent',
      },
    }, null, 2)
  );

  const db = new DatabaseSync(path.join(codexHome, 'state_5.sqlite'));
  db.exec(`
    CREATE TABLE threads (
      id TEXT PRIMARY KEY,
      rollout_path TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      source TEXT NOT NULL,
      model_provider TEXT NOT NULL,
      cwd TEXT NOT NULL,
      title TEXT NOT NULL,
      sandbox_policy TEXT NOT NULL,
      approval_mode TEXT NOT NULL,
      tokens_used INTEGER NOT NULL DEFAULT 0,
      has_user_event INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      archived_at INTEGER,
      git_sha TEXT,
      git_branch TEXT,
      git_origin_url TEXT,
      cli_version TEXT NOT NULL DEFAULT '',
      first_user_message TEXT NOT NULL DEFAULT '',
      agent_nickname TEXT,
      agent_role TEXT,
      memory_mode TEXT NOT NULL DEFAULT 'enabled',
      model TEXT,
      reasoning_effort TEXT,
      agent_path TEXT
    );
  `);
  db.prepare(`
    INSERT INTO threads (
      id, rollout_path, created_at, updated_at, source, model_provider, cwd, title,
      sandbox_policy, approval_mode, tokens_used, has_user_event, archived, cli_version,
      first_user_message, memory_mode, model, reasoning_effort
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    '019d465b-8876-7f30-8812-3a4a3cd597e1',
    rolloutPath,
    1775001897,
    1775031335,
    'vscode',
    'custom',
    'D:\\remote-agent',
    '拉起根本不生成日志，然后闪退',
    '{"type":"danger-full-access"}',
    'never',
    22093882,
    0,
    0,
    '0.118.0-alpha.2',
    '拉起根本不生成日志，然后闪退',
    'enabled',
    'gpt-5.4',
    'high'
  );
  db.close();

  await fsp.writeFile(
    rolloutPath,
    [
      JSON.stringify({
        timestamp: '2026-04-01T00:05:01.488Z',
        type: 'event_msg',
        payload: {
          type: 'user_message',
          message: '拉起根本不生成日志，然后闪退',
        },
      }),
      JSON.stringify({
        timestamp: '2026-04-01T00:05:11.681Z',
        type: 'event_msg',
        payload: {
          type: 'agent_message',
          message: '我先按“启动即闪退”方向排查。',
        },
      }),
      '',
    ].join('\n')
  );

  const dataDir = path.join(tempDir, 'state');
  const port = await getFreePort();
  const token = 'test-token';
  const server = await startServer({
    AUTH_TOKEN: token,
    PORT: String(port),
    AGENT_DATA_DIR: dataDir,
    CODEX_HOME: codexHome,
  });

  try {
    const projects = await httpJson({
      port,
      token,
      method: 'GET',
      pathname: '/api/projects',
    });

    assert.equal(projects.statusCode, 200);
    assert.deepEqual(
      projects.body.projects.map((project) => project.cwd),
      ['D:\\remote-agent', 'D:\\ji_paiban']
    );
    assert.equal(projects.body.projects[1].isActive, true);

    const threads = await httpJson({
      port,
      token,
      method: 'GET',
      pathname: '/api/threads?projectId=D%3A%5Cremote-agent',
    });

    assert.equal(threads.statusCode, 200);
    assert.equal(threads.body.threads.length, 1);
    assert.equal(threads.body.threads[0].id, '019d465b-8876-7f30-8812-3a4a3cd597e1');
    assert.equal(threads.body.threads[0].source, 'codex');
    assert.equal(threads.body.threads[0].projectId, 'D:\\remote-agent');

    const messages = await httpJson({
      port,
      token,
      method: 'GET',
      pathname: '/api/threads/019d465b-8876-7f30-8812-3a4a3cd597e1/messages',
    });

    assert.equal(messages.statusCode, 200);
    assert.deepEqual(
      messages.body.messages.map((message) => [message.role, message.text]),
      [
        ['user', '拉起根本不生成日志，然后闪退'],
        ['assistant', '我先按“启动即闪退”方向排查。'],
      ]
    );
  } finally {
    await stopChild(server.child);
    await fsp.rm(tempDir, { recursive: true, force: true });
  }
});
