import SwiftUI
import UIKit

/// Shows this launch's popup, if any (see `LaunchPopups`): the static welcome, the Telegram
/// invitation, or an announcement from Firestore. All use our own sheet, so they always follow the
/// app's language direction (system alerts follow the phone's language until the app restarts).
struct LaunchPopupsPresenter: ViewModifier {
    @Environment(AppEnvironment.self) private var environment
    @State private var popup: PopupContent?

    func body(content: Content) -> some View {
        content
            .task {
                guard let next = await environment.nextLaunchPopup() else { return }
                popup = PopupContent(next)
            }
            .sheet(item: $popup) { item in
                PopupSheet(content: item)
                    .appLanguageAndFont(environment)
            }
    }
}

/// What one popup shows: an optional picture, a title, a text, a main button and a close button.
struct PopupContent: Identifiable {
    let id = UUID()
    var image: Data?
    var symbol: String?
    var title: String
    var message: String
    /// The main button (it closes the popup, after opening `link` if there is one).
    var buttonText: String?
    var link: URL?
    /// The second, quieter button; nil when the main button is enough.
    var closeText: String?

    init(_ popup: LaunchPopup) {
        switch popup {
        case .welcome:
            symbol = "hand.wave.fill"
            title = tr("welcome.title")
            message = tr("welcome.message")
            buttonText = tr("welcome.start")
        case .telegram:
            symbol = "paperplane.circle.fill"
            title = tr("promo.telegram.title")
            message = tr("promo.telegram.message")
            buttonText = tr("promo.telegram.button")
            link = AppLinks.telegram
            closeText = tr("common.later")
        case .announcement(let item):
            image = item.image
            title = item.title
            message = item.message
            buttonText = item.buttonText
            link = item.buttonLink
            closeText = tr("common.close")
        }
    }
}

struct PopupSheet: View {
    let content: PopupContent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let data = content.image, let image = UIImage(data: data) {   // a broken image is skipped
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else if let symbol = content.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 50))
                        .foregroundStyle(Color(argb: SettingsStyle.accent))
                }
                if !content.title.isEmpty {
                    Text(content.title)
                        .appFont(22, .bold)
                        .multilineTextAlignment(.center)
                }
                if !content.message.isEmpty {
                    Text(content.message)
                        .appFont(16, .regular)
                        .multilineTextAlignment(.center)
                        .opacity(0.85)
                }
                if let buttonText = content.buttonText {
                    Button {
                        if let link = content.link { openURL(link) }
                        dismiss()
                    } label: {
                        Text(buttonText)
                            .appFont(17, .bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Capsule().fill(Color(argb: SettingsStyle.accent)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("popup.button")
                }
                if let closeText = content.closeText {
                    Button(closeText) { dismiss() }
                        .appFont(16, .medium)
                        .tint(Color(argb: SettingsStyle.accent))
                        .accessibilityIdentifier("popup.close")
                }
            }
            .foregroundStyle(.white)
            .padding(24)
            .padding(.top, 8)
        }
        .background(Color(argb: SettingsStyle.background).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("popup")
    }
}
