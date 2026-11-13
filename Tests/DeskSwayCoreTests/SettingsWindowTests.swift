import XCTest
import AppKit
@testable import DeskSway
import DeskSwayCore
import ServiceManagement

final class SettingsWindowTests: XCTestCase {
    @MainActor
    func testLaunchAtLoginReflectsSystemStatusAndApproval() async throws {
        _ = NSApplication.shared
        let controller = SettingsWindow()
        let content = try XCTUnwrap(controller.window?.contentView)
        let toggle = try launchAtLoginSwitch(in: content)
        let approval = try XCTUnwrap(button(named: "ログイン項目を開く…", in: content))
        var opened = false
        controller.onOpenLoginItems = { opened = true }
        for (status, state, needsApproval) in [
            (SMAppService.Status.notRegistered, NSControl.StateValue.off, false),
            (.enabled, .on, false), (.requiresApproval, .on, true), (.notRegistered, .off, false),
            (.notFound, .off, false)
        ] {
            controller.update(settingsStatus(loginItem: status))
            XCTAssertEqual(toggle.state, state)
            XCTAssertEqual(approval.isHidden, !needsApproval)
            if needsApproval { approval.performClick(nil) }
        }
        XCTAssertTrue(opened)
    }

    @MainActor
    func testLaunchAtLoginAppliesImmediatelyWithoutSavingDraft() async throws {
        _ = NSApplication.shared
        let controller = SettingsWindow()
        let content = try XCTUnwrap(controller.window?.contentView)
        let toggle = try launchAtLoginSwitch(in: content)
        let slider = try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSSlider }.first)
        slider.doubleValue = 1.25
        NSApp.sendAction(try XCTUnwrap(slider.action), to: slider.target, from: slider)
        var requests: [Bool] = []
        var systemStatus = SMAppService.Status.notRegistered
        var saves = 0
        controller.onSave = { _ in saves += 1 }
        controller.onSetLaunchAtLogin = {
            requests.append($0)
            systemStatus = $0 ? .enabled : .notRegistered
        }
        controller.onRefresh = { [weak controller] in controller?.update(self.settingsStatus(loginItem: systemStatus)) }
        for state in [NSControl.StateValue.on, .off] {
            toggle.state = state
            NSApp.sendAction(try XCTUnwrap(toggle.action), to: toggle.target, from: toggle)
            XCTAssertEqual(toggle.state, state)
        }
        XCTAssertEqual(requests, [true, false])
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(slider.doubleValue, 1.25)
    }

    @MainActor
    func testLaunchAtLoginFailureRestoresSystemStateAndShowsError() async throws {
        _ = NSApplication.shared
        let controller = SettingsWindow()
        let content = try XCTUnwrap(controller.window?.contentView)
        let toggle = try launchAtLoginSwitch(in: content)
        controller.onSetLaunchAtLogin = { _ in throw NSError(domain: "LoginItemTest", code: 1,
                                                            userInfo: [NSLocalizedDescriptionKey: "Registration denied"]) }
        for status in [SMAppService.Status.notRegistered, .enabled, .requiresApproval] {
            controller.update(settingsStatus(loginItem: status))
            let previous = toggle.state
            controller.onRefresh = { [weak controller] in controller?.update(self.settingsStatus(loginItem: status)) }
            toggle.state = previous == .on ? .off : .on
            NSApp.sendAction(try XCTUnwrap(toggle.action), to: toggle.target, from: toggle)
            XCTAssertEqual(toggle.state, previous)
            XCTAssertTrue(descendants(of: content).compactMap { $0 as? NSTextField }
                .contains { $0.stringValue.contains("Registration denied") })
        }
    }

    @MainActor
    private func settingsStatus(loginItem: SMAppService.Status) -> SettingsStatus {
        SettingsStatus(running: false, accessibility: false, listening: false, posting: false,
                       summary: "", detection: "", loginItem: loginItem)
    }

    @MainActor
    private func launchAtLoginSwitch(in content: NSView) throws -> NSSwitch {
        try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSSwitch }
            .first { $0.accessibilityLabel() == L("ログイン時に起動") })
    }

    @MainActor
    func testPostingButtonRequestsPostingRatherThanAccessibility() async throws {
        let savedLanguage = InterfaceLanguage.saved
        defer { InterfaceLanguage.saved = savedLanguage }
        _ = NSApplication.shared
        let controller = SettingsWindow()
        var postingRequests = 0
        var accessibilityRequests = 0
        controller.onPosting = { postingRequests += 1 }
        controller.onAccessibility = { accessibilityRequests += 1 }
        let tabs = try XCTUnwrap(descendants(of: controller.window!.contentView!).compactMap { $0 as? NSTabView }.first)
        tabs.selectTabViewItem(at: 1)
        let button = try XCTUnwrap(button(named: "キー送信を許可…", in: controller.window?.contentView))
        button.performClick(nil)
        XCTAssertEqual(postingRequests, 1)
        XCTAssertEqual(accessibilityRequests, 0)
    }

    @MainActor
    func testSaveButtonPersistsWithoutClosingSettings() async throws {
        let savedLanguage = InterfaceLanguage.saved
        defer { InterfaceLanguage.saved = savedLanguage }
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
    func testTabsPreserveDraftAndSaveFailureFeedback() async throws {
        let savedLanguage = InterfaceLanguage.saved
        defer { InterfaceLanguage.saved = savedLanguage }
        _ = NSApplication.shared
        let controller = SettingsWindow()
        let content = try XCTUnwrap(controller.window?.contentView)
        let slider = try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSSlider }.first)
        slider.doubleValue = 1.25
        NSApp.sendAction(try XCTUnwrap(slider.action), to: slider.target, from: slider)
        let tabs = try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSTabView }.first)
        XCTAssertEqual(tabs.tabViewItems.map(\.label), [L("一般"), L("権限")])
        tabs.selectTabViewItem(at: 1)
        XCTAssertNotNil(button(named: "キー送信を許可…", in: content))
        tabs.selectTabViewItem(at: 0)
        var attempted: InputConfiguration?
        controller.onSave = {
            attempted = $0
            throw SettingsError.invalidShortcuts
        }
        try XCTUnwrap(button(named: "保存", in: content)).performClick(nil)
        XCTAssertEqual(attempted?.repeatInterval, 1.25)
        XCTAssertEqual(slider.doubleValue, 1.25)
        XCTAssertTrue(descendants(of: content).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue == L("設定を保存できませんでした。") })
    }

    @MainActor
    func testTabsHaveUsableContentBoundsBeforeFirstLayout() async throws {
        _ = NSApplication.shared
        let controller = SettingsWindow()
        let content = try XCTUnwrap(controller.window?.contentView)
        let tabs = try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSTabView }.first)
        // AppKit sizes tab contents as soon as they are inserted, before the
        // window's first layout pass. A zero-size tab view produces invalid frames.
        XCTAssertGreaterThan(tabs.contentRect.width, 0)
        XCTAssertGreaterThan(tabs.contentRect.height, 0)
        for item in tabs.tabViewItems {
            let body = try XCTUnwrap(item.view)
            XCTAssertGreaterThan(body.bounds.width, 0, item.label)
            XCTAssertGreaterThan(body.bounds.height, 0, item.label)
        }
    }

    @MainActor
    func testSettingsLayoutAndAppearance() async throws {
        let savedLanguage = InterfaceLanguage.saved
        defer { InterfaceLanguage.saved = savedLanguage }
        _ = NSApplication.shared
        let controller = SettingsWindow()
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView)
        let tabs = try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSTabView }.first)
        controller.update(SettingsStatus(running: true, accessibility: true, listening: true, posting: true,
                                         summary: "待機中", detection: "通常画面（変換対象外）"))
        for (name, appearance, size, expanded) in [
            ("light", NSAppearance.Name.aqua, NSSize(width: 800, height: 700), false),
            ("dark", NSAppearance.Name.darkAqua, NSSize(width: 800, height: 700), false),
            ("approval", NSAppearance.Name.aqua, NSSize(width: 800, height: 700), false),
            ("expanded", NSAppearance.Name.aqua, NSSize(width: 800, height: 700), true),
            ("larger", NSAppearance.Name.aqua, NSSize(width: 1000, height: 850), false),
            ("minimum-again", NSAppearance.Name.darkAqua, NSSize(width: 800, height: 700), true)
        ] {
            controller.update(settingsStatus(loginItem: name == "approval" ? .requiresApproval : .enabled))
            window.appearance = NSAppearance(named: appearance)
            window.setContentSize(size)
            tabs.selectTabViewItem(at: expanded ? 1 : 0)
            content.layoutSubtreeIfNeeded()
            let save = try XCTUnwrap(button(named: "保存", in: content))
            let saveFrame = save.convert(save.bounds, to: content)
            XCTAssertTrue(content.bounds.contains(saveFrame), "Save must remain visible at \(name) size")
            XCTAssertFalse(descendants(of: content).contains { $0 is NSScrollView })
            for button in descendants(of: content).compactMap({ $0 as? NSButton })
                where !button.isHiddenOrHasHiddenAncestor {
                XCTAssertTrue(content.bounds.contains(button.convert(button.bounds, to: content)),
                              "Button must remain visible: \(button.title)")
            }
            let selectedContent = try XCTUnwrap(tabs.selectedTabViewItem?.view)
            for button in descendants(of: selectedContent).compactMap({ $0 as? NSButton })
                where !button.isHiddenOrHasHiddenAncestor {
                XCTAssertTrue(selectedContent.bounds.contains(button.convert(button.bounds, to: selectedContent)),
                              "Button must fit its tab at \(name) size: \(button.title)")
            }
            for control in descendants(of: selectedContent).compactMap({ $0 as? NSControl })
                where !control.isHiddenOrHasHiddenAncestor {
                XCTAssertTrue(selectedContent.bounds.contains(control.convert(control.bounds, to: selectedContent)),
                              "Control must fit its tab at \(name) size: \(control)")
            }
        }
    }

    @MainActor
    func testLanguageIsAppliedOnlyAfterSuccessfulSave() async throws {
        let savedLanguage = InterfaceLanguage.saved
        defer { InterfaceLanguage.saved = savedLanguage }
        _ = NSApplication.shared
        let controller = SettingsWindow()
        let content = try XCTUnwrap(controller.window?.contentView)
        let picker = try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSPopUpButton }.first)
        let next: InterfaceLanguage = savedLanguage == .japanese ? .english : .japanese
        picker.selectItem(at: try XCTUnwrap(InterfaceLanguage.allCases.firstIndex(of: next)))
        NSApp.sendAction(try XCTUnwrap(picker.action), to: picker.target, from: picker)
        XCTAssertEqual(InterfaceLanguage.saved, savedLanguage)
        controller.onSave = { _ in throw SettingsError.invalidShortcuts }
        try XCTUnwrap(button(named: "保存", in: content)).performClick(nil)
        XCTAssertEqual(InterfaceLanguage.saved, savedLanguage)
        controller.onSave = { _ in }
        try XCTUnwrap(button(named: "保存", in: content)).performClick(nil)
        XCTAssertEqual(InterfaceLanguage.saved, next)
    }

    @MainActor
    private func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }

    @MainActor
    private func button(named title: String, in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton, button.title == L(title) { return button }
        return view.subviews.lazy.compactMap { self.button(named: title, in: $0) }.first
    }
}
