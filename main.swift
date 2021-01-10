import AppKit

let app = NSApplication.shared
NSApp.setActivationPolicy(.regular)

let appDelegate = AppDelegate()
NSApp.delegate = appDelegate

NSApp.run()
