import Foundation

/// At most one popup per launch (Android order): the welcome for a new user, otherwise a newer
/// announcement, otherwise a promo. Each one is shown once, whatever the user answers.
nonisolated enum LaunchPopup: Equatable, Sendable {
    case welcome
    case announcement(Announcement)
    case telegram
    case support
}

nonisolated struct LaunchState: Equatable, Sendable {
    var launchCount: Int
    var welcomeShown: Bool
    var announcementVersionShown: Int
    var telegramPromoShown: Bool
    var supportPromoShown: Bool
    var isSupporter: Bool
}

nonisolated enum LaunchPopups {
    /// Apple's rating prompt is asked after counting (never at launch, Apple's advice), from this launch.
    static let reviewFromLaunch = 7
    static let telegramFromLaunch = 13
    static let supportFromLaunch = 20

    /// Whether the announcement is worth fetching this launch (the welcome comes first).
    static func needsAnnouncement(_ state: LaunchState) -> Bool {
        state.welcomeShown
    }

    static func choose(_ state: LaunchState, announcement: Announcement?) -> LaunchPopup? {
        if !state.welcomeShown { return .welcome }
        if let announcement, announcement.version > state.announcementVersionShown { return .announcement(announcement) }
        if state.launchCount >= telegramFromLaunch && !state.telegramPromoShown { return .telegram }
        if state.launchCount >= supportFromLaunch && !state.supportPromoShown && !state.isSupporter { return .support }
        return nil
    }

    static func shouldAskForReview(launchCount: Int, alreadyAsked: Bool) -> Bool {
        launchCount >= reviewFromLaunch && !alreadyAsked
    }
}
