import XCTest
import ApplicationServices
@testable import DeskSwayCore

final class TraversalTests: XCTestCase {
    func testEachAXElementGetsTimeoutBeforeAnyRead() {
        let root = AXUIElementCreateApplication(100)
        let child = AXUIElementCreateApplication(101)
        var configured: [AXUIElement] = []
        var reader = MissionControlReader()
        reader.configureTimeout = { element, timeout in
            XCTAssertEqual(timeout, 0.15)
            configured.append(element)
            return .success
        }
        reader.readAttribute = { element, attribute in
            // Simulates an unresponsive AX source unless the element is bounded.
            guard configured.contains(where: { CFEqual($0, element) }) else { return (.cannotComplete, nil) }
            switch attribute {
            case kAXRoleAttribute: return (.success, kAXGroupRole as CFString)
            case kAXIdentifierAttribute: return (.success, (CFEqual(element, child) ? "mc.display" : "mc") as CFString)
            default: return (.success, (CFEqual(element, root) ? [child] : []) as CFArray)
            }
        }
        var result = MissionControlReader.Scan()
        reader.scan(root, depth: 0, result: &result)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.nodes, 2)
        XCTAssertEqual(result.mcPopulated, 1)
    }
    func testTimeoutSetupFailureDoesNotReadElement() {
        let root = AXUIElementCreateApplication(100)
        var reader = MissionControlReader()
        reader.configureTimeout = { _, _ in .invalidUIElement }
        reader.readAttribute = { _, _ in XCTFail("Must not perform unbounded reads"); return (.cannotComplete, nil) }
        var result = MissionControlReader.Scan()
        reader.scan(root, depth: 0, result: &result)
        XCTAssertFalse(result.errors.isEmpty)
    }
    func testTraversalStopsAtNodeLimit() {
        var reader = MissionControlReader()
        reader.configureTimeout = { _, _ in .success }
        reader.readAttribute = { _, attribute in
            switch attribute {
            case kAXRoleAttribute: return (.success, kAXGroupRole as CFString)
            case kAXIdentifierAttribute: return (.attributeUnsupported, nil)
            default: return (.success, (0..<250).map { AXUIElementCreateApplication(pid_t($0 + 100)) } as CFArray)
            }
        }
        var result = MissionControlReader.Scan()
        reader.scan(AXUIElementCreateApplication(1), depth: 0, result: &result)
        XCTAssertLessThanOrEqual(result.nodes, 200)
        XCTAssertTrue(result.errors.contains("traversalLimit"))
    }
}
