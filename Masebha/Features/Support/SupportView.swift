import SwiftUI
import StoreKit

enum SupportStyle {
    static let gold: ARGB = 0xFFF5_C542
}

/// Links required next to the purchase buttons (App Store rules for subscriptions).
enum AppLinks {
    /// Apple's standard Terms of Use (EULA).
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// The owner publishes this page before the App Store submission.
    static let privacy = URL(string: "https://tasbeeh-app.pages.dev/privacy")!
    static let contact = URL(string: "mailto:masebha0@gmail.com")!
}

/// "Support the app" (≈ SupportActivity): what supporters get, the two ways to support with
/// live App Store prices, restore, manage the subscription, and contact.
struct SupportView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var message: String?
    @State private var showThanks = false
    @State private var manageSubscription = false

    var body: some View {
        let store = environment.supportStore
        let entitlements = environment.entitlements
        ScrollView {
            VStack(spacing: 22) {
                header(isSupporter: entitlements.isSupporter)
                Text(tr("support.pitch"))
                    .appFont(16, .regular)
                    .multilineTextAlignment(.center)
                    .opacity(0.85)
                SupporterPerks()
                purchases(store, entitlements)
                VStack(spacing: 14) {
                    Button(tr("support.restore")) { restore() }
                        .disabled(store.isRestoring || store.busyProductID != nil)
                        .accessibilityIdentifier("support.restore")
                    if entitlements.hasSubscription {
                        Button(tr("support.manage")) { manageSubscription = true }
                            .accessibilityIdentifier("support.manage")
                    }
                    Link(tr("support.contact"), destination: AppLinks.contact)
                }
                .appFont(16, .medium)
                .tint(Color(argb: SettingsStyle.accent))
                legal
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .background(Color(argb: SettingsStyle.background).ignoresSafeArea())
        .navigationTitle(tr("more.support"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
        .task { await store.loadProducts() }
        .onAppear { store.justBecameSupporter = false }
        .onChange(of: store.justBecameSupporter) { _, became in
            guard became else { return }
            store.justBecameSupporter = false
            showThanks = true
        }
        .manageSubscriptionsSheet(isPresented: $manageSubscription)
        .alert(tr("support.thanks.title"), isPresented: $showThanks) {
            Button(tr("common.ok"), role: .cancel) {}
        } message: {
            Text(tr("support.thanks.message"))
        }
        .alert(tr("more.support"), isPresented: isPresented($message)) {
            Button(tr("common.ok"), role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: Parts

    private func header(isSupporter: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: isSupporter ? "checkmark.seal.fill" : "heart.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color(argb: SupportStyle.gold))
            Text(isSupporter ? tr("support.title.supporter") : tr("support.title"))
                .appFont(24, .bold)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("support.status")
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func purchases(_ store: SupportStore, _ entitlements: Entitlements) -> some View {
        switch store.availability {
        case .loading:
            ProgressView()
                .tint(.white)
                .frame(minHeight: 120)
        case .unavailable:
            VStack(spacing: 12) {
                Text(tr("support.unavailable"))
                    .appFont(15, .regular)
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                Button(tr("support.retry")) {
                    Task { await store.loadProducts() }
                }
                .appFont(16, .bold)
                .tint(Color(argb: SettingsStyle.accent))
                .accessibilityIdentifier("support.retry")
            }
            .padding(.vertical, 8)
        case .ready:
            VStack(spacing: 12) {
                if let monthly = store.products[SupporterProduct.monthly] {
                    option(store, product: monthly, title: tr("support.monthly"),
                           price: tr("support.monthly.price", monthly.displayPrice),
                           hint: tr("support.monthly.hint"), owned: entitlements.hasSubscription,
                           id: "support.buyMonthly")
                }
                if let once = store.products[SupporterProduct.once] {
                    option(store, product: once, title: tr("support.once"), price: once.displayPrice,
                           hint: tr("support.once.hint"), owned: entitlements.record.ownsOnce,
                           id: "support.buyOnce")
                }
            }
        }
    }

    private func option(_ store: SupportStore, product: Product, title: String, price: String, hint: String,
                        owned: Bool, id: String) -> some View {
        Button {
            buy(product.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .appFont(17, .bold)
                    Spacer(minLength: 8)
                    if store.busyProductID == product.id {
                        ProgressView().tint(.white)
                    } else if owned {
                        Text(tr("support.owned"))
                            .appFont(15, .bold)
                            .foregroundStyle(Color(argb: SupportStyle.gold))
                    } else {
                        Text(price)
                            .appFont(17, .bold)
                            .foregroundStyle(Color(argb: SupportStyle.gold))
                    }
                }
                Text(hint)
                    .appFont(13, .regular)
                    .opacity(0.7)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(argb: SettingsStyle.row)))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(argb: SupportStyle.gold).opacity(owned ? 0.6 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(owned || store.busyProductID != nil || store.isRestoring)
        .accessibilityIdentifier(id)
    }

    private var legal: some View {
        VStack(spacing: 10) {
            Text(tr("support.legal"))
                .appFont(12, .regular)
                .multilineTextAlignment(.center)
                .opacity(0.55)
            HStack(spacing: 20) {
                Link(tr("support.terms"), destination: AppLinks.terms)
                Link(tr("support.privacy"), destination: AppLinks.privacy)
            }
            .appFont(13, .medium)
            .tint(Color(argb: SettingsStyle.accent))
        }
    }

    // MARK: Actions

    private func buy(_ productID: String) {
        Task {
            switch await environment.supportStore.purchase(productID) {
            case .pending: message = tr("support.pending")
            case .failed: message = tr("support.failed")
            case .purchased, .cancelled: break   // a new supporter gets the "thank you" alert
            }
        }
    }

    private func restore() {
        Task {
            let isSupporter = await environment.supportStore.restore()
            message = isSupporter ? tr("support.restore.done") : tr("support.restore.none")
        }
    }
}

/// What supporters get (themes and fonts are already in the app; Wird is the Wird tab).
struct SupporterPerks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            perk("list.number", tr("support.perk.wird"))
            perk("paintpalette.fill", tr("support.perk.themes"))
            perk("textformat", tr("support.perk.fonts"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(argb: SettingsStyle.row)))
        .foregroundStyle(.white)
    }

    private func perk(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(argb: SupportStyle.gold))
                .frame(width: 26)
            Text(text)
                .appFont(16, .medium)
                .multilineTextAlignment(.leading)
        }
    }
}
