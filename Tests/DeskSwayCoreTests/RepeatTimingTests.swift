import XCTest
import ApplicationServices
@testable import DeskSwayCore

final class RepeatTimingTests: XCTestCase {
    private let wheel = ScrollSample(horizontal: -4, vertical: 0)
    private func gate(_ time: Double) -> InputGate {
        InputGate(running: true, permissionsGranted: true, tapEnabled: true, settingsValid: true,
                  detection: Detection(state: .missionControl, observedAt: time))
    }
    func testShortIntervalAcceptsContinuousInputAtBoundary() {
        var policy = ScrollPolicy()
        XCTAssertEqual(policy.process(wheel, at: 0, gate: gate(0), repeatInterval: 0.2), .consume(.right))
        XCTAssertEqual(policy.process(wheel, at: 0.199, gate: gate(0.199), repeatInterval: 0.2), .consume(nil))
        XCTAssertEqual(policy.process(wheel, at: 0.2, gate: gate(0.2), repeatInterval: 0.2), .consume(.right))
        XCTAssertEqual(policy.process(wheel, at: 0.4, gate: gate(0.4), repeatInterval: 0.2), .consume(.right))
    }
    func testLongIntervalSurvivesSilenceBetweenSeparateInputs() {
        var policy = ScrollPolicy()
        XCTAssertEqual(policy.process(wheel, at: 0, gate: gate(0), repeatInterval: 1.5), .consume(.right))
        XCTAssertEqual(policy.process(wheel, at: 0.7, gate: gate(0.7), repeatInterval: 1.5), .consume(nil))
        XCTAssertEqual(policy.process(wheel, at: 1.499, gate: gate(1.499), repeatInterval: 1.5), .consume(nil))
        XCTAssertEqual(policy.process(wheel, at: 1.5, gate: gate(1.5), repeatInterval: 1.5), .consume(.right))
    }
    func testPhasedInputRepeatsButMomentumAndZeroInputDoNot() {
        var policy = ScrollPolicy()
        let mapping = ScrollMapping(left: ScrollBinding(sign: 1, phased: true), right: ScrollBinding(sign: -1, phased: true))
        for (time, phase, expected) in [(0.0, Int64(1), ScrollDecision.consume(.right)), (0.1, 2, .consume(nil)), (0.2, 2, .consume(.right))] {
            XCTAssertEqual(policy.process(ScrollSample(horizontal: -4, vertical: 0, phase: phase), at: time, gate: gate(time), mapping: mapping, repeatInterval: 0.2), expected)
        }
        XCTAssertEqual(policy.process(ScrollSample(horizontal: 0, vertical: 0, phase: 2), at: 1, gate: gate(1), mapping: mapping, repeatInterval: 0.2), .pass)
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -4, vertical: 0, phase: 2, momentumPhase: 1), at: 2, gate: gate(2), mapping: mapping, repeatInterval: 0.2), .pass)
    }
    func testNewGestureBeginningDuringCooldownCanMoveAfterWait() {
        var policy = ScrollPolicy()
        let mapping = ScrollMapping(left: ScrollBinding(sign: 1, phased: true), right: ScrollBinding(sign: -1, phased: true))
        _ = policy.process(ScrollSample(horizontal: -4, vertical: 0, phase: 1), at: 0, gate: gate(0), mapping: mapping, repeatInterval: 0.2)
        _ = policy.process(ScrollSample(horizontal: 0, vertical: 0, phase: 4), at: 0.05, gate: gate(0.05), mapping: mapping, repeatInterval: 0.2)
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -4, vertical: 0, phase: 1), at: 0.1, gate: gate(0.1), mapping: mapping, repeatInterval: 0.2), .consume(nil))
        XCTAssertEqual(policy.process(ScrollSample(horizontal: -4, vertical: 0, phase: 2), at: 0.2, gate: gate(0.2), mapping: mapping, repeatInterval: 0.2), .consume(.right))
    }
    func testShortWaitNeverBypassesDetectionLoss() {
        var policy = ScrollPolicy()
        _ = policy.process(wheel, at: 0, gate: gate(0), repeatInterval: 0.1)
        var unknown = gate(0.1); unknown.detection.state = .unknown
        XCTAssertEqual(policy.process(wheel, at: 0.1, gate: unknown, repeatInterval: 0.1), .pass)
        XCTAssertEqual(policy.process(wheel, at: 0.2, gate: gate(0.2), repeatInterval: 0.1), .pass)
        XCTAssertEqual(policy.process(wheel, at: 0.5, gate: gate(0.5), repeatInterval: 0.1), .consume(.right))
    }
    func testAdapterUsesTimingForActualPreparedKeyPairs() throws {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: -4, wheel3: 0))
        var policy = ScrollPolicy()
        let first = ScrollEventAdapter.prepare(event, at: 0, gate: gate(0), shortcuts: .standard, repeatInterval: 0.2, policy: &policy)
        let waiting = ScrollEventAdapter.prepare(event, at: 0.1, gate: gate(0.1), shortcuts: .standard, repeatInterval: 0.2, policy: &policy)
        let second = ScrollEventAdapter.prepare(event, at: 0.2, gate: gate(0.2), shortcuts: .standard, repeatInterval: 0.2, policy: &policy)
        XCTAssertNotNil(first?.keys)
        XCTAssertNotNil(waiting)
        XCTAssertNil(waiting?.keys)
        XCTAssertEqual(second?.keys?.down.getIntegerValueField(.keyboardEventKeycode), 124)
    }
    func testLegacyConfigurationGetsDefaultWithoutLosingBindings() throws {
        let data = Data(#"{"shortcuts":{"left":{"keyCode":0,"modifiers":15},"right":{"keyCode":1,"modifiers":15}},"scrollMapping":{"left":{"sign":-1,"phased":true},"right":{"sign":1,"phased":true}}}"#.utf8)
        let config = try JSONDecoder().decode(InputConfiguration.self, from: data)
        XCTAssertEqual(config.repeatInterval, 0.6)
        XCTAssertEqual(config.shortcuts.left.keyCode, 0)
        XCTAssertEqual(config.scrollMapping.left, ScrollBinding(sign: -1, phased: true))
    }
    func testTimingRoundTripsAndShortcutUpdateRetainsIt() throws {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        var config = InputConfiguration.standard; config.repeatInterval = 0.25
        try store.save(config)
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.configuration?.repeatInterval, 0.25)
        try restored.save(ShortcutPair(left: Shortcut(keyCode: 0, modifiers: .all), right: Shortcut(keyCode: 1, modifiers: .all)))
        XCTAssertEqual(restored.configuration?.repeatInterval, 0.25)
    }
    func testZeroWaitAcceptsEveryEligibleEventWithoutBypassingInputProtection() {
        for phased in [false, true] {
            var policy = ScrollPolicy()
            let mapping = ScrollMapping(left: ScrollBinding(sign: 1, phased: phased), right: ScrollBinding(sign: -1, phased: phased))
            let begin = ScrollSample(horizontal: -4, vertical: 0, phase: phased ? 1 : 0)
            let next = ScrollSample(horizontal: -4, vertical: 0, phase: phased ? 2 : 0)
            XCTAssertEqual(policy.process(begin, at: 0, gate: gate(0), mapping: mapping, repeatInterval: 0), .consume(.right))
            XCTAssertEqual(policy.process(next, at: 0, gate: gate(0), mapping: mapping, repeatInterval: 0), .consume(.right))
            XCTAssertEqual(policy.process(ScrollSample(horizontal: -4, vertical: 0, momentumPhase: 1), at: 0.01, gate: gate(0.01), mapping: mapping, repeatInterval: 0), .pass)
            XCTAssertEqual(policy.process(ScrollSample(horizontal: 0, vertical: 4), at: 0.02, gate: gate(0.02), mapping: mapping, repeatInterval: 0), .pass)
            var paused = gate(0.03); paused.running = false
            XCTAssertEqual(policy.process(next, at: 0.03, gate: paused, mapping: mapping, repeatInterval: 0), .pass)
        }
    }
    func testZeroWaitCanBeSavedAndRestored() throws {
        let defaults = makeDefaults()
        var config = InputConfiguration.standard; config.repeatInterval = 0
        try SettingsStore(defaults: defaults).save(config)
        XCTAssertEqual(SettingsStore(defaults: defaults).configuration?.repeatInterval, 0)
    }
    func testInvalidWaitCannotBeSavedOrConsumeInput() {
        let store = SettingsStore(defaults: makeDefaults())
        for value in [-1.0, -0.001, 2.001, Double.infinity, Double.nan] {
            var config = InputConfiguration.standard; config.repeatInterval = value
            XCTAssertThrowsError(try store.save(config))
            var policy = ScrollPolicy()
            XCTAssertEqual(policy.process(wheel, at: 0, gate: gate(0), repeatInterval: value), .pass)
        }
    }
    private func makeDefaults() -> UserDefaults {
        let name = "DeskSwayTimingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
}
