import Foundation
import XCTest
@testable import agent_workbench

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
      paths.codexExecutableURL.path,
      "/tmp/agent_workbench.app/Contents/Resources/bin/codex"
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
