# macOS Resident App and Bundled Daemon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current macOS shell into a proper resident app that bundles the daemon, keeps running after the main window closes, exposes both Dock and menu bar entry points, and stops the daemon only when the app quits.

**Architecture:** Move daemon lifecycle ownership from Dart into native `Swift/AppKit`. The macOS shell will resolve bundled resource paths, launch a bundled Node runtime plus daemon entrypoint, track daemon state with health checks and log capture, and publish that state to Flutter over native channels. Flutter remains responsible for the companion UI and consumes shell snapshots instead of spawning processes itself.

**Tech Stack:** Swift, AppKit, XCTest, Flutter, Dart, `MethodChannel`, `EventChannel`, Bash, Node.js daemon

---

### Task 1: Bundle the daemon runtime and formalize macOS app paths

**Files:**
- Create: `app/macos/Runner/AppPaths.swift`
- Create: `app/macos/RunnerTests/AppPathsTests.swift`
- Modify: `app/macos/Runner.xcodeproj/project.pbxproj`
- Modify: `scripts/build_macos_companion.sh`
- Modify: `README.md`

- [ ] **Step 1: Write the failing macOS path tests**

```swift
import XCTest
@testable import Runner

final class AppPathsTests: XCTestCase {
  func test_resolvesBundledRuntimeAndDaemonLocationsInsideAppResources() {
    let bundleURL = URL(fileURLWithPath: "/tmp/agent_workbench.app")
    let paths = AppPaths(
      bundleURL: bundleURL,
      applicationSupportURL: URL(fileURLWithPath: "/Users/test/Library/Application Support"),
      logsURL: URL(fileURLWithPath: "/Users/test/Library/Logs")
    )

    XCTAssertEqual(
      paths.nodeExecutableURL.path,
      "/tmp/agent_workbench.app/Contents/Resources/bin/node"
    )
    XCTAssertEqual(
      paths.daemonEntrypointURL.path,
      "/tmp/agent_workbench.app/Contents/Resources/daemon/src/index.js"
    )
    XCTAssertEqual(
      paths.daemonDataDirectoryURL.path,
      "/Users/test/Library/Application Support/agent_workbench"
    )
    XCTAssertEqual(
      paths.daemonLogDirectoryURL.path,
      "/Users/test/Library/Logs/agent_workbench"
    )
  }
}
```

- [ ] **Step 2: Run the focused macOS tests to verify they fail**

Run: `cd app/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests/AppPathsTests`
Expected: FAIL because `AppPaths` does not exist and the test target does not include the new file yet.

- [ ] **Step 3: Add the path model and update the bundle script**

```swift
// app/macos/Runner/AppPaths.swift
import Foundation

struct AppPaths {
  let bundleURL: URL
  let applicationSupportURL: URL
  let logsURL: URL

  var nodeExecutableURL: URL {
    bundleURL.appendingPathComponent("Contents/Resources/bin/node")
  }

  var daemonEntrypointURL: URL {
    bundleURL.appendingPathComponent("Contents/Resources/daemon/src/index.js")
  }

  var daemonDataDirectoryURL: URL {
    applicationSupportURL.appendingPathComponent("agent_workbench", isDirectory: true)
  }

  var daemonLogDirectoryURL: URL {
    logsURL.appendingPathComponent("agent_workbench", isDirectory: true)
  }
}
```

```bash
# scripts/build_macos_companion.sh
RESOLVED_NODE="$(command -v node)"
BUNDLED_NODE_DIR="$OUTPUT_APP/Contents/Resources/bin"

mkdir -p "$BUNDLED_NODE_DIR"
cp "$RESOLVED_NODE" "$BUNDLED_NODE_DIR/node"
chmod +x "$BUNDLED_NODE_DIR/node"

mkdir -p "$BUNDLED_DAEMON_DIR"
rsync -a --delete --exclude 'tests' "$DAEMON_DIR/" "$BUNDLED_DAEMON_DIR/"
```

```md
# README.md
- The release app bundles both the daemon source and a Node runtime inside
  `Contents/Resources`.
- Runtime data is written to `~/Library/Application Support/agent_workbench/`.
- Logs are written to `~/Library/Logs/agent_workbench/`.
```

- [ ] **Step 4: Register the new test file in the Xcode project and rerun the test**

Run: `cd app/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests/AppPathsTests`
Expected: PASS with resource-path and Library-directory coverage.

- [ ] **Step 5: Commit**

```bash
git add app/macos/Runner/AppPaths.swift app/macos/RunnerTests/AppPathsTests.swift app/macos/Runner.xcodeproj/project.pbxproj scripts/build_macos_companion.sh README.md
git commit -m "build: bundle daemon runtime for macos app"
```

### Task 2: Add a native daemon controller with health checks, state transitions, and log files

**Files:**
- Create: `app/macos/Runner/DaemonController.swift`
- Create: `app/macos/RunnerTests/DaemonControllerTests.swift`
- Modify: `app/macos/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing native daemon-controller tests**

```swift
import XCTest
@testable import Runner

final class DaemonControllerTests: XCTestCase {
  func test_start_transitionsFromStartingToRunningAfterHealthCheck() async throws {
    let process = FakeProcessHandle()
    let healthCheck = FakeHealthCheckClient(results: [.failure(TestError.notReady), .success(())])
    let controller = DaemonController(
      processLauncher: FakeProcessLauncher(process: process),
      healthCheckClient: healthCheck,
      paths: .testDefault()
    )

    try await controller.start()

    XCTAssertEqual(controller.snapshot.status, .running)
    XCTAssertEqual(process.launchCount, 1)
    XCTAssertEqual(process.environment["DAEMON_DATA_DIR"], "/Users/test/Library/Application Support/agent_workbench")
  }

  func test_stop_requestsTerminateThenKillAfterTimeout() async throws {
    let process = FakeProcessHandle(exitAfterTerminate: false)
    let controller = DaemonController(
      processLauncher: FakeProcessLauncher(process: process),
      healthCheckClient: FakeHealthCheckClient(results: [.success(())]),
      paths: .testDefault(),
      shutdownTimeout: .milliseconds(1)
    )

    try await controller.start()
    await controller.stop()

    XCTAssertEqual(process.terminateCallCount, 1)
    XCTAssertEqual(process.killCallCount, 1)
    XCTAssertEqual(controller.snapshot.status, .stopped)
  }
}
```

- [ ] **Step 2: Run the focused macOS tests to verify they fail**

Run: `cd app/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests/DaemonControllerTests`
Expected: FAIL because `DaemonController`, `DaemonSnapshot`, and the fakeable process interfaces do not exist.

- [ ] **Step 3: Implement the daemon controller and state model**

```swift
// app/macos/Runner/DaemonController.swift
import Foundation

enum DaemonStatus: String {
  case starting
  case running
  case stopping
  case stopped
  case failed
}

struct DaemonSnapshot: Equatable {
  var status: DaemonStatus = .stopped
  var errorMessage: String?
  var logFilePath: String
  var recentLogs: [String] = []
}

final class DaemonController {
  func start() async throws {
    snapshot.status = .starting
    try fileManager.createDirectory(at: paths.daemonDataDirectoryURL, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: paths.daemonLogDirectoryURL, withIntermediateDirectories: true)

    process = try processLauncher.launch(
      executableURL: paths.nodeExecutableURL,
      arguments: [paths.daemonEntrypointURL.path],
      environment: [
        "HOST": "0.0.0.0",
        "PORT": "3333",
        "DAEMON_DATA_DIR": paths.daemonDataDirectoryURL.path,
      ]
    )

    try await healthCheckClient.waitUntilHealthy(url: URL(string: "http://127.0.0.1:3333/ping")!)
    snapshot.status = .running
  }

  func stop() async {
    snapshot.status = .stopping
    process?.terminate()
    if await process?.waitForExit(timeout: shutdownTimeout) == false {
      process?.kill()
    }
    snapshot.status = .stopped
  }
}
```

```swift
// inside DaemonController
private func appendLog(_ line: String) {
  snapshot.recentLogs.append(line)
  snapshot.recentLogs = Array(snapshot.recentLogs.suffix(100))
  try? "\(line)\n".appendLine(to: logFileURL)
  onSnapshotChange?(snapshot)
}
```

- [ ] **Step 4: Rerun the focused macOS tests**

Run: `cd app/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests/DaemonControllerTests`
Expected: PASS with startup, shutdown, environment, and failure-state coverage.

- [ ] **Step 5: Commit**

```bash
git add app/macos/Runner/DaemonController.swift app/macos/RunnerTests/DaemonControllerTests.swift app/macos/Runner.xcodeproj/project.pbxproj
git commit -m "feat: add macos daemon process controller"
```

### Task 3: Add menu bar integration, window-hide behavior, and Flutter bridge channels

**Files:**
- Create: `app/macos/Runner/ShellCoordinator.swift`
- Create: `app/macos/Runner/StatusItemController.swift`
- Create: `app/macos/Runner/CompanionBridge.swift`
- Create: `app/macos/RunnerTests/ShellCoordinatorTests.swift`
- Modify: `app/macos/Runner/AppDelegate.swift`
- Modify: `app/macos/Runner/MainFlutterWindow.swift`
- Modify: `app/macos/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing shell-coordinator tests**

```swift
import XCTest
@testable import Runner

final class ShellCoordinatorTests: XCTestCase {
  func test_windowCloseHidesWindowInsteadOfTerminatingApp() {
    let window = FakeWindow()
    let coordinator = ShellCoordinator(
      daemonController: FakeDaemonController(),
      windowController: window,
      statusItemController: FakeStatusItemController()
    )

    let shouldClose = coordinator.handleMainWindowClose()

    XCTAssertFalse(shouldClose)
    XCTAssertEqual(window.orderOutCallCount, 1)
  }

  func test_statusItemUpdatesMenuTitleFromDaemonSnapshot() {
    let statusItem = FakeStatusItemController()
    let coordinator = ShellCoordinator(
      daemonController: FakeDaemonController(snapshot: .init(status: .running, errorMessage: nil, logFilePath: "", recentLogs: [])),
      windowController: FakeWindow(),
      statusItemController: statusItem
    )

    coordinator.apply(snapshot: .init(status: .running, errorMessage: nil, logFilePath: "", recentLogs: []))

    XCTAssertEqual(statusItem.lastStatusTitle, "Server Status: Running")
  }

  func test_restartServiceCommandRestartsDaemonAndPublishesSnapshot() async {
    let daemon = FakeDaemonController()
    let bridge = CompanionBridge(daemonController: daemon)

    try await bridge.handleMethodCall(name: "restartDaemon", arguments: nil)

    XCTAssertEqual(daemon.restartCallCount, 1)
  }
}
```

- [ ] **Step 2: Run the focused macOS tests to verify they fail**

Run: `cd app/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests/ShellCoordinatorTests`
Expected: FAIL because window lifecycle handling, menu bar controller wiring, and Flutter bridge methods are not implemented.

- [ ] **Step 3: Implement the shell coordinator and native channels**

```swift
// app/macos/Runner/AppDelegate.swift
@main
class AppDelegate: FlutterAppDelegate {
  private var shellCoordinator: ShellCoordinator?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let window = mainFlutterWindow, let controller = window.contentViewController as? FlutterViewController else {
      return
    }

    let daemonController = DaemonController.live()
    let bridge = CompanionBridge(
      messenger: controller.engine.binaryMessenger,
      daemonController: daemonController
    )

    shellCoordinator = ShellCoordinator.live(
      app: NSApp,
      mainWindow: window,
      daemonController: daemonController,
      statusItemController: StatusItemController(),
      bridge: bridge
    )
    shellCoordinator?.start()
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    shellCoordinator?.showMainWindow()
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    shellCoordinator?.prepareForTermination()
    super.applicationWillTerminate(notification)
  }
}
```

```swift
// app/macos/Runner/StatusItemController.swift
final class StatusItemController {
  func install(
    openMainWindow: @escaping () -> Void,
    restartService: @escaping () -> Void,
    openLogs: @escaping () -> Void,
    quitApplication: @escaping () -> Void
  ) {
    statusItem.button?.title = "Agent"
    statusMenu.items = [
      menuItem("Open Main Window", action: openMainWindow),
      menuItem("Server Status: Starting", action: {}),
      menuItem("Restart Service", action: restartService),
      menuItem("Open Logs", action: openLogs),
      menuItem("Quit", action: quitApplication),
    ]
  }

  func update(with snapshot: DaemonSnapshot) {
    statusItem.button?.title = snapshot.status.menuBarTitle
    serverStatusMenuItem.title = "Server Status: \(snapshot.status.displayName)"
  }
}
```

```swift
// app/macos/Runner/MainFlutterWindow.swift
class MainFlutterWindow: NSWindow {
  weak var lifecycleDelegate: ShellWindowLifecycleDelegate?

  override func performClose(_ sender: Any?) {
    if lifecycleDelegate?.handleMainWindowClose() == false { return }
    super.performClose(sender)
  }
}
```

```swift
// app/macos/Runner/CompanionBridge.swift
final class CompanionBridge: NSObject {
  private let methodChannel = FlutterMethodChannel(
    name: "agent_workbench/companion/methods",
    binaryMessenger: messenger
  )
  private let eventChannel = FlutterEventChannel(
    name: "agent_workbench/companion/events",
    binaryMessenger: messenger
  )

  func publish(_ snapshot: DaemonSnapshot) {
    eventSink?(snapshot.asMap)
  }

  func handleMethodCall(name: String, arguments: Any?) async throws {
    switch name {
    case "restartDaemon":
      try await daemonController.restart()
    case "openLogs":
      workspace.openFile(daemonController.snapshot.logFilePath)
    case "quitApplication":
      await daemonController.stop()
      NSApp.terminate(nil)
    default:
      throw BridgeError.unimplemented(name)
    }
  }
}
```

- [ ] **Step 4: Rerun the focused macOS tests**

Run: `cd app/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests/ShellCoordinatorTests`
Expected: PASS with close-window, reopen, restart, and bridge-command coverage.

- [ ] **Step 5: Commit**

```bash
git add app/macos/Runner/ShellCoordinator.swift app/macos/Runner/StatusItemController.swift app/macos/Runner/CompanionBridge.swift app/macos/Runner/AppDelegate.swift app/macos/Runner/MainFlutterWindow.swift app/macos/RunnerTests/ShellCoordinatorTests.swift app/macos/Runner.xcodeproj/project.pbxproj
git commit -m "feat: add macos resident shell lifecycle"
```

### Task 4: Replace Dart-side daemon spawning with a native-shell companion client

**Files:**
- Create: `app/lib/src/features/companion/companion_shell_client.dart`
- Create: `app/lib/src/features/companion/companion_snapshot.dart`
- Modify: `app/lib/src/features/companion/daemon_companion_screen.dart`
- Modify: `app/lib/app.dart`
- Modify: `app/test/app_shell_test.dart`
- Modify: `app/test/daemon_companion_screen_test.dart`
- Create: `app/test/companion_shell_client_test.dart`
- Delete: `app/lib/src/features/companion/daemon_supervisor.dart`
- Delete: `app/test/daemon_supervisor_test.dart`

- [ ] **Step 1: Write the failing Flutter companion-client tests**

```dart
test('maps native event payloads into companion snapshots', () async {
  final controller = StreamController<dynamic>();
  final client = CompanionShellClient(
    methodChannel: const MethodChannel('agent_workbench/companion/methods'),
    eventChannel: FakeEventChannel(controller.stream),
  );

  controller.add({
    'status': 'running',
    'errorMessage': null,
    'logFilePath': '/Users/test/Library/Logs/agent_workbench/daemon.log',
    'recentLogs': ['[daemon] listening on http://0.0.0.0:3333']
  });

  expect(
    await client.snapshots.first,
    const CompanionSnapshot(
      status: CompanionStatus.running,
      logFilePath: '/Users/test/Library/Logs/agent_workbench/daemon.log',
      recentLogs: ['[daemon] listening on http://0.0.0.0:3333'],
    ),
  );
});

testWidgets('renders native shell state and restart/open-logs actions', (tester) async {
  final client = FakeCompanionShellClient(
    initialSnapshot: const CompanionSnapshot(
      status: CompanionStatus.failed,
      errorMessage: 'Port 3333 is already in use.',
      logFilePath: '/Users/test/Library/Logs/agent_workbench/daemon.log',
      recentLogs: ['Failed to bind daemon port.'],
    ),
  );

  await tester.pumpWidget(MaterialApp(home: DaemonCompanionScreen(client: client)));

  expect(find.text('Port 3333 is already in use.'), findsOneWidget);
  expect(find.text('Restart Service'), findsOneWidget);
  expect(find.text('Open Logs'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused Flutter tests to verify they fail**

Run: `cd app && flutter test test/companion_shell_client_test.dart test/daemon_companion_screen_test.dart test/app_shell_test.dart`
Expected: FAIL because Flutter still depends on `DaemonSupervisor`, there is no native shell client, and the companion screen does not expose shell-driven actions.

- [ ] **Step 3: Implement the native-shell client and update the companion UI**

```dart
// app/lib/src/features/companion/companion_snapshot.dart
enum CompanionStatus { starting, running, stopping, stopped, failed }

class CompanionSnapshot {
  const CompanionSnapshot({
    required this.status,
    this.errorMessage,
    required this.logFilePath,
    required this.recentLogs,
  });

  factory CompanionSnapshot.fromMap(Map<Object?, Object?> map) {
    return CompanionSnapshot(
      status: CompanionStatus.values.byName(map['status'] as String),
      errorMessage: map['errorMessage'] as String?,
      logFilePath: map['logFilePath'] as String? ?? '',
      recentLogs: (map['recentLogs'] as List<Object?>? ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
    );
  }
}
```

```dart
// app/lib/src/features/companion/companion_shell_client.dart
class CompanionShellClient {
  CompanionShellClient({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('agent_workbench/companion/methods'),
        _eventChannel =
            eventChannel ?? const EventChannel('agent_workbench/companion/events');

  Stream<CompanionSnapshot> get snapshots => _eventChannel
      .receiveBroadcastStream()
      .map((event) => CompanionSnapshot.fromMap(event as Map<Object?, Object?>));

  Future<void> restartDaemon() => _methodChannel.invokeMethod('restartDaemon');
  Future<void> openLogs() => _methodChannel.invokeMethod('openLogs');
  Future<void> quitApplication() => _methodChannel.invokeMethod('quitApplication');
}
```

```dart
// app/lib/app.dart
class AgentWorkbenchApp extends StatefulWidget {
  const AgentWorkbenchApp({
    super.key,
    this.companionClient,
    this.shellMode = AppShellMode.workbench,
  });

  final CompanionShellClient? companionClient;
}

if (shellMode == AppShellMode.daemonCompanion) {
  return DaemonCompanionScreen(
    client: widget.companionClient ?? CompanionShellClient(),
  );
}
```

```dart
// app/lib/src/features/companion/daemon_companion_screen.dart
OutlinedButton(
  onPressed: snapshot.status == CompanionStatus.starting ? null : client.restartDaemon,
  child: const Text('Restart Service'),
)

OutlinedButton(
  onPressed: client.openLogs,
  child: const Text('Open Logs'),
)
```

- [ ] **Step 4: Run the focused Flutter tests again**

Run: `cd app && flutter test test/companion_shell_client_test.dart test/daemon_companion_screen_test.dart test/app_shell_test.dart`
Expected: PASS with native snapshot mapping and macOS companion-shell rendering covered.

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/features/companion/companion_shell_client.dart app/lib/src/features/companion/companion_snapshot.dart app/lib/src/features/companion/daemon_companion_screen.dart app/lib/app.dart app/test/app_shell_test.dart app/test/daemon_companion_screen_test.dart app/test/companion_shell_client_test.dart
git rm app/lib/src/features/companion/daemon_supervisor.dart app/test/daemon_supervisor_test.dart
git commit -m "feat: connect flutter companion to native macos shell"
```

### Task 5: Verify release packaging, native tests, and resident-app behavior end to end

**Files:**
- No planned file changes

- [ ] **Step 1: Run daemon verification**

Run: `cd daemon && npm test`
Expected: PASS

- [ ] **Step 2: Run Flutter verification**

Run: `cd app && flutter test`
Expected: PASS

- [ ] **Step 3: Run macOS native verification**

Run: `cd app/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS'`
Expected: PASS with `AppPathsTests`, `DaemonControllerTests`, and `ShellCoordinatorTests`.

- [ ] **Step 4: Build the release app with bundled runtime**

Run: `npm run build:macos:companion`
Expected: PASS and produce `app/build/macos/Build/Products/Release/agent_workbench.app`

- [ ] **Step 5: Manually verify resident-app behavior**

Run:

```bash
open app/build/macos/Build/Products/Release/agent_workbench.app
```

Expected:
- Main window appears on launch
- Menu bar status item appears immediately
- Closing the main window hides it without quitting the app
- Clicking the Dock icon restores the window
- The menu bar menu can reopen the window
- `Quit` stops the daemon and removes the menu bar item
- `~/Library/Application Support/agent_workbench/` contains runtime data
- `~/Library/Logs/agent_workbench/` contains the daemon log file

- [ ] **Step 6: Sanity-check the worktree**

Run: `git status --short`
Expected: clean worktree
