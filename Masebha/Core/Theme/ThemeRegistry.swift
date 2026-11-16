import Foundation

/// A preset theme (≈ ThemeRegistry.java). Theme keys are the Android ones ("theme1"…"theme13").
nonisolated struct Theme: Identifiable, Equatable, Sendable {
    let key: String
    let nameKey: String   // localization key of the theme name
    let isPaid: Bool
    let palette: ThemePalette

    var id: String { key }
}

nonisolated enum ThemeRegistry {
    static let defaultKey = "theme1"

    static let all: [Theme] = [
        // Free themes — values copied from the Android app.
        Theme(key: "theme1", nameKey: "theme.theme1", isPaid: false, palette: ThemePalette(
            card: 0xFF000000, text: 0xFFFFFFFF, tools: 0xFF009736, background: 0xFF202020, toolsAccent: 0xFFFFFFFF,
            counterText: 0xFFFFFFFF, counterBackground: 0xFF202020, progressButton: 0xFF000000,
            progressText: 0xFFFFFFFF, ring: 0xFF009736, ringTrack: 0xFFF0F0F0)),
        Theme(key: "theme2", nameKey: "theme.theme2", isPaid: false, palette: ThemePalette(
            card: 0xFFFFFFFF, text: 0xFF000000, tools: 0xFF000000, background: 0xFFF0F0F0, toolsAccent: 0xFFFFFFFF,
            counterText: 0xFF000000, counterBackground: 0xFFCCCCCC, progressButton: 0xFFFFFFFF,
            progressText: 0xFF000000, ring: 0xFF000000, ringTrack: 0xFFF0F0F0)),
        Theme(key: "theme3", nameKey: "theme.theme3", isPaid: false, palette: ThemePalette(
            card: 0xFF2E7D32, text: 0xFFFFFFFF, tools: 0xFF2E7D32, background: 0xFFF1F8E9, toolsAccent: 0xFFFFFFFF,
            counterText: 0xFF2E7D32, counterBackground: 0xFFD0F0C0, progressButton: 0xFF388E3C,
            progressText: 0xFFFFFFFF, ring: 0xFF2E7D32, ringTrack: 0xFFF0F0F0)),
        Theme(key: "theme4", nameKey: "theme.theme4", isPaid: false, palette: ThemePalette(
            card: 0xFF1565C0, text: 0xFFFFFFFF, tools: 0xFF0D47A1, background: 0xFFE3F2FD, toolsAccent: 0xFFFFFFFF,
            counterText: 0xFF0D47A1, counterBackground: 0xFFBBDEFB, progressButton: 0xFF1976D2,
            progressText: 0xFFFFFFFF, ring: 0xFF0D47A1, ringTrack: 0xFFF0F0F0)),
        Theme(key: "theme5", nameKey: "theme.theme5", isPaid: false, palette: ThemePalette(
            card: 0xFFD81B60, text: 0xFFFFFFFF, tools: 0xFFAD1457, background: 0xFFFCE4EC, toolsAccent: 0xFFFFFFFF,
            counterText: 0xFF880E4F, counterBackground: 0xFFF8BBD0, progressButton: 0xFFEC407A,
            progressText: 0xFFFFFFFF, ring: 0xFFAD1457, ringTrack: 0xFFF0F0F0)),
        // Supporter themes (shown with the pattern background).
        paid("theme6", card: 0x182636, text: 0xE3EAF2, tools: 0x1E3F63, background: 0x0D1520, toolsAccent: 0xE3EAF2,
             button: 0x152A41, buttonText: 0xF2F6FA, ring: 0x5E9FD8, track: 0x182636),   // Deep Ocean
        paid("theme7", card: 0xF8FAFC, text: 0x22303C, tools: 0x3E6A8F, background: 0xE8EEF3, toolsAccent: 0xF5F8FB,
             button: 0x3E6A8F, buttonText: 0xF5F8FB, ring: 0x2F577A, track: 0xCBD6DF),   // Soft Sky
        paid("theme8", card: 0x27231F, text: 0xECE6DC, tools: 0x4A3A26, background: 0x181614, toolsAccent: 0xF3E5C8,
             button: 0x31281D, buttonText: 0xF6EBD3, ring: 0xE6D1AE, track: 0x27231F),   // Warm Charcoal
        paid("theme9", card: 0xFAF8F2, text: 0x2A332E, tools: 0x4F6F5E, background: 0xECE8DD, toolsAccent: 0xF7F5EE,
             button: 0x4F6F5E, buttonText: 0xF7F5EE, ring: 0x3F5E4E, track: 0xD3CEBF),   // Sage Ivory
        paid("theme10", card: 0x1A2B26, text: 0xE4ECE7, tools: 0x1F4A3D, background: 0x0E1815, toolsAccent: 0xE4ECE7,
             button: 0x163129, buttonText: 0xE4ECE7, ring: 0x4FB08A, track: 0x1A2B26),   // Midnight Emerald
        paid("theme11", card: 0xFBF6F3, text: 0x3A2B2C, tools: 0x9A5B64, background: 0xF1E8E4, toolsAccent: 0xFBF4F2,
             button: 0x9A5B64, buttonText: 0xFBF4F2, ring: 0x82474F, track: 0xDDCFCA),   // Rose Sand
        paid("theme12", card: 0x241C33, text: 0xE9E4F0, tools: 0x3F2F63, background: 0x16121F, toolsAccent: 0xEDE6F7,
             button: 0x2A2041, buttonText: 0xF4EFFA, ring: 0xA78BDB, track: 0x241C33),   // Dusk Amethyst
        paid("theme13", card: 0xFAF5E8, text: 0x33291A, tools: 0x7F6029, background: 0xEFE6D2, toolsAccent: 0xFBF6E8,
             button: 0x7F6029, buttonText: 0xFBF6E8, ring: 0x6F5322, track: 0xD6CAAE),   // Parchment Gold
    ]

    static var defaultTheme: Theme { all[0] }

    static func theme(_ key: String) -> Theme? {
        all.first { $0.key == key }
    }

    static func isPaid(_ key: String) -> Bool {
        theme(key)?.isPaid ?? false
    }

    /// Same layout as Android's `pal(...)`: text and background are reused for both screens.
    private static func paid(_ key: String, card: ARGB, text: ARGB, tools: ARGB, background: ARGB, toolsAccent: ARGB,
                             button: ARGB, buttonText: ARGB, ring: ARGB, track: ARGB) -> Theme {
        let o = ColorMath.opaque
        return Theme(key: key, nameKey: "theme.\(key)", isPaid: true, palette: ThemePalette(
            card: o(card), text: o(text), tools: o(tools), background: o(background), toolsAccent: o(toolsAccent),
            counterText: o(text), counterBackground: o(background), progressButton: o(button),
            progressText: o(buttonText), ring: o(ring), ringTrack: o(track)))
    }
}
