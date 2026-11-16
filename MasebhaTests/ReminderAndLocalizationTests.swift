import Foundation
import Testing
import UserNotifications
@testable import Masebha

/// Fake notification center: records what the reminder asks iOS to do.
@MainActor
final class FakeNotificationCenter: NotificationCenterClient {
    var status: UNAuthorizationStatus
    var grantOnRequest: Bool
    var requests: [String: UNNotificationRequest] = [:]
    var permissionRequests = 0

    init(status: UNAuthorizationStatus, grantOnRequest: Bool = true) {
        self.status = status
        self.grantOnRequest = grantOnRequest
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async -> Bool {
        permissionRequests += 1
        status = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func add(_ request: UNNotificationRequest) async throws { requests[request.identifier] = request }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        for id in identifiers { requests[id] = nil }
    }

    func pendingRequest(withIdentifier identifier: String) async -> UNNotificationRequest? { requests[identifier] }
}

@MainActor
struct ReminderSchedulerTests {
    @Test func enablingSchedulesOneRepeatingDailyNotification() async throws {
        let center = FakeNotificationCenter(status: .authorized)
        let scheduler = ReminderScheduler(center: center)
        let status = await scheduler.apply(enabled: true, title: "مسبحة", body: "حان وقت الذكر", hour: 21, minute: 5)
        #expect(status == .scheduled(hour: 21, minute: 5))
        #expect(center.requests.count == 1)
        let request = try #require(center.requests[ReminderScheduler.identifier])
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 21 && trigger.dateComponents.minute == 5)
        #expect(trigger.dateComponents.day == nil)   // every day
        #expect(request.content.title == "مسبحة")
        #expect(request.content.body == "حان وقت الذكر")
    }

    @Test func savingAgainReplacesInsteadOfDuplicating() async {
        let center = FakeNotificationCenter(status: .authorized)
        let scheduler = ReminderScheduler(center: center)
        _ = await scheduler.apply(enabled: true, title: "T", body: "B", hour: 8, minute: 0)
        _ = await scheduler.apply(enabled: true, title: "T", body: "B", hour: 9, minute: 30)
        #expect(center.requests.count == 1)
        #expect(await scheduler.status(enabled: true) == .scheduled(hour: 9, minute: 30))
    }

    @Test func disablingRemovesTheNotification() async {
        let center = FakeNotificationCenter(status: .authorized)
        let scheduler = ReminderScheduler(center: center)
        _ = await scheduler.apply(enabled: true, title: "T", body: "B", hour: 8, minute: 0)
        #expect(await scheduler.apply(enabled: false, title: "T", body: "B", hour: 8, minute: 0) == .off)
        #expect(center.requests.isEmpty)
    }

    @Test func asksPermissionOnlyWhenEnablingTheFirstTime() async {
        let center = FakeNotificationCenter(status: .notDetermined)
        let scheduler = ReminderScheduler(center: center)
        #expect(await scheduler.apply(enabled: true, title: "T", body: "B", hour: 8, minute: 0) == .scheduled(hour: 8, minute: 0))
        #expect(center.permissionRequests == 1)
    }

    @Test func refusedPermissionIsReportedAndNothingIsScheduled() async {
        let center = FakeNotificationCenter(status: .notDetermined, grantOnRequest: false)
        let scheduler = ReminderScheduler(center: center)
        #expect(await scheduler.apply(enabled: true, title: "T", body: "B", hour: 8, minute: 0) == .notAllowed)
        #expect(center.requests.isEmpty)
    }

    @Test func launchRefreshNeverAsksForPermission() async {
        let center = FakeNotificationCenter(status: .notDetermined)
        let scheduler = ReminderScheduler(center: center)
        #expect(await scheduler.refresh(enabled: true, title: "T", body: "B", hour: 8, minute: 0) == .notAllowed)
        #expect(center.permissionRequests == 0)
    }

    @Test func launchRefreshUpdatesTheText() async {
        let center = FakeNotificationCenter(status: .authorized)
        let scheduler = ReminderScheduler(center: center)
        _ = await scheduler.apply(enabled: true, title: "T", body: "حان وقت الذكر", hour: 8, minute: 0)
        _ = await scheduler.refresh(enabled: true, title: "T", body: "Time to remember Allah", hour: 8, minute: 0)
        #expect(center.requests[ReminderScheduler.identifier]?.content.body == "Time to remember Allah")
    }
}

@MainActor
struct LocalizationTests {
    private func strings(_ language: String) throws -> [String: String] {
        let url = try #require(Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                               subdirectory: nil, localization: language))
        let dictionary = try #require(NSDictionary(contentsOf: url) as? [String: String])
        return dictionary
    }

    @Test func arabicAndEnglishHaveTheSameKeys() throws {
        let arabic = try strings("ar")
        let english = try strings("en")
        #expect(arabic.count > 150)
        #expect(Set(arabic.keys) == Set(english.keys))
        #expect(arabic.values.allSatisfy { !$0.isEmpty })
        #expect(english.values.allSatisfy { !$0.isEmpty })
    }

    @Test func switchingLanguageChangesTheText() {
        let localizer = Localizer.shared
        let original = localizer.language
        defer { localizer.setLanguage(original) }

        localizer.setLanguage(.english)
        #expect(tr("tab.azkar") == "Azkar")
        #expect(tr("card.opened.today", "09:42") == "Today 09:42")
        localizer.setLanguage(.arabic)
        #expect(tr("tab.azkar") == "الأذكار")
        #expect(tr("timer.set_format", 1.5) == "تم ضبط المؤقت على 1.5 ثانية")
    }

    @Test func seedsFollowTheChosenLanguage() {
        let localizer = Localizer.shared
        let original = localizer.language
        defer { localizer.setLanguage(original) }

        localizer.setLanguage(.arabic)
        let arabic = SeedData.items()
        localizer.setLanguage(.english)
        let english = SeedData.items()
        #expect(arabic.count == 7 && english.count == 7)
        #expect(arabic.first?.name == "سبحان الله")
        #expect(english.first?.name == "Subhan Allah")
        #expect(arabic.map(\.loopSize) == [33, 33, 33, 33, 100, 33, 33])
    }
}
