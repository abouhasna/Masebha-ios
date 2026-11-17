import Foundation
import Observation

/// Whether the user is a supporter (unlocks Wird, supporter themes and supporter fonts).
///
/// The value comes only from StoreKit (`SupportStore`), through `apply(_:)`. It is saved on the
/// device so a supporter stays unlocked offline and after any error; see `SupporterRules`.
/// It is never read from or written to a backup file.
@Observable
final class Entitlements {
    @ObservationIgnored private let defaults: UserDefaults
    private(set) var record: SupporterRecord

    /// Debug builds only: a switch in Settings to preview supporter features in the Simulator.
    /// Release builds never read or set it, so it is always false there.
    var debugSupporter: Bool {
        didSet {
            #if DEBUG
            defaults.set(debugSupporter, forKey: Keys.debugSupporter)
            #endif
        }
    }

    var isSupporter: Bool { record.isSupporter || debugSupporter }
    /// Shows "Manage subscription".
    var hasSubscription: Bool { record.subscribed }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.record),
           let saved = try? JSONDecoder().decode(SupporterRecord.self, from: data) {
            record = saved
        } else {
            record = SupporterRecord()
        }
        #if DEBUG
        debugSupporter = defaults.bool(forKey: Keys.debugSupporter)
        #else
        debugSupporter = false
        #endif
    }

    /// Applies one App Store check. Returns true when the user just became a supporter.
    @discardableResult
    func apply(_ facts: StoreFacts) -> Bool {
        let updated = SupporterRules.updated(record, with: facts)
        guard updated != record else { return false }
        let wasSupporter = record.isSupporter
        record = updated
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: Keys.record)
        }
        return !wasSupporter && updated.isSupporter
    }

    private enum Keys {
        static let record = "supporter_record"
        static let debugSupporter = "debug_supporter"
    }
}
