# Codex Project Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror Codex desktop's saved workspace roots and thread history into the remote agent UI on every load, with fallback to the local JSON model if Codex state cannot be read.

**Architecture:** Add a focused Codex sync reader that loads workspace roots from `.codex-global-state.json`, threads from `state_5.sqlite`, and message history from rollout `.jsonl` files. Keep the existing Express endpoints stable, but have them prefer Codex-backed data for reads while preserving the current local JSON store for fallback writes and chat persistence.

**Tech Stack:** Node.js, `node:sqlite`, Express, JSON file persistence, Vitest, Node test runner

---

### Task 1: Add Codex-backed read tests

**Files:**
- Modify: `D:\remote-agent\tests\server-state.test.js`
- Test: `D:\remote-agent\tests\server-state.test.js`

- [ ] **Step 1: Write the failing test**

```js
test('server mirrors Codex workspace roots, threads, and messages when Codex state is available', async () => {
  // create fake .codex-global-state.json with project-order
  // create fake state sqlite with threads rows
  // create fake rollout jsonl with user_message and agent_message
  // assert GET /api/projects reflects Codex roots
  // assert GET /api/threads?projectId=... reflects sqlite threads
  // assert GET /api/threads/:id/messages reflects rollout messages
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test D:\remote-agent\tests\server-state.test.js`
Expected: FAIL because current server only reads the local JSON store.

- [ ] **Step 3: Keep existing local-state test intact**

```js
test('server persists projects, threads, and messages for the codex-style UI model', async () => {
  // existing fallback persistence test stays in place
})
```

- [ ] **Step 4: Run test file again**

Run: `node --test D:\remote-agent\tests\server-state.test.js`
Expected: One PASS for fallback behavior, one FAIL for missing Codex sync behavior.

### Task 2: Implement a Codex sync reader

**Files:**
- Create: `D:\remote-agent\lib\codex-sync-store.js`
- Modify: `D:\remote-agent\server.js`
- Test: `D:\remote-agent\tests\server-state.test.js`

- [ ] **Step 1: Add the Codex sync reader skeleton**

```js
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { DatabaseSync } = require('node:sqlite')

function createCodexSyncStore({ codexHomeDir } = {}) {
  const resolvedCodexHomeDir = codexHomeDir || process.env.CODEX_HOME || path.join(os.homedir(), '.codex')
  return {
    codexHomeDir: resolvedCodexHomeDir,
    isAvailable() {},
    listProjects() {},
    listThreads() {},
    listMessages() {},
  }
}

module.exports = { createCodexSyncStore }
```

- [ ] **Step 2: Implement project loading from `.codex-global-state.json`**

```js
function readGlobalState(globalStatePath) {
  return JSON.parse(fs.readFileSync(globalStatePath, 'utf8'))
}

function listProjects() {
  const state = readGlobalState(globalStatePath)
  const orderedRoots = state['project-order'] || state['electron-saved-workspace-roots'] || []
  return orderedRoots.map((cwd) => ({
    id: cwd,
    name: path.basename(cwd.replace(/^\\\\\?\\/, '')) || cwd,
    cwd,
    source: 'codex',
    isActive: (state['active-workspace-roots'] || []).includes(cwd),
  }))
}
```

- [ ] **Step 3: Implement thread loading from `state_5.sqlite`**

```js
function listThreads({ projectId } = {}) {
  const db = new DatabaseSync(stateDbPath, { readonly: true })
  const rows = db.prepare(`
    SELECT id, cwd, title, updated_at, model
    FROM threads
    WHERE archived = 0
    ORDER BY updated_at DESC
  `).all()

  return rows
    .filter((row) => !projectId || normalizeCwd(row.cwd) === normalizeCwd(projectId))
    .map((row) => ({
      id: row.id,
      projectId: normalizeCwd(row.cwd),
      title: row.title,
      engine: 'codex',
      updatedAt: new Date(row.updated_at * 1000).toISOString(),
      source: 'codex',
    }))
}
```

- [ ] **Step 4: Implement message loading from rollout `.jsonl`**

```js
function listMessages(threadId) {
  const rolloutPath = getRolloutPathForThread(threadId)
  const lines = fs.readFileSync(rolloutPath, 'utf8').split(/\r?\n/).filter(Boolean)

  return lines.flatMap((line) => {
    const record = JSON.parse(line)
    const payload = record.payload || {}
    if (record.type === 'event_msg' && payload.type === 'user_message') {
      return [{ id: `${threadId}:${record.timestamp}:user`, role: 'user', text: payload.message || '', engine: 'codex', createdAt: record.timestamp }]
    }
    if (record.type === 'event_msg' && payload.type === 'agent_message') {
      return [{ id: `${threadId}:${record.timestamp}:assistant`, role: 'assistant', text: payload.message || '', engine: 'codex', createdAt: record.timestamp }]
    }
    return []
  })
}
```

- [ ] **Step 5: Wire server read routes to prefer Codex sync**

```js
const { createCodexSyncStore } = require('./lib/codex-sync-store')
const codexSyncStore = createCodexSyncStore()

app.get('/api/projects', (req, res) => {
  const projects = codexSyncStore.isAvailable() ? codexSyncStore.listProjects() : stateStore.listProjects()
  res.json({ projects })
})
```

- [ ] **Step 6: Run the state tests**

Run: `node --test D:\remote-agent\tests\server-state.test.js`
Expected: PASS for both local fallback and Codex-backed reads.

### Task 3: Keep writes on the local model without breaking the mirrored UI

**Files:**
- Modify: `D:\remote-agent\server.js`
- Modify: `D:\remote-agent\lib\state-store.js`
- Test: `D:\remote-agent\tests\server-state.test.js`

- [ ] **Step 1: Leave POST endpoints on the fallback store**

```js
app.post('/api/projects', (req, res) => {
  const project = stateStore.createProject(...)
  res.status(201).json({ project })
})
```

- [ ] **Step 2: Make GET thread messages resolve Codex threads first, then fallback**

```js
app.get('/api/threads/:id/messages', (req, res) => {
  if (codexSyncStore.hasThread(req.params.id)) {
    return res.json({ messages: codexSyncStore.listMessages(req.params.id) })
  }
  const thread = stateStore.getThread(req.params.id)
  ...
})
```

- [ ] **Step 3: Keep `/api/chat` writing only to fallback-managed threads**

```js
if (threadId && !stateStore.getThread(threadId) && !codexSyncStore.hasThread(threadId)) {
  return res.status(404).json({ error: 'Thread not found' })
}
```

- [ ] **Step 4: Run all server tests**

Run: `npm run test:server`
Expected: PASS with no regressions in startup, chat bridge, or state tests.

### Task 4: Update the frontend to treat mirrored projects as the default source

**Files:**
- Modify: `D:\remote-agent\src\App.vue`
- Modify: `D:\remote-agent\src\components\WorkspaceSidebar.vue`
- Modify: `D:\remote-agent\tests\ui\app-smoke.test.mjs`
- Modify: `D:\remote-agent\tests\ui\workspace-sidebar.test.mjs`

- [ ] **Step 1: Add a failing UI expectation for mirrored projects**

```js
expect(wrapper.text()).toContain('remote-agent')
expect(wrapper.text()).not.toContain('项目名称，例如')
```

- [ ] **Step 2: Make the sidebar prefer mirrored projects and collapse manual creation into fallback mode**

```vue
<WorkspaceSidebar
  :show-manual-create="allowManualProjectCreation"
  ...
/>
```

- [ ] **Step 3: Set the selected project from the mirrored `isActive` project when available**

```js
if (!selectedProjectId.value) {
  const activeProject = projects.value.find((project) => project.isActive)
  selectedProjectId.value = activeProject?.id || projects.value[0]?.id || ''
}
```

- [ ] **Step 4: Run UI tests**

Run: `npm run test:ui`
Expected: PASS with mirrored-project behavior covered.

### Task 5: Final verification

**Files:**
- Modify: `D:\remote-agent\package.json` (only if a verification helper is needed)

- [ ] **Step 1: Run full automated verification**

Run: `npm test`
Expected: All server and UI tests pass.

- [ ] **Step 2: Run production build**

Run: `npm run build`
Expected: Vite build succeeds and writes `dist/` assets.

- [ ] **Step 3: Manual sanity check**

Run:

```bash
node server.js
```

Expected:
- `/api/projects` shows Codex workspace roots in Codex order
- `/api/threads?projectId=D:\remote-agent` shows Codex threads for that workspace
- `/api/threads/<codex-thread-id>/messages` returns rollout user and assistant messages
- if Codex files are unavailable, the existing local fallback still works
