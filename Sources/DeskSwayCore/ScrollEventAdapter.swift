import ApplicationServices

public enum ScrollEventAdapter {
    public struct KeyEvents {
        public let down: CGEvent
        public let up: CGEvent
    }
    public struct PreparedScroll {
        public let event: CGEvent
        public let keys: KeyEvents?
    }
    public static func sample(_ event: CGEvent) -> ScrollSample {
        let representations: [(CGEventField, CGEventField)] = [
            (.scrollWheelEventPointDeltaAxis2, .scrollWheelEventPointDeltaAxis1),
            (.scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis1),
            (.scrollWheelEventDeltaAxis2, .scrollWheelEventDeltaAxis1)
        ]
        let fields = representations.first { event.getDoubleValueField($0.0) != 0 || event.getDoubleValueField($0.1) != 0 } ?? representations[2]
        return ScrollSample(horizontal: event.getDoubleValueField(fields.0), vertical: event.getDoubleValueField(fields.1),
                            phase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
                            momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase))
    }
    public static func removingHorizontal(from event: CGEvent) -> CGEvent? {
        guard let copy = event.copy() else { return nil }
        for field in [CGEventField.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2,
                      .scrollWheelEventPointDeltaAxis2, .scrollWheelEventRawDeltaAxis2,
                      .scrollWheelEventAcceleratedDeltaAxis2] {
            copy.setDoubleValueField(field, value: 0)
        }
        return copy
    }
    public static func keyEvents(for shortcut: Shortcut) -> KeyEvents? {
        guard shortcut.isValid,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else { return nil }
        let mapping: [(KeyModifiers, CGEventFlags)] = [(.control, .maskControl), (.option, .maskAlternate), (.shift, .maskShift), (.command, .maskCommand)]
        let flags = mapping.reduce(CGEventFlags()) { shortcut.modifiers.contains($1.0) ? $0.union($1.1) : $0 }
        down.flags = flags; up.flags = flags
        return KeyEvents(down: down, up: up)
    }
    public static func prepare(_ event: CGEvent, at now: Double, gate: InputGate,
                               shortcuts: ShortcutPair?, mapping: ScrollMapping = .standard, repeatInterval: Double = InputConfiguration.defaultRepeatInterval, policy: inout ScrollPolicy) -> PreparedScroll? {
        var next = policy
        let decision = next.process(sample(event), at: now, gate: gate, mapping: mapping, repeatInterval: repeatInterval)
        guard case .consume(let direction) = decision else { policy = next; return nil }
        // Commit consumption only after ALL required objects have been constructed.
        guard let shortcuts, shortcuts.isValid, let copy = removingHorizontal(from: event) else { return nil }
        var keys: KeyEvents?
        if let direction {
            guard let pair = keyEvents(for: direction == .left ? shortcuts.left : shortcuts.right) else { return nil }
            keys = pair
        }
        policy = next
        return PreparedScroll(event: copy, keys: keys)
    }
}
