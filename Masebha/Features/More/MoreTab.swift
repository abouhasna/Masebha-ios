import SwiftUI
import StoreKit

/// The More tab (≈ the Android side drawer): support, total, reset all, settings, ideas and
/// contact, rating, sharing and links.
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
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
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
                link(tr("more.suggest"), subtitle: tr("more.suggest.summary"), icon: "lightbulb.fill",
                     url: AppLinks.suggestions, id: "more.suggest")
                link(tr("more.contact"), icon: "envelope.fill", url: AppLinks.contact, id: "more.contact")
                Button {
                    // The App Store's review page once the app's id is known; Apple's prompt until then.
                    if let page = AppLinks.writeReview { openURL(page) } else { requestReview() }
                } label: {
                    SettingsRowLabel(icon: "star.fill", title: tr("more.rate"))
                }
                .settingsRowBackground()
                .accessibilityIdentifier("more.rate")
                ShareLink(item: tr("share.text", AppLinks.store.absoluteString)) {
                    SettingsRowLabel(icon: "square.and.arrow.up", title: tr("more.share"))
                }
                .settingsRowBackground()
                .accessibilityIdentifier("more.share")
            } header: {
                Text(tr("more.feedback"))
            }

            Section {
                link(tr("more.youtube"), icon: "play.rectangle.fill", url: AppLinks.youtube, id: "more.youtube")
                link(tr("more.telegram"), icon: "paperplane.fill", url: AppLinks.telegram, id: "more.telegram")
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

    private func link(_ title: String, subtitle: String? = nil, icon: String, url: URL, id: String) -> some View {
        Link(destination: url) {
            SettingsRowLabel(icon: icon, title: title, subtitle: subtitle)
        }
        .settingsRowBackground()
        .accessibilityIdentifier(id)
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
