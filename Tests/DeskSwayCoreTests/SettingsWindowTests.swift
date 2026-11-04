import XCTest
import AppKit
@testable import DeskSway
import DeskSwayCore

final class SettingsWindowTests: XCTestCase {
    @MainActor
    func testPostingButtonRequestsPostingRatherThanAccessibility() async throws {
        _ = NSApplication.shared
        let controller = SettingsWindow()
        var postingRequests = 0
        var accessibilityRequests = 0
        controller.onPosting = { postingRequests += 1 }
        controller.onAccessibility = { accessibilityRequests += 1 }
        let button = try XCTUnwrap(button(named: "キー送信を許可…", in: controller.window?.contentView))
        button.performClick(nil)
        XCTAssertEqual(postingRequests, 1)
        XCTAssertEqual(accessibilityRequests, 0)
    }

    @MainActor
    func testSaveButtonPersistsWithoutClosingSettings() async throws {
        _ = NSApplication.shared
        let controller = SettingsWindow()
        var saved: InputConfiguration?
        var closed = false
        controller.onSave = { saved = $0 }
        controller.onClose = { closed = true }
        let button = try XCTUnwrap(button(named: "保存", in: controller.window?.contentView))
        button.performClick(nil)
        XCTAssertEqual(saved, .standard)
        XCTAssertFalse(closed)
    }

    @MainActor
    private func button(named title: String, in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton, button.title == title { return button }
        return view.subviews.lazy.compactMap { self.button(named: title, in: $0) }.first
    }
}
