import Foundation
import Observation

/// Whether the user is a supporter (unlocks supporter themes and fonts; later also Wird).
///
/// Leap 1 has no purchases yet, so the value is always false in release builds. Debug builds
/// (the Simulator tests) have a hidden switch in Settings to preview supporter features.
/// Leap 2 replaces this with StoreKit, the only source of truth.
@Observable
final class Entitlements {
    @ObservationIgnored private let defaults: UserDefaults
    private static let debugKey = "debug_supporter"

    var isSupporter: Bool {
        didSet {
            #if DEBUG
            defaults.set(isSupporter, forKey: Entitlements.debugKey)
            #endif
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        isSupporter = defaults.bool(forKey: Entitlements.debugKey)
        #else
        isSupporter = false
        #endif
    }
}
