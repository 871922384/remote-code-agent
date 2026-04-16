import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var shellCoordinator: ShellCoordinator?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard
      let window = mainFlutterWindow as? MainFlutterWindow,
      let controller = window.contentViewController as? FlutterViewController
    else {
      super.applicationDidFinishLaunching(notification)
      return
    }

    let daemonController = DaemonController.live()
    let bridge = CompanionBridge(
      messenger: controller.engine.binaryMessenger,
      daemonController: daemonController,
      workspace: NSWorkspace.shared,
      application: NSApplication.shared
    )
    let shellCoordinator = ShellCoordinator(
      daemonController: daemonController,
      windowController: window,
      statusItemController: StatusItemController(),
      bridge: bridge,
      application: NSApplication.shared
    )

    window.lifecycleDelegate = shellCoordinator
    self.shellCoordinator = shellCoordinator
    shellCoordinator.start()

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    shellCoordinator?.showMainWindow()
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    shellCoordinator?.prepareForTermination()
    super.applicationWillTerminate(notification)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }
}
