import Foundation
import Observation

/// Looks up UI text in the language chosen inside the app (≈ getString on Android).
///
/// iOS normally picks the language once, at launch, from the phone settings. The app lets the
/// user pick it in-app and switch instantly, so strings are read from the matching `.lproj`
/// folder directly. Views that call `tr` re-render automatically when the language changes,
/// because `language` is observed.
@Observable
final class Localizer {
    static let shared = Localizer()

    private(set) var language: AppLanguage = .arabic
    @ObservationIgnored private var bundle: Bundle = Localizer.bundle(for: .arabic)

    private static let missing = "\u{FFFF}"

    func setLanguage(_ language: AppLanguage) {
        bundle = Localizer.bundle(for: language)
        self.language = language
    }

    func string(_ key: String) -> String {
        _ = language  // registers the dependency, so views refresh on language change
        let value = bundle.localizedString(forKey: key, value: Localizer.missing, table: nil)
        if value == Localizer.missing {
            assertionFailure("Missing localized string: \(key)")
            return key
        }
        return value
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

/// Localized text for `key` in the app's current language.
func tr(_ key: String) -> String {
    Localizer.shared.string(key)
}

/// Localized format string filled with `arguments`, always using ASCII digits.
func tr(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: tr(key), locale: Locale(identifier: "en_US_POSIX"), arguments: arguments)
}
