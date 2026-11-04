import Foundation

public struct KeyModifiers: OptionSet, Codable, Equatable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let control = KeyModifiers(rawValue: 1)
    public static let option = KeyModifiers(rawValue: 2)
    public static let shift = KeyModifiers(rawValue: 4)
    public static let command = KeyModifiers(rawValue: 8)
    public static let all: KeyModifiers = [.control, .option, .shift, .command]
}
public struct Shortcut: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: KeyModifiers
    public init(keyCode: UInt16, modifiers: KeyModifiers) { self.keyCode = keyCode; self.modifiers = modifiers }
    // Physical ANSI key positions; labels are intentionally not a keyboard-layout recorder.
    public static let keys: [(code: UInt16, label: String)] = [
        (123, "←"), (124, "→"), (125, "↓"), (126, "↑"),
        (0,"A"), (11,"B"), (8,"C"), (2,"D"), (14,"E"), (3,"F"), (5,"G"),
        (4,"H"), (34,"I"), (38,"J"), (40,"K"), (37,"L"), (46,"M"), (45,"N"),
        (31,"O"), (35,"P"), (12,"Q"), (15,"R"), (1,"S"), (17,"T"), (32,"U"),
        (9,"V"), (13,"W"), (7,"X"), (16,"Y"), (6,"Z"),
        (18,"1"), (19,"2"), (20,"3"), (21,"4"), (23,"5"), (22,"6"),
        (26,"7"), (28,"8"), (25,"9"), (29,"0"),
        (36,"Return"), (48,"Tab"), (49,"Space"), (51,"Delete"), (53,"Esc"), (117,"⌦"),
        (24,"="), (27,"−"), (30,"]"), (33,"["), (39,"’"), (41,";"), (42,"\\"), (43,","), (44,"/"), (47,"."), (50,"`"),
        (122,"F1"), (120,"F2"), (99,"F3"), (118,"F4"), (96,"F5"), (97,"F6"),
        (98,"F7"), (100,"F8"), (101,"F9"), (109,"F10"), (103,"F11"), (111,"F12"),
        (105,"F13"), (107,"F14"), (113,"F15"), (106,"F16"), (64,"F17"), (79,"F18"), (80,"F19"), (90,"F20"),
        (115,"Home"), (119,"End"), (116,"Page Up"), (121,"Page Down")
    ]
    public var isValid: Bool { !modifiers.isEmpty && modifiers.rawValue & ~KeyModifiers.all.rawValue == 0 && Self.keys.contains { $0.code == keyCode } }
    public var label: String {
        let symbols: [(KeyModifiers, String)] = [(.control,"⌃"), (.option,"⌥"), (.shift,"⇧"), (.command,"⌘")]
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + (Self.keys.first { $0.code == keyCode }?.label ?? "?")
    }
}
public struct ShortcutPair: Codable, Equatable {
    public var left: Shortcut
    public var right: Shortcut
    public init(left: Shortcut, right: Shortcut) { self.left = left; self.right = right }
    public static let standard = ShortcutPair(left: Shortcut(keyCode: 123, modifiers: [.control]), right: Shortcut(keyCode: 124, modifiers: [.control]))
    public var isValid: Bool { left.isValid && right.isValid && left != right }
}
public enum SettingsError: Error { case invalidShortcuts }
public final class SettingsStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var running: Bool {
        get { defaults.bool(forKey: "running") }
        set { defaults.set(newValue, forKey: "running") }
    }
    public var configuration: InputConfiguration? {
        if defaults.object(forKey: "configuration") != nil {
            guard let data = defaults.data(forKey: "configuration"),
                  let value = try? JSONDecoder().decode(InputConfiguration.self, from: data), value.isValid else { return nil }
            return value
        }
        // Migrate the original shortcut-only preferences without changing them.
        guard defaults.object(forKey: "shortcuts") != nil else { return .standard }
        guard let data = defaults.data(forKey: "shortcuts"),
              let pair = try? JSONDecoder().decode(ShortcutPair.self, from: data), pair.isValid else { return nil }
        return InputConfiguration(shortcuts: pair, scrollMapping: .standard)
    }
    public var shortcuts: ShortcutPair? { configuration?.shortcuts }
    public func save(_ configuration: InputConfiguration) throws {
        guard configuration.isValid else { throw SettingsError.invalidShortcuts }
        defaults.set(try JSONEncoder().encode(configuration), forKey: "configuration")
    }
    public func save(_ pair: ShortcutPair) throws {
        try save(InputConfiguration(shortcuts: pair, scrollMapping: configuration?.scrollMapping ?? .standard,
                                    repeatInterval: configuration?.repeatInterval ?? InputConfiguration.defaultRepeatInterval))
    }
}
