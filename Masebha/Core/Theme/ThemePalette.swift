import SwiftUI
import UIKit

/// A color stored the Android way: 0xAARRGGBB. Keeping this format makes backups compatible.
typealias ARGB = UInt32

/// The 11 customizable colors. Raw values are the Android `ColorsPrefs` keys, kept identical
/// so backup files can be shared between the two apps.
nonisolated enum ColorSlot: String, CaseIterable, Sendable {
    // Azkar list screen
    case card = "cardSelectedColor"
    case text = "textSelectedColor"
    case tools = "toolsSelectedColor"
    case background = "backgroundSelectedColor"
    case toolsAccent = "toolsAccentSelectedColor"
    // Counter screen
    case counterText = "textSelectedColor1"
    case counterBackground = "backgroundSelectedColor1"
    case progressButton = "progressButtonSelectedColor"
    case progressText = "progressTextSelectedColor"
    case ring = "resetSelectedColor"
    case ringTrack = "resetAccentSelectedColor"

    static let listScreen: [ColorSlot] = [.card, .background, .text, .tools, .toolsAccent]
    static let counterScreen: [ColorSlot] = [.counterText, .counterBackground, .progressButton, .progressText, .ring, .ringTrack]
}

/// One full set of the 11 colors. Every theme or color change writes all of them together.
nonisolated struct ThemePalette: Equatable, Sendable {
    var card: ARGB
    var text: ARGB
    var tools: ARGB
    var background: ARGB
    var toolsAccent: ARGB
    var counterText: ARGB
    var counterBackground: ARGB
    var progressButton: ARGB
    var progressText: ARGB
    var ring: ARGB
    var ringTrack: ARGB

    subscript(slot: ColorSlot) -> ARGB {
        get {
            switch slot {
            case .card: card
            case .text: text
            case .tools: tools
            case .background: background
            case .toolsAccent: toolsAccent
            case .counterText: counterText
            case .counterBackground: counterBackground
            case .progressButton: progressButton
            case .progressText: progressText
            case .ring: ring
            case .ringTrack: ringTrack
            }
        }
        set {
            switch slot {
            case .card: card = newValue
            case .text: text = newValue
            case .tools: tools = newValue
            case .background: background = newValue
            case .toolsAccent: toolsAccent = newValue
            case .counterText: counterText = newValue
            case .counterBackground: counterBackground = newValue
            case .progressButton: progressButton = newValue
            case .progressText: progressText = newValue
            case .ring: ring = newValue
            case .ringTrack: ringTrack = newValue
            }
        }
    }
}

nonisolated enum ColorMath {
    /// Relative luminance (WCAG), the same formula as Android's ColorUtils.calculateLuminance.
    static func luminance(_ argb: ARGB) -> Double {
        func channel(_ shift: ARGB) -> Double {
            let value = Double((argb >> shift) & 0xFF) / 255.0
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func contrast(_ first: ARGB, _ second: ARGB) -> Double {
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    static func isLight(_ argb: ARGB) -> Bool { luminance(argb) > 0.5 }

    /// Icon color on a toolbar: the accent if it is readable (>= 4.5:1), otherwise near-black or white.
    static func readableIcon(accent: ARGB, on background: ARGB) -> ARGB {
        if contrast(accent, background) >= 4.5 { return accent }
        return isLight(background) ? 0xFF1A1A1A : 0xFFFFFFFF
    }

    static func opaque(_ argb: ARGB) -> ARGB { argb | 0xFF00_0000 }
}

extension Color {
    nonisolated init(argb: ARGB) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255.0,
            green: Double((argb >> 8) & 0xFF) / 255.0,
            blue: Double(argb & 0xFF) / 255.0,
            opacity: Double((argb >> 24) & 0xFF) / 255.0
        )
    }

    /// The color as 0xAARRGGBB (sRGB). Used when the user picks a custom color.
    func argb() -> ARGB {
        let resolved = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0xFF00_0000 }
        func byte(_ value: CGFloat) -> ARGB { ARGB(max(0, min(255, (value * 255).rounded()))) }
        return (byte(alpha) << 24) | (byte(red) << 16) | (byte(green) << 8) | byte(blue)
    }
}
