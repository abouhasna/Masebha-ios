import Foundation
import Testing
@testable import Masebha

/// The supporter rules (owner's top priority): a supporter is never removed by mistake, by being
/// offline, or by any error. Only a definite answer from Apple removes support.
struct SupporterRulesTests {
    private let none = SupporterRecord()
    private let once = SupporterRecord(ownsOnce: true, subscribed: false)
    private let monthly = SupporterRecord(ownsOnce: false, subscribed: true)
    private let both = SupporterRecord(ownsOnce: true, subscribed: true)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 3600

    @Test func nobodyIsASupporterByDefault() {
        #expect(none.isSupporter == false)
        #expect(once.isSupporter && monthly.isSupporter && both.isSupporter)
    }

    @Test func noAnswerNeverChangesAnything() {
        for record in [none, once, monthly, both] {
            #expect(SupporterRules.updated(record, with: StoreFacts()) == record)
        }
    }

    @Test func aConfirmedPurchaseGrants() {
        #expect(SupporterRules.updated(none, with: StoreFacts(once: .active)) == once)
        #expect(SupporterRules.updated(none, with: StoreFacts(subscription: .active)) == monthly)
        #expect(SupporterRules.updated(once, with: StoreFacts(subscription: .active)) == both)
    }

    @Test func onlyARefundEndsTheOneTimePurchase() {
        // An ended subscription, or "nothing found", never touches the one-time purchase.
        #expect(SupporterRules.updated(once, with: StoreFacts(subscription: .ended)) == once)
        #expect(SupporterRules.updated(once, with: StoreFacts(once: nil, subscription: nil)) == once)
        #expect(SupporterRules.updated(once, with: StoreFacts(once: .ended)) == none)
    }

    @Test func anEndedSubscriptionKeepsTheOneTimePurchase() {
        let result = SupporterRules.updated(both, with: StoreFacts(subscription: .ended))
        #expect(result == once)
        #expect(result.isSupporter)
    }

    @Test func aDefiniteEndRemovesOnlyThatPart() {
        #expect(SupporterRules.updated(monthly, with: StoreFacts(subscription: .ended)) == none)
        #expect(SupporterRules.updated(both, with: StoreFacts(once: .ended, subscription: .active)) == monthly)
    }

    @Test func manyOfflineChecksInARowKeepTheSupporter() {
        var record = monthly
        for _ in 0..<1_000 { record = SupporterRules.updated(record, with: StoreFacts()) }
        #expect(record == monthly)
    }

    // MARK: Subscription statuses

    @Test func noStatusIsNoAnswer() {
        #expect(SupporterRules.subscriptionFinding([], now: now) == nil)
    }

    @Test func anyActiveStatusMeansActive() {
        #expect(SupporterRules.subscriptionFinding([.active], now: now) == .active)
        #expect(SupporterRules.subscriptionFinding([.ended(now.addingTimeInterval(-30 * day)), .active], now: now) == .active)
        #expect(SupporterRules.subscriptionFinding([.unknown, .active], now: now) == .active)
    }

    @Test func aRecentEndIsNotFinalYet() {
        // A renewal can reach the device late: within the margin, no answer (support is kept).
        let recent = now.addingTimeInterval(-SupporterRules.endMargin + 60)
        #expect(SupporterRules.subscriptionFinding([.ended(recent)], now: now) == nil)
        #expect(SupporterRules.subscriptionFinding([.ended(now)], now: now) == nil)
    }

    @Test func anOldEndIsFinal() {
        let old = now.addingTimeInterval(-SupporterRules.endMargin - 60)
        #expect(SupporterRules.subscriptionFinding([.ended(old)], now: now) == .ended)
        #expect(SupporterRules.subscriptionFinding([.ended(old), .ended(old.addingTimeInterval(-day))], now: now) == .ended)
    }

    @Test func anyDoubtGivesNoAnswer() {
        let old = now.addingTimeInterval(-30 * day)
        #expect(SupporterRules.subscriptionFinding([.unknown], now: now) == nil)
        #expect(SupporterRules.subscriptionFinding([.ended(old), .unknown], now: now) == nil)
        #expect(SupporterRules.subscriptionFinding([.ended(old), .ended(now)], now: now) == nil)
    }
}

/// The saved record behind `Entitlements`.
@MainActor
struct EntitlementsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsAsNotASupporter() {
        let entitlements = Entitlements(defaults: freshDefaults())
        #expect(entitlements.isSupporter == false)
        #expect(entitlements.hasSubscription == false)
    }

    @Test func survivesARelaunchWithoutAnyNetwork() {
        let defaults = freshDefaults()
        let first = Entitlements(defaults: defaults)
        #expect(first.apply(StoreFacts(once: .active)) == true)   // just became a supporter

        let relaunched = Entitlements(defaults: defaults)        // next launch, offline: no check at all
        #expect(relaunched.isSupporter)
        relaunched.apply(StoreFacts())                            // and a failed check
        #expect(relaunched.isSupporter)
        #expect(Entitlements(defaults: defaults).isSupporter)
    }

    @Test func reportsOnlyTheMomentSomeoneBecomesASupporter() {
        let entitlements = Entitlements(defaults: freshDefaults())
        #expect(entitlements.apply(StoreFacts()) == false)
        #expect(entitlements.apply(StoreFacts(subscription: .active)) == true)
        #expect(entitlements.apply(StoreFacts(subscription: .active)) == false)   // already one
        #expect(entitlements.apply(StoreFacts(once: .active)) == false)           // still one
        #expect(entitlements.hasSubscription)
    }

    @Test func aRefundIsSavedToo() {
        let defaults = freshDefaults()
        let entitlements = Entitlements(defaults: defaults)
        entitlements.apply(StoreFacts(once: .active))
        entitlements.apply(StoreFacts(once: .ended))
        #expect(entitlements.isSupporter == false)
        #expect(Entitlements(defaults: defaults).isSupporter == false)
    }

    @Test func aDamagedSavedValueIsNotASupporterButHealsOnTheNextCheck() {
        let defaults = freshDefaults()
        defaults.set(Data("not json".utf8), forKey: "supporter_record")
        let entitlements = Entitlements(defaults: defaults)
        #expect(entitlements.isSupporter == false)
        entitlements.apply(StoreFacts(once: .active))   // StoreKit is the source of truth
        #expect(Entitlements(defaults: defaults).isSupporter)
    }

    @Test func theDebugSwitchIsSeparateFromRealSupport() {
        let defaults = freshDefaults()
        let entitlements = Entitlements(defaults: defaults)
        entitlements.debugSupporter = true
        #expect(entitlements.isSupporter)
        #expect(entitlements.record.isSupporter == false)   // never saved as a real purchase
    }
}
