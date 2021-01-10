import AppKit

class AppDelegate : NSObject, NSApplicationDelegate {

  let window = NSWindow()
  let windowDelegate = WindowDelegate()
  var rootViewController: NSViewController?

  func applicationDidFinishLaunching(_ notification: Notification) {

    window.setContentSize(
      NSSize(width: 512, height: 512)
    )

    window.level = .normal
    window.styleMask = [
      .titled,
      .closable,
      .miniaturizable,
      .resizable ]

    window.title = "Game of Life"
    window.delegate = windowDelegate
    window.center()

    let view = window.contentView!
    rootViewController = ViewController(nibName: nil, bundle: nil)
    rootViewController!.view.frame = view.bounds
    view.addSubview(rootViewController!.view)

    window.makeKeyAndOrderFront(window)

    NSApp.activate(ignoringOtherApps: true)

  }
}

class WindowDelegate : NSObject, NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    NSApp.terminate(self)
  }
  func windowDidResize(_ notification: Notification) {
    //print("didresize")
  }
}
