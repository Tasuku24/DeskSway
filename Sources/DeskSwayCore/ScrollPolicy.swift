import Foundation

public struct InputGate {
    public var running: Bool
    public var permissionsGranted: Bool
    public var tapEnabled: Bool
    public var settingsValid: Bool
    public var detection: Detection
    public init(running: Bool, permissionsGranted: Bool, tapEnabled: Bool, settingsValid: Bool, detection: Detection) {
        self.running = running; self.permissionsGranted = permissionsGranted
        self.tapEnabled = tapEnabled; self.settingsValid = settingsValid; self.detection = detection
    }
    public func permits(at now: TimeInterval) -> Bool {
        let age = now - detection.observedAt
        return running && permissionsGranted && tapEnabled && settingsValid
            && detection.state == .missionControl && age.isFinite && age >= 0 && age <= 0.5
    }
}
public struct ScrollSample {
    public var horizontal: Double
    public var vertical: Double
    public var phase: Int64
    public var momentumPhase: Int64
    public init(horizontal: Double, vertical: Double, phase: Int64 = 0, momentumPhase: Int64 = 0) {
        self.horizontal = horizontal; self.vertical = vertical; self.phase = phase; self.momentumPhase = momentumPhase
    }
}
public enum SpaceDirection: Equatable { case left, right }
public enum ScrollDecision: Equatable { case pass, consume(SpaceDirection?) }
public struct ScrollPolicy {
    private var lastHorizontal: TimeInterval?
    private var lastMovement: TimeInterval?
    private var wheelInterrupted = false
    private var gestureEligible = false
    public init() {}
    public mutating func process(_ input: ScrollSample, at now: TimeInterval, gate: InputGate,
                                 mapping: ScrollMapping = .standard,
                                 repeatInterval: TimeInterval = InputConfiguration.defaultRepeatInterval) -> ScrollDecision {
        guard now.isFinite, mapping.isValid, InputConfiguration.repeatIntervalRange.contains(repeatInterval) else { return .pass }
        if mapping.left.phased {
            return processGesture(input, at: now, gate: gate, mapping: mapping, repeatInterval: repeatInterval)
        }
        let newBurst = lastHorizontal.map { now >= $0 + 0.25 || now < $0 } ?? true
        // Keep observing through gate loss, so restoration cannot turn an
        // interrupted held wheel into a fresh, authorized input sequence.
        if input.horizontal.isFinite && input.horizontal != 0 { lastHorizontal = now }
        if newBurst { wheelInterrupted = false }
        guard gate.permits(at: now) else { wheelInterrupted = true; return .pass }
        guard !wheelInterrupted, input.horizontal.isFinite, input.vertical.isFinite,
              input.phase == 0, input.momentumPhase == 0,
              abs(input.horizontal) > abs(input.vertical) else { return .pass }
        return repeatDecision(horizontal: input.horizontal, at: now, mapping: mapping, interval: repeatInterval)
    }
    private mutating func processGesture(_ input: ScrollSample, at now: TimeInterval, gate: InputGate,
                                         mapping: ScrollMapping, repeatInterval: TimeInterval) -> ScrollDecision {
        if input.phase == 4 || input.phase == 8 { gestureEligible = false; return .pass }
        if input.phase == 1 { gestureEligible = gate.permits(at: now) }
        guard gate.permits(at: now) else { gestureEligible = false; return .pass }
        guard gestureEligible, input.phase == 1 || input.phase == 2,
              input.momentumPhase == 0, input.horizontal.isFinite, input.vertical.isFinite,
              abs(input.horizontal) > abs(input.vertical) else { return .pass }
        return repeatDecision(horizontal: input.horizontal, at: now, mapping: mapping, interval: repeatInterval)
    }
    private mutating func repeatDecision(horizontal: Double, at now: TimeInterval, mapping: ScrollMapping,
                                         interval: TimeInterval) -> ScrollDecision {
        // Event-driven only: no timer and no queued movement after input stops.
        guard lastMovement.map({ now >= $0 + interval }) ?? true else { return .consume(nil) }
        lastMovement = now
        return .consume(mapping.direction(for: horizontal))
    }
}
