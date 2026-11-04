import XCTest
import ApplicationServices
@testable import DeskSwayCore

final class NativeTests: XCTestCase {
    func testStrippingHorizontalPreservesAllOtherAxesAndOriginalEvent() throws {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 3, wheel1: 7, wheel2: -10, wheel3: 3))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 7)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -10)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis3, value: 3)
        event.setDoubleValueField(.scrollWheelEventRawDeltaAxis1, value: 6)
        event.setDoubleValueField(.scrollWheelEventRawDeltaAxis2, value: -9)
        event.setDoubleValueField(.scrollWheelEventAcceleratedDeltaAxis2, value: -12)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 7.5)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 8)
        let output = try XCTUnwrap(ScrollEventAdapter.removingHorizontal(from: event))
        for field in [CGEventField.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventRawDeltaAxis2, .scrollWheelEventAcceleratedDeltaAxis2] {
            XCTAssertEqual(output.getDoubleValueField(field), 0)
        }
        XCTAssertEqual(output.getIntegerValueField(.scrollWheelEventDeltaAxis1), 7)
        XCTAssertEqual(output.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1), 7.5)
        XCTAssertEqual(output.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), 8)
        XCTAssertEqual(output.getIntegerValueField(.scrollWheelEventDeltaAxis3), 3)
        XCTAssertEqual(output.getDoubleValueField(.scrollWheelEventRawDeltaAxis1), 6)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventDeltaAxis2), -10)
    }
    func testEmptyScrollHasZeroSample() throws {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0))
        XCTAssertEqual(ScrollEventAdapter.sample(event).horizontal, 0)
        XCTAssertEqual(ScrollEventAdapter.sample(event).vertical, 0)
    }
    func testSampleUsesSameUnitsForBothAxesAndRetainsPhases() throws {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 2, wheel2: -8, wheel3: 0))
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)
        let sample = ScrollEventAdapter.sample(event)
        XCTAssertEqual(sample.horizontal, -8)
        XCTAssertEqual(sample.vertical, 2)
        XCTAssertEqual(sample.phase, 2)
        XCTAssertEqual(sample.momentumPhase, 1)
    }
    func testKeyPairHasOnlyConfiguredKeyAndModifiers() throws {
        let shortcut = Shortcut(keyCode: 0, modifiers: [.control, .option, .command, .shift])
        let pair = try XCTUnwrap(ScrollEventAdapter.keyEvents(for: shortcut))
        XCTAssertEqual(pair.down.type, .keyDown)
        XCTAssertEqual(pair.up.type, .keyUp)
        XCTAssertEqual(pair.down.getIntegerValueField(.keyboardEventKeycode), 0)
        XCTAssertEqual(pair.up.getIntegerValueField(.keyboardEventKeycode), 0)
        let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        XCTAssertEqual(pair.down.flags, flags)
        XCTAssertEqual(pair.up.flags, flags)
        XCTAssertNil(ScrollEventAdapter.keyEvents(for: Shortcut(keyCode: 65535, modifiers: [.control])))
    }
    func testFailedPreparationLeavesInputAndPolicyUnconsumed() throws {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: -4, wheel3: 0))
        let gate = InputGate(running: true, permissionsGranted: true, tapEnabled: true, settingsValid: true,
                             detection: Detection(state: .missionControl, observedAt: 10))
        var policy = ScrollPolicy()
        XCTAssertNil(ScrollEventAdapter.prepare(event, at: 10, gate: gate, shortcuts: nil, policy: &policy))
        let result = try XCTUnwrap(ScrollEventAdapter.prepare(event, at: 10.1, gate: gate, shortcuts: .standard, policy: &policy))
        XCTAssertNotNil(result.keys)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventDeltaAxis2), -4)
    }
    func testAXErrorsAndConflictingSignaturesAreUnknown() {
        XCTAssertEqual(MissionControlReader.classify(mc: 1, expose: 0, failed: false), .missionControl)
        XCTAssertEqual(MissionControlReader.classify(mc: 0, expose: 1, failed: false), .appExpose)
        XCTAssertEqual(MissionControlReader.classify(mc: 0, expose: 0, failed: false), .inactiveCandidate)
        XCTAssertEqual(MissionControlReader.classify(mc: 1, expose: 1, failed: false), .unknown)
        XCTAssertEqual(MissionControlReader.classify(mc: 1, expose: 0, failed: true), .unknown)
    }
    func testInvalidationRejectsOldInFlightScan() {
        var cache = DetectionCache()
        let old = cache.generation
        cache.invalidate()
        cache.accept(Detection(state: .missionControl, observedAt: 10), generation: old)
        XCTAssertEqual(cache.detection.state, .unknown)
        cache.accept(Detection(state: .missionControl, observedAt: 11), generation: cache.generation)
        XCTAssertEqual(cache.detection.state, .missionControl)
    }
}
