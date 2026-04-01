# Controller Singleton Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce a single desktop controller instance and a single live service stack per app port, with automatic stale-process cleanup on startup and shutdown.

**Architecture:** Keep the current PowerShell controller structure, but add a launcher-level named mutex, a runtime state file that records managed PIDs, and aggressive cleanup helpers in `agent-control.ps1` that kill stale tracked processes plus any current owner of the configured app port before starting new services.

**Tech Stack:** PowerShell, Windows Forms, Node test runner

---

### Task 1: Add failing contract tests for singleton and cleanup boundaries

**Files:**
- Modify: `D:\remote-agent\tests\controller-script.test.js`
- Test: `D:\remote-agent\tests\controller-script.test.js`

- [ ] **Step 1: Write failing tests**

Add tests that assert:

```js
assert.match(launcherScript, /System\.Threading\.Mutex/);
assert.match(launcherScript, /already running/i);
assert.match(script, /controller-state\.json/);
assert.match(script, /Get-NetTCPConnection/);
assert.match(script, /OwningProcess/);
assert.match(script, /Remove-Item .*controller-state\.json/);
```

- [ ] **Step 2: Run the controller tests to verify they fail**

Run: `node --test tests/controller-script.test.js`
Expected: FAIL because the current launcher script has no named mutex and the controller script has no runtime state file or app-port cleanup logic.

### Task 2: Add single-instance lock in the launcher

**Files:**
- Modify: `D:\remote-agent\agent-control-launcher.ps1`
- Test: `D:\remote-agent\tests\controller-script.test.js`

- [ ] **Step 1: Add a stable mutex name helper**

Implement a small helper that derives a mutex name from the workspace path, for example using an MD5 hash of `$workDir`.

- [ ] **Step 2: Acquire the mutex before launching the controller**

Use `System.Threading.Mutex` to refuse duplicate launches:

```powershell
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
  [System.Windows.Forms.MessageBox]::Show("Remote Agent Controller is already running.")
  return
}
```

- [ ] **Step 3: Release the mutex in `finally`**

Run: `node --test tests/controller-script.test.js`
Expected: launcher-related singleton assertions now pass while runtime-state assertions still fail.

### Task 3: Add runtime state and stale cleanup to the controller

**Files:**
- Modify: `D:\remote-agent\agent-control.ps1`
- Test: `D:\remote-agent\tests\controller-script.test.js`

- [ ] **Step 1: Add runtime state helpers**

Create helpers for:

- `Get-StateFilePath`
- `Save-RuntimeState`
- `Get-RuntimeState`
- `Clear-RuntimeState`

Store JSON like:

```json
{
  "workspace": "D:\\remote-agent",
  "port": 3333,
  "nodePid": 12345,
  "frpcPid": 12346,
  "startedAt": "2026-04-01T17:00:00.000Z"
}
```

- [ ] **Step 2: Add stale PID cleanup**

Implement a helper that reads the state file, attempts to stop `nodePid` and `frpcPid`, then clears the state file.

- [ ] **Step 3: Add configured app-port cleanup**

Implement a helper that uses `Get-NetTCPConnection -LocalPort $AppPort` to locate any current owner of the port and terminate it.

- [ ] **Step 4: Wire cleanup into startup and shutdown**

Before starting services:

- cleanup stale tracked PIDs
- cleanup the current app-port owner

After starting services:

- save runtime state

During shutdown:

- stop tracked child processes
- cleanup the port again
- clear runtime state

- [ ] **Step 5: Handle partial startup failures**

If startup throws after launching `node` or `frpc`, stop any managed processes that started and clear runtime state before rethrowing.

- [ ] **Step 6: Run controller tests to verify they pass**

Run: `node --test tests/controller-script.test.js`
Expected: PASS with singleton, runtime-state, and port-cleanup contract assertions all green.

### Task 4: Run full verification

**Files:**
- Modify: none
- Test: `D:\remote-agent\tests\controller-script.test.js`

- [ ] **Step 1: Run the full test suite**

Run: `npm test`
Expected: PASS with all server, UI, and controller tests green.

- [ ] **Step 2: Run the production build**

Run: `npm run build`
Expected: PASS with the frontend build still succeeding.
