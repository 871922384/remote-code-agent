# Controller Singleton Boundary Design

## Goal

Guarantee that the desktop controller manages exactly one live tool stack for the local web service:

- only one controller GUI instance at a time
- only one service set bound to the app port at a time
- closing the GUI tears down the managed background processes
- reopening after a crash cleans up stale processes before starting again

## Background

The current controller already starts and stops `node` and `frpc` from a desktop GUI, but it does not enforce hard singleton boundaries. In practice this means old background processes can survive, a later launch can fail on the port, and users can lose track of what is actually running.

This project is used in a "pick it up quickly and continue coding" workflow, so the system should prefer strict uniqueness over manual process hygiene. If a stale process is in the way, the controller should clean it up.

## Recommended Approach

Use a three-part boundary model:

1. Controller GUI single-instance lock
2. Runtime state file with tracked PIDs
3. Aggressive startup and shutdown cleanup for the configured service port

This gives the simplest behavior for the user:

- opening the GUI always leads to one known-good service set
- closing the GUI always tries to remove that service set
- stale leftovers are treated as bugs and cleaned automatically

## Scope

### In Scope

- prevent multiple controller windows from managing the same workspace
- write and maintain a runtime state file under `runlogs/` or a similar local-only location
- track the PIDs of managed `node` and `frpc` processes
- on startup, kill previously tracked stale processes if they still exist
- on startup, detect and kill any process using the configured app port
- on shutdown, stop tracked child processes and verify the port is freed
- if startup fails partway through, clean up partial child processes before returning control to the GUI
- add tests covering singleton and cleanup contracts

### Out of Scope

- converting the controller into a Windows service
- supporting multiple independent controller stacks on different ports in the same workspace
- protecting unrelated third-party processes from termination if they occupy the configured app port
- adding a user confirmation step before killing stale processes

## User Experience

### Normal Launch

When the user opens the desktop controller:

1. The controller acquires a single-instance lock.
2. It loads the last runtime state file if present.
3. It kills any previously tracked stale `node` or `frpc` processes that are still alive.
4. It checks the app port, currently `3333`.
5. If anything is listening on that port, it terminates the owning process.
6. It starts fresh `node` and `frpc` child processes.
7. It records the new runtime state.
8. It updates the GUI log so the user can see cleanup and launch events.

### Duplicate Launch

If the user launches the controller while another controller window is already running:

- the second instance should not start another GUI
- it should show a clear message that the controller is already running, then exit

### Normal Close

When the GUI closes:

1. The controller stops tracked `frpc`
2. The controller stops tracked `node`
3. It re-checks the port and force-clears any residue
4. It deletes the runtime state file
5. It releases the single-instance lock

### Crash Recovery

If the GUI or machine exits unexpectedly:

- the runtime state file remains as a stale hint
- the next controller launch uses that file to kill old tracked processes before starting again
- if the state file is missing or incomplete, the port cleanup step still enforces uniqueness

## Architecture

### 1. Single-Instance Lock

The PowerShell launcher should acquire a named process lock before opening the GUI. A named mutex is the simplest fit on Windows.

Expected behavior:

- first instance acquires the mutex and continues
- second instance fails to acquire it, shows a message, and exits

The mutex name should be stable for this app and workspace, for example based on the absolute workspace path.

### 2. Runtime State File

The controller should maintain a local JSON state file containing:

- workspace path
- app port
- node PID
- frpc PID
- start timestamp
- UI URL or other contextual info if useful for debugging

This file is not a source of truth by itself. It is a hint used to clean up stale processes and improve log output.

### 3. Port Ownership Cleanup

Before launching services, the controller should inspect the configured app port.

Expected policy:

- if nothing is listening, continue
- if anything is listening, terminate the owning process

This is intentionally strict. The product requirement is uniqueness, not coexistence.

### 4. Managed Process Lifecycle

`node` and `frpc` remain managed child processes started by the controller.

The controller should:

- record their PIDs immediately after startup
- update the runtime state file after each successful start
- remove or clear the state when they exit permanently
- aggressively stop them during shutdown

### 5. Failure Handling

If startup fails after `node` starts but before `frpc` is healthy:

- the controller should stop any partially started managed processes
- the state file should be removed or reset
- the GUI should remain open and show the failure

If cleanup fails for a process:

- log the PID and the failure reason
- continue best-effort cleanup of the rest
- leave a clear trace in controller logs

## File-Level Plan

### `D:\remote-agent\agent-control-launcher.ps1`

Responsibilities:

- acquire and release the single-instance mutex
- refuse duplicate controller launches early
- hand off to `agent-control.ps1`

### `D:\remote-agent\agent-control.ps1`

Responsibilities:

- create, update, and delete the runtime state file
- perform stale PID cleanup
- perform port-owner cleanup
- keep existing GUI behavior and process logging
- ensure shutdown is idempotent

### `D:\remote-agent\tests\controller-script.test.js`

Responsibilities:

- assert presence of the singleton lock behavior
- assert presence of runtime state persistence
- assert startup cleanup and shutdown cleanup contract text

## Data Model

Proposed runtime file:

```json
{
  "workspace": "D:\\remote-agent",
  "port": 3333,
  "nodePid": 12345,
  "frpcPid": 12346,
  "startedAt": "2026-04-01T17:00:00.000Z"
}
```

## Testing Strategy

### Automated

- extend controller contract tests to verify:
  - a single-instance mutex is used
  - a runtime state file path exists
  - startup cleanup logic references the configured app port
  - shutdown cleanup removes managed processes and clears runtime state

### Manual

Run these checks on Windows:

1. Start the controller once and confirm `node` and `frpc` start.
2. Try to start it again and confirm the second launch is refused.
3. Close the GUI and confirm the app port is no longer listening.
4. Manually leave a stale process on the app port, then launch the GUI and confirm cleanup happens automatically.
5. Force-close the GUI, relaunch, and confirm stale PID recovery works.

## Risks

### Killing the Wrong Port Owner

This design intentionally kills any process using the configured app port. That is acceptable because the user's priority is uniqueness, not coexistence.

### Partial Cleanup

If Windows refuses to terminate a process, the controller could still leave residue. The design reduces this risk with:

- tracked PID cleanup
- port cleanup
- repeated cleanup on next launch

### Lock Leaks

A badly handled mutex could block relaunch after a crash. Using the process lifetime of the controller launcher as the lock owner reduces this risk.

## Decision

Proceed with the strict singleton boundary design:

- single controller instance
- single owner of the app port
- runtime PID tracking
- automatic cleanup on close and on next launch
