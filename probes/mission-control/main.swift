import AppKit
import Foundation

// Read-only probe: shares exactly the app's AX reader, but no event adapter,
// event tap, key posting, AX actions, screenshots or input monitoring.
let duration = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 15
let interval = 0.2
let start = ProcessInfo.processInfo.systemUptime
var previous = ""
var samples = 0
var totalMS = 0.0
var maxMS = 0.0
var heartbeat = start
setbuf(stdout, nil)

print("probe=readOnly intervalMS=200 durationSeconds=\(duration) displayCount=\(NSScreen.screens.count)")
repeat {
    let tick = ProcessInfo.processInfo.systemUptime
    let report = MissionControlReader().scan()
    let signature = "state=\(report.detection.state.rawValue) " + report.details
    let now = ProcessInfo.processInfo.systemUptime
    let ms = (now - tick) * 1000
    samples += 1; totalMS += ms; maxMS = max(maxMS, ms)
    if signature != previous || now >= heartbeat {
        print(String(format: "t=%.3f scanMS=%.3f ", now - start, ms) + signature)
        previous = signature; heartbeat = now + 5
    }
    RunLoop.current.run(until: Date(timeIntervalSinceNow: max(0, interval - (ProcessInfo.processInfo.systemUptime - tick))))
} while ProcessInfo.processInfo.systemUptime - start < duration
print(String(format: "summary samples=%d meanScanMS=%.3f maxScanMS=%.3f", samples, totalMS / Double(max(1, samples)), maxMS))
