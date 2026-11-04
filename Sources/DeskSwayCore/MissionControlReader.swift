import AppKit
import ApplicationServices
import Foundation

// Public AX APIs; these UI identifiers are undocumented and OS-dependent.
// Reads roles, identifiers and children only, never titles or input text.
public struct MissionControlReader {
    public struct Report {
        public let detection: Detection
        public let details: String
    }
    struct Scan {
        var mcDisplays = 0
        var exposeDisplays = 0
        var mcPopulated = 0
        var spaceLists = 0
        var nodes = 0
        var errors: [String] = []
    }
    private static let knownIDs: Set<String> = ["mc", "mc.display", "mc.spaces", "mc.spaces.list", "appexpose", "appexpose.display"]
    // The AX boundary is injectable internally for traversal/error tests.
    var configureTimeout: (AXUIElement, Float) -> AXError = AXUIElementSetMessagingTimeout
    var readAttribute: (AXUIElement, String) -> (AXError, CFTypeRef?) = { element, key in
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        return (error, value)
    }
    public init() {}
    public static func classify(mc: Int, expose: Int, failed: Bool) -> OverviewState {
        if failed || (mc > 0 && expose > 0) { return .unknown }
        return mc > 0 ? .missionControl : expose > 0 ? .appExpose : .inactiveCandidate
    }
    public func scan() -> Report {
        // Timestamp the START: a slow read must not revive an old observation.
        let started = ProcessInfo.processInfo.systemUptime
        guard AXIsProcessTrusted() else {
            return Report(detection: Detection(state: .unknown, observedAt: started), details: "accessibilityPermissionMissing")
        }
        var sources: [String] = []
        var mc = 0, expose = 0
        var failed = false
        for bundle in ["com.apple.dock", "com.apple.WindowManager"] {
            let label = bundle == "com.apple.dock" ? "Dock" : "WindowManager"
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
                failed = true; sources.append("\(label):processMissing"); continue
            }
            let root = AXUIElementCreateApplication(app.processIdentifier)
            var result = Scan()
            scan(root, depth: 0, result: &result)
            mc += result.mcDisplays + result.mcPopulated
            expose += result.exposeDisplays
            if !result.errors.isEmpty { failed = true }
            sources.append("\(label):mcDisplay=\(result.mcDisplays),mcGroup=\(result.mcPopulated),exposeDisplay=\(result.exposeDisplays),spaceList=\(result.spaceLists),nodes=\(result.nodes),errors=\(Set(result.errors).sorted())")
        }
        return Report(detection: Detection(state: Self.classify(mc: mc, expose: expose, failed: failed), observedAt: started), details: sources.joined(separator: " "))
    }
    func scan(_ element: AXUIElement, depth: Int, result: inout Scan) {
        guard result.nodes < 200, depth <= 4 else { result.errors.append("traversalLimit"); return }
        result.nodes += 1
        // An application-root timeout is NOT inherited by child AX objects.
        guard configureTimeout(element, 0.15) == .success else {
            result.errors.append("timeoutSetupFailed"); return
        }
        let (roleError, roleValue) = readAttribute(element, kAXRoleAttribute)
        guard roleError == .success, let role = roleValue as? String else { result.errors.append("role:\(roleError.rawValue)"); return }
        let (idError, idValue) = readAttribute(element, kAXIdentifierAttribute)
        if ![AXError.success, .attributeUnsupported, .noValue].contains(idError) { result.errors.append("identifier:\(idError.rawValue)") }
        let id = idValue as? String ?? ""
        guard depth == 0 || role == kAXGroupRole || Self.knownIDs.contains(id) else { return }
        let (childError, childValue) = readAttribute(element, kAXChildrenAttribute)
        guard childError == .success, let children = childValue as? [AXUIElement] else { result.errors.append("children:\(childError.rawValue)"); return }
        if id == "mc.display", !children.isEmpty { result.mcDisplays += 1 }
        if id == "appexpose.display", !children.isEmpty { result.exposeDisplays += 1 }
        if id == "mc", !children.isEmpty { result.mcPopulated += 1 }
        if id == "mc.spaces.list" { result.spaceLists += 1 }
        guard depth < 4 || children.isEmpty else { result.errors.append("traversalLimit"); return }
        for child in children {
            guard result.nodes < 200 else { result.errors.append("traversalLimit"); break }
            scan(child, depth: depth + 1, result: &result)
        }
    }
}
