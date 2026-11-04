import AppKit
import Darwin

let arguments = CommandLine.arguments
if arguments.count == 3, arguments[1] == "--relaunch-after",
   let previousPID = Int32(arguments[2]), previousPID > 1, previousPID != getpid() {
    // No AppKit application, event tap or permission request in this helper.
    let deadline = ProcessInfo.processInfo.systemUptime + 10
    while kill(previousPID, 0) == 0 && ProcessInfo.processInfo.systemUptime < deadline {
        Thread.sleep(forTimeInterval: 0.05)
    }
    guard kill(previousPID, 0) != 0 else { exit(1) }
    let opener = Process()
    opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    opener.arguments = ["-n", Bundle.main.bundleURL.path]
    do { try opener.run(); opener.waitUntilExit(); exit(opener.terminationStatus) }
    catch { exit(1) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
