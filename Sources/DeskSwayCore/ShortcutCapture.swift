import ApplicationServices

public extension KeyModifiers {
    init(eventFlags flags: CGEventFlags) {
        self = []
        for (flag, modifier) in [(CGEventFlags.maskControl, Self.control), (.maskAlternate, .option), (.maskShift, .shift), (.maskCommand, .command)] where flags.contains(flag) {
            formUnion(modifier)
        }
    }
}

// Records one chord, never text. Its owner installs a key tap ONLY while armed.
public struct ShortcutCapture {
    public enum Outcome: Equatable { case shortcut(Shortcut), invalid, cancelled }
    public enum Decision: Equatable { case pass, consume, finished(Outcome) }
    private var held: Set<UInt16> = []
    private var outcome: Outcome?
    private var cancelled = false
    public var hasHeldKeys: Bool { !held.isEmpty }
    public mutating func cancel() { cancelled = true; outcome = .cancelled }
    public init() {}
    public mutating func process(code: UInt16, modifiers: KeyModifiers, isDown: Bool, isRepeat: Bool = false) -> Decision {
        if cancelled {
            guard held.contains(code) else { return .pass }
            if isDown { return .consume }
            held.remove(code)
            return held.isEmpty ? .finished(.cancelled) : .consume
        }
        if isDown {
            if isRepeat { return held.contains(code) ? .consume : .pass }
            if held.isEmpty {
                let shortcut = Shortcut(keyCode: code, modifiers: modifiers)
                outcome = code == 53 && modifiers.isEmpty ? .cancelled : shortcut.isValid ? .shortcut(shortcut) : .invalid
            }
            held.insert(code)
            return .consume
        }
        guard held.remove(code) != nil else { return .pass }
        guard held.isEmpty, let outcome else { return .consume }
        self.outcome = nil
        return .finished(outcome)
    }
}
