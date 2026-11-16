import SwiftUI

/// Font choice (≈ FontSelectionActivity). Each card shows a sample in its own font.
/// The new font applies immediately to every screen.
struct FontPickerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var lockedFont: FontFamily?

    var body: some View {
        let isSupporter = environment.entitlements.isSupporter
        let selected = environment.fontFamily.key
        List {
            ForEach(FontRegistry.all) { family in
                Button {
                    choose(family, isSupporter: isSupporter)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: "اللهم صل على محمد")
                                .font(.custom(family.regular, size: 26))
                            Text(verbatim: family.displayName)
                                .font(.custom(family.regular, size: 15))
                                .opacity(0.65)
                        }
                        .foregroundStyle(.white)
                        Spacer(minLength: 0)
                        if family.isPaid {
                            Image(systemName: isSupporter ? "crown.fill" : "lock.fill")
                                .foregroundStyle(isSupporter ? Color(argb: 0xFFF5_C542) : Color.white.opacity(0.7))
                        }
                        if family.key == selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(argb: SettingsStyle.accent))
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .settingsRowBackground()
                .accessibilityIdentifier("font.\(family.key)")
            }
        }
        .settingsListStyle()
        .navigationTitle(tr("settings.font"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
        .alert(tr("font.locked.title"), isPresented: isPresented($lockedFont)) {
            Button(tr("common.ok"), role: .cancel) {}
        } message: {
            Text(tr("font.locked.message"))
        }
    }

    private func choose(_ family: FontFamily, isSupporter: Bool) {
        if family.isPaid && !isSupporter {
            lockedFont = family
            return
        }
        environment.settings.fontKey = family.key
        dismiss()
    }
}
