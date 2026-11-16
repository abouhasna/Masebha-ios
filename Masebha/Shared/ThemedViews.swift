import SwiftUI
import UIKit

/// Screen background: the theme color, plus the geometric pattern on supporter themes.
struct ThemedBackground: View {
    let color: ARGB
    let pattern: Bool

    var body: some View {
        Group {
            if pattern {
                Image(uiImage: KhatamPattern.tile(base: color))
                    .resizable(resizingMode: .tile)
            } else {
                Color(argb: color)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Colors the navigation bar (and the status bar text) like the Android toolbar.
    func themedNavigationBar(_ color: ARGB) -> some View {
        toolbarBackground(Color(argb: color), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(ColorMath.isLight(color) ? .light : .dark, for: .navigationBar)
    }

    /// Colors the bottom tab bar like the Android bottom navigation.
    func themedTabBar(_ color: ARGB) -> some View {
        toolbarBackground(Color(argb: color), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(ColorMath.isLight(color) ? .light : .dark, for: .tabBar)
    }
}

/// The dark grouped style of the Android Settings screen.
enum SettingsStyle {
    static let background: ARGB = 0xFF12_1212
    static let row: ARGB = 0xFF2E_2E2E
    static let accent: ARGB = 0xFF00_9736
}

extension View {
    func settingsListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(Color(argb: SettingsStyle.background).ignoresSafeArea())
            .environment(\.colorScheme, .dark)
            .tint(Color(argb: SettingsStyle.accent))
    }

    func settingsRowBackground() -> some View {
        listRowBackground(Color(argb: SettingsStyle.row))
    }
}

/// One settings row: an icon, a title and an optional summary line (like the Android preference rows).
struct SettingsRowLabel: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 26)
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(16, .medium)
                    .foregroundStyle(.white)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .appFont(13, .regular)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
