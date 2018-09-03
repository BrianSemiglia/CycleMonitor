import Cocoa

let app = NSApplication.shared
let appDelegate = CycledApplicationDelegate()
app.delegate = appDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
