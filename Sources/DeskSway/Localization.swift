import Foundation

enum InterfaceLanguage: String, CaseIterable {
    case system, japanese = "ja", english = "en"

    static var saved: InterfaceLanguage {
        get { InterfaceLanguage(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "interfaceLanguage") }
    }

    var title: String {
        switch self {
        case .system: return L("システム設定に従う")
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }
}

// Resolve once per launch so menus and recording messages use the same language.
private let localizationBundle: Bundle = {
    let language = InterfaceLanguage.saved
    guard language != .system,
          let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return Bundle.module }
    return bundle
}()

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let format = localizationBundle.localizedString(forKey: key, value: nil, table: nil)
    return arguments.isEmpty ? format : String(format: format, locale: Locale.current, arguments: arguments)
}
