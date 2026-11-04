import XCTest
@testable import DeskSwayCore

final class PolicyTests: XCTestCase {
    private func gate(_ time: Double = 10) -> InputGate {
        InputGate(running: true, permissionsGranted: true, tapEnabled: true,
                  settingsValid: true, detection: Detection(state: .missionControl, observedAt: time))
    }
    private let right = ScrollSample(horizontal: -4, vertical: 0)

    func testFreshMissionControlConvertsBothDirections() {
        var policy = ScrollPolicy()
        XCTAssertEqual(policy.process(right, at: 10, gate: gate()), .consume(.right))
        policy = ScrollPolicy()
        XCTAssertEqual(policy.process(ScrollSample(horizontal: 4, vertical: 0), at: 10, gate: gate()), .consume(.left))
    }
    func testEveryReadinessConditionFailsOpen() {
        for index in 0..<7 {
            var g = gate()
            switch index {
            case 0: g.running = false
            case 1: g.permissionsGranted = false
            case 2: g.tapEnabled = false
            case 3: g.settingsValid = false
            case 4: g.detection.state = .unknown
            case 5: g.detection.state = .appExpose
            default: g.detection.state = .inactiveCandidate
            }
            var policy = ScrollPolicy()
            XCTAssertEqual(policy.process(right, at: 10, gate: g), .pass, "gate \(index)")
        }
    }
    func testFreshnessUsesBoundedNonnegativeAge() {
        for now in [9.9, 10.501, Double.infinity, Double.nan] {
            var policy = ScrollPolicy()
            XCTAssertEqual(policy.process(right, at: now, gate: gate()), .pass)
        }
        var policy = ScrollPolicy()
        XCTAssertEqual(policy.process(right, at: 10.5, gate: gate()), .consume(.right))
    }
    func testVerticalDominantAndZeroInputPass() {
        for sample in [ScrollSample(horizontal: 0, vertical: 4),
                       ScrollSample(horizontal: 4, vertical: -4),
                       ScrollSample(horizontal: -3, vertical: 6),
                       ScrollSample(horizontal: .nan, vertical: 0)] {
            var policy = ScrollPolicy()
            XCTAssertEqual(policy.process(sample, at: 10, gate: gate()), .pass)
        }
        var policy = ScrollPolicy()
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -4, vertical: 2), at: 10, gate: gate()), .consume(.right))
    }
    func testPhasedAndMomentumInputPass() {
        for sample in [ScrollSample(horizontal: -4, vertical: 0, phase: 1),
                       ScrollSample(horizontal: -4, vertical: 0, momentumPhase: 1)] {
            var policy = ScrollPolicy()
            XCTAssertEqual(policy.process(sample, at: 10, gate: gate()), .pass)
        }
    }
    func testHeldBurstRepeatsAtDefaultInterval() {
        var policy = ScrollPolicy()
        XCTAssertEqual(policy.process(right, at: 10, gate: gate()), .consume(.right))
        for now in [10.1, 10.2, 10.3, 10.4, 10.5] {
            XCTAssertEqual(policy.process(right, at: now, gate: gate(now)), .consume(nil))
        }
        XCTAssertEqual(policy.process(right, at: 10.6, gate: gate(10.6)), .consume(.right))
        XCTAssertEqual(policy.process(right, at: 10.7, gate: gate(10.7)), .consume(nil))
        XCTAssertEqual(policy.process(right, at: 11.2, gate: gate(11.2)), .consume(.right))
    }
    func testCooldownInputDoesNotExtendTheWaitingPeriod() {
        var policy = ScrollPolicy()
        XCTAssertEqual(policy.process(right, at: 10, gate: gate()), .consume(.right))
        for now in [10.3, 10.5] {
            XCTAssertEqual(policy.process(right, at: now, gate: gate(now)), .consume(nil))
        }
        XCTAssertEqual(policy.process(right, at: 10.7, gate: gate(10.7)), .consume(.right))
    }
    func testGateLossDiscardsConsumedBurst() {
        var policy = ScrollPolicy()
        _ = policy.process(right, at: 10, gate: gate())
        var off = gate(); off.running = false
        XCTAssertEqual(policy.process(right, at: 10.1, gate: off), .pass)
        XCTAssertEqual(policy.process(right, at: 10.2, gate: gate(10.2)), .pass)
    }
    func testTransientDetectionLossCannotRearmHeldWheelAfterCooldown() {
        var policy = ScrollPolicy()
        XCTAssertEqual(policy.process(right, at: 10, gate: gate()), .consume(.right))
        for i in 1...6 {
            let time = 10 + Double(i) / 10
            _ = policy.process(right, at: time, gate: gate(time))
        }
        var unknown = gate(10.7); unknown.detection.state = .unknown
        XCTAssertEqual(policy.process(right, at: 10.7, gate: unknown), .pass)
        XCTAssertEqual(policy.process(right, at: 10.8, gate: gate(10.8)), .pass)
        XCTAssertEqual(policy.process(right, at: 11.4, gate: gate(11.4)), .consume(.right))
    }
}

final class SettingsTests: XCTestCase {
    func testDefaultsArePausedAndControlArrows() {
        let store = makeStore()
        XCTAssertFalse(store.running)
        XCTAssertEqual(store.shortcuts?.left, Shortcut(keyCode: 123, modifiers: [.control]))
        XCTAssertEqual(store.shortcuts?.right, Shortcut(keyCode: 124, modifiers: [.control]))
    }
    func testRejectsDuplicatesBareKeysUnsupportedKeysAndUnknownModifiers() {
        let valid = Shortcut(keyCode: 0, modifiers: [.control, .option, .command, .shift])
        for pair in [ShortcutPair(left: valid, right: valid),
                     ShortcutPair(left: Shortcut(keyCode: 0, modifiers: []), right: valid),
                     ShortcutPair(left: Shortcut(keyCode: 65535, modifiers: [.control]), right: valid),
                     ShortcutPair(left: Shortcut(keyCode: 1, modifiers: KeyModifiers(rawValue: 128)), right: valid)] {
            XCTAssertFalse(pair.isValid)
        }
    }
    func testValidSettingsRoundTrip() throws {
        let store = makeStore()
        let pair = ShortcutPair(left: Shortcut(keyCode: 0, modifiers: [.control, .option, .command, .shift]),
                                right: Shortcut(keyCode: 1, modifiers: [.control, .option, .command, .shift]))
        try store.save(pair)
        store.running = true
        XCTAssertEqual(store.shortcuts, pair)
        XCTAssertTrue(store.running)
    }
    func testMalformedSavedSettingsDoNotFallbackToActiveDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data("broken".utf8), forKey: "shortcuts")
        XCTAssertNil(SettingsStore(defaults: defaults).shortcuts)
    }
    private func makeDefaults() -> UserDefaults {
        let name = "DeskSwayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    private func makeStore() -> SettingsStore { SettingsStore(defaults: makeDefaults()) }
}
