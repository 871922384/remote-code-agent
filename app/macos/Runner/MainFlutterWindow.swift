import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  weak var lifecycleDelegate: ShellWindowLifecycleDelegate?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func performClose(_ sender: Any?) {
    if lifecycleDelegate?.handleMainWindowClose() == false {
      return
    }

    super.performClose(sender)
  }
}
