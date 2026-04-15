# Android Agent Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Mac-only Codex daemon and Flutter Android client that replace the current Windows-first web wrapper with a mobile-first multi-conversation workbench.

**Architecture:** Keep execution and durable state on the Mac in a dedicated `daemon/` service, and move all phone UX into a new `app/` Flutter client. The daemon owns project discovery from `~/code`, conversation/run persistence, Codex child-process control, and WebSocket events; the app owns project switching, conversation switching, live action/error visibility, and normal chat-style input.

**Tech Stack:** Node.js 24, Express, `ws`, SQLite via `node:sqlite`, `node:test`, Flutter, `flutter_test`, `http`, `web_socket_channel`, `shared_preferences`

---

### Task 1: Create the Mac Daemon Skeleton

**Files:**
- Create: `daemon/package.json`
- Create: `daemon/src/config.js`
- Create: `daemon/src/http/app.js`
- Create: `daemon/src/index.js`
- Test: `daemon/tests/ping.test.js`

- [ ] **Step 1: Write the failing daemon boot test**

```js
// daemon/tests/ping.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');
const http = require('node:http');

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

  await new Promise((resolve, reject) => {
    child.stdout.on('data', (chunk) => {
      if (chunk.toString().includes('[daemon] listening')) resolve();
    });
    child.once('error', reject);
    child.once('close', (code) => reject(new Error(`daemon exited with ${code}`)));
  });

  const response = await getJson(4311, '/health');
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.ok, true);
  assert.equal(response.body.product, 'android-agent-workbench-daemon');

  child.kill('SIGTERM');
});
```

- [ ] **Step 2: Run the test to confirm the daemon does not exist yet**

Run: `node --test daemon/tests/ping.test.js`  
Expected: FAIL with `Cannot find module .../daemon/src/index.js`

- [ ] **Step 3: Add the initial daemon package and HTTP app**

```json
// daemon/package.json
{
  "name": "android-agent-workbench-daemon",
  "private": true,
  "type": "commonjs",
  "scripts": {
    "dev": "node --watch src/index.js",
    "test": "node --test tests/*.test.js"
  },
  "dependencies": {
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "ws": "^8.18.0"
  }
}
```

```js
// daemon/src/config.js
const os = require('node:os');
const path = require('node:path');

function loadConfig() {
  return {
    port: Number(process.env.PORT || 3333),
    host: process.env.HOST || '127.0.0.1',
    workspaceRoot: process.env.WORKSPACE_ROOT || path.join(os.homedir(), 'code'),
    daemonDataDir: process.env.DAEMON_DATA_DIR || path.join(os.homedir(), '.remote-code-agent'),
    codexBin: process.env.CODEX_BIN || 'codex',
  };
}

module.exports = {
  loadConfig,
};
```

```js
// daemon/src/http/app.js
const express = require('express');

function createApp() {
  const app = express();
  app.use(express.json({ limit: '1mb' }));
  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      product: 'android-agent-workbench-daemon',
      time: new Date().toISOString(),
    });
  });
  return app;
}

module.exports = {
  createApp,
};
```

```js
// daemon/src/index.js
require('dotenv').config();
const { createApp } = require('./http/app');
const { loadConfig } = require('./config');

const config = loadConfig();
const app = createApp();

app.listen(config.port, config.host, () => {
  console.log(`[daemon] listening on http://${config.host}:${config.port}`);
});
```

- [ ] **Step 4: Run the daemon test again**

Run: `node --test daemon/tests/ping.test.js`  
Expected: PASS with `ok 1 - daemon exposes a health endpoint`

- [ ] **Step 5: Commit the daemon scaffold**

```bash
git add daemon/package.json daemon/src/config.js daemon/src/http/app.js daemon/src/index.js daemon/tests/ping.test.js
git commit -m "feat: scaffold mac daemon service"
```

### Task 2: Add SQLite Persistence and Project Discovery

**Files:**
- Create: `daemon/src/db/schema.sql`
- Create: `daemon/src/db/open-db.js`
- Create: `daemon/src/db/migrate.js`
- Create: `daemon/src/projects/workspace-scanner.js`
- Create: `daemon/src/projects/project-service.js`
- Modify: `daemon/src/http/app.js`
- Test: `daemon/tests/projects.test.js`

- [ ] **Step 1: Write the failing project discovery and metadata test**

```js
// daemon/tests/projects.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createProjectService } = require('../src/projects/project-service');

test('project service lists first-level folders from the workspace root and merges metadata', () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-workspace-'));
  const workspaceRoot = path.join(tempRoot, 'code');
  const dataDir = path.join(tempRoot, 'data');
  fs.mkdirSync(workspaceRoot, { recursive: true });
  fs.mkdirSync(path.join(workspaceRoot, 'alpha-api'));
  fs.mkdirSync(path.join(workspaceRoot, 'beta-admin'));

  const db = openDatabase({ daemonDataDir: dataDir });
  migrate(db);
  db.prepare(`
    INSERT INTO project_metadata (project_id, pinned, last_opened_at, last_active_conversation_id)
    VALUES (?, 1, '2026-04-15T10:00:00.000Z', 'conv-9')
  `).run(path.join(workspaceRoot, 'beta-admin'));

  const service = createProjectService({ workspaceRoot, db });
  const projects = service.listProjects();

  assert.deepEqual(
    projects.map((project) => ({
      name: project.name,
      path: project.path,
      pinned: project.pinned,
      lastActiveConversationId: project.lastActiveConversationId,
    })),
    [
      {
        name: 'beta-admin',
        path: path.join(workspaceRoot, 'beta-admin'),
        pinned: true,
        lastActiveConversationId: 'conv-9',
      },
      {
        name: 'alpha-api',
        path: path.join(workspaceRoot, 'alpha-api'),
        pinned: false,
        lastActiveConversationId: null,
      },
    ],
  );
});
```

- [ ] **Step 2: Run the test to verify the persistence layer is missing**

Run: `node --test daemon/tests/projects.test.js`  
Expected: FAIL with `Cannot find module '../src/db/open-db'`

- [ ] **Step 3: Add the database bootstrap, schema, and project service**

```sql
-- daemon/src/db/schema.sql
CREATE TABLE IF NOT EXISTS project_metadata (
  project_id TEXT PRIMARY KEY,
  pinned INTEGER NOT NULL DEFAULT 0,
  last_opened_at TEXT,
  last_active_conversation_id TEXT
);

CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  role TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS runs (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  status TEXT NOT NULL,
  requires_confirmation INTEGER NOT NULL DEFAULT 0,
  started_at TEXT NOT NULL,
  ended_at TEXT
);

CREATE TABLE IF NOT EXISTS run_events (
  id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

```js
// daemon/src/db/open-db.js
const fs = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');

function openDatabase({ daemonDataDir }) {
  fs.mkdirSync(daemonDataDir, { recursive: true });
  return new DatabaseSync(path.join(daemonDataDir, 'agent-workbench.sqlite'));
}

module.exports = {
  openDatabase,
};
```

```js
// daemon/src/db/migrate.js
const fs = require('node:fs');
const path = require('node:path');

function migrate(db) {
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  db.exec(schema);
}

module.exports = {
  migrate,
};
```

```js
// daemon/src/projects/workspace-scanner.js
const fs = require('node:fs');
const path = require('node:path');

function listWorkspaceProjects(workspaceRoot) {
  return fs.readdirSync(workspaceRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => ({
      id: path.join(workspaceRoot, entry.name),
      name: entry.name,
      path: path.join(workspaceRoot, entry.name),
    }))
    .sort((left, right) => left.name.localeCompare(right.name));
}

module.exports = {
  listWorkspaceProjects,
};
```

```js
// daemon/src/projects/project-service.js
const { listWorkspaceProjects } = require('./workspace-scanner');

function createProjectService({ workspaceRoot, db }) {
  const selectMetadata = db.prepare(`
    SELECT project_id, pinned, last_opened_at, last_active_conversation_id
    FROM project_metadata
    WHERE project_id = ?
  `);

  function listProjects() {
    return listWorkspaceProjects(workspaceRoot)
      .map((project) => {
        const metadata = selectMetadata.get(project.id);
        return {
          ...project,
          pinned: Boolean(metadata?.pinned),
          lastOpenedAt: metadata?.last_opened_at || null,
          lastActiveConversationId: metadata?.last_active_conversation_id || null,
        };
      })
      .sort((left, right) => {
        if (left.pinned !== right.pinned) return left.pinned ? -1 : 1;
        return left.name.localeCompare(right.name);
      });
  }

  return {
    listProjects,
  };
}

module.exports = {
  createProjectService,
};
```

```js
// daemon/src/http/app.js
const express = require('express');

function createApp({ projectService }) {
  const app = express();
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({ ok: true, product: 'android-agent-workbench-daemon', time: new Date().toISOString() });
  });

  app.get('/projects', (_req, res) => {
    res.json({ projects: projectService.listProjects() });
  });

  return app;
}

module.exports = {
  createApp,
};
```

- [ ] **Step 4: Run the project tests**

Run: `node --test daemon/tests/projects.test.js`  
Expected: PASS with `ok 1 - project service lists first-level folders from the workspace root and merges metadata`

- [ ] **Step 5: Commit the persistence and project discovery baseline**

```bash
git add daemon/src/db/schema.sql daemon/src/db/open-db.js daemon/src/db/migrate.js daemon/src/projects/workspace-scanner.js daemon/src/projects/project-service.js daemon/src/http/app.js daemon/tests/projects.test.js
git commit -m "feat: add sqlite-backed project discovery"
```

### Task 3: Add Conversations and Messages APIs

**Files:**
- Create: `daemon/src/conversations/conversation-repo.js`
- Create: `daemon/src/conversations/message-repo.js`
- Create: `daemon/src/conversations/conversation-service.js`
- Modify: `daemon/src/http/app.js`
- Modify: `daemon/src/index.js`
- Test: `daemon/tests/conversations.test.js`

- [ ] **Step 1: Write the failing conversation API test**

```js
// daemon/tests/conversations.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createConversationService } = require('../src/conversations/conversation-service');

test('conversation service creates a conversation and appends a user message', () => {
  const db = openDatabase({ daemonDataDir: `/tmp/${randomUUID()}` });
  migrate(db);

  const service = createConversationService({ db });
  const conversation = service.createConversation({
    projectId: '/Users/rex/code/alpha-api',
    title: '修复支付回调',
    openingMessage: '先看为什么重复入库',
  });

  const conversations = service.listConversations('/Users/rex/code/alpha-api');
  const messages = service.listMessages(conversation.id);

  assert.equal(conversations.length, 1);
  assert.equal(conversations[0].status, 'idle');
  assert.equal(messages.length, 1);
  assert.equal(messages[0].role, 'user');
  assert.equal(messages[0].text, '先看为什么重复入库');
});
```

- [ ] **Step 2: Run the conversation test**

Run: `node --test daemon/tests/conversations.test.js`  
Expected: FAIL with `Cannot find module '../src/conversations/conversation-service'`

- [ ] **Step 3: Add the conversation repository and service**

```js
// daemon/src/conversations/conversation-repo.js
const { randomUUID } = require('node:crypto');

function createConversationRepo(db) {
  const insertConversation = db.prepare(`
    INSERT INTO conversations (id, project_id, title, status, archived, created_at, updated_at)
    VALUES (?, ?, ?, ?, 0, ?, ?)
  `);
  const listByProject = db.prepare(`
    SELECT id, project_id, title, status, created_at, updated_at
    FROM conversations
    WHERE project_id = ? AND archived = 0
    ORDER BY updated_at DESC
  `);

  return {
    create({ projectId, title, now }) {
      const id = randomUUID();
      insertConversation.run(id, projectId, title, 'idle', now, now);
      return { id, projectId, title, status: 'idle', createdAt: now, updatedAt: now };
    },
    list(projectId) {
      return listByProject.all(projectId).map((row) => ({
        id: row.id,
        projectId: row.project_id,
        title: row.title,
        status: row.status,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }));
    },
  };
}

module.exports = {
  createConversationRepo,
};
```

```js
// daemon/src/conversations/message-repo.js
const { randomUUID } = require('node:crypto');

function createMessageRepo(db) {
  const insertMessage = db.prepare(`
    INSERT INTO messages (id, conversation_id, role, text, created_at)
    VALUES (?, ?, ?, ?, ?)
  `);
  const listByConversation = db.prepare(`
    SELECT id, conversation_id, role, text, created_at
    FROM messages
    WHERE conversation_id = ?
    ORDER BY created_at ASC
  `);

  return {
    create({ conversationId, role, text, now }) {
      const id = randomUUID();
      insertMessage.run(id, conversationId, role, text, now);
      return { id, conversationId, role, text, createdAt: now };
    },
    list(conversationId) {
      return listByConversation.all(conversationId).map((row) => ({
        id: row.id,
        conversationId: row.conversation_id,
        role: row.role,
        text: row.text,
        createdAt: row.created_at,
      }));
    },
  };
}

module.exports = {
  createMessageRepo,
};
```

```js
// daemon/src/conversations/conversation-service.js
const { createConversationRepo } = require('./conversation-repo');
const { createMessageRepo } = require('./message-repo');

function createConversationService({ db }) {
  const conversationRepo = createConversationRepo(db);
  const messageRepo = createMessageRepo(db);

  return {
    createConversation({ projectId, title, openingMessage }) {
      const now = new Date().toISOString();
      const conversation = conversationRepo.create({ projectId, title, now });
      if (openingMessage && openingMessage.trim()) {
        messageRepo.create({
          conversationId: conversation.id,
          role: 'user',
          text: openingMessage.trim(),
          now,
        });
      }
      return conversation;
    },
    listConversations(projectId) {
      return conversationRepo.list(projectId);
    },
    appendUserMessage({ conversationId, text }) {
      return messageRepo.create({
        conversationId,
        role: 'user',
        text: text.trim(),
        now: new Date().toISOString(),
      });
    },
    listMessages(conversationId) {
      return messageRepo.list(conversationId);
    },
  };
}

module.exports = {
  createConversationService,
};
```

```js
// daemon/src/http/app.js
app.get('/projects/:projectId/conversations', (req, res) => {
  res.json({ conversations: conversationService.listConversations(req.params.projectId) });
});

app.post('/projects/:projectId/conversations', (req, res) => {
  const conversation = conversationService.createConversation({
    projectId: req.params.projectId,
    title: req.body.title,
    openingMessage: req.body.openingMessage,
  });
  res.status(201).json({ conversation });
});

app.get('/conversations/:conversationId/messages', (req, res) => {
  res.json({ messages: conversationService.listMessages(req.params.conversationId) });
});

app.post('/conversations/:conversationId/messages', (req, res) => {
  const message = conversationService.appendUserMessage({
    conversationId: req.params.conversationId,
    text: req.body.text,
  });
  res.status(201).json({ message });
});
```

- [ ] **Step 4: Run the conversation tests**

Run: `node --test daemon/tests/conversations.test.js`  
Expected: PASS with `ok 1 - conversation service creates a conversation and appends a user message`

- [ ] **Step 5: Commit the conversation model**

```bash
git add daemon/src/conversations/conversation-repo.js daemon/src/conversations/message-repo.js daemon/src/conversations/conversation-service.js daemon/src/http/app.js daemon/tests/conversations.test.js
git commit -m "feat: add conversation and message storage"
```

### Task 4: Add Run Persistence and Codex Process Control

**Files:**
- Create: `daemon/src/runs/build-codex-command.js`
- Create: `daemon/src/runs/codex-line-parser.js`
- Create: `daemon/src/runs/run-service.js`
- Modify: `daemon/src/http/app.js`
- Test: `daemon/tests/runs.test.js`

- [ ] **Step 1: Write the failing run lifecycle test**

```js
// daemon/tests/runs.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createConversationService } = require('../src/conversations/conversation-service');
const { createRunService } = require('../src/runs/run-service');

test('run service persists action events, assistant output, and completion state', async () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'run-service-'));
  const fakeCodex = path.join(tempRoot, 'fake-codex.sh');
  fs.writeFileSync(fakeCodex, [
    '#!/usr/bin/env bash',
    'printf \'{"type":"action","name":"reading files"}\\n\'',
    'printf \'{"type":"assistant","text":"已定位到问题文件。"}\\n\'',
    'printf \'{"type":"error","message":"API unavailable"}\\n\'',
  ].join('\n'));
  fs.chmodSync(fakeCodex, 0o755);

  const db = openDatabase({ daemonDataDir: path.join(tempRoot, 'data') });
  migrate(db);

  const conversationService = createConversationService({ db });
  const conversation = conversationService.createConversation({
    projectId: '/Users/rex/code/alpha-api',
    title: '排查接口失败',
    openingMessage: '看下为什么超时',
  });

  const runService = createRunService({ db, codexBin: fakeCodex });
  const run = await runService.startRun({
    conversationId: conversation.id,
    cwd: '/Users/rex/code/alpha-api',
    prompt: '看下为什么超时',
  });

  assert.equal(run.status, 'completed');
  const events = runService.listRunEvents(run.id);
  assert.equal(events[0].kind, 'run.action');
  assert.equal(events[1].kind, 'message.created');
  assert.equal(events[2].kind, 'run.error');
});
```

- [ ] **Step 2: Run the run test**

Run: `node --test daemon/tests/runs.test.js`  
Expected: FAIL with `Cannot find module '../src/runs/run-service'`

- [ ] **Step 3: Add the run repository, parser, and service**

```js
// daemon/src/runs/build-codex-command.js
function buildCodexCommand({ codexBin, prompt }) {
  return {
    command: codexBin,
    args: ['exec', '--skip-git-repo-check', prompt],
  };
}

module.exports = {
  buildCodexCommand,
};
```

```js
// daemon/src/runs/codex-line-parser.js
function parseCodexLine(line) {
  const payload = JSON.parse(line);
  if (payload.type === 'assistant') {
    return { kind: 'message.created', payload: { role: 'assistant', text: payload.text } };
  }
  if (payload.type === 'action') {
    return { kind: 'run.action', payload: { label: payload.name } };
  }
  if (payload.type === 'error') {
    return { kind: 'run.error', payload: { message: payload.message } };
  }
  return { kind: 'run.chunk', payload };
}

module.exports = {
  parseCodexLine,
};
```

```js
// daemon/src/runs/run-service.js
const { spawn } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const readline = require('node:readline');
const { buildCodexCommand } = require('./build-codex-command');
const { parseCodexLine } = require('./codex-line-parser');

function createRunService({ db, codexBin, eventBroker = null }) {
  const activeRuns = new Map();
  const insertRun = db.prepare(`
    INSERT INTO runs (id, conversation_id, status, requires_confirmation, started_at, ended_at)
    VALUES (?, ?, ?, 0, ?, NULL)
  `);
  const updateRun = db.prepare(`UPDATE runs SET status = ?, ended_at = ? WHERE id = ?`);
  const insertMessage = db.prepare(`
    INSERT INTO messages (id, conversation_id, role, text, created_at)
    VALUES (?, ?, ?, ?, ?)
  `);
  const insertEvent = db.prepare(`
    INSERT INTO run_events (id, run_id, kind, payload_json, created_at)
    VALUES (?, ?, ?, ?, ?)
  `);
  const selectEvents = db.prepare(`
    SELECT kind, payload_json, created_at
    FROM run_events
    WHERE run_id = ?
    ORDER BY created_at ASC
  `);

  async function startRun({ conversationId, cwd, prompt }) {
    const runId = randomUUID();
    const startedAt = new Date().toISOString();
    insertRun.run(runId, conversationId, 'running', startedAt);

    const { command, args } = buildCodexCommand({ codexBin, prompt });
    const child = spawn(command, args, { cwd, stdio: ['pipe', 'pipe', 'pipe'] });
    activeRuns.set(runId, child);
    const stream = readline.createInterface({ input: child.stdout });

    if (eventBroker) {
      eventBroker.publish({ kind: 'run.started', runId, conversationId, createdAt: startedAt });
    }

    try {
      for await (const line of stream) {
        const event = parseCodexLine(line);
        const createdAt = new Date().toISOString();
        insertEvent.run(randomUUID(), runId, event.kind, JSON.stringify(event.payload), createdAt);
        if (event.kind === 'message.created') {
          insertMessage.run(randomUUID(), conversationId, event.payload.role, event.payload.text, createdAt);
        }
        if (eventBroker) eventBroker.publish({ runId, ...event, createdAt });
      }
    } finally {
      activeRuns.delete(runId);
    }

    const endedAt = new Date().toISOString();
    updateRun.run('completed', endedAt, runId);
    if (eventBroker) eventBroker.publish({ kind: 'run.completed', runId, createdAt: endedAt });
    return { id: runId, conversationId, status: 'completed', startedAt, endedAt };
  }

  function listRunEvents(runId) {
    return selectEvents.all(runId).map((row) => ({
      kind: row.kind,
      payload: JSON.parse(row.payload_json),
      createdAt: row.created_at,
    }));
  }

  function interruptRun(runId) {
    const child = activeRuns.get(runId);
    if (!child) return false;
    child.kill('SIGINT');
    activeRuns.delete(runId);
    if (eventBroker) {
      eventBroker.publish({ kind: 'run.interrupted', runId, createdAt: new Date().toISOString() });
    }
    return true;
  }

  async function confirmRun(runId) {
    const child = activeRuns.get(runId);
    if (!child) return { ok: false };
    child.stdin.write('y\n');
    if (eventBroker) {
      eventBroker.publish({ kind: 'run.waiting_confirmation', runId, createdAt: new Date().toISOString() });
    }
    return { ok: true };
  }

  return {
    startRun,
    listRunEvents,
    interruptRun,
    confirmRun,
  };
}

module.exports = {
  createRunService,
};
```

```js
// daemon/src/http/app.js
app.post('/conversations/:conversationId/runs', async (req, res, next) => {
  try {
    const run = await runService.startRun({
      conversationId: req.params.conversationId,
      cwd: req.body.cwd,
      prompt: req.body.prompt,
    });
    res.status(201).json({ run });
  } catch (error) {
    next(error);
  }
});
```

- [ ] **Step 4: Run the run lifecycle tests**

Run: `node --test daemon/tests/runs.test.js`  
Expected: PASS with `ok 1 - run service persists action events, assistant output, and completion state`

- [ ] **Step 5: Commit the Codex run foundation**

```bash
git add daemon/src/runs/build-codex-command.js daemon/src/runs/codex-line-parser.js daemon/src/runs/run-service.js daemon/src/http/app.js daemon/tests/runs.test.js
git commit -m "feat: add codex run lifecycle persistence"
```

### Task 5: Add Confirmation, Interrupt, and Realtime Events

**Files:**
- Create: `daemon/src/realtime/event-broker.js`
- Create: `daemon/src/realtime/ws-server.js`
- Modify: `daemon/src/runs/run-service.js`
- Modify: `daemon/src/http/app.js`
- Modify: `daemon/src/index.js`
- Test: `daemon/tests/realtime.test.js`

- [ ] **Step 1: Write the failing realtime test**

```js
// daemon/tests/realtime.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { EventBroker } = require('../src/realtime/event-broker');

test('event broker replays published events to subscribers', async () => {
  const broker = new EventBroker();
  const seen = [];
  const unsubscribe = broker.subscribe((event) => {
    seen.push(event);
  });

  broker.publish({ kind: 'run.started', runId: 'run-1' });
  broker.publish({ kind: 'run.action', runId: 'run-1', payload: { label: 'reading files' } });
  unsubscribe();

  assert.deepEqual(seen, [
    { kind: 'run.started', runId: 'run-1' },
    { kind: 'run.action', runId: 'run-1', payload: { label: 'reading files' } },
  ]);
});
```

- [ ] **Step 2: Run the realtime test**

Run: `node --test daemon/tests/realtime.test.js`  
Expected: FAIL with `Cannot find module '../src/realtime/event-broker'`

- [ ] **Step 3: Add the broker, WebSocket bridge, and run controls**

```js
// daemon/src/realtime/event-broker.js
class EventBroker {
  constructor() {
    this.listeners = new Set();
  }

  subscribe(listener) {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  publish(event) {
    for (const listener of this.listeners) {
      listener(event);
    }
  }
}

module.exports = {
  EventBroker,
};
```

```js
// daemon/src/realtime/ws-server.js
const { WebSocketServer } = require('ws');

function attachWebSocketServer(server, eventBroker) {
  const wss = new WebSocketServer({ server, path: '/ws' });
  eventBroker.subscribe((event) => {
    const payload = JSON.stringify(event);
    for (const client of wss.clients) {
      if (client.readyState === 1) {
        client.send(payload);
      }
    }
  });
  return wss;
}

module.exports = {
  attachWebSocketServer,
};
```

```js
// daemon/src/runs/run-service.js
function interruptRun(runId) {
  const child = activeRuns.get(runId);
  if (!child) return false;
  child.kill('SIGINT');
  activeRuns.delete(runId);
  updateRun.run('interrupted', new Date().toISOString(), runId);
  if (eventBroker) {
    eventBroker.publish({ kind: 'run.interrupted', runId, createdAt: new Date().toISOString() });
  }
  return true;
}

async function confirmRun(runId) {
  const child = activeRuns.get(runId);
  if (!child) return { ok: false };
  child.stdin.write('y\n');
  if (eventBroker) {
    eventBroker.publish({ kind: 'run.waiting_confirmation', runId, createdAt: new Date().toISOString() });
  }
  return { ok: true };
}

return {
  startRun,
  listRunEvents,
  interruptRun,
  confirmRun,
};
```

```js
// daemon/src/http/app.js
app.post('/runs/:runId/interrupt', (req, res) => {
  const ok = runService.interruptRun(req.params.runId);
  res.status(ok ? 200 : 404).json({ ok });
});

app.post('/runs/:runId/confirm', async (req, res) => {
  const result = await runService.confirmRun(req.params.runId);
  res.json(result);
});
```

```js
// daemon/src/index.js
require('dotenv').config();
const { loadConfig } = require('./config');
const { createApp } = require('./http/app');
const { openDatabase } = require('./db/open-db');
const { migrate } = require('./db/migrate');
const { createProjectService } = require('./projects/project-service');
const { createConversationService } = require('./conversations/conversation-service');
const { createRunService } = require('./runs/run-service');
const { EventBroker } = require('./realtime/event-broker');
const { attachWebSocketServer } = require('./realtime/ws-server');

const config = loadConfig();
const db = openDatabase({ daemonDataDir: config.daemonDataDir });
migrate(db);

const eventBroker = new EventBroker();
const projectService = createProjectService({ workspaceRoot: config.workspaceRoot, db });
const conversationService = createConversationService({ db });
const runService = createRunService({ db, codexBin: config.codexBin, eventBroker });

const app = createApp({ projectService, conversationService, runService });
const server = app.listen(config.port, config.host, () => {
  console.log(`[daemon] listening on http://${config.host}:${config.port}`);
});

attachWebSocketServer(server, eventBroker);
```

- [ ] **Step 4: Run the realtime tests and the whole daemon suite**

Run: `node --test daemon/tests/*.test.js`  
Expected: PASS with `ok` lines for `ping`, `projects`, `conversations`, `runs`, and `realtime`

- [ ] **Step 5: Commit the realtime control layer**

```bash
git add daemon/src/realtime/event-broker.js daemon/src/realtime/ws-server.js daemon/src/runs/run-service.js daemon/src/http/app.js daemon/src/index.js daemon/tests/realtime.test.js
git commit -m "feat: add realtime updates and run controls"
```

### Task 6: Scaffold the Flutter App and Project Workspace

**Files:**
- Create: `app/pubspec.yaml`
- Create: `app/lib/main.dart`
- Create: `app/lib/app.dart`
- Create: `app/lib/src/data/api_client.dart`
- Create: `app/lib/src/models/project_summary.dart`
- Create: `app/lib/src/models/conversation_summary.dart`
- Create: `app/lib/src/features/projects/project_home_screen.dart`
- Create: `app/lib/src/features/workspace/workspace_screen.dart`
- Create: `app/lib/src/features/workspace/conversation_strip.dart`
- Test: `app/test/project_home_screen_test.dart`
- Test: `app/test/workspace_screen_test.dart`

- [ ] **Step 1: Write the failing widget tests for project and workspace entry**

```dart
// app/test/project_home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/app.dart';

void main() {
  testWidgets('shows the pinned project list and opens a workspace', (tester) async {
    await tester.pumpWidget(const AgentWorkbenchApp());

    expect(find.text('Projects'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsWidgets);
  });
}
```

```dart
// app/test/workspace_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/features/workspace/workspace_screen.dart';
import 'package:agent_workbench/src/models/conversation_summary.dart';

void main() {
  testWidgets('renders a horizontal conversation strip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          projectName: 'alpha-api',
          conversations: const [
            ConversationSummary(
              id: 'c-1',
              title: '修复支付回调',
              status: 'running',
              lastMessagePreview: '正在检查 controller',
            ),
          ],
        ),
      ),
    );

    expect(find.text('alpha-api'), findsOneWidget);
    expect(find.text('修复支付回调'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the Flutter tests before the app exists**

Run: `cd app && flutter test`  
Expected: FAIL with `No such file or directory` for `pubspec.yaml`

- [ ] **Step 3: Add the app scaffold, API client, and workspace UI**

```yaml
# app/pubspec.yaml
name: agent_workbench
publish_to: "none"
environment:
  sdk: ">=3.5.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2
  web_socket_channel: ^3.0.1
  shared_preferences: ^2.3.2
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
flutter:
  uses-material-design: true
```

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(const AgentWorkbenchApp());
}
```

```dart
// app/lib/app.dart
import 'package:flutter/material.dart';
import 'src/features/projects/project_home_screen.dart';

class AgentWorkbenchApp extends StatelessWidget {
  const AgentWorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agent Workbench',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6FEB)),
      home: const ProjectHomeScreen(),
    );
  }
}
```

```dart
// app/lib/src/models/project_summary.dart
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.path,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String path;
  final bool pinned;
}
```

```dart
// app/lib/src/models/conversation_summary.dart
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.lastMessagePreview,
  });

  final String id;
  final String title;
  final String status;
  final String lastMessagePreview;
}
```

```dart
// app/lib/src/data/api_client.dart
import '../models/project_summary.dart';
import '../models/conversation_summary.dart';

class ApiClient {
  Future<List<ProjectSummary>> fetchProjects() async {
    return const [
      ProjectSummary(id: '/Users/rex/code/alpha-api', name: 'alpha-api', path: '~/code/alpha-api', pinned: true),
      ProjectSummary(id: '/Users/rex/code/beta-admin', name: 'beta-admin', path: '~/code/beta-admin'),
    ];
  }

  Future<List<ConversationSummary>> fetchConversations(String projectId) async {
    return const [
      ConversationSummary(
        id: 'c-1',
        title: '修复支付回调',
        status: 'running',
        lastMessagePreview: '正在检查 controller',
      ),
    ];
  }
}
```

```dart
// app/lib/src/features/projects/project_home_screen.dart
import 'package:flutter/material.dart';
import '../../data/api_client.dart';
import '../../models/project_summary.dart';
import '../workspace/workspace_screen.dart';

class ProjectHomeScreen extends StatelessWidget {
  const ProjectHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ApiClient();
    return FutureBuilder<List<ProjectSummary>>(
      future: client.fetchProjects(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? const <ProjectSummary>[];
        return Scaffold(
          appBar: AppBar(title: const Text('Projects')),
          body: ListView(
            children: projects.map((project) {
              return ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(project.name),
                subtitle: Text(project.path),
                onTap: () async {
                  final conversations = await client.fetchConversations(project.id);
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WorkspaceScreen(
                      projectName: project.name,
                      conversations: conversations,
                    ),
                  ));
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
```

```dart
// app/lib/src/features/workspace/conversation_strip.dart
import 'package:flutter/material.dart';
import '../../models/conversation_summary.dart';

class ConversationStrip extends StatelessWidget {
  const ConversationStrip({
    super.key,
    required this.conversations,
  });

  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return Chip(
            avatar: CircleAvatar(child: Text(conversation.title.characters.first)),
            label: Text(conversation.title),
          );
        },
      ),
    );
  }
}
```

```dart
// app/lib/src/features/workspace/workspace_screen.dart
import 'package:flutter/material.dart';
import '../../models/conversation_summary.dart';
import 'conversation_strip.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({
    super.key,
    required this.projectName,
    required this.conversations,
  });

  final String projectName;
  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(projectName)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ConversationStrip(conversations: conversations),
          ),
          Expanded(
            child: ListView(
              children: conversations.map((conversation) {
                return ListTile(
                  title: Text(conversation.title),
                  subtitle: Text(conversation.lastMessagePreview),
                  trailing: Text(conversation.status),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the Flutter tests**

Run: `cd app && flutter test test/project_home_screen_test.dart test/workspace_screen_test.dart`  
Expected: PASS with `All tests passed`

- [ ] **Step 5: Commit the mobile shell**

```bash
git add app/pubspec.yaml app/lib/main.dart app/lib/app.dart app/lib/src/features/projects/project_home_screen.dart app/lib/src/features/workspace/conversation_strip.dart app/test/project_home_screen_test.dart app/test/workspace_screen_test.dart
git commit -m "feat: scaffold flutter mobile workspace"
```

### Task 7: Add Conversation Timeline, Action/Error Cards, and Controls

**Files:**
- Create: `app/lib/src/models/conversation_event.dart`
- Create: `app/lib/src/data/realtime_client.dart`
- Create: `app/lib/src/data/snapshot_cache.dart`
- Create: `app/lib/src/features/conversation/conversation_screen.dart`
- Create: `app/lib/src/features/conversation/conversation_timeline.dart`
- Create: `app/lib/src/features/conversation/conversation_composer.dart`
- Modify: `app/lib/src/features/workspace/workspace_screen.dart`
- Test: `app/test/conversation_screen_test.dart`

- [ ] **Step 1: Write the failing conversation screen test**

```dart
// app/test/conversation_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/features/conversation/conversation_screen.dart';
import 'package:agent_workbench/src/models/conversation_event.dart';

void main() {
  testWidgets('shows messages, action cards, error cards, and confirm/interruption controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          title: '修复支付回调',
          events: const [
            ConversationEvent.message(text: '先看为什么重复入库', role: 'user'),
            ConversationEvent.action(label: 'reading files'),
            ConversationEvent.error(message: 'API unavailable'),
          ],
          canConfirm: true,
          canInterrupt: true,
        ),
      ),
    );

    expect(find.text('reading files'), findsOneWidget);
    expect(find.text('API unavailable'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Interrupt'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the conversation screen test**

Run: `cd app && flutter test test/conversation_screen_test.dart`  
Expected: FAIL with `Target of URI doesn't exist` for `conversation_screen.dart`

- [ ] **Step 3: Add the conversation event model, timeline, and controls**

```dart
// app/lib/src/models/conversation_event.dart
class ConversationEvent {
  const ConversationEvent._({
    required this.kind,
    this.role,
    this.text,
    this.label,
    this.message,
  });

  final String kind;
  final String? role;
  final String? text;
  final String? label;
  final String? message;

  const ConversationEvent.message({required String text, required String role})
      : this._(kind: 'message', role: role, text: text);

  const ConversationEvent.action({required String label})
      : this._(kind: 'action', label: label);

  const ConversationEvent.error({required String message})
      : this._(kind: 'error', message: message);
}
```

```dart
// app/lib/src/features/conversation/conversation_timeline.dart
import 'package:flutter/material.dart';
import '../../models/conversation_event.dart';

class ConversationTimeline extends StatelessWidget {
  const ConversationTimeline({super.key, required this.events});

  final List<ConversationEvent> events;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        if (event.kind == 'action') {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.settings_suggest),
              title: Text(event.label!),
            ),
          );
        }
        if (event.kind == 'error') {
          return Card(
            color: const Color(0xFFFFE5E5),
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(event.message!),
            ),
          );
        }
        return ListTile(
          title: Text(event.text!),
          subtitle: Text(event.role!),
        );
      },
    );
  }
}
```

```dart
// app/lib/src/features/conversation/conversation_screen.dart
import 'package:flutter/material.dart';
import '../../models/conversation_event.dart';
import 'conversation_composer.dart';
import 'conversation_timeline.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({
    super.key,
    required this.title,
    required this.events,
    required this.canConfirm,
    required this.canInterrupt,
  });

  final String title;
  final List<ConversationEvent> events;
  final bool canConfirm;
  final bool canInterrupt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(child: ConversationTimeline(events: events)),
          Row(
            children: [
              if (canConfirm) FilledButton(onPressed: () {}, child: const Text('Confirm')),
              const SizedBox(width: 12),
              if (canInterrupt) OutlinedButton(onPressed: () {}, child: const Text('Interrupt')),
            ],
          ),
          const ConversationComposer(),
        ],
      ),
    );
  }
}
```

```dart
// app/lib/src/features/conversation/conversation_composer.dart
import 'package:flutter/material.dart';

class ConversationComposer extends StatelessWidget {
  const ConversationComposer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: TextField(
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Continue the conversation',
        ),
      ),
    );
  }
}
```

```dart
// app/lib/src/data/realtime_client.dart
import 'dart:async';
import '../models/conversation_event.dart';

class RealtimeClient {
  Stream<ConversationEvent> subscribe(String conversationId) async* {
    yield const ConversationEvent.action(label: 'reading files');
    yield const ConversationEvent.error(message: 'API unavailable');
  }
}
```

```dart
// app/lib/src/data/snapshot_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SnapshotCache {
  Future<void> write(String key, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(payload));
  }

  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
```

- [ ] **Step 4: Run the full Flutter test suite**

Run: `cd app && flutter test`  
Expected: PASS with `All tests passed`

- [ ] **Step 5: Commit the conversation UX**

```bash
git add app/lib/src/models/conversation_event.dart app/lib/src/data/snapshot_cache.dart app/lib/src/features/conversation/conversation_screen.dart app/lib/src/features/conversation/conversation_timeline.dart app/test/conversation_screen_test.dart
git commit -m "feat: add conversation timeline and controls"
```

### Task 8: Retire the Legacy Web/Windows Surface and Repoint the Repo

**Files:**
- Modify: `README.md`
- Modify: `package.json`
- Delete: `server.js`
- Delete: `agent-control-launcher.ps1`
- Delete: `agent-control.ps1`
- Delete: `start-agent.bat`
- Delete: `start-agent-debug.bat`
- Delete: `start-agent-legacy.bat`
- Delete: `src/App.vue`
- Delete: `src/main.js`
- Delete: `src/styles.css`
- Delete: `src/components/ChatComposer.vue`
- Delete: `src/components/MessageList.vue`
- Delete: `src/components/MobileSidebar.vue`
- Delete: `src/components/ProjectList.vue`
- Delete: `src/components/ThreadList.vue`
- Delete: `src/components/WorkspaceSidebar.vue`
- Delete: `public/index.html`
- Delete: `index.html`
- Delete: `lib/state-store.js`
- Delete: `lib/codex-sync-store.js`
- Delete: `tests/server-chat.test.js`
- Delete: `tests/server-startup.test.js`
- Delete: `tests/server-state.test.js`
- Delete: `tests/controller-script.test.js`
- Delete: `tests/mobile-feed.test.js`
- Delete: `tests/mobile-settings.test.js`
- Delete: `tests/mobile-shell.test.js`
- Delete: `tests/mobile-style.test.js`
- Delete: `tests/ui/app-smoke.test.mjs`
- Delete: `tests/ui/chat-composer.test.mjs`
- Delete: `tests/ui/message-list.test.mjs`
- Delete: `tests/ui/mobile-sidebar.test.mjs`
- Delete: `tests/ui/project-list.test.mjs`
- Delete: `tests/ui/thread-list.test.mjs`
- Delete: `tests/ui/workspace-sidebar.test.mjs`

- [ ] **Step 1: Write the failing repository smoke test script**

```json
// package.json
{
  "name": "remote-code-agent",
  "private": true,
  "scripts": {
    "test": "npm run test:daemon && npm run test:app",
    "test:daemon": "npm --prefix daemon test",
    "test:app": "cd app && flutter test"
  }
}
```

- [ ] **Step 2: Run the root test command before the repo is repointed**

Run: `npm test`  
Expected: FAIL because the root package still points at the legacy web/server scripts

- [ ] **Step 3: Replace the README and root scripts, then remove the legacy surface**

```md
<!-- README.md -->
# Android Agent Workbench

Mac-only Codex daemon plus Android Flutter client for managing multiple Codex conversations from a phone.

## Development

### Daemon

- `cd daemon`
- `npm install`
- `npm test`
- `npm run dev`

### App

- `cd app`
- `flutter pub get`
- `flutter test`
- `flutter run`
```

```bash
git rm server.js agent-control-launcher.ps1 agent-control.ps1 start-agent.bat start-agent-debug.bat start-agent-legacy.bat
git rm -r src public tests/ui
git rm lib/state-store.js lib/codex-sync-store.js
git rm tests/server-chat.test.js tests/server-startup.test.js tests/server-state.test.js tests/controller-script.test.js tests/mobile-feed.test.js tests/mobile-settings.test.js tests/mobile-shell.test.js tests/mobile-style.test.js
```

- [ ] **Step 4: Run the repo-level tests after cleanup**

Run: `npm test`  
Expected: PASS after delegating to `npm --prefix daemon test` and `cd app && flutter test`

- [ ] **Step 5: Commit the migration completion**

```bash
git add README.md package.json
git commit -m "refactor: retire legacy web wrapper in favor of daemon and app"
```
