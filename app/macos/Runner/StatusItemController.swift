import Cocoa
import Foundation

final class StatusItemController: NSObject, StatusItemControlling {
  init(statusBar: NSStatusBar = .system) {
    statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
    super.init()
    statusItem.button?.title = DaemonStatus.stopped.menuBarTitle
    statusItem.menu = statusMenu
    serverStatusMenuItem.isEnabled = false
    serverStatusMenuItem.title = "Server Status: \(DaemonStatus.stopped.displayName)"
  }

  private let statusItem: NSStatusItem
  private let statusMenu = NSMenu()
  private let serverStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private var actionHandlers: [MenuActionHandler] = []

  func install(
    openMainWindow: @escaping () -> Void,
    restartService: @escaping () -> Void,
    openLogs: @escaping () -> Void,
    quitApplication: @escaping () -> Void
  ) {
    actionHandlers.removeAll()
    statusMenu.removeAllItems()
    statusMenu.addItem(makeMenuItem(title: "Open Main Window", handler: openMainWindow))
    statusMenu.addItem(serverStatusMenuItem)
    statusMenu.addItem(.separator())
    statusMenu.addItem(makeMenuItem(title: "Restart Service", handler: restartService))
    statusMenu.addItem(makeMenuItem(title: "Open Logs", handler: openLogs))
    statusMenu.addItem(.separator())
    statusMenu.addItem(makeMenuItem(title: "Quit", handler: quitApplication))
  }

  func update(with snapshot: DaemonSnapshot) {
    statusItem.button?.title = snapshot.status.menuBarTitle
    serverStatusMenuItem.title = "Server Status: \(snapshot.status.displayName)"
  }

  private func makeMenuItem(title: String, handler: @escaping () -> Void) -> NSMenuItem {
    let actionHandler = MenuActionHandler(handler: handler)
    actionHandlers.append(actionHandler)
    let item = NSMenuItem(title: title, action: #selector(MenuActionHandler.invoke), keyEquivalent: "")
    item.target = actionHandler
    return item
  }
}

private final class MenuActionHandler: NSObject {
  init(handler: @escaping () -> Void) {
    self.handler = handler
  }

  private let handler: () -> Void

  @objc func invoke() {
    handler()
  }
}
