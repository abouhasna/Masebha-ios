import SwiftUI

/// The five weights every screen uses (≈ ?attr/appFont… on Android).
nonisolated enum AppFontWeight: Sendable {
    case extraLight, light, regular, medium, bold
}

/// A bundled font family (≈ FontRegistry.java). Keys are the Android `app_font` values.
nonisolated struct FontFamily: Identifiable, Equatable, Sendable {
    let key: String
    let displayName: String
    let isPaid: Bool
    let extraLight: String
    let light: String
    let regular: String
    let medium: String
    let bold: String

    var id: String { key }

    func postScriptName(_ weight: AppFontWeight) -> String {
        switch weight {
        case .extraLight: extraLight
        case .light: light
        case .regular: regular
        case .medium: medium
        case .bold: bold
        }
    }
}

nonisolated enum FontRegistry {
    static let defaultKey = "ibmplexsansarabic"

    static let all: [FontFamily] = [
        standard(key: "ibmplexsansarabic", name: "IBM Plex Sans Arabic", prefix: "IBMPlexSansArabic", paid: false),
        standard(key: "tajawal", name: "Tajawal", prefix: "Tajawal", paid: false),
        standard(key: "handjet", name: "Handjet", prefix: "Handjet", paid: true),
        standard(key: "cairo", name: "Cairo", prefix: "Cairo", paid: true),
        standard(key: "playpensansarabic", name: "Playpen Sans Arabic", prefix: "PlaypenSansArabic", paid: true),
        // Reem Kufi has no light weights; Android maps them to regular too.
        FontFamily(key: "reemkufi", displayName: "Reem Kufi", isPaid: true,
                   extraLight: "ReemKufi-Regular", light: "ReemKufi-Regular", regular: "ReemKufi-Regular",
                   medium: "ReemKufi-Medium", bold: "ReemKufi-Bold"),
    ]

    static var defaultFamily: FontFamily { all[0] }

    /// Unknown keys fall back to the default font, like Android.
    static func family(_ key: String) -> FontFamily {
        all.first { $0.key == key } ?? defaultFamily
    }

    private static func standard(key: String, name: String, prefix: String, paid: Bool) -> FontFamily {
        FontFamily(key: key, displayName: name, isPaid: paid,
                   extraLight: "\(prefix)-ExtraLight", light: "\(prefix)-Light", regular: "\(prefix)-Regular",
                   medium: "\(prefix)-Medium", bold: "\(prefix)-Bold")
    }
}

/// The font family currently in effect, available to every view.
nonisolated struct AppFontFamilyKey: EnvironmentKey {
    static let defaultValue: FontFamily = FontRegistry.defaultFamily
}

extension EnvironmentValues {
    nonisolated var appFontFamily: FontFamily {
        get { self[AppFontFamilyKey.self] }
        set { self[AppFontFamilyKey.self] = newValue }
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appFontFamily) private var family
    let size: CGFloat
    let weight: AppFontWeight
    let textStyle: Font.TextStyle

    func body(content: Content) -> some View {
        content.font(.custom(family.postScriptName(weight), size: size, relativeTo: textStyle))
    }
}

extension View {
    /// Applies the app font at `size` points. It scales with the system text size, like `sp` on Android.
    func appFont(_ size: CGFloat, _ weight: AppFontWeight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(AppFontModifier(size: size, weight: weight, textStyle: textStyle))
    }
}
