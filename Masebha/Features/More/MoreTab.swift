import SwiftUI

/// The More tab (≈ the Android side drawer): total, reset all, settings and links.
/// Support, feedback, rating and sharing arrive in the next leaps.
struct MoreTab: View {
    var body: some View {
        NavigationStack {
            MoreView()
        }
        .modifier(TabContentTint())
    }
}

struct MoreView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var total = 0
    @State private var confirmResetAll = false
    @State private var failed = false

    var body: some View {
        let isSupporter = environment.entitlements.isSupporter
        List {
            Section {
                NavigationLink {
                    SupportView()
                } label: {
                    SettingsRowLabel(icon: isSupporter ? "checkmark.seal.fill" : "heart.fill", title: tr("more.support"),
                                     subtitle: isSupporter ? tr("more.support.thanks") : tr("more.support.summary"))
                }
                .settingsRowBackground()
                .accessibilityIdentifier("more.support")
            }

            Section {
                HStack {
                    Text(tr("more.total"))
                        .appFont(17, .medium)
                    Spacer()
                    Text(NumberText.grouped(total))
                        .appFont(20, .bold)
                        .foregroundStyle(Color(argb: SettingsStyle.accent))
                        .accessibilityIdentifier("more.total")
                }
                .settingsRowBackground()
                Button(role: .destructive) {
                    confirmResetAll = true
                } label: {
                    Text(tr("more.reset_all"))
                        .appFont(17, .bold)
                        .frame(maxWidth: .infinity)
                }
                .settingsRowBackground()
                .accessibilityIdentifier("more.resetAll")
            }

            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    SettingsRowLabel(icon: "gearshape.fill", title: tr("more.settings"))
                }
                .settingsRowBackground()
                .accessibilityIdentifier("more.settings")
            }

            Section {
                link(tr("more.youtube"), icon: "play.rectangle.fill",
                     url: "https://youtube.com/shorts/V6j_zEb3h5w?si=lzXx3qbB7xV1i3bw")
                link(tr("more.telegram"), icon: "paperplane.fill", url: "https://t.me/nafiapp")
            } header: {
                Text(tr("more.follow"))
            }
        }
        .settingsListStyle()
        .navigationTitle(tr("tab.more"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
        .alert(tr("more.reset_all.title"), isPresented: $confirmResetAll) {
            Button(tr("common.reset"), role: .destructive, action: resetAll)
            Button(tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(tr("more.reset_all.message"))
        }
        .alert(tr("error.title"), isPresented: $failed) {
            Button(tr("common.ok"), role: .cancel) {}
        } message: {
            Text(tr("error.save"))
        }
        .onAppear(perform: reload)
    }

    private func link(_ title: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            SettingsRowLabel(icon: icon, title: title)
        }
        .settingsRowBackground()
    }

    private func reload() {
        total = (try? environment.store.grandTotal()) ?? 0
    }

    private func resetAll() {
        do {
            try environment.store.resetAll(day: DayKey.today())
        } catch {
            failed = true
        }
        reload()
    }
}
