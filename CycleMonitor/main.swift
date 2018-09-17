import Cocoa
import Cycle

let app = NSApplication.shared
let appDelegate = CycledApplicationDelegate(
  router: CycleMonitorApp()
)
app.delegate = appDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
