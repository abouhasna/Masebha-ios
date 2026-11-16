import Foundation
import UserNotifications

/// What the reminder really is right now (shown in Settings, so the user can trust it).
nonisolated enum ReminderStatus: Equatable, Sendable {
    case off
    case scheduled(hour: Int, minute: Int)
    case notAllowed   // enabled by the user, but iOS notifications are not allowed for the app
}

/// The parts of UNUserNotificationCenter the reminder uses (replaced by a fake in unit tests).
protocol NotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
    func pendingRequest(withIdentifier identifier: String) async -> UNNotificationRequest?
}

struct LiveNotificationCenter: NotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingRequest(withIdentifier identifier: String) async -> UNNotificationRequest? {
        await UNUserNotificationCenter.current().pendingNotificationRequests().first { $0.identifier == identifier }
    }
}

/// The daily reminder (≈ ReminderScheduler + ReminderReceiver + BootReceiver on Android).
///
/// iOS repeats the notification every day by itself, at the exact time, even after a restart or
/// if the app is never opened again. There is nothing to re-arm, unlike AlarmManager on Android.
final class ReminderScheduler {
    static let identifier = "daily-reminder"

    private let center: NotificationCenterClient

    init(center: NotificationCenterClient = LiveNotificationCenter()) {
        self.center = center
    }

    /// Saves the reminder with iOS. Asks for notification permission the first time it is enabled.
    func apply(enabled: Bool, title: String, body: String, hour: Int, minute: Int) async -> ReminderStatus {
        guard enabled else {
            center.removePendingRequests(withIdentifiers: [Self.identifier])
            return .off
        }
        var status = await center.authorizationStatus()
        if status == .notDetermined {
            _ = await center.requestAuthorization()
            status = await center.authorizationStatus()
        }
        guard Self.isAllowed(status) else {
            center.removePendingRequests(withIdentifiers: [Self.identifier])
            return .notAllowed
        }
        do {
            try await center.add(Self.request(title: title, body: body, hour: hour, minute: minute))
            return .scheduled(hour: hour, minute: minute)
        } catch {
            return .notAllowed
        }
    }

    /// At launch: re-saves an enabled reminder so its text follows the current language.
    /// Never asks for permission (that only happens when the user enables the reminder).
    func refresh(enabled: Bool, title: String, body: String, hour: Int, minute: Int) async -> ReminderStatus {
        guard enabled else {
            center.removePendingRequests(withIdentifiers: [Self.identifier])
            return .off
        }
        guard Self.isAllowed(await center.authorizationStatus()) else { return .notAllowed }
        try? await center.add(Self.request(title: title, body: body, hour: hour, minute: minute))
        return await status(enabled: true)
    }

    /// The real state, read back from iOS.
    func status(enabled: Bool) async -> ReminderStatus {
        guard enabled else { return .off }
        guard Self.isAllowed(await center.authorizationStatus()) else { return .notAllowed }
        guard let request = await center.pendingRequest(withIdentifier: Self.identifier),
              let trigger = request.trigger as? UNCalendarNotificationTrigger,
              let hour = trigger.dateComponents.hour, let minute = trigger.dateComponents.minute else {
            return .notAllowed
        }
        return .scheduled(hour: hour, minute: minute)
    }

    static func request(title: String, body: String, hour: Int, minute: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var time = DateComponents()
        time.hour = hour
        time.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        // Same identifier every time: a new request replaces the previous one, never duplicates it.
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private static func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }
}
