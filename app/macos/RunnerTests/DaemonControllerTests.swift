import Foundation
import XCTest
@testable import agent_workbench

final class DaemonControllerTests: XCTestCase {
  func test_start_transitionsFromStartingToRunningAfterHealthCheck() async throws {
    let process = FakeProcessHandle()
    let healthCheck = FakeHealthCheckClient(
      results: [.failure(TestError.notReady), .success(())]
    )
    let controller = DaemonController(
      processLauncher: FakeProcessLauncher(process: process),
      healthCheckClient: healthCheck,
      paths: .testDefault()
    )

    try await controller.start()

    XCTAssertEqual(controller.snapshot.status, .running)
    XCTAssertEqual(process.launchCount, 1)
    XCTAssertEqual(
      process.environment["DAEMON_DATA_DIR"],
      "/tmp/agent-workbench-tests/Application Support/agent_workbench"
    )
    XCTAssertEqual(
      process.environment["REMOTE_CODE_AGENT_CODEX_BIN"],
      "/tmp/agent_workbench.app/Contents/Resources/bin/codex"
    )
  }

  func test_stop_requestsTerminateThenKillAfterTimeout() async throws {
    let process = FakeProcessHandle(exitAfterTerminate: false)
    let controller = DaemonController(
      processLauncher: FakeProcessLauncher(process: process),
      healthCheckClient: FakeHealthCheckClient(results: [.success(())]),
      paths: .testDefault(),
      shutdownTimeout: 0.001
    )

    try await controller.start()
    await controller.stop()

    XCTAssertEqual(process.terminateCallCount, 1)
    XCTAssertEqual(process.killCallCount, 1)
    XCTAssertEqual(controller.snapshot.status, .stopped)
  }
}

private enum TestError: Error {
  case notReady
}

private final class FakeProcessLauncher: DaemonProcessLauncher {
  init(process: FakeProcessHandle) {
    self.process = process
  }

  let process: FakeProcessHandle

  func launch(
    executableURL: URL,
    arguments: [String],
    environment: [String: String],
    currentDirectoryURL: URL
  ) throws -> DaemonProcessHandle {
    process.launchCount += 1
    process.executableURL = executableURL
    process.arguments = arguments
    process.environment = environment
    process.currentDirectoryURL = currentDirectoryURL
    return process
  }
}

private final class FakeProcessHandle: DaemonProcessHandle {
  init(exitAfterTerminate: Bool = true) {
    self.exitAfterTerminate = exitAfterTerminate
  }

  let exitAfterTerminate: Bool
  var launchCount = 0
  var terminateCallCount = 0
  var killCallCount = 0
  var executableURL: URL?
  var arguments: [String] = []
  var environment: [String: String] = [:]
  var currentDirectoryURL: URL?
  var isRunning = true

  func setOutputHandlers(
    stdout _: @escaping (String) -> Void,
    stderr _: @escaping (String) -> Void
  ) {}

  func terminate() {
    terminateCallCount += 1
    if exitAfterTerminate {
      isRunning = false
    }
  }

  func kill() {
    killCallCount += 1
    isRunning = false
  }

  func waitForExit(timeout _: TimeInterval) async -> Bool {
    !isRunning
  }
}

private final class FakeHealthCheckClient: HealthCheckClient {
  init(results: [Result<Void, Error>]) {
    self.results = results
  }

  private var results: [Result<Void, Error>]

  func waitUntilHealthy(url _: URL) async throws {
    guard !results.isEmpty else {
      return
    }

    let next = results.removeFirst()
    switch next {
    case .success:
      return
    case let .failure(error):
      throw error
    }
  }
}

private extension AppPaths {
  static func testDefault() -> AppPaths {
    AppPaths(
      bundleURL: URL(fileURLWithPath: "/tmp/agent_workbench.app"),
      applicationSupportURL: URL(fileURLWithPath: "/tmp/agent-workbench-tests/Application Support"),
      logsURL: URL(fileURLWithPath: "/tmp/agent-workbench-tests/Logs")
    )
  }
}
