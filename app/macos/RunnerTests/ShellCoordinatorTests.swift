import XCTest
@testable import agent_workbench

final class ShellCoordinatorTests: XCTestCase {
  func test_windowCloseHidesWindowInsteadOfTerminatingApp() {
    let window = FakeWindow()
    let coordinator = ShellCoordinator(
      daemonController: FakeDaemonController(),
      windowController: window,
      statusItemController: FakeStatusItemController(),
      bridge: FakeCompanionBridge(),
      application: FakeApplication()
    )

    let shouldClose = coordinator.handleMainWindowClose()

    XCTAssertFalse(shouldClose)
    XCTAssertEqual(window.orderOutCallCount, 1)
  }

  func test_statusItemUpdatesMenuTitleFromDaemonSnapshot() {
    let statusItemController = FakeStatusItemController()
    let coordinator = ShellCoordinator(
      daemonController: FakeDaemonController(),
      windowController: FakeWindow(),
      statusItemController: statusItemController,
      bridge: FakeCompanionBridge(),
      application: FakeApplication()
    )

    coordinator.apply(
      snapshot: DaemonSnapshot(
        status: .running,
        errorMessage: nil,
        logFilePath: "/tmp/daemon.log",
        recentLogs: []
      )
    )

    XCTAssertEqual(statusItemController.lastStatusTitle, "Server Status: Running")
  }

  func test_restartServiceCommandRestartsDaemonAndPublishesSnapshot() async throws {
    let daemonController = FakeDaemonController()
    let bridge = CompanionBridge(
      daemonController: daemonController,
      workspace: FakeWorkspace(),
      application: FakeApplication()
    )

    try await bridge.handleMethodCall(name: "restartDaemon", arguments: nil)

    XCTAssertEqual(daemonController.restartCallCount, 1)
  }
}

private final class FakeDaemonController: DaemonControlling {
  init(
    snapshot: DaemonSnapshot = DaemonSnapshot(
      status: .stopped,
      errorMessage: nil,
      logFilePath: "/tmp/daemon.log",
      recentLogs: []
    )
  ) {
    self.snapshot = snapshot
  }

  var snapshot: DaemonSnapshot
  var onSnapshotChange: ((DaemonSnapshot) -> Void)?
  var startCallCount = 0
  var stopCallCount = 0
  var restartCallCount = 0

  func start() async throws {
    startCallCount += 1
  }

  func stop() async {
    stopCallCount += 1
  }

  func restart() async throws {
    restartCallCount += 1
  }
}

private final class FakeWindow: ShellWindowControlling {
  var orderOutCallCount = 0
  var makeKeyAndOrderFrontCallCount = 0

  func orderOut(_ sender: Any?) {
    orderOutCallCount += 1
  }

  func makeKeyAndOrderFront(_ sender: Any?) {
    makeKeyAndOrderFrontCallCount += 1
  }
}

private final class FakeStatusItemController: StatusItemControlling {
  var lastStatusTitle: String?

  func install(
    openMainWindow: @escaping () -> Void,
    restartService: @escaping () -> Void,
    openLogs: @escaping () -> Void,
    quitApplication: @escaping () -> Void
  ) {}

  func update(with snapshot: DaemonSnapshot) {
    lastStatusTitle = "Server Status: \(snapshot.status.displayName)"
  }
}

private final class FakeCompanionBridge: CompanionBridging {
  var publishedSnapshots: [DaemonSnapshot] = []

  func publish(_ snapshot: DaemonSnapshot) {
    publishedSnapshots.append(snapshot)
  }

  func handleMethodCall(name _: String, arguments _: Any?) async throws {}
}

private final class FakeApplication: ApplicationControlling {
  var activateCallCount = 0
  var terminateCallCount = 0

  func activate(ignoringOtherApps _: Bool) {
    activateCallCount += 1
  }

  func terminate(_ sender: Any?) {
    terminateCallCount += 1
  }
}

private final class FakeWorkspace: WorkspaceOpening {
  var openedURLs: [URL] = []

  @discardableResult
  func open(_ url: URL) -> Bool {
    openedURLs.append(url)
    return true
  }
}
