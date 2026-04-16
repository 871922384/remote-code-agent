import Cocoa
import FlutterMacOS
import Foundation

protocol WorkspaceOpening: AnyObject {
  @discardableResult
  func open(_ url: URL) -> Bool
}

extension NSWorkspace: WorkspaceOpening {}

extension DaemonSnapshot {
  var asDictionary: [String: Any] {
    [
      "status": status.rawValue,
      "errorMessage": errorMessage as Any,
      "logFilePath": logFilePath,
      "recentLogs": recentLogs,
    ]
  }
}

enum CompanionBridgeError: Error {
  case unimplemented(String)
}

final class CompanionBridge: NSObject, CompanionBridging, FlutterStreamHandler {
  init(
    daemonController: DaemonControlling,
    workspace: WorkspaceOpening,
    application: ApplicationControlling
  ) {
    self.daemonController = daemonController
    self.workspace = workspace
    self.application = application
  }

  convenience init(
    messenger: FlutterBinaryMessenger,
    daemonController: DaemonControlling,
    workspace: WorkspaceOpening,
    application: ApplicationControlling
  ) {
    self.init(
      daemonController: daemonController,
      workspace: workspace,
      application: application
    )

    let methodChannel = FlutterMethodChannel(
      name: Self.methodChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }

    let eventChannel = FlutterEventChannel(
      name: Self.eventChannelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)

    self.methodChannel = methodChannel
    self.eventChannel = eventChannel
  }

  private static let methodChannelName = "agent_workbench/companion/methods"
  private static let eventChannelName = "agent_workbench/companion/events"

  private let daemonController: DaemonControlling
  private let workspace: WorkspaceOpening
  private let application: ApplicationControlling

  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?

  func publish(_ snapshot: DaemonSnapshot) {
    let payload = snapshot.asDictionary
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }

  func handleMethodCall(name: String, arguments _: Any?) async throws {
    switch name {
    case "restartDaemon":
      try await daemonController.restart()
    case "openLogs":
      _ = workspace.open(URL(fileURLWithPath: daemonController.snapshot.logFilePath))
    case "quitApplication":
      await daemonController.stop()
      application.terminate(nil)
    default:
      throw CompanionBridgeError.unimplemented(name)
    }
  }

  func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    events(daemonController.snapshot.asDictionary)
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    Task {
      do {
        try await handleMethodCall(name: call.method, arguments: call.arguments)
        result(nil)
      } catch CompanionBridgeError.unimplemented {
        result(FlutterMethodNotImplemented)
      } catch {
        result(
          FlutterError(
            code: "companion_bridge",
            message: String(describing: error),
            details: nil
          )
        )
      }
    }
  }
}
