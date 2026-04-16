# macOS Desktop App and Resident Daemon Design

**Problem**

The current macOS build is still a thin development shell:

- closing the main window exits the app
- there is no menu bar entry point
- the daemon is not packaged as part of a proper desktop app experience
- there is no clear distinction between closing the window and quitting the product

That makes the Mac side feel temporary instead of like a real local application that can stay available while the daemon keeps serving clients.

**Decision Summary**

Build the Mac product as a standard macOS `.app` with three layers:

- `Swift/AppKit shell` for application lifecycle, Dock behavior, menu bar integration, and daemon process management
- `Flutter UI` for the main window content
- `bundled daemon executable` shipped inside the app bundle and launched by the shell as a managed child process

The app keeps both `Dock` and `menu bar` entry points. Opening the app starts the daemon automatically. Closing the main window hides it but does not quit the app or stop the daemon. Only `Quit` stops the daemon and exits the app.

**User Constraints Confirmed**

- Preferred shell mode: `Dock + menu bar`
- Daemon lifecycle: start on app launch, keep running after the window closes, stop only when the app quits
- Startup behavior: no login or boot auto-start; the user launches the app manually

**Goals**

- Make the macOS build behave like a real desktop application rather than a dev shell
- Bundle the daemon with the app so the Mac experience does not depend on a separate terminal session
- Keep the app resident after the main window closes
- Expose both Dock and menu bar recovery paths for reopening the window
- Surface daemon state clearly in both the shell and the UI
- Keep the first version operationally simple and reliable

**Non-Goals**

- No login-item or boot auto-start in this slice
- No helper app or `SMAppService` background agent in this slice
- No `launchd`-managed standalone daemon in this slice
- No full rewrite of the Flutter UI into native Swift
- No automatic crash-restart loop for the daemon in the first version

**Product Behavior**

The macOS app should follow these rules:

1. Launching the app opens the main window and starts the bundled daemon.
2. A menu bar status item appears immediately and reflects daemon state.
3. Closing the main window hides or removes the window from view, but does not quit the app.
4. The app remains visible in the Dock after the window closes.
5. Clicking the Dock icon restores the main window and brings the app to the foreground.
6. The menu bar menu also provides `Open Main Window`.
7. The daemon keeps running while the app remains alive in the background.
8. Choosing `Quit` from the menu bar or the standard app menu stops the daemon and exits the app.

This intentionally separates `close window` from `quit application`.

**Architecture**

**Shell**

The native macOS shell remains responsible for all system-facing behavior:

- window close handling
- app activation and reactivation
- Dock integration
- menu bar status item creation and updates
- starting, stopping, and observing the daemon process
- locating the bundled daemon executable inside the app bundle
- mapping daemon state into a simple UI-facing state model

This is native work and should stay in `Swift/AppKit`.

**Main UI**

The main window content remains in Flutter.

Flutter already owns the current product UI, so rewriting it in native Swift would add cost without solving the actual desktopization problem. The desktopization work is primarily in lifecycle and system integration, not in view rendering.

The Flutter side should consume daemon state from the shell instead of trying to manage operating-system behavior itself.

**Daemon Packaging**

The daemon should be distributed inside the `.app` bundle as an app resource, for example under `Contents/Resources`.

The shell launches that bundled executable directly instead of asking the user to run `npm run dev` or any external command. This keeps distribution and runtime ownership inside the application.

The first version should prefer a stable bundled executable over a runtime-dependent Node development command. The implementation plan must choose one concrete build path, but the runtime contract is fixed:

- the app ships the daemon
- the app finds it
- the app launches it
- the app stops it on quit

**Daemon Lifecycle Model**

The shell should own a small daemon state machine:

- `starting`
- `running`
- `stopping`
- `stopped`
- `failed`

Behavior:

- On app launch, transition to `starting` and spawn the daemon process.
- Run an explicit health check before promoting the daemon to `running`.
- If startup fails, transition to `failed` and surface the error.
- If the daemon exits unexpectedly while the app is still alive, transition to `failed`.
- If the user chooses `Quit`, transition to `stopping`, try graceful shutdown, then force terminate if needed before exiting the app.

The first version should not do repeated automatic restart attempts. Manual restart from the UI or menu bar is sufficient and easier to reason about.

**Window and Menu Bar Interaction**

The shell should expose two recovery paths after the main window closes:

- `Dock`
- `menu bar`

The menu bar menu should include at least:

- `Open Main Window`
- `Server Status: Running` (or the current state label)
- `Restart Service`
- `Open Logs`
- `Quit`

The menu bar item itself should visually distinguish at least:

- `Starting`
- `Running`
- `Failed`
- `Stopped`

Closing the main window should use a true hide/remove-from-view flow such as `orderOut` or equivalent behavior, not just window miniaturization.

**Error Handling**

The app should report daemon failures explicitly rather than silently disappearing or exiting.

Expected failure cases include:

- bundled executable missing
- startup process launch failure
- health check timeout
- port already in use
- permission or filesystem failure
- unexpected daemon exit after startup

Error reporting rules:

- menu bar state changes to `Failed`
- the main window shows a clear error state if open
- the user can trigger a manual restart
- the app itself stays alive unless the user quits it

**Data and Log Locations**

Runtime data must not be written back into the `.app` bundle.

The daemon and shell should write mutable data to user directories such as:

- `~/Library/Application Support/agent_workbench/`
- `~/Library/Logs/agent_workbench/`

Examples of mutable data:

- log files
- pid files
- sockets
- cache
- local databases
- generated runtime config

The `.app` bundle remains read-only at runtime apart from standard macOS metadata outside the app process contract.

**Packaging Strategy**

The primary release artifact for this slice is a proper `Release` macOS `.app`.

This slice does not need a helper app, installer, or advanced distribution system. A later slice may add a `DMG` or a signed distribution path, but the core packaging goal here is simpler:

- the daemon is inside the app
- the app launches cleanly
- the app behaves correctly when windows close and reopen

**Verification Criteria**

The implementation is complete when all of the following are true:

1. Launching the app opens the main window, shows the menu bar item, and starts the bundled daemon.
2. Closing the main window does not quit the app.
3. After the main window closes, the daemon continues running.
4. The app remains available from both the Dock and the menu bar.
5. Reopening from either entry point restores the main window reliably.
6. Choosing `Quit` stops the daemon and exits the app.
7. Simulated startup failure produces a visible `Failed` state in both shell surfaces and the main UI.
8. Logs and runtime files are written to `Library` locations rather than into the app bundle.

**Recommended Implementation Boundary**

The first implementation should focus on four things only:

- native lifecycle control
- menu bar integration
- bundled-daemon process management
- clear daemon state presentation

It should explicitly avoid jumping ahead to helper apps, login items, or daemon auto-restart policies until the standard resident app behavior is stable.
