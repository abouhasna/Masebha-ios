import XCTest

/// Settings, language switching, themes, fonts, reminder, and the remaining screens.
final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSwitchingLanguageFlipsTheWholeApp() throws {
        let app = launchApp()
        app.openSettings()
        screenshot(app, "20-settings-english")
        let language = app.element("settings.language")
        app.swipeUpUntil(language)
        language.tap()
        app.text("العربية").tap()
        XCTAssertTrue(app.tabBars.buttons["المزيد"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text("الإعدادات").exists || app.text("اللغة").exists)
        screenshot(app, "21-settings-arabic")
        app.tab("الأذكار")
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 5))   // the user's texts stay as they are
        screenshot(app, "22-list-after-switch-to-arabic")

        relaunch(app)
        XCTAssertTrue(app.tabBars.buttons["الأذكار"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testFreeThemeAndLockedSupporterTheme() throws {
        let app = launchApp()
        app.openSettings()
        app.element("settings.theme").tap()
        XCTAssertTrue(app.element("theme.theme3").waitForExistence(timeout: 5))
        screenshot(app, "23-theme-picker")

        app.element("theme.theme6").tap()   // supporter theme, locked
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.firstMatch.staticTexts["Supporter theme"].exists)
        app.alerts.firstMatch.buttons["OK"].tap()

        app.element("theme.theme3").tap()   // green, free
        app.tab("Azkar")
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 5))
        screenshot(app, "24-list-green-theme")
        app.openCard("Subhan Allah")
        app.count(12)
        screenshot(app, "25-counter-green-theme")
    }

    @MainActor
    func testSupporterThemeAndFontWithDebugUnlock() throws {
        let app = launchApp(LaunchOptions(supporter: true))
        app.openSettings()
        app.element("settings.theme").tap()
        XCTAssertTrue(app.element("theme.theme6").waitForExistence(timeout: 5))
        screenshot(app, "26-theme-picker-supporter")
        app.element("theme.theme6").tap()
        app.element("settings.font").tap()
        XCTAssertTrue(app.element("font.cairo").waitForExistence(timeout: 5))
        screenshot(app, "27-font-picker")
        app.element("font.cairo").tap()
        app.tab("Azkar")
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 5))
        screenshot(app, "28-list-deep-ocean-cairo")
        app.openCard("Subhan Allah")
        app.count(20)
        screenshot(app, "29-counter-deep-ocean-cairo")
    }

    @MainActor
    func testLockedFontWithoutSupport() throws {
        let app = launchApp()
        app.openSettings()
        app.element("settings.font").tap()
        app.element("font.cairo").tap()
        XCTAssertTrue(app.alerts.firstMatch.staticTexts["Supporter font"].waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons["OK"].tap()
        app.element("font.tajawal").tap()   // free
        XCTAssertTrue(app.element("settings.font").waitForExistence(timeout: 5))
        XCTAssertTrue(app.text("Tajawal").exists)
    }

    @MainActor
    func testHijriOffsetChangesTheDate() throws {
        let app = launchApp()
        let date = app.element("list.hijriDate")
        XCTAssertTrue(date.waitForExistence(timeout: 10))
        let before = date.label
        app.openSettings()
        let offset = app.element("settings.hijriOffset")
        app.swipeUpUntil(offset)
        offset.tap()
        app.text("Plus 1 day").tap()
        app.tab("Azkar")
        XCTAssertNotEqual(app.element("list.hijriDate").label, before)
    }

    @MainActor
    func testFontSizeChangesTheCounterText() throws {
        let app = launchApp()
        app.openSettings()
        app.element("settings.fontSize").tap()
        app.text("Huge").tap()
        app.tab("Azkar")
        app.openCard("Subhan Allah wa bihamdihi, Subhan Allah al-Azim")
        screenshot(app, "30-counter-huge-font-long-text")
    }

    @MainActor
    func testDailyReminderIsReallyScheduled() throws {
        let app = launchApp()
        app.openSettings()
        app.element("settings.reminder").tap()
        app.setSwitch("reminder.enabled", on: true)
        app.element("reminder.save").tap()
        app.allowSystemAlertIfShown()
        let status = app.element("reminder.status")
        let predicate = NSPredicate(format: "label == %@", "Daily at 08:00")
        expectation(for: predicate, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        screenshot(app, "31-reminder-scheduled")

        app.setSwitch("reminder.enabled", on: false)
        app.element("reminder.save").tap()
        XCTAssertTrue(app.text("Off").waitForExistence(timeout: 5))
    }

    @MainActor
    func testMoreTabTotalAndResetAll() throws {
        let app = launchApp()
        app.openCard("Subhan Allah")
        app.count(4)
        app.goBack()
        app.openCard("Alhamdulillah")
        app.count(6)
        app.goBack()
        app.tab("More")
        XCTAssertEqual(app.value("more.total"), "10")
        screenshot(app, "32-more-tab")
        app.element("more.resetAll").tap()
        app.alerts.firstMatch.buttons["Reset"].tap()
        XCTAssertEqual(app.value("more.total"), "0")
        app.tab("Azkar")
        XCTAssertEqual(app.cardTotal("Alhamdulillah"), "0")
    }

    @MainActor
    func testRemainingScreensForVisualReview() throws {
        let app = launchApp(LaunchOptions(language: "ar"))
        app.tab("الأوراد")
        screenshot(app, "33-wird-placeholder-arabic")
        app.tab("المزيد")
        screenshot(app, "34-more-arabic")
        app.element("more.settings").tap()
        app.element("settings.colors").tap()
        XCTAssertTrue(app.element("colors.save").waitForExistence(timeout: 5))
        screenshot(app, "35-colors-main-arabic")
        app.element("colors.save").tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons.firstMatch.tap()
        app.tab("الأذكار")
        app.openCard("سبحان الله")
        app.count(7)
        screenshot(app, "36-counter-arabic")
    }
}
