import Foundation

public struct ScrollBinding: Codable, Equatable {
    public var sign: Int
    public var phased: Bool
    public init(sign: Int, phased: Bool) { self.sign = sign; self.phased = phased }
    public init?(capturing input: ScrollSample) {
        guard input.horizontal.isFinite, input.vertical.isFinite,
              abs(input.horizontal) > abs(input.vertical), input.momentumPhase == 0,
              input.phase == 0 || input.phase == 1 || input.phase == 2 else { return nil }
        self.init(sign: input.horizontal > 0 ? 1 : -1, phased: input.phase != 0)
    }
    public var isValid: Bool { sign == 1 || sign == -1 }
    public var label: String { "\(sign > 0 ? "＋" : "−")方向 · \(phased ? "ジェスチャー型" : "ホイール型")" }
}
public struct ScrollMapping: Codable, Equatable {
    public var left: ScrollBinding
    public var right: ScrollBinding
    public init(left: ScrollBinding, right: ScrollBinding) { self.left = left; self.right = right }
    public static let standard = ScrollMapping(left: ScrollBinding(sign: 1, phased: false), right: ScrollBinding(sign: -1, phased: false))
    public var isValid: Bool { left.isValid && right.isValid && left.sign != right.sign && left.phased == right.phased }
    public func direction(for horizontal: Double) -> SpaceDirection { (horizontal > 0 ? 1 : -1) == left.sign ? .left : .right }
}
public struct InputConfiguration: Codable, Equatable {
    public static let defaultRepeatInterval: TimeInterval = 0.6
    public static let repeatIntervalRange: ClosedRange<TimeInterval> = 0.0...2.0
    public var repeatInterval: TimeInterval
    public var shortcuts: ShortcutPair
    public var scrollMapping: ScrollMapping
    public init(shortcuts: ShortcutPair, scrollMapping: ScrollMapping, repeatInterval: TimeInterval = Self.defaultRepeatInterval) {
        self.shortcuts = shortcuts; self.scrollMapping = scrollMapping; self.repeatInterval = repeatInterval
    }
    private enum CodingKeys: String, CodingKey { case shortcuts, scrollMapping, repeatInterval }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        shortcuts = try values.decode(ShortcutPair.self, forKey: .shortcuts)
        scrollMapping = try values.decode(ScrollMapping.self, forKey: .scrollMapping)
        // Only an absent field is an older schema; malformed present data fails.
        repeatInterval = try values.contains(.repeatInterval)
            ? values.decode(TimeInterval.self, forKey: .repeatInterval) : Self.defaultRepeatInterval
    }
    public static let standard = InputConfiguration(shortcuts: .standard, scrollMapping: .standard)
    public var isValid: Bool { shortcuts.isValid && scrollMapping.isValid && Self.repeatIntervalRange.contains(repeatInterval) }
}
