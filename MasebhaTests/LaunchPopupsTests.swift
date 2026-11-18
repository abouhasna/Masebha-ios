import Foundation
import Testing
@testable import Masebha

/// The announcement document from Firestore: everything is checked, nothing can crash the app.
struct AnnouncementTests {
    private func document(_ fields: [String: String]) -> Data {
        let body = fields.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", ")
        return Data("{\"name\": \"projects/p/databases/(default)/documents/masebha/ios_popup\", \"fields\": {\(body)}}".utf8)
    }

    private let valid: [String: String] = [
        "enabled": #"{"booleanValue": true}"#,
        "version": #"{"integerValue": "3"}"#,
        "title": #"{"stringValue": "عنوان"}"#,
        "title_en": #"{"stringValue": "Title"}"#,
        "description": #"{"stringValue": "نص"}"#,
        "buttonText": #"{"stringValue": "افتح"}"#,
        "buttonLink": #"{"stringValue": "https://t.me/nafiapp"}"#,
    ]

    @Test func aValidDocumentIsRead() throws {
        let item = try #require(Announcement.parse(document(valid), english: false))
        #expect(item.version == 3)
        #expect(item.title == "عنوان" && item.message == "نص")
        #expect(item.buttonText == "افتح")
        #expect(item.buttonLink == URL(string: "https://t.me/nafiapp"))
        #expect(item.image == nil)
    }

    @Test func englishFallsBackToArabicFieldByField() throws {
        let item = try #require(Announcement.parse(document(valid), english: true))
        #expect(item.title == "Title")   // title_en exists
        #expect(item.message == "نص")    // no description_en: the Arabic text
    }

    @Test func disabledOrWithoutAVersionShowsNothing() {
        var fields = valid
        fields["enabled"] = #"{"booleanValue": false}"#
        #expect(Announcement.parse(document(fields), english: false) == nil)
        fields = valid
        fields["version"] = nil
        #expect(Announcement.parse(document(fields), english: false) == nil)
        fields["version"] = #"{"integerValue": "0"}"#
        #expect(Announcement.parse(document(fields), english: false) == nil)
        fields["version"] = #"{"integerValue": "abc"}"#
        #expect(Announcement.parse(document(fields), english: false) == nil)
    }

    @Test func aVersionTypedAsADecimalStillWorks() {
        var fields = valid
        fields["version"] = #"{"doubleValue": 4}"#
        #expect(Announcement.parse(document(fields), english: false)?.version == 4)
    }

    @Test func withoutAnyTextThereIsNothingToShow() {
        var fields = valid
        fields["title"] = #"{"stringValue": "  "}"#
        fields["title_en"] = nil
        fields["description"] = nil
        #expect(Announcement.parse(document(fields), english: false) == nil)
    }

    @Test func aBrokenImageOrUnsafeLinkIsLeftOutNotFatal() throws {
        var fields = valid
        fields["image"] = #"{"stringValue": "@@@not base64@@@"}"#
        fields["buttonLink"] = #"{"stringValue": "javascript:alert(1)"}"#
        let item = try #require(Announcement.parse(document(fields), english: false))
        #expect(item.image == nil)
        #expect(item.buttonLink == nil)
        #expect(item.buttonText == "افتح")   // the button still closes the popup
    }

    @Test func aRealImageIsKept() throws {
        var fields = valid
        let pixel = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        fields["image"] = "{\"stringValue\": \"\(pixel)\"}"
        #expect(try #require(Announcement.parse(document(fields), english: false)).image?.isEmpty == false)
    }

    @Test func errorsAndGarbageShowNothing() {
        #expect(Announcement.parse(Data("not json".utf8), english: false) == nil)
        #expect(Announcement.parse(Data(#"{"error": {"code": 404, "status": "NOT_FOUND"}}"#.utf8), english: false) == nil)
        #expect(Announcement.parse(Data(#"{"fields": "x"}"#.utf8), english: false) == nil)
    }
}

/// One popup per launch, in Android's order; each shown once.
struct LaunchPopupsTests {
    private let announcement = Announcement(version: 2, title: "T", message: "M", buttonText: nil, buttonLink: nil, image: nil)

    private func state(launch: Int = 1, welcome: Bool = true, version: Int = 0, telegram: Bool = false) -> LaunchState {
        LaunchState(launchCount: launch, welcomeShown: welcome, announcementVersionShown: version,
                    telegramPromoShown: telegram)
    }

    @Test func aNewUserSeesTheWelcomeFirst() {
        #expect(LaunchPopups.choose(state(welcome: false), announcement: announcement) == .welcome)
        #expect(LaunchPopups.needsAnnouncement(state(welcome: false)) == false)   // no fetch needed
    }

    @Test func aNewerAnnouncementComesNext() {
        #expect(LaunchPopups.choose(state(), announcement: announcement) == .announcement(announcement))
        #expect(LaunchPopups.choose(state(version: 2), announcement: announcement) == nil)   // already seen
        #expect(LaunchPopups.choose(state(version: 5), announcement: announcement) == nil)
    }

    @Test func theTelegramInvitationComesOnceFromTheThirteenthLaunch() {
        #expect(LaunchPopups.choose(state(launch: 12), announcement: nil) == nil)
        #expect(LaunchPopups.choose(state(launch: 13), announcement: nil) == .telegram)
        #expect(LaunchPopups.choose(state(launch: 40, telegram: true), announcement: nil) == nil)
    }

    @Test func anAnnouncementWinsOverAPromo() {
        #expect(LaunchPopups.choose(state(launch: 25), announcement: announcement) == .announcement(announcement))
    }

    @Test func theRatingPromptComesOnceFromTheSeventhLaunch() {
        #expect(LaunchPopups.shouldAskForReview(launchCount: 6, alreadyAsked: false) == false)
        #expect(LaunchPopups.shouldAskForReview(launchCount: 7, alreadyAsked: false))
        #expect(LaunchPopups.shouldAskForReview(launchCount: 40, alreadyAsked: true) == false)
    }
}

/// Launch after launch, with the saved flags (one popup per launch, each once).
@MainActor
struct LaunchSequenceTests {
    private let defaults: UserDefaults = {
        let name = "launch-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    private let sample = Data(#"""
        {"fields": {"enabled": {"booleanValue": true}, "version": {"integerValue": "1"},
         "title": {"stringValue": "T"}, "description": {"stringValue": "M"}}}
        """#.utf8)

    /// A new launch of the app with the same saved settings.
    private func launch() throws -> AppEnvironment {
        let environment = AppEnvironment(settings: AppSettings(defaults: defaults), entitlements: Entitlements(defaults: defaults),
                                         database: try AppDatabase.inMemory())
        environment.settings.launchCount += 1
        environment.announcementOverride = sample
        return environment
    }

    @Test func eachPopupShowsOnceAcrossLaunches() async throws {
        let first = try launch()
        #expect(await first.nextLaunchPopup() == .welcome)
        #expect(await first.nextLaunchPopup() == nil)   // one per launch

        let second = try launch()
        guard case .announcement(let item)? = await second.nextLaunchPopup() else {
            Issue.record("Expected the announcement")
            return
        }
        #expect(item.version == 1)

        let third = try launch()
        #expect(await third.nextLaunchPopup() == nil)   // version 1 already seen
        #expect(third.settings.launchCount == 3)
    }

    @Test func uiTestsCanTurnPopupsAndRatingOff() async throws {
        let environment = try launch()
        environment.launchPopupsEnabled = false
        environment.settings.launchCount = 50
        #expect(await environment.nextLaunchPopup() == nil)
        #expect(environment.takeReviewTurn() == false)
    }

    @Test func theRatingTurnIsTakenOnce() throws {
        let environment = try launch()
        environment.settings.launchCount = 7
        #expect(environment.takeReviewTurn())
        #expect(environment.takeReviewTurn() == false)
        #expect(try launch().takeReviewTurn() == false)   // remembered after a relaunch
    }
}
