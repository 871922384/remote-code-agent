# Startup Stability Design

**Problem**

The desktop launcher can appear to flash and disappear before useful diagnostics are visible. Two failure paths are currently hard to inspect:

1. The Node service crashes immediately when port `3333` is already in use.
2. The WinForms controller updates UI controls from process event callbacks, which may run off the UI thread and can terminate the window before the existing catch blocks record useful details.

**Goals**

- Preserve enough startup evidence in `runlogs` to explain early failures.
- Make the controller resilient to child-process output and exit events.
- Turn the Node startup failure for occupied ports into a controlled, logged error instead of an unhandled crash.

**Non-Goals**

- No controller redesign.
- No protocol changes for the HTTP API.
- No FRP behavior changes beyond better observability around startup.

**Approach**

Add a file-backed controller log path that records every startup phase and child-process event before the UI receives it. Route WinForms updates through a helper that marshals onto the UI thread when required, so process callbacks cannot touch controls directly. In `server.js`, wrap `app.listen()` with explicit server error handling so `EADDRINUSE` becomes a clear startup error message and non-zero exit, rather than an unhandled event exception.

**Testing**

- Add a Node test that spawns the server while port `3333` is intentionally occupied and asserts a clean, diagnostic failure message.
- Add a lightweight script-content test that verifies the controller script contains the new early-log and UI-thread-safety guards.
- Run the full existing test suite after the targeted tests pass.
