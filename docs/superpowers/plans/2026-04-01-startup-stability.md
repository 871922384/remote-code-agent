# Startup Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the desktop startup path survivable and diagnosable when the controller or Node service fails early.

**Architecture:** Keep the existing launcher flow, but strengthen the two weak links. The PowerShell controller gets a file-first logging helper plus a UI-thread-safe append path for process callbacks, and the Node server gets explicit `listen` error handling for occupied ports.

**Tech Stack:** PowerShell 5/WinForms, Node.js built-in test runner, Express

---

### Task 1: Add regression tests for startup failures

**Files:**
- Create: `D:\remote-agent\tests\server-startup.test.js`
- Modify: `D:\remote-agent\package.json`
- Test: `D:\remote-agent\tests\server-startup.test.js`

- [ ] **Step 1: Write the failing test**

```js
test('server exits cleanly with a clear message when the port is already in use', async () => {
  const blocker = net.createServer();
  await once(blocker.listen(3333, '127.0.0.1'), 'listening');

  const child = spawn(process.execPath, [serverPath], {
    cwd: projectRoot,
    env: { ...process.env, AUTH_TOKEN: 'test-token', PORT: '3333' },
  });

  const [code] = await once(child, 'close');
  assert.notEqual(code, 0);
  assert.match(stderr + stdout, /port 3333 is already in use/i);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tests/server-startup.test.js`
Expected: FAIL because the current server emits the default unhandled `EADDRINUSE` stack trace instead of the clear message.

- [ ] **Step 3: Write minimal implementation**

```js
const server = app.listen(PORT, '127.0.0.1', () => {
  console.log(`[Agent] Listening on http://127.0.0.1:${PORT}`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`[ERROR] Startup failed: port ${PORT} is already in use on 127.0.0.1.`);
  } else {
    console.error(`[ERROR] Startup failed: ${err.message}`);
  }
  process.exitCode = 1;
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test tests/server-startup.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add package.json tests/server-startup.test.js server.js
git commit -m "fix: harden server startup errors"
```

### Task 2: Harden controller logging and UI updates

**Files:**
- Modify: `D:\remote-agent\agent-control.ps1`
- Create: `D:\remote-agent\tests\controller-script.test.js`
- Test: `D:\remote-agent\tests\controller-script.test.js`

- [ ] **Step 1: Write the failing test**

```js
test('controller script contains the early trace log and UI-thread-safe append helper', () => {
  assert.match(script, /controller\.log/);
  assert.match(script, /if \(\$script:logBox\.InvokeRequired\)/);
  assert.match(script, /BeginInvoke\(/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tests/controller-script.test.js`
Expected: FAIL because the current script only logs startup trace entries and writes to the textbox directly.

- [ ] **Step 3: Write minimal implementation**

```powershell
function Write-ControllerLog { ... }

function Append-Log {
  param([string]$Message)
  Write-ControllerLog $Message
  if (-not $script:logBox) { return }
  if ($script:logBox.InvokeRequired) {
    $null = $script:logBox.BeginInvoke([Action[string]]{ param($m) Append-LogToTextBox -Message $m }, $Message)
    return
  }
  Append-LogToTextBox -Message $Message
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test tests/controller-script.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add agent-control.ps1 tests/controller-script.test.js
git commit -m "fix: stabilize controller startup logging"
```

### Task 3: Verify the full startup path

**Files:**
- Modify: `D:\remote-agent\runlogs\` (runtime artifacts only)
- Test: `D:\remote-agent\tests\server-startup.test.js`
- Test: `D:\remote-agent\tests\controller-script.test.js`

- [ ] **Step 1: Run targeted tests**

```bash
node --test tests/server-startup.test.js tests/controller-script.test.js
```

- [ ] **Step 2: Run the full suite**

```bash
npm test
```

- [ ] **Step 3: Validate manual startup behavior**

```powershell
& 'D:\remote-agent\start-agent-debug.bat'
Get-Content 'D:\remote-agent\runlogs\controller.log' -Tail 20
```

Expected: The controller stays open or records the exact reason it could not start services; the Node failure path logs a readable occupied-port message instead of a raw unhandled exception.

- [ ] **Step 4: Commit**

```bash
git add server.js agent-control.ps1 tests/server-startup.test.js tests/controller-script.test.js docs/superpowers/specs/2026-04-01-startup-stability-design.md docs/superpowers/plans/2026-04-01-startup-stability.md
git commit -m "fix: improve startup diagnostics"
```
