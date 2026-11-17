import Foundation
import Observation
import StoreKit

/// Purchases with StoreKit 2 (≈ BillingManager on Android).
///
/// - Listens to `Transaction.updates` from launch: renewals, "Ask to Buy" approvals, refunds and
///   purchases made on another device arrive there.
/// - Every check reads only verified data and goes through `Entitlements.apply`, which never
///   removes support without a definite answer from Apple.
/// - Prices always come from the App Store (`Product.displayPrice`), never hard-coded.
@Observable
final class SupportStore {
    enum Availability: Equatable {
        case loading, ready, unavailable
    }

    enum PurchaseOutcome: Equatable {
        case purchased, pending, cancelled, failed
    }

    private(set) var availability: Availability = .loading
    private(set) var products: [String: Product] = [:]
    /// The product being bought (its button shows a spinner and the others are disabled).
    private(set) var busyProductID: String?
    private(set) var isRestoring = false
    /// Set when the user became a supporter while the app runs; the Support screen thanks them.
    var justBecameSupporter = false

    @ObservationIgnored private let entitlements: Entitlements
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(entitlements: Entitlements) {
        self.entitlements = entitlements
    }

    /// Call once at launch.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    self?.record(StoreFactsReader.facts(of: transaction, now: Date()))
                }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// Asks the App Store for the products (with their local prices). Safe to call again.
    func loadProducts() async {
        guard availability != .ready else { return }
        availability = .loading
        do {
            let loaded = try await Product.products(for: SupporterProduct.all)
            products = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            availability = products.isEmpty ? .unavailable : .ready
        } catch {
            availability = .unavailable
        }
    }

    /// Checks the user's purchases again (at launch, when the app comes back, after a purchase).
    func refresh() async {
        if products[SupporterProduct.monthly] == nil {
            await loadProducts()
        }
        let facts = await StoreFactsReader.read(monthly: products[SupporterProduct.monthly], now: Date())
        record(facts)
    }

    func purchase(_ productID: String) async -> PurchaseOutcome {
        guard busyProductID == nil, !isRestoring, let product = products[productID] else { return .failed }
        busyProductID = productID
        defer { busyProductID = nil }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                await transaction.finish()
                record(StoreFactsReader.facts(of: transaction, now: Date()))   // unlock at once
                await refresh()
                return .purchased
            case .pending:
                return .pending   // unlocks later through Transaction.updates
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// "Restore purchases": syncs with the App Store (it may ask the user to sign in), then
    /// checks again. Returns whether the user is a supporter afterwards.
    func restore() async -> Bool {
        guard !isRestoring else { return entitlements.isSupporter }
        isRestoring = true
        defer { isRestoring = false }
        try? await AppStore.sync()   // a cancelled sign-in still leaves the local check below
        await refresh()
        return entitlements.isSupporter
    }

    private func record(_ facts: StoreFacts) {
        if entitlements.apply(facts) {
            justBecameSupporter = true
        }
    }
}

/// Reads the user's support from StoreKit. Only verified data counts; anything else is "no answer".
nonisolated enum StoreFactsReader {
    static func read(monthly: Product?, now: Date) async -> StoreFacts {
        var facts = StoreFacts()

        // 1. What the device already knows (works offline).
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            let found = Self.facts(of: transaction, now: now)
            if found.once == .active { facts.once = .active }
            if found.subscription == .active { facts.subscription = .active }
        }

        // 2. A verified refund of the one-time purchase is the only thing that ends it.
        if facts.once == nil, let latest = await Transaction.latest(for: SupporterProduct.once),
           case .verified(let transaction) = latest, transaction.revocationDate != nil {
            facts.once = .ended
        }

        // 3. The subscription as Apple reports it (needs the product, i.e. an answer from the store).
        if facts.subscription == nil, let info = monthly?.subscription,
           let statuses = try? await info.status {
            facts.subscription = SupporterRules.subscriptionFinding(statuses.map(Self.status), now: now)
        }
        return facts
    }

    /// What a single verified transaction proves. It can grant support, or end the one-time
    /// purchase when it carries a refund. Ending a subscription is left to `read`, which looks at
    /// all of Apple's statuses first.
    static func facts(of transaction: Transaction, now: Date) -> StoreFacts {
        var facts = StoreFacts()
        let revoked = transaction.revocationDate != nil
        switch transaction.productID {
        case SupporterProduct.once:
            facts.once = revoked ? .ended : .active
        case SupporterProduct.monthly:
            if !revoked, (transaction.expirationDate ?? .distantFuture) > now {
                facts.subscription = .active
            }
        default:
            break
        }
        return facts
    }

    private static func status(_ status: Product.SubscriptionInfo.Status) -> SupporterRules.SubscriptionStatus {
        guard case .verified(let transaction) = status.transaction else { return .unknown }
        switch status.state {
        case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
            return .active
        case .expired, .revoked:
            guard let end = transaction.revocationDate ?? transaction.expirationDate else { return .unknown }
            return .ended(end)
        default:
            return .unknown
        }
    }
}
