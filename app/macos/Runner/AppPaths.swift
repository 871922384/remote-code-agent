import Foundation

struct AppPaths {
  let bundleURL: URL
  let applicationSupportURL: URL
  let logsURL: URL

  var nodeExecutableURL: URL {
    bundleURL.appendingPathComponent("Contents/Resources/bin/node")
  }

  var codexExecutableURL: URL {
    bundleURL.appendingPathComponent("Contents/Resources/bin/codex")
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
