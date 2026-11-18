import Foundation

/// At most one popup per launch (Android order): the welcome for a new user, otherwise a newer
/// announcement, otherwise the Telegram invitation. Each one is shown once, whatever the answer.
/// (No support popup: the Wird tab already explains support. Owner's decision.)
nonisolated enum LaunchPopup: Equatable, Sendable {
    case welcome
    case announcement(Announcement)
    case telegram
}

nonisolated struct LaunchState: Equatable, Sendable {
    var launchCount: Int
    var welcomeShown: Bool
    var announcementVersionShown: Int
    var telegramPromoShown: Bool
}

nonisolated enum LaunchPopups {
    /// Apple's rating prompt is asked after counting (never at launch, Apple's advice), from this launch.
    static let reviewFromLaunch = 7
    static let telegramFromLaunch = 13

    /// Whether the announcement is worth fetching this launch (the welcome comes first).
    static func needsAnnouncement(_ state: LaunchState) -> Bool {
        state.welcomeShown
    }

    static func choose(_ state: LaunchState, announcement: Announcement?) -> LaunchPopup? {
        if !state.welcomeShown { return .welcome }
        if let announcement, announcement.version > state.announcementVersionShown { return .announcement(announcement) }
        if state.launchCount >= telegramFromLaunch && !state.telegramPromoShown { return .telegram }
        return nil
    }

    static func shouldAskForReview(launchCount: Int, alreadyAsked: Bool) -> Bool {
        launchCount >= reviewFromLaunch && !alreadyAsked
    }
}
