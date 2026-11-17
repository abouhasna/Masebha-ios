import Foundation

/// The two ways to support the app. These are the App Store Connect product IDs: never change
/// them once the app is live.
nonisolated enum SupporterProduct {
    /// Auto-renewable monthly subscription (subscription group "Supporter").
    static let monthly = "nafii.masebha.support.monthly"
    /// One-time, non-consumable purchase: a supporter forever.
    static let once = "nafii.masebha.support.once"
    static let all = [monthly, once]
}

/// What the app remembers about the user's support, saved on the device.
///
/// This record is the safety net that keeps a supporter unlocked when the App Store cannot be
/// asked (offline, an error, a slow start). Each part is switched off only by a definite answer
/// from Apple, never by a missing one. See `SupporterRules`.
nonisolated struct SupporterRecord: Codable, Equatable, Sendable {
    var ownsOnce = false
    var subscribed = false

    var isSupporter: Bool { ownsOnce || subscribed }
}

/// Apple's answer about one product, from one check.
nonisolated enum StoreFinding: Equatable, Sendable {
    /// Apple confirms it (verified data).
    case active
    /// Apple confirms it is over: the one-time purchase was refunded, or the subscription ended
    /// more than `SupporterRules.endMargin` ago.
    case ended
}

/// What one check with the App Store found. nil means "no answer" (offline, an error, never
/// bought, unverified data): the saved record is kept as it is.
nonisolated struct StoreFacts: Equatable, Sendable {
    var once: StoreFinding?
    var subscription: StoreFinding?
}

/// The rules that turn App Store answers into the saved record. Pure logic, fully unit-tested.
nonisolated enum SupporterRules {
    /// A subscription that ended less than this long ago still counts: a renewal can reach the
    /// device late (no network, the App Store catching up).
    static let endMargin: TimeInterval = 3 * 24 * 3600

    /// The new record after a check. Only a definite answer changes a part of it.
    static func updated(_ record: SupporterRecord, with facts: StoreFacts) -> SupporterRecord {
        var result = record
        if let once = facts.once { result.ownsOnce = once == .active }
        if let subscription = facts.subscription { result.subscribed = subscription == .active }
        return result
    }

    /// One subscription status as reported by Apple.
    enum SubscriptionStatus: Equatable, Sendable {
        /// Subscribed, in a billing grace period or in billing retry (we stay generous).
        case active
        /// Expired or revoked, with the verified date it ended.
        case ended(Date)
        /// Unverified or incomplete data.
        case unknown
    }

    /// The subscription is "ended" only if every status says so with a verified date older than
    /// the margin. Any doubt gives no answer.
    static func subscriptionFinding(_ statuses: [SubscriptionStatus], now: Date) -> StoreFinding? {
        guard !statuses.isEmpty else { return nil }
        if statuses.contains(.active) { return .active }
        let limit = now.addingTimeInterval(-endMargin)
        for status in statuses {
            guard case .ended(let date) = status, date < limit else { return nil }
        }
        return .ended
    }
}
