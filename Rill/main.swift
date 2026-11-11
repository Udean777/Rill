import AppKit

// Top-level bindings are globals: the delegate outlives this frame for the
// lifetime of the process, which NSApplication.delegate (weak) requires.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
