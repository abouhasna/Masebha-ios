import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Masebha

/// Purchases end to end against Apple's local test store (StoreKit/Supporter.storekit):
/// real StoreKit transactions, verification, refunds, expiry, "Ask to Buy" and failures.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
final class StoreKitTests {
    private let session: SKTestSession

    init() throws {
        let url = try #require(Bundle(for: StoreKitTests.self).url(forResource: "Supporter", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    private func makeStore() -> (SupportStore, Entitlements, UserDefaults) {
        let name = "storekit-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let entitlements = Entitlements(defaults: defaults)
        return (SupportStore(entitlements: entitlements), entitlements, defaults)
    }

    @Test func productsLoadWithTheirPrices() async {
        // StoreKit's own answer first, so a failure says exactly what the test store returned.
        do {
            let products = try await Product.products(for: SupporterProduct.all)
            #expect(Set(products.map(\.id)) == Set(SupporterProduct.all), "The test store returned \(products.map(\.id))")
        } catch {
            Issue.record("Product.products failed: \(error)")
        }
        let (store, _, _) = makeStore()
        await store.loadProducts()
        #expect(store.availability == .ready)
        #expect(Set(store.products.keys) == Set(SupporterProduct.all))
        #expect(store.products[SupporterProduct.once]?.displayPrice.isEmpty == false)
        #expect(store.products[SupporterProduct.monthly]?.subscription != nil)
    }

    @Test func withoutPurchasesThereIsNoAnswer() async {
        let (store, _, _) = makeStore()
        await store.loadProducts()
        let facts = await StoreFactsReader.read(monthly: store.products[SupporterProduct.monthly], now: Date())
        #expect(facts == StoreFacts())
    }

    @Test func buyingOnceMakesASupporterThatStays() async {
        let (store, entitlements, defaults) = makeStore()
        await store.loadProducts()
        #expect(await store.purchase(SupporterProduct.once) == .purchased)
        #expect(entitlements.isSupporter)
        #expect(entitlements.record.ownsOnce)
        #expect(store.justBecameSupporter)

        let facts = await StoreFactsReader.read(monthly: nil, now: Date())
        #expect(facts.once == .active)
        #expect(Entitlements(defaults: defaults).isSupporter)   // next launch
    }

    @Test func aRefundEndsTheOneTimePurchase() async throws {
        let (store, entitlements, _) = makeStore()
        await store.loadProducts()
        #expect(await store.purchase(SupporterProduct.once) == .purchased)
        let latest = await Transaction.latest(for: SupporterProduct.once)
        guard case .verified(let transaction) = try #require(latest) else {
            Issue.record("The purchase is not verified")
            return
        }
        try session.refundTransaction(identifier: UInt(transaction.id))
        await store.refresh()
        #expect(entitlements.isSupporter == false)
    }

    @Test func monthlySupportEndsOnlyAfterTheMargin() async throws {
        let (store, entitlements, _) = makeStore()
        await store.loadProducts()
        #expect(await store.purchase(SupporterProduct.monthly) == .purchased)
        #expect(entitlements.isSupporter)
        #expect(entitlements.hasSubscription)

        try session.expireSubscription(productIdentifier: SupporterProduct.monthly)
        let monthly = store.products[SupporterProduct.monthly]

        // Just expired: a renewal could still arrive, so there is no answer and support stays.
        let now = await StoreFactsReader.read(monthly: monthly, now: Date())
        #expect(now.subscription == nil)
        entitlements.apply(now)
        #expect(entitlements.isSupporter)

        // Four days later Apple's answer is final.
        let later = await StoreFactsReader.read(monthly: monthly, now: Date().addingTimeInterval(4 * 24 * 3600))
        #expect(later.subscription == .ended)
        entitlements.apply(later)
        #expect(entitlements.isSupporter == false)
    }

    @Test func anExpiredSubscriptionNeverRemovesTheOneTimePurchase() async throws {
        let (store, entitlements, _) = makeStore()
        await store.loadProducts()
        #expect(await store.purchase(SupporterProduct.once) == .purchased)
        #expect(await store.purchase(SupporterProduct.monthly) == .purchased)
        try session.expireSubscription(productIdentifier: SupporterProduct.monthly)
        let facts = await StoreFactsReader.read(monthly: store.products[SupporterProduct.monthly],
                                                now: Date().addingTimeInterval(30 * 24 * 3600))
        entitlements.apply(facts)
        #expect(entitlements.isSupporter)
        #expect(entitlements.record.ownsOnce)
    }

    @Test func askToBuyUnlocksOnlyAfterApproval() async throws {
        let (store, entitlements, _) = makeStore()
        session.askToBuyEnabled = true
        await store.loadProducts()
        #expect(await store.purchase(SupporterProduct.once) == .pending)
        #expect(entitlements.isSupporter == false)

        let transactions = try session.allTransactions()
        let pending = try #require(transactions.first { $0.productIdentifier == SupporterProduct.once })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        for _ in 0..<20 where !entitlements.isSupporter {
            await store.refresh()
            try await Task.sleep(for: .milliseconds(200))
        }
        #expect(entitlements.isSupporter)
    }

    @Test func aFailedPurchaseChangesNothing() async {
        let (store, entitlements, _) = makeStore()
        await store.loadProducts()
        session.failTransactionsEnabled = true
        #expect(await store.purchase(SupporterProduct.once) == .failed)
        #expect(entitlements.isSupporter == false)
        #expect(store.busyProductID == nil)
    }

    @Test func restoreFindsAPurchaseAfterAReinstall() async {
        let (first, _, _) = makeStore()
        await first.loadProducts()
        #expect(await first.purchase(SupporterProduct.once) == .purchased)

        let (reinstalled, entitlements, _) = makeStore()   // empty saved record, like a new install
        #expect(entitlements.isSupporter == false)
        #expect(await reinstalled.restore() == true)
        #expect(entitlements.isSupporter)
    }
}
