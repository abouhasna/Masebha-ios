import SwiftUI
import UIKit

/// Shows this launch's popup, if any (see `LaunchPopups`): the static welcome, an announcement
/// from Firestore, or a promo (Telegram, support).
struct LaunchPopupsPresenter: ViewModifier {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL
    @State private var alert: PromoAlert?
    @State private var announcement: Announcement?
    @State private var showSupport = false

    enum PromoAlert: Identifiable {
        case welcome, telegram, support
        var id: Self { self }
    }

    func body(content: Content) -> some View {
        content
            .task {
                guard let popup = await environment.nextLaunchPopup() else { return }
                switch popup {
                case .welcome: alert = .welcome
                case .telegram: alert = .telegram
                case .support: alert = .support
                case .announcement(let item): announcement = item
                }
            }
            .alert(title(alert), isPresented: isPresented($alert), presenting: alert) { kind in
                switch kind {
                case .welcome:
                    Button(tr("welcome.start"), role: .cancel) {}
                case .telegram:
                    Button(tr("promo.telegram.button")) { openURL(AppLinks.telegram) }
                    Button(tr("common.later"), role: .cancel) {}
                case .support:
                    Button(tr("promo.support.button")) { showSupport = true }
                    Button(tr("common.later"), role: .cancel) {}
                }
            } message: { kind in
                Text(message(kind))
            }
            .sheet(item: $announcement) { item in
                AnnouncementSheet(announcement: item)
                    .appLanguageAndFont(environment)
            }
            .sheet(isPresented: $showSupport) {
                NavigationStack { SupportView() }
                    .appLanguageAndFont(environment)
            }
    }

    private func title(_ kind: PromoAlert?) -> String {
        switch kind {
        case .welcome: tr("welcome.title")
        case .telegram: tr("promo.telegram.title")
        case .support: tr("promo.support.title")
        case nil: ""
        }
    }

    private func message(_ kind: PromoAlert) -> String {
        switch kind {
        case .welcome: tr("welcome.message")
        case .telegram: tr("promo.telegram.message")
        case .support: tr("promo.support.message")
        }
    }
}

/// The announcement popup: an optional image, a title, a text and an optional button (Android's
/// popup document). A broken image is simply not shown.
struct AnnouncementSheet: View {
    let announcement: Announcement
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let data = announcement.image, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if !announcement.title.isEmpty {
                    Text(announcement.title)
                        .appFont(22, .bold)
                        .multilineTextAlignment(.center)
                }
                if !announcement.message.isEmpty {
                    Text(announcement.message)
                        .appFont(16, .regular)
                        .multilineTextAlignment(.center)
                        .opacity(0.85)
                }
                if let buttonText = announcement.buttonText {
                    Button {
                        if let link = announcement.buttonLink { openURL(link) }
                        dismiss()
                    } label: {
                        Text(buttonText)
                            .appFont(17, .bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Capsule().fill(Color(argb: SettingsStyle.accent)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("announcement.button")
                }
                Button(tr("common.close")) { dismiss() }
                    .appFont(16, .medium)
                    .tint(Color(argb: SettingsStyle.accent))
                    .accessibilityIdentifier("announcement.close")
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .background(Color(argb: SettingsStyle.background).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("announcement")
    }
}
