import Foundation

enum DaemonStatus: String {
  case starting
  case running
  case stopping
  case stopped
  case failed
}

struct DaemonSnapshot: Equatable {
  var status: DaemonStatus
  var errorMessage: String?
  var logFilePath: String
  var recentLogs: [String]

  init(
    status: DaemonStatus = .stopped,
    errorMessage: String? = nil,
    logFilePath: String,
    recentLogs: [String] = []
  ) {
    self.status = status
    self.errorMessage = errorMessage
    self.logFilePath = logFilePath
    self.recentLogs = recentLogs
  }
}

protocol DaemonProcessHandle: AnyObject {
  var isRunning: Bool { get }

  func setOutputHandlers(
    stdout: @escaping (String) -> Void,
    stderr: @escaping (String) -> Void
  )

  func terminate()
  func kill()
  func waitForExit(timeout: TimeInterval) async -> Bool
}

protocol DaemonProcessLauncher {
  func launch(
    executableURL: URL,
    arguments: [String],
    environment: [String: String],
    currentDirectoryURL: URL
  ) throws -> DaemonProcessHandle
}

protocol HealthCheckClient {
  func waitUntilHealthy(url: URL) async throws
}

final class DaemonController {
  static func live() -> DaemonController {
    let fileManager = FileManager.default
    let applicationSupportURL =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
        "Library/Application Support",
        isDirectory: true
      )
    let logsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Logs",
      isDirectory: true
    )

    return DaemonController(
      processLauncher: LiveDaemonProcessLauncher(),
      healthCheckClient: HttpHealthCheckClient(),
      paths: AppPaths(
        bundleURL: Bundle.main.bundleURL,
        applicationSupportURL: applicationSupportURL,
        logsURL: logsURL
      )
    )
  }

  init(
    processLauncher: DaemonProcessLauncher,
    healthCheckClient: HealthCheckClient,
    paths: AppPaths,
    healthCheckURL: URL = URL(string: "http://127.0.0.1:3333/health")!,
    startupPollInterval: TimeInterval = 0.05,
    shutdownTimeout: TimeInterval = 1,
    fileManager: FileManager = .default,
    onSnapshotChange: ((DaemonSnapshot) -> Void)? = nil
  ) {
    self.processLauncher = processLauncher
    self.healthCheckClient = healthCheckClient
    self.paths = paths
    self.healthCheckURL = healthCheckURL
    self.startupPollInterval = startupPollInterval
    self.shutdownTimeout = shutdownTimeout
    self.fileManager = fileManager
    self.onSnapshotChange = onSnapshotChange
    snapshot = DaemonSnapshot(logFilePath: paths.daemonLogDirectoryURL.appendingPathComponent("daemon.log").path)
  }

  private let processLauncher: DaemonProcessLauncher
  private let healthCheckClient: HealthCheckClient
  private let paths: AppPaths
  private let healthCheckURL: URL
  private let startupPollInterval: TimeInterval
  private let shutdownTimeout: TimeInterval
  private let fileManager: FileManager

  private var process: DaemonProcessHandle?

  var onSnapshotChange: ((DaemonSnapshot) -> Void)?
  private(set) var snapshot: DaemonSnapshot {
    didSet {
      onSnapshotChange?(snapshot)
    }
  }

  func start() async throws {
    if snapshot.status == .running {
      return
    }

    updateSnapshot(status: .starting, errorMessage: nil)
    appendLog("Launching daemon...")
    try prepareRuntimeDirectories()

    do {
      let launchedProcess = try processLauncher.launch(
        executableURL: paths.nodeExecutableURL,
        arguments: [paths.daemonEntrypointURL.path],
        environment: [
          "HOST": "0.0.0.0",
          "PORT": String(healthCheckURL.port ?? 3333),
          "DAEMON_DATA_DIR": paths.daemonDataDirectoryURL.path,
          "REMOTE_CODE_AGENT_CODEX_BIN": paths.codexExecutableURL.path,
        ],
        currentDirectoryURL: paths.daemonEntrypointURL
          .deletingLastPathComponent()
          .deletingLastPathComponent()
      )
      launchedProcess.setOutputHandlers(
        stdout: { [weak self] line in self?.appendLog(line) },
        stderr: { [weak self] line in self?.appendLog(line) }
      )
      process = launchedProcess
    } catch {
      updateSnapshot(status: .failed, errorMessage: "Failed to launch daemon: \(error)")
      appendLog(snapshot.errorMessage ?? "Failed to launch daemon.")
      throw error
    }

    var lastHealthCheckError: Error?
    while process?.isRunning == true {
      do {
        try await healthCheckClient.waitUntilHealthy(url: healthCheckURL)
        updateSnapshot(status: .running, errorMessage: nil)
        appendLog("Daemon is healthy.")
        return
      } catch {
        lastHealthCheckError = error
        if startupPollInterval > 0 {
          try? await Task.sleep(nanoseconds: UInt64(startupPollInterval * 1_000_000_000))
        }
      }
    }

    let message = lastHealthCheckError.map { "Daemon failed to become healthy: \($0)" }
      ?? "Daemon exited before becoming healthy."
    updateSnapshot(status: .failed, errorMessage: message)
    appendLog(message)
    throw lastHealthCheckError ?? DaemonControllerError.processExitedBeforeHealthy
  }

  func stop() async {
    guard let process else {
      updateSnapshot(status: .stopped, errorMessage: nil)
      return
    }

    updateSnapshot(status: .stopping, errorMessage: nil)
    process.terminate()
    let exitedGracefully = await process.waitForExit(timeout: shutdownTimeout)
    if !exitedGracefully {
      process.kill()
      _ = await process.waitForExit(timeout: shutdownTimeout)
    }
    self.process = nil
    updateSnapshot(status: .stopped, errorMessage: nil)
  }

  func restart() async throws {
    await stop()
    try await start()
  }

  private func updateSnapshot(status: DaemonStatus, errorMessage: String?) {
    snapshot.status = status
    snapshot.errorMessage = errorMessage
  }

  private func prepareRuntimeDirectories() throws {
    try fileManager.createDirectory(
      at: paths.daemonDataDirectoryURL,
      withIntermediateDirectories: true
    )
    try fileManager.createDirectory(
      at: paths.daemonLogDirectoryURL,
      withIntermediateDirectories: true
    )
    if !fileManager.fileExists(atPath: snapshot.logFilePath) {
      fileManager.createFile(atPath: snapshot.logFilePath, contents: nil)
    }
  }

  private func appendLog(_ line: String) {
    snapshot.recentLogs.append(line)
    snapshot.recentLogs = Array(snapshot.recentLogs.suffix(100))

    guard let data = "\(line)\n".data(using: .utf8) else {
      return
    }

    if !fileManager.fileExists(atPath: snapshot.logFilePath) {
      fileManager.createFile(atPath: snapshot.logFilePath, contents: nil)
    }

    guard let handle = FileHandle(forWritingAtPath: snapshot.logFilePath) else {
      return
    }

    handle.seekToEndOfFile()
    handle.write(data)
    handle.closeFile()
  }
}

enum DaemonControllerError: Error {
  case processExitedBeforeHealthy
}

final class LiveDaemonProcessLauncher: DaemonProcessLauncher {
  func launch(
    executableURL: URL,
    arguments: [String],
    environment: [String: String],
    currentDirectoryURL: URL
  ) throws -> DaemonProcessHandle {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectoryURL
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    try process.run()
    return LiveDaemonProcessHandle(process: process, stdoutPipe: stdoutPipe, stderrPipe: stderrPipe)
  }
}

final class LiveDaemonProcessHandle: DaemonProcessHandle {
  init(process: Process, stdoutPipe: Pipe, stderrPipe: Pipe) {
    self.process = process
    self.stdoutPipe = stdoutPipe
    self.stderrPipe = stderrPipe
  }

  private let process: Process
  private let stdoutPipe: Pipe
  private let stderrPipe: Pipe
  private var stdoutBuffer = Data()
  private var stderrBuffer = Data()

  var isRunning: Bool {
    process.isRunning
  }

  func setOutputHandlers(
    stdout: @escaping (String) -> Void,
    stderr: @escaping (String) -> Void
  ) {
    stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      self?.consumeStdout(from: handle, emit: stdout)
    }
    stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      self?.consumeStderr(from: handle, emit: stderr)
    }
  }

  func terminate() {
    process.terminate()
  }

  func kill() {
    process.terminate()
  }

  func waitForExit(timeout: TimeInterval) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning && Date() < deadline {
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
    return !process.isRunning
  }

  private func consumeStdout(from handle: FileHandle, emit: @escaping (String) -> Void) {
    consume(data: handle.availableData, buffer: &stdoutBuffer, emit: emit)
  }

  private func consumeStderr(from handle: FileHandle, emit: @escaping (String) -> Void) {
    consume(data: handle.availableData, buffer: &stderrBuffer, emit: emit)
  }

  private func consume(data: Data, buffer: inout Data, emit: @escaping (String) -> Void) {
    if data.isEmpty {
      return
    }

    buffer.append(data)
    while let newline = buffer.firstIndex(of: 0x0A) {
      let lineData = buffer.subdata(in: buffer.startIndex..<newline)
      buffer.removeSubrange(buffer.startIndex...newline)
      if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
        emit(line)
      }
    }
  }
}

final class HttpHealthCheckClient: HealthCheckClient {
  func waitUntilHealthy(url: URL) async throws {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard
      let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200
    else {
      throw URLError(.badServerResponse)
    }

    let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard payload?["ok"] as? Bool == true else {
      throw URLError(.cannotParseResponse)
    }
  }
}
