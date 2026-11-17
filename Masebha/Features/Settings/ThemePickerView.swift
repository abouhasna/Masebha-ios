import SwiftUI

/// Preset themes in a 2-column grid (≈ ThemeSelectionActivity). Supporter themes show a lock
/// when locked and a crown when unlocked.
struct ThemePickerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var lockedTheme: Theme?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        let isSupporter = environment.entitlements.isSupporter
        let selected = environment.settings.effectiveThemeKey(isSupporter: isSupporter)
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(ThemeRegistry.all) { theme in
                    ThemePreviewCard(theme: theme, isSelected: theme.key == selected,
                                     isLocked: theme.isPaid && !isSupporter)
                        .onTapGesture { choose(theme, isSupporter: isSupporter) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("theme.\(theme.key)")
                }
            }
            .padding(16)
        }
        .background(Color(argb: SettingsStyle.background).ignoresSafeArea())
        .navigationTitle(tr("settings.theme"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
        .alert(tr("theme.locked.title"), isPresented: isPresented($lockedTheme)) {
            Button(tr("common.ok"), role: .cancel) {}
        } message: {
            Text(tr("theme.locked.message"))
        }
    }

    private func choose(_ theme: Theme, isSupporter: Bool) {
        if theme.isPaid && !isSupporter {
            lockedTheme = theme
            return
        }
        environment.settings.applyTheme(theme)
        dismiss()
    }
}

/// A miniature of the list and counter screens in the theme's colors.
struct ThemePreviewCard: View {
    let theme: Theme
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        let colors = theme.palette
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Mini list screen
                VStack(spacing: 0) {
                    Color(argb: colors.tools).frame(height: 14)
                    VStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(argb: colors.card))
                                .frame(height: 14)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color(argb: colors.text)).frame(width: 22, height: 3).padding(.leading, 5)
                                }
                        }
                    }
                    .padding(6)
                    Spacer(minLength: 0)
                }
                .background(previewBackground(colors.background))
                // Mini counter screen
                VStack(spacing: 0) {
                    Color(argb: theme.isPaid ? colors.tools : colors.ring).frame(height: 14)
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().stroke(Color(argb: colors.ringTrack), lineWidth: 3)
                        Circle().trim(from: 0, to: 0.35)
                            .stroke(Color(argb: colors.ring), lineWidth: 3)
                            .rotationEffect(.degrees(-90))
                        Circle().fill(Color(argb: colors.progressButton)).padding(3)
                        Text(verbatim: "33")
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(Color(argb: colors.progressText))
                    }
                    .frame(width: 44, height: 44)
                    // Starts at the top and fills clockwise, in Arabic too (like the real counter ring).
                    .environment(\.layoutDirection, .leftToRight)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .background(previewBackground(colors.counterBackground))
            }
            .frame(height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 6) {
                if theme.isPaid {
                    Image(systemName: isLocked ? "lock.fill" : "crown.fill")
                        .foregroundStyle(isLocked ? Color.white.opacity(0.7) : Color(argb: 0xFFF5_C542))
                        .accessibilityLabel(tr("theme.supporter"))
                }
                Text(tr(theme.nameKey))
                    .appFont(15, .medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(argb: SettingsStyle.accent))
                        .accessibilityLabel(tr("common.selected"))
                }
            }
            .padding(.top, 8)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(argb: SettingsStyle.row)))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color(argb: SettingsStyle.accent) : .clear, lineWidth: 2)
        )
        .opacity(isLocked ? 0.85 : 1)
    }

    @ViewBuilder
    private func previewBackground(_ color: ARGB) -> some View {
        if theme.isPaid {
            Image(uiImage: KhatamPattern.tile(base: color)).resizable(resizingMode: .tile)
        } else {
            Color(argb: color)
        }
    }
}
