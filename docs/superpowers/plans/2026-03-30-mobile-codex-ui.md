# Mobile Codex-Style UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the existing static frontend into a mobile-first, Codex-style single-session workspace while preserving the current auth flow and `Claude / Codex` backend APIs.

**Architecture:** Keep the backend unchanged and refactor the frontend in place inside `public/index.html`. Add a tiny Node built-in test harness that protects the UI contract by checking for required shell sections, mobile styles, renderer functions, and settings drawer hooks before and after each incremental change.

**Tech Stack:** Node.js, Express static hosting, plain HTML/CSS/JavaScript, Node built-in `node:test`

---

## File Structure

- Modify: `D:/remote-agent/package.json`
  - Add a `test` script for the Node built-in test runner.
- Modify: `D:/remote-agent/public/index.html`
  - Replace the current terminal-style layout with the mobile-first app shell, Codex-style feed, drawer, and refactored state/rendering logic.
- Create: `D:/remote-agent/tests/mobile-shell.test.js`
  - Verify the top bar, engine switch, feed, composer, and settings drawer shell exist.
- Create: `D:/remote-agent/tests/mobile-style.test.js`
  - Verify the mobile-first CSS contract and required UI classes exist.
- Create: `D:/remote-agent/tests/mobile-feed.test.js`
  - Verify the JavaScript state model and feed rendering functions exist.
- Create: `D:/remote-agent/tests/mobile-settings.test.js`
  - Verify the drawer and settings actions are wired in the HTML/JS contract.

## Task 1: Establish the Test Harness and App Shell

**Files:**
- Create: `D:/remote-agent/tests/mobile-shell.test.js`
- Modify: `D:/remote-agent/package.json`
- Modify: `D:/remote-agent/public/index.html`

- [ ] **Step 1: Write the failing shell contract test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'index.html'),
  'utf8'
);

test('mobile shell exposes the core Codex-style regions', () => {
  assert.match(html, /id="top-bar"/);
  assert.match(html, /id="engine-switch"/);
  assert.match(html, /id="session-feed"/);
  assert.match(html, /id="composer"/);
  assert.match(html, /id="settings-drawer"/);
});
```

- [ ] **Step 2: Run the shell test to verify it fails**

Run: `node --test tests/mobile-shell.test.js`

Expected: FAIL with an assertion showing at least one missing ID such as `id="top-bar"`.

- [ ] **Step 3: Add the test script and replace the main shell markup**

Update `D:/remote-agent/package.json`:

```json
{
  "name": "remote-code-agent",
  "version": "1.0.0",
  "description": "Remote wrapper for Claude Code & Codex CLI",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node --watch server.js",
    "test": "node --test tests/*.test.js"
  },
  "dependencies": {
    "dotenv": "^16.4.5",
    "express": "^4.19.2"
  }
}
```

Replace the current app body shell in `D:/remote-agent/public/index.html` with:

```html
<div id="app-shell" class="app-shell" style="display:none">
  <header id="top-bar" class="top-bar">
    <div class="brand-block">
      <div class="brand-kicker">Remote Agent</div>
      <div class="brand-title">Mobile Workbench</div>
    </div>
    <div class="top-actions">
      <div id="connection-pill" class="status-pill offline">
        <span class="status-dot"></span>
        <span id="status-text">Offline</span>
      </div>
      <button id="settings-toggle" class="icon-button" type="button" aria-label="Open settings">
        Settings
      </button>
    </div>
  </header>

  <section id="engine-switch" class="engine-switch" aria-label="Engine switcher">
    <button id="tab-claude" class="engine-chip active" type="button" onclick="setEngine('claude')">Claude</button>
    <button id="tab-codex" class="engine-chip" type="button" onclick="setEngine('codex')">Codex</button>
  </section>

  <main id="session-feed" class="session-feed"></main>

  <form id="composer" class="composer" onsubmit="event.preventDefault(); sendOrStop();">
    <label class="composer-label" for="prompt-input">Prompt</label>
    <div class="composer-row">
      <textarea id="prompt-input" placeholder="Tell the agent what to do" rows="3"></textarea>
      <button id="send-btn" class="send-btn" type="submit">Send</button>
    </div>
  </form>

  <aside id="settings-drawer" class="settings-drawer" aria-hidden="true">
    <div class="settings-sheet">
      <div class="settings-header">
        <h2>Session Settings</h2>
        <button id="settings-close" class="icon-button" type="button">Close</button>
      </div>
      <label class="settings-label" for="cwd-input">Working directory</label>
      <input id="cwd-input" class="settings-input" type="text" placeholder="C:\Users\name\project" />
      <button id="clear-chat-btn" class="secondary-btn" type="button">Clear session</button>
      <div id="token-summary" class="settings-meta">Token stored locally</div>
    </div>
  </aside>
</div>
```

- [ ] **Step 4: Re-run the shell test to verify it passes**

Run: `node --test tests/mobile-shell.test.js`

Expected: PASS with `ok 1 - mobile shell exposes the core Codex-style regions`

- [ ] **Step 5: Record the checkpoint in git if available**

Run: `git rev-parse --is-inside-work-tree`

Expected: `true`

If the command succeeds:

```bash
git add package.json public/index.html tests/mobile-shell.test.js
git commit -m "feat: add mobile codex app shell"
```

If the command fails because this workspace is not a Git repository, note that explicitly in the task log and continue without committing.

## Task 2: Add the Mobile-First Visual System

**Files:**
- Create: `D:/remote-agent/tests/mobile-style.test.js`
- Modify: `D:/remote-agent/public/index.html`

- [ ] **Step 1: Write the failing style contract test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'index.html'),
  'utf8'
);

test('mobile style contract is present', () => {
  assert.match(html, /\.app-shell\s*\{/);
  assert.match(html, /\.top-bar\s*\{/);
  assert.match(html, /\.engine-chip\s*\{/);
  assert.match(html, /\.run-card\s*\{/);
  assert.match(html, /\.settings-sheet\s*\{/);
  assert.match(html, /@media\s*\(min-width:\s*768px\)/);
});
```

- [ ] **Step 2: Run the style test to verify it fails**

Run: `node --test tests/mobile-style.test.js`

Expected: FAIL because the new CSS classes are not defined yet.

- [ ] **Step 3: Replace the old terminal styling with the mobile-first card system**

In the `<style>` block of `D:/remote-agent/public/index.html`, replace the current layout and component styles with:

```css
:root {
  --bg: #0b0d12;
  --panel: #121722;
  --panel-2: #181e2b;
  --panel-3: #212838;
  --border: #283042;
  --text: #ecf1ff;
  --muted: #9ba6bd;
  --accent: #7dd3fc;
  --accent-2: #9ef0b8;
  --warn: #f7b267;
  --danger: #f38ba8;
}

html, body {
  min-height: 100%;
  background:
    radial-gradient(circle at top, rgba(125, 211, 252, 0.18), transparent 28%),
    linear-gradient(180deg, #081018 0%, #0b0d12 55%, #0a0c11 100%);
  color: var(--text);
  font-family: "Inter", "Segoe UI", sans-serif;
}

.app-shell {
  min-height: 100vh;
  max-width: 760px;
  margin: 0 auto;
  padding: 18px 14px 128px;
}

.top-bar,
.engine-switch,
.composer,
.settings-sheet,
.user-card,
.run-card {
  border: 1px solid var(--border);
  background: rgba(18, 23, 34, 0.82);
  backdrop-filter: blur(14px);
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.22);
}

.top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  border-radius: 22px;
  padding: 16px 18px;
}

.engine-switch {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
  margin-top: 14px;
  border-radius: 18px;
  padding: 8px;
}

.engine-chip {
  border: 0;
  border-radius: 14px;
  padding: 12px 14px;
  background: transparent;
  color: var(--muted);
  font: inherit;
}

.engine-chip.active {
  background: linear-gradient(135deg, rgba(125, 211, 252, 0.22), rgba(158, 240, 184, 0.18));
  color: var(--text);
}

.status-pill,
.icon-button,
.secondary-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border-radius: 999px;
  border: 1px solid var(--border);
  background: rgba(33, 40, 56, 0.86);
  color: var(--text);
  padding: 10px 14px;
  font: inherit;
}

.status-pill.online .status-dot {
  background: var(--accent-2);
}

.status-pill.offline .status-dot {
  background: var(--danger);
}

.status-dot {
  width: 10px;
  height: 10px;
  border-radius: 999px;
}

.session-feed {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin-top: 16px;
}

.user-card,
.run-card {
  border-radius: 22px;
  padding: 16px;
}

.card-label {
  color: var(--muted);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.card-title {
  margin-top: 4px;
  font-size: 18px;
  font-weight: 600;
}

.card-copy,
.run-card-body {
  margin-top: 12px;
  font-family: "JetBrains Mono", "Consolas", monospace;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

.run-card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}

.run-chunk {
  padding: 12px;
  border-radius: 16px;
  background: rgba(33, 40, 56, 0.88);
  border: 1px solid rgba(255, 255, 255, 0.04);
}

.run-chunk + .run-chunk {
  margin-top: 10px;
}

.run-chunk-tool {
  border-color: rgba(125, 211, 252, 0.36);
}

.run-chunk-err {
  border-color: rgba(243, 139, 168, 0.42);
}

.run-status-running {
  box-shadow: 0 24px 64px rgba(125, 211, 252, 0.12);
}

.run-status-completed {
  box-shadow: 0 24px 64px rgba(158, 240, 184, 0.10);
}

.run-status-interrupted,
.run-status-error {
  box-shadow: 0 24px 64px rgba(243, 139, 168, 0.12);
}

.composer {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  margin: 0 auto;
  width: min(760px, calc(100vw - 16px));
  border-radius: 22px 22px 0 0;
  padding: 14px;
}

.settings-drawer {
  position: fixed;
  inset: 0;
  display: none;
  background: rgba(5, 8, 14, 0.48);
}

.settings-drawer.open {
  display: block;
}

.settings-sheet {
  position: absolute;
  left: 12px;
  right: 12px;
  bottom: 12px;
  border-radius: 24px;
  padding: 18px;
}

@media (min-width: 768px) {
  .app-shell {
    padding-left: 22px;
    padding-right: 22px;
  }

  .composer {
    width: min(760px, calc(100vw - 40px));
  }
}
```

- [ ] **Step 4: Re-run the style test to verify it passes**

Run: `node --test tests/mobile-style.test.js`

Expected: PASS with `ok 1 - mobile style contract is present`

- [ ] **Step 5: Record the checkpoint in git if available**

Run: `git rev-parse --is-inside-work-tree`

Expected: `true`

If the command succeeds:

```bash
git add public/index.html tests/mobile-style.test.js
git commit -m "feat: add mobile-first codex visual system"
```

If the command fails because this workspace is not a Git repository, note that explicitly in the task log and continue without committing.

## Task 3: Refactor Feed State and Streaming Rendering

**Files:**
- Create: `D:/remote-agent/tests/mobile-feed.test.js`
- Modify: `D:/remote-agent/public/index.html`

- [ ] **Step 1: Write the failing feed-state contract test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'index.html'),
  'utf8'
);

test('feed renderer exposes the mobile session state hooks', () => {
  assert.match(html, /let messages = \[\];/);
  assert.match(html, /function renderFeed\(\)/);
  assert.match(html, /function addUserMessage\(/);
  assert.match(html, /function startAgentRun\(/);
  assert.match(html, /function appendRunChunk\(/);
  assert.match(html, /function finishAgentRun\(/);
});
```

- [ ] **Step 2: Run the feed-state test to verify it fails**

Run: `node --test tests/mobile-feed.test.js`

Expected: FAIL because the current page still relies on ad hoc `streamingMsgEl` mutation instead of a feed state model.

- [ ] **Step 3: Replace ad hoc streaming DOM mutation with a message/run state model**

In the `<script>` block of `D:/remote-agent/public/index.html`, replace the current feed handling with:

```js
let TOKEN = localStorage.getItem('agent_token') || '';
let engine = 'claude';
let currentReader = null;
let currentSessionId = null;
let activeRunId = null;
let streaming = false;
let settingsDrawerOpen = false;
let connectionStatus = 'offline';
let messages = [];

function addUserMessage(text) {
  messages.push({
    id: crypto.randomUUID(),
    kind: 'user',
    text
  });
  renderFeed();
}

function startAgentRun(activeEngine) {
  const run = {
    id: crypto.randomUUID(),
    kind: 'run',
    engine: activeEngine,
    status: 'running',
    chunks: []
  };
  messages.push(run);
  renderFeed();
  return run.id;
}

function appendRunChunk(runId, chunkType, text) {
  const run = messages.find((entry) => entry.id === runId);
  if (!run) return;
  run.chunks.push({ type: chunkType, text });
  renderFeed();
}

function finishAgentRun(runId, statusLabel) {
  const run = messages.find((entry) => entry.id === runId);
  if (!run) return;
  run.status = statusLabel;
  renderFeed();
}

function renderFeed() {
  const feed = document.getElementById('session-feed');
  feed.innerHTML = messages.map(renderEntry).join('');
  feed.scrollTop = feed.scrollHeight;
}

function escapeHtml(value) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function renderChunkText(text) {
  const escaped = escapeHtml(text);
  return escaped
    .replace(/```(\w*)\n?([\s\S]*?)```/g, '<pre class="code-block">$2</pre>')
    .replace(/`([^`\n]+)`/g, '<code>$1</code>');
}

function formatRunStatus(status) {
  if (status === 'running') return 'Working';
  if (status === 'completed') return 'Completed';
  if (status === 'interrupted') return 'Interrupted';
  if (status === 'error') return 'Needs attention';
  return 'Ready';
}

function renderEntry(entry) {
  if (entry.kind === 'user') {
    return `
      <article class="user-card">
        <div class="card-label">You</div>
        <div class="card-copy">${escapeHtml(entry.text)}</div>
      </article>
    `;
  }

  const chunks = entry.chunks.map((chunk) => {
    return `
      <div class="run-chunk run-chunk-${chunk.type}">
        ${renderChunkText(chunk.text)}
      </div>
    `;
  }).join('');

  return `
    <article class="run-card run-status-${entry.status}">
      <div class="run-card-header">
        <div>
          <div class="card-label">${entry.engine === 'claude' ? 'Claude' : 'Codex'}</div>
          <div class="card-title">${formatRunStatus(entry.status)}</div>
        </div>
      </div>
      <div class="run-card-body">${chunks}</div>
    </article>
  `;
}

async function sendOrStop() {
  if (streaming) {
    await stopStream();
    return;
  }

  const input = document.getElementById('prompt-input');
  const prompt = input.value.trim();
  if (!prompt) return;

  const cwd = document.getElementById('cwd-input').value.trim();
  addUserMessage(prompt);
  activeRunId = startAgentRun(engine);
  input.value = '';
  setStreaming(true);

  try {
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-auth-token': TOKEN
      },
      body: JSON.stringify({ engine, prompt, cwd })
    });

    if (!response.ok) {
      appendRunChunk(activeRunId, 'err', `[HTTP ${response.status}]`);
      finishAgentRun(activeRunId, 'error');
      setStreaming(false);
      return;
    }

    currentReader = response.body.getReader();
    const decoder = new TextDecoder();
    let sseBuffer = '';

    while (true) {
      const { done, value } = await currentReader.read();
      if (done) break;
      sseBuffer += decoder.decode(value, { stream: true });
      const lines = sseBuffer.split('\n');
      sseBuffer = lines.pop();

      for (const line of lines) {
        if (!line.startsWith('data: ')) continue;
        handleEvent(JSON.parse(line.slice(6)));
      }
    }
  } catch (error) {
    appendRunChunk(activeRunId, 'err', `[Connection error: ${error.message}]`);
    finishAgentRun(activeRunId, 'error');
    setStatus(false);
  } finally {
    setStreaming(false);
  }
}

function handleEvent(event) {
  currentSessionId = event.sessionId || currentSessionId;

  if (event.type === 'text') appendRunChunk(activeRunId, 'text', event.text);
  if (event.type === 'tool') appendRunChunk(activeRunId, 'tool', event.text);
  if (event.type === 'tool_result') appendRunChunk(activeRunId, 'text', event.text);
  if (event.type === 'stderr' || event.type === 'error') appendRunChunk(activeRunId, 'err', event.text);
  if (event.type === 'done') finishAgentRun(activeRunId, 'completed');
}

async function stopStream() {
  if (currentReader) {
    try {
      await currentReader.cancel();
    } catch {}
    currentReader = null;
  }

  if (currentSessionId) {
    fetch('/api/kill/' + currentSessionId, {
      method: 'POST',
      headers: { 'x-auth-token': TOKEN }
    }).catch(() => {});
  }

  finishAgentRun(activeRunId, 'interrupted');
  currentSessionId = null;
}

function setStreaming(isActive) {
  streaming = isActive;
  const button = document.getElementById('send-btn');
  button.textContent = isActive ? 'Stop' : 'Send';
  button.classList.toggle('stop', isActive);
}
```

- [ ] **Step 4: Re-run the feed-state test to verify it passes**

Run: `node --test tests/mobile-feed.test.js`

Expected: PASS with `ok 1 - feed renderer exposes the mobile session state hooks`

- [ ] **Step 5: Run the full test suite**

Run: `npm test`

Expected: PASS with all three tests green.

- [ ] **Step 6: Record the checkpoint in git if available**

Run: `git rev-parse --is-inside-work-tree`

Expected: `true`

If the command succeeds:

```bash
git add public/index.html tests/mobile-feed.test.js package.json tests/mobile-shell.test.js tests/mobile-style.test.js
git commit -m "feat: add codex-style streaming session feed"
```

If the command fails because this workspace is not a Git repository, note that explicitly in the task log and continue without committing.

## Task 4: Wire the Settings Drawer, Clear Action, and Connection Presentation

**Files:**
- Create: `D:/remote-agent/tests/mobile-settings.test.js`
- Modify: `D:/remote-agent/public/index.html`

- [ ] **Step 1: Write the failing settings contract test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'index.html'),
  'utf8'
);

test('settings drawer contract is present', () => {
  assert.match(html, /let settingsDrawerOpen = false;/);
  assert.match(html, /function toggleSettings\(/);
  assert.match(html, /function syncSettingsDrawer\(/);
  assert.match(html, /id="clear-chat-btn"/);
  assert.match(html, /id="connection-pill"/);
});
```

- [ ] **Step 2: Run the settings test to verify it fails**

Run: `node --test tests/mobile-settings.test.js`

Expected: FAIL because the drawer state and sync helpers are not implemented yet.

- [ ] **Step 3: Add drawer controls and wire connection status**

In `D:/remote-agent/public/index.html`, add the drawer helpers:

```js
function toggleSettings(forceValue) {
  settingsDrawerOpen = typeof forceValue === 'boolean' ? forceValue : !settingsDrawerOpen;
  syncSettingsDrawer();
}

function syncSettingsDrawer() {
  const drawer = document.getElementById('settings-drawer');
  drawer.classList.toggle('open', settingsDrawerOpen);
  drawer.setAttribute('aria-hidden', String(!settingsDrawerOpen));
}

function clearSession() {
  messages = [];
  renderFeed();
}

function setStatus(ok) {
  connectionStatus = ok ? 'online' : 'offline';
  const pill = document.getElementById('connection-pill');
  const text = document.getElementById('status-text');
  pill.className = 'status-pill ' + (ok ? 'online' : 'offline');
  text.textContent = ok ? 'Online' : 'Offline';
}

document.getElementById('settings-toggle').addEventListener('click', () => toggleSettings(true));
document.getElementById('settings-close').addEventListener('click', () => toggleSettings(false));
document.getElementById('clear-chat-btn').addEventListener('click', clearSession);
document.getElementById('settings-drawer').addEventListener('click', (event) => {
  if (event.target.id === 'settings-drawer') toggleSettings(false);
});
```

Make sure the auth success path still shows the app shell and updates the connection pill through `setStatus(true)`.

Update the auth helpers in `D:/remote-agent/public/index.html` so they reveal `#app-shell` instead of the old `#app` container:

```js
async function doAuth() {
  const candidate = document.getElementById('token-input').value.trim();
  if (!candidate) return;

  try {
    const response = await fetch('/api/ping', {
      headers: { 'x-auth-token': candidate }
    });

    if (!response.ok) {
      document.getElementById('auth-err').style.display = 'block';
      return;
    }

    TOKEN = candidate;
    localStorage.setItem('agent_token', candidate);
    document.getElementById('auth-screen').style.display = 'none';
    document.getElementById('app-shell').style.display = 'block';
    setStatus(true);
  } catch {
    document.getElementById('auth-err').textContent = 'Unable to connect to server';
    document.getElementById('auth-err').style.display = 'block';
  }
}

async function checkAuth() {
  if (!TOKEN) return;

  try {
    const response = await fetch('/api/ping', {
      headers: { 'x-auth-token': TOKEN }
    });

    if (!response.ok) return;

    document.getElementById('auth-screen').style.display = 'none';
    document.getElementById('app-shell').style.display = 'block';
    setStatus(true);
  } catch {}
}
```

- [ ] **Step 4: Re-run the settings test to verify it passes**

Run: `node --test tests/mobile-settings.test.js`

Expected: PASS with `ok 1 - settings drawer contract is present`

- [ ] **Step 5: Run the full test suite**

Run: `npm test`

Expected: PASS with all four tests green.

- [ ] **Step 6: Record the checkpoint in git if available**

Run: `git rev-parse --is-inside-work-tree`

Expected: `true`

If the command succeeds:

```bash
git add public/index.html tests/mobile-settings.test.js package.json tests/mobile-shell.test.js tests/mobile-style.test.js tests/mobile-feed.test.js
git commit -m "feat: add mobile settings drawer and session controls"
```

If the command fails because this workspace is not a Git repository, note that explicitly in the task log and continue without committing.

## Task 5: Run the Final Verification Pass

**Files:**
- Modify: `D:/remote-agent/public/index.html` if verification reveals any contract or layout regressions

- [ ] **Step 1: Run the static test suite**

Run: `npm test`

Expected: PASS with all tests green.

- [ ] **Step 2: Run a syntax check on the backend entrypoint**

Run: `node --check server.js`

Expected: No output and exit code `0`

- [ ] **Step 3: Start the service locally**

Run: `npm start`

Expected: Console output similar to:

```text
[Agent] Listening on http://127.0.0.1:3333
[Agent] Default CWD: C:\
```

- [ ] **Step 4: Verify the mobile-width experience manually**

Open: `http://127.0.0.1:3333`

Use a narrow viewport around `390 x 844` and confirm:

- Auth screen still accepts a token.
- The top bar, engine switch, feed, and composer fit without horizontal scrolling.
- Sending a prompt creates a user card and a running agent card.
- Pressing stop changes the run state to interrupted.
- The settings drawer opens, updates `cwd`, and clears the feed.

- [ ] **Step 5: Verify the desktop-width experience manually**

Keep the same page open and widen the viewport to around `1280 x 900`, then confirm:

- The layout remains single-column and centered.
- The composer remains usable and does not cover the newest feed item.
- The engine switch and status pill remain visually stable.

- [ ] **Step 6: Commit the final verified state if git is available**

Run: `git rev-parse --is-inside-work-tree`

Expected: `true`

If the command succeeds:

```bash
git add package.json public/index.html tests/mobile-shell.test.js tests/mobile-style.test.js tests/mobile-feed.test.js tests/mobile-settings.test.js
git commit -m "feat: ship mobile codex-style remote agent ui"
```

If the command fails because this workspace is not a Git repository, note that explicitly in the task log and finish without committing.
