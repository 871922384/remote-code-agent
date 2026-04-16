import Cocoa
import Foundation

protocol DaemonControlling: AnyObject {
  var snapshot: DaemonSnapshot { get }
  var onSnapshotChange: ((DaemonSnapshot) -> Void)? { get set }

  func start() async throws
  func stop() async
  func restart() async throws
}

protocol ShellWindowControlling: AnyObject {
  func orderOut(_ sender: Any?)
  func makeKeyAndOrderFront(_ sender: Any?)
}

protocol ApplicationControlling: AnyObject {
  func activate(ignoringOtherApps flag: Bool)
  func terminate(_ sender: Any?)
}

protocol StatusItemControlling: AnyObject {
  func install(
    openMainWindow: @escaping () -> Void,
    restartService: @escaping () -> Void,
    openLogs: @escaping () -> Void,
    quitApplication: @escaping () -> Void
  )

  func update(with snapshot: DaemonSnapshot)
}

protocol ShellWindowLifecycleDelegate: AnyObject {
  func handleMainWindowClose() -> Bool
}

protocol CompanionBridging: AnyObject {
  func publish(_ snapshot: DaemonSnapshot)
  func handleMethodCall(name: String, arguments: Any?) async throws
}

extension DaemonController: DaemonControlling {}
extension MainFlutterWindow: ShellWindowControlling {}
extension NSApplication: ApplicationControlling {}

extension DaemonStatus {
  var displayName: String {
    switch self {
    case .starting:
      return "Starting"
    case .running:
      return "Running"
    case .stopping:
      return "Stopping"
    case .stopped:
      return "Stopped"
    case .failed:
      return "Failed"
    }
  }

  var menuBarTitle: String {
    switch self {
    case .starting, .stopping:
      return "Agent..."
    case .failed:
      return "Agent!"
    case .running, .stopped:
      return "Agent"
    }
  }
}

final class ShellCoordinator: ShellWindowLifecycleDelegate {
  init(
    daemonController: DaemonControlling,
    windowController: ShellWindowControlling,
    statusItemController: StatusItemControlling,
    bridge: CompanionBridging,
    application: ApplicationControlling
  ) {
    self.daemonController = daemonController
    self.windowController = windowController
    self.statusItemController = statusItemController
    self.bridge = bridge
    self.application = application
  }

  private let daemonController: DaemonControlling
  private let windowController: ShellWindowControlling
  private let statusItemController: StatusItemControlling
  private let bridge: CompanionBridging
  private let application: ApplicationControlling

  func start() {
    daemonController.onSnapshotChange = { [weak self] snapshot in
      DispatchQueue.main.async {
        self?.apply(snapshot: snapshot)
      }
    }

    statusItemController.install(
      openMainWindow: { [weak self] in
        self?.showMainWindow()
      },
      restartService: { [weak self] in
        guard let self else { return }
        Task {
          try? await self.bridge.handleMethodCall(name: "restartDaemon", arguments: nil)
        }
      },
      openLogs: { [weak self] in
        guard let self else { return }
        Task {
          try? await self.bridge.handleMethodCall(name: "openLogs", arguments: nil)
        }
      },
      quitApplication: { [weak self] in
        guard let self else { return }
        Task {
          try? await self.bridge.handleMethodCall(name: "quitApplication", arguments: nil)
        }
      }
    )

    apply(snapshot: daemonController.snapshot)

    Task { [weak self] in
      guard let self else { return }
      try? await self.daemonController.start()
    }
  }

  func handleMainWindowClose() -> Bool {
    windowController.orderOut(nil)
    return false
  }

  func showMainWindow() {
    application.activate(ignoringOtherApps: true)
    windowController.makeKeyAndOrderFront(nil)
  }

  func apply(snapshot: DaemonSnapshot) {
    statusItemController.update(with: snapshot)
    bridge.publish(snapshot)
  }

  func prepareForTermination() {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      await daemonController.stop()
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 2)
  }
}
