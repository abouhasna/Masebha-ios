import Foundation

/// The two languages the app supports. Arabic is the default, like on Android.
nonisolated enum AppLanguage: String, CaseIterable, Sendable {
    case arabic = "ar"
    case english = "en"

    var isRightToLeft: Bool { self == .arabic }

    /// Locale for system controls. Latin digits on purpose: the app shows ASCII digits everywhere
    /// (like Android), except the Arabic Hijri date, which converts them explicitly.
    var locale: Locale {
        switch self {
        case .arabic: Locale(identifier: "ar@numbers=latn")
        case .english: Locale(identifier: "en")
        }
    }

    /// Unknown or missing values fall back to Arabic.
    init(storedValue: String?) {
        self = storedValue.flatMap(AppLanguage.init(rawValue:)) ?? .arabic
    }
}
