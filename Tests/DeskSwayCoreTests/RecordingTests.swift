import XCTest
import ApplicationServices
@testable import DeskSwayCore

final class RecordingTests: XCTestCase {
    func testShortcutIsCapturedOnReleaseAndKeyPairIsConsumed() {
        var recorder = ShortcutCapture()
        XCTAssertEqual(recorder.process(code: 0, modifiers: [.control, .option, .shift, .command], isDown: true), .consume)
        XCTAssertEqual(recorder.process(code: 0, modifiers: [], isDown: false), .finished(.shortcut(Shortcut(keyCode: 0, modifiers: [.control, .option, .shift, .command]))))
    }
    func testRepeatsAndAdditionalKeysCannotLeakOrReplaceShortcut() {
        var recorder = ShortcutCapture()
        _ = recorder.process(code: 0, modifiers: [.control], isDown: true)
        XCTAssertEqual(recorder.process(code: 0, modifiers: [.control], isDown: true, isRepeat: true), .consume)
        XCTAssertEqual(recorder.process(code: 1, modifiers: [.control], isDown: true), .consume)
        XCTAssertEqual(recorder.process(code: 0, modifiers: [], isDown: false), .consume)
        XCTAssertEqual(recorder.process(code: 1, modifiers: [], isDown: false), .finished(.shortcut(Shortcut(keyCode: 0, modifiers: [.control]))))
    }
    func testBareKeyIsRejectedAndEscapeCancelsAfterKeyUp() {
        var recorder = ShortcutCapture()
        _ = recorder.process(code: 0, modifiers: [], isDown: true)
        XCTAssertEqual(recorder.process(code: 0, modifiers: [], isDown: false), .finished(.invalid))
        recorder = ShortcutCapture()
        _ = recorder.process(code: 53, modifiers: [], isDown: true)
        XCTAssertEqual(recorder.process(code: 53, modifiers: [], isDown: false), .finished(.cancelled))
    }
    func testUnrelatedKeyUpPassesAndRepeatCannotStartRecording() {
        var recorder = ShortcutCapture()
        XCTAssertEqual(recorder.process(code: 0, modifiers: [], isDown: false), .pass)
        XCTAssertEqual(recorder.process(code: 0, modifiers: [.command], isDown: true, isRepeat: true), .pass)
    }
    func testCGFlagsRecordConfiguredModifiersWithoutCapsLock() {
        XCTAssertEqual(KeyModifiers(eventFlags: [.maskControl, .maskAlternate, .maskShift, .maskCommand, .maskAlphaShift]), .all)
    }
    func testCancellationDrainsOnlyAlreadySwallowedKeys() {
        var recorder = ShortcutCapture()
        _ = recorder.process(code: 0, modifiers: [.control], isDown: true)
        recorder.cancel()
        XCTAssertTrue(recorder.hasHeldKeys)
        XCTAssertEqual(recorder.process(code: 1, modifiers: [.command], isDown: true), .pass)
        XCTAssertEqual(recorder.process(code: 0, modifiers: [.control], isDown: true, isRepeat: true), .consume)
        XCTAssertEqual(recorder.process(code: 0, modifiers: [], isDown: false), .finished(.cancelled))
        XCTAssertFalse(recorder.hasHeldKeys)
    }
    func testScrollCaptureUsesSignAndPhaseButRejectsVerticalAndMomentum() {
        XCTAssertEqual(ScrollBinding(capturing: ScrollSample(horizontal: -12, vertical: 2)), ScrollBinding(sign: -1, phased: false))
        XCTAssertEqual(ScrollBinding(capturing: ScrollSample(horizontal: 3, vertical: 0, phase: 2)), ScrollBinding(sign: 1, phased: true))
        for sample in [ScrollSample(horizontal: 1, vertical: 3), ScrollSample(horizontal: 0, vertical: 0),
                       ScrollSample(horizontal: .nan, vertical: 0), ScrollSample(horizontal: 4, vertical: 0, momentumPhase: 1),
                       ScrollSample(horizontal: 4, vertical: 0, phase: 4)] {
            XCTAssertNil(ScrollBinding(capturing: sample))
        }
    }
    func testMappingRejectsSameDirectionAndMismatchedInputKinds() {
        XCTAssertFalse(ScrollMapping(left: ScrollBinding(sign: 1, phased: false), right: ScrollBinding(sign: 1, phased: false)).isValid)
        XCTAssertFalse(ScrollMapping(left: ScrollBinding(sign: 1, phased: false), right: ScrollBinding(sign: -1, phased: true)).isValid)
        XCTAssertFalse(ScrollMapping(left: ScrollBinding(sign: 0, phased: false), right: ScrollBinding(sign: -1, phased: false)).isValid)
    }
    func testRecordedReverseDirectionActuallyChangesGeneratedShortcut() throws {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: -3, wheel3: 0))
        let mapping = ScrollMapping(left: ScrollBinding(sign: -1, phased: false), right: ScrollBinding(sign: 1, phased: false))
        var policy = ScrollPolicy()
        let output = try XCTUnwrap(ScrollEventAdapter.prepare(event, at: 10, gate: gate(10), shortcuts: .standard, mapping: mapping, policy: &policy))
        XCTAssertEqual(output.keys?.down.getIntegerValueField(.keyboardEventKeycode), 123)
    }
    func testRecordedPhasedGestureAcceptsFreshInputAfterWait() {
        var policy = ScrollPolicy()
        let mapping = ScrollMapping(left: ScrollBinding(sign: 1, phased: true), right: ScrollBinding(sign: -1, phased: true))
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -3, vertical: 0, phase: 1), at: 10, gate: gate(10), mapping: mapping), .consume(.right))
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -3, vertical: 0, phase: 2), at: 12, gate: gate(12), mapping: mapping), .consume(.right))
        XCTAssertEqual(policy.process(ScrollSample(horizontal: 0, vertical: 0, phase: 4), at: 12.1, gate: gate(12.1), mapping: mapping), .pass)
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -3, vertical: 0, momentumPhase: 1), at: 13, gate: gate(13), mapping: mapping), .pass)
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -3, vertical: 0, phase: 1), at: 14, gate: gate(14), mapping: mapping), .consume(.right))
    }
    func testPhasedGestureCannotStartMidwayOrAfterDetectionLoss() {
        var policy = ScrollPolicy()
        let mapping = ScrollMapping(left: ScrollBinding(sign: 1, phased: true), right: ScrollBinding(sign: -1, phased: true))
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -3, vertical: 0, phase: 2), at: 10, gate: gate(10), mapping: mapping), .pass)
        var unknown = gate(11); unknown.detection.state = .unknown
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -3, vertical: 0, phase: 1), at: 11, gate: unknown, mapping: mapping), .pass)
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -3, vertical: 0, phase: 2), at: 12, gate: gate(12), mapping: mapping), .pass)
    }
    func testZeroDeltaBeginAllowsFirstHorizontalUpdate() {
        var policy = ScrollPolicy()
        let mapping = ScrollMapping(left: ScrollBinding(sign: 1, phased: true), right: ScrollBinding(sign: -1, phased: true))
        XCTAssertEqual(policy.process(ScrollSample(horizontal: 0, vertical: 0, phase: 1), at: 10, gate: gate(10), mapping: mapping), .pass)
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -3, vertical: 0, phase: 2), at: 10.1, gate: gate(10.1), mapping: mapping), .consume(.right))
    }
    func testExistingShortcutsMigrateAndConfigurationRoundTripsTogether() throws {
        let defaults = makeDefaults()
        let pair = ShortcutPair(left: Shortcut(keyCode: 0, modifiers: .all), right: Shortcut(keyCode: 1, modifiers: .all))
        defaults.set(try JSONEncoder().encode(pair), forKey: "shortcuts")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.configuration?.shortcuts, pair)
        XCTAssertEqual(store.configuration?.scrollMapping, .standard)
        let config = InputConfiguration(shortcuts: pair, scrollMapping: ScrollMapping(left: ScrollBinding(sign: -1, phased: true), right: ScrollBinding(sign: 1, phased: true)))
        try store.save(config)
        XCTAssertEqual(SettingsStore(defaults: defaults).configuration, config)
    }
    func testCorruptNewConfigurationNeverFallsBackToOldDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data("broken".utf8), forKey: "configuration")
        XCTAssertNil(SettingsStore(defaults: defaults).configuration)
    }
    private func makeDefaults() -> UserDefaults {
        let name = "DeskSwayRecordingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    private func gate(_ time: Double) -> InputGate {
        InputGate(running: true, permissionsGranted: true, tapEnabled: true, settingsValid: true, detection: Detection(state: .missionControl, observedAt: time))
    }
}
