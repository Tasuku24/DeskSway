import AppKit
import ApplicationServices
import Foundation

// Read-only feasibility probe. No event tap, input monitoring, key posting,
// AX actions, screenshots, titles, or network access.
// AX APIs are public; the observed Mission Control identifiers are undocumented.
struct Scan {
    var mcDisplays = 0
    var exposeDisplays = 0
    var mcPopulated = 0
    var spaceLists = 0
    var nodes = 0
    var errors: [String] = []
}
let knownIDs: Set<String> = ["mc", "mc.display", "mc.spaces", "mc.spaces.list", "appexpose", "appexpose.display"]
let duration = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 15
let interval = 0.2
let start = ProcessInfo.processInfo.systemUptime
var previous = ""
var samples = 0
var totalMS = 0.0
var maxMS = 0.0
var heartbeat = start
setbuf(stdout, nil)

func read(_ e: AXUIElement, _ key: String) -> (AXError, CFTypeRef?) {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(e, key as CFString, &value)
    return (error, value)
}
func scan(_ e: AXUIElement, depth: Int, result: inout Scan) {
    guard result.nodes < 200, depth <= 4 else {
        result.errors.append("traversalLimit"); return
    }
    result.nodes += 1
    let (roleError, roleValue) = read(e, kAXRoleAttribute)
    guard roleError == .success, let role = roleValue as? String else {
        result.errors.append("role:\(roleError.rawValue)"); return
    }
    let (idError, idValue) = read(e, kAXIdentifierAttribute)
    if ![AXError.success, .attributeUnsupported, .noValue].contains(idError) {
        result.errors.append("identifier:\(idError.rawValue)")
    }
    let id = idValue as? String ?? ""
    // Avoid entering thumbnail buttons, app contents, and unrelated groups.
    guard depth == 0 || role == kAXGroupRole || knownIDs.contains(id) else { return }
    let (childError, childValue) = read(e, kAXChildrenAttribute)
    guard childError == .success, let children = childValue as? [AXUIElement] else {
        result.errors.append("children:\(childError.rawValue)"); return
    }
    if id == "mc.display", !children.isEmpty { result.mcDisplays += 1 }
    if id == "appexpose.display", !children.isEmpty { result.exposeDisplays += 1 }
    if id == "mc", !children.isEmpty { result.mcPopulated += 1 }
    if id == "mc.spaces.list" { result.spaceLists += 1 }
    for child in children { scan(child, depth: depth + 1, result: &result) }
}

print("probe=readOnly intervalMS=200 durationSeconds=\(duration) displayCount=\(NSScreen.screens.count)")
repeat {
    let tick = ProcessInfo.processInfo.systemUptime
    var sources: [String] = []
    var mc = 0
    var expose = 0
    var failed = false
    if !AXIsProcessTrusted() {
        failed = true
        sources = ["accessibilityPermissionMissing"]
    } else {
        for bundle in ["com.apple.dock", "com.apple.WindowManager"] {
            let label = bundle == "com.apple.dock" ? "Dock" : "WindowManager"
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
                failed = true; sources.append("\(label):processMissing"); continue
            }
            let root = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.15)
            var result = Scan()
            scan(root, depth: 0, result: &result)
            mc += result.mcDisplays + result.mcPopulated
            expose += result.exposeDisplays
            if !result.errors.isEmpty { failed = true }
            sources.append("\(label):mcDisplay=\(result.mcDisplays),mcGroup=\(result.mcPopulated),exposeDisplay=\(result.exposeDisplays),spaceList=\(result.spaceLists),nodes=\(result.nodes),errors=\(Set(result.errors).sorted())")
        }
    }
    // An AX error must never become 'inactive'. Simultaneous signatures also fail open.
    let state = failed || (mc > 0 && expose > 0) ? "unknown" : mc > 0 ? "missionControl" : expose > 0 ? "appExpose" : "inactiveCandidate"
    let signature = "state=\(state) " + sources.joined(separator: " ")
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
