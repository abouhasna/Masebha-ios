import XCTest
import StoreKitTest

/// Walks through every screen and state and saves numbered screenshots for the owner's review.
/// Arabic first ("A…"), with a shorter English set ("E…").
final class VisualTourTests: XCTestCase {
    /// The local test store, so the Support screen shows prices (the tour never buys).
    private var session: SKTestSession?

    override func setUpWithError() throws {
        continueAfterFailure = false
        if let url = Bundle(for: VisualTourTests.self).url(forResource: "Supporter", withExtension: "storekit") {
            session = try? SKTestSession(contentsOf: url)
            session?.resetToDefaultState()
            session?.disableDialogs = true
            session?.clearTransactions()
        }
    }

    // MARK: Arabic

    @MainActor
    func testA1ArabicFirstLaunch() throws {
        let app = launchApp(LaunchOptions(language: nil))
        XCTAssertTrue(app.element("language.arabic").waitForExistence(timeout: 10))
        screenshot(app, "A01-language-picker")
        app.element("language.arabic").tap()
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        screenshot(app, "A02-first-launch-list")
    }

    @MainActor
    func testA2ArabicListAndEditing() throws {
        let app = launchApp(LaunchOptions(language: "ar", demoData: true))
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        screenshot(app, "A03-list-with-last-opened-labels")

        app.card("سبحان الله").buttons.matching(identifier: "card.menu").firstMatch.tap()
        XCTAssertTrue(app.buttons["ترتيب"].waitForExistence(timeout: 5))
        screenshot(app, "A04-card-menu")
        app.tapItem("ترتيب")
        XCTAssertTrue(app.buttons["list.doneReordering"].waitForExistence(timeout: 5))
        screenshot(app, "A05-reorder-mode")
        app.buttons["list.doneReordering"].tap()

        app.element("list.add").tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
        screenshot(app, "A06-add-sheet")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.element("editor.problem").waitForExistence(timeout: 5))
        screenshot(app, "A07-add-sheet-error")
        app.buttons["editor.cancel"].tap()

        app.cardMenu("الحمد لله", choose: "تعديل")
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
        screenshot(app, "A08-edit-sheet")
        app.buttons["editor.cancel"].tap()

        app.cardMenu("الحمد لله", choose: "حذف")
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        screenshot(app, "A09-delete-confirmation")
        app.alerts.firstMatch.buttons["الغاء"].tap()

        app.scrollToCard(ayatAlKursi)
        screenshot(app, "A10-list-bottom-long-dhikr")
    }

    @MainActor
    func testA3ArabicCounter() throws {
        let app = launchApp(LaunchOptions(language: "ar", skipCoachMark: false, demoData: true))
        XCTAssertTrue(app.card("الله أكبر").waitForExistence(timeout: 10))
        app.openCard("الله أكبر")
        XCTAssertTrue(app.element("counter.coachMark").waitForExistence(timeout: 5))
        screenshot(app, "A11-coach-mark")
        app.element("counter.coachMark").tap()

        app.count(12)
        screenshot(app, "A12-counter")

        app.buttons["counter.more"].tap()
        XCTAssertTrue(app.buttons["عدد اليوم"].waitForExistence(timeout: 5))
        screenshot(app, "A13-counter-menu")
        app.tapItem("عدد اليوم")
        XCTAssertTrue(app.element("counter.today").waitForExistence(timeout: 5))
        screenshot(app, "A14-today-and-session")

        app.buttons["counter.more"].tap()
        app.tapItem("تصفير")
        XCTAssertTrue(app.buttons["تصفير الكل"].waitForExistence(timeout: 5))
        screenshot(app, "A15-reset-dialog")
        app.dismissPopover(cancelLabel: "الغاء")

        app.buttons["counter.more"].tap()
        app.tapItem("تعديل المؤقت")
        XCTAssertTrue(app.element("timer.value").waitForExistence(timeout: 5))
        screenshot(app, "A16-timer-manual")
        app.buttons["تلقائي"].firstMatch.tap()
        XCTAssertTrue(app.element("timer.tapHere").waitForExistence(timeout: 5))
        screenshot(app, "A17-timer-auto")
        for _ in 0..<4 { app.element("timer.tapHere").tap() }
        XCTAssertTrue(app.element("timer.autoResult").waitForExistence(timeout: 5))
        screenshot(app, "A18-timer-auto-result")
        app.buttons["timer.start"].tap()
        sleep(2)
        screenshot(app, "A19-timer-running")
        app.buttons["counter.timer"].tap()

        app.buttons["counter.power"].tap()
        XCTAssertTrue(app.element("counter.powerClose").waitForExistence(timeout: 5))
        screenshot(app, "A20-power-mode")
        app.element("counter.powerClose").tap()
    }

    @MainActor
    func testA4ArabicLongDhikr() throws {
        let app = launchApp(LaunchOptions(language: "ar", demoData: true))
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        let medium = "سبحان الله وبحمده سبحان الله العظيم"

        // The text has priority. Step 2: a long text keeps the user's size; the ring is smaller.
        app.openCard(mediumLongDhikr)
        screenshot(app, "A21-long-text-full-size-smaller-ring")
        app.goBack()

        // Step 3: a very long text switches to the small size and gets all the room the
        // minimum ring leaves; it scrolls inside its window.
        app.openCard(ayatAlKursi)
        screenshot(app, "A22-very-long-text-small-size")
        app.element("counter.textWindow").swipeUp()
        screenshot(app, "A23-very-long-text-scrolled")
        app.goBack()

        // Hardest case: biggest font + the extra "today" row.
        app.openSettings(moreLabel: "المزيد")
        app.element("settings.fontSize").tap()
        app.tapItem("كبير جداً")
        app.tab("الأذكار")
        app.openCard(medium)
        app.buttons["counter.more"].tap()
        app.tapItem("عدد اليوم")
        XCTAssertTrue(app.element("counter.today").waitForExistence(timeout: 5))
        screenshot(app, "A24-huge-font-today-row")
        app.goBack()
        app.openCard(mediumLongDhikr)
        screenshot(app, "A25-huge-font-long-text")
        app.goBack()
        app.openCard(ayatAlKursi)
        screenshot(app, "A26-huge-font-very-long-text")
        app.count(3)
        XCTAssertEqual(app.value("counter.total"), "10")
    }

    @MainActor
    func testA5ArabicSettingsScreens() throws {
        let app = launchApp(LaunchOptions(language: "ar", demoData: true))
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        app.tab("المزيد")
        XCTAssertTrue(app.element("more.settings").waitForExistence(timeout: 5))
        screenshot(app, "A27-more-tab")
        app.element("more.settings").tap()
        screenshot(app, "A28-settings-top")
        app.swipeUp()
        screenshot(app, "A29-settings-middle")
        app.swipeUp()
        app.swipeUp()
        screenshot(app, "A30-settings-bottom")

        app.element("settings.tapVibration").tap()
        screenshot(app, "A31-vibration-durations")
        app.goBack()
        app.swipeDown()
        app.swipeDown()
        app.swipeDown()

        app.element("settings.theme").tap()
        XCTAssertTrue(app.element("theme.theme3").waitForExistence(timeout: 5))
        screenshot(app, "A32-themes")
        app.element("theme.theme6").tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        screenshot(app, "A33-locked-theme")
        app.alerts.firstMatch.buttons.firstMatch.tap()
        app.element("theme.theme3").tap()

        app.element("settings.font").tap()
        XCTAssertTrue(app.element("font.cairo").waitForExistence(timeout: 5))
        screenshot(app, "A34-fonts")
        app.goBack()

        app.element("settings.colors").tap()
        XCTAssertTrue(app.element("colors.save").waitForExistence(timeout: 5))
        screenshot(app, "A35-colors-main")
        app.buttons["التسبيح"].firstMatch.tap()
        screenshot(app, "A36-colors-counter")
        app.goBack()

        app.element("settings.reminder").tap()
        XCTAssertTrue(app.element("reminder.save").waitForExistence(timeout: 5))
        screenshot(app, "A37-reminder")
        app.goBack()

        app.tab("الأوراد")
        screenshot(app, "A38-wird-locked")
        app.tab("الأذكار")
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 5))
        screenshot(app, "A39-list-green-theme")
        app.openCard("سبحان الله")
        app.count(5)
        screenshot(app, "A40-counter-green-theme")
        app.goBack()

        // Reorder mode on a light theme: the ≡ handles use the card's text color.
        app.cardMenu("الحمد لله", choose: "ترتيب")
        XCTAssertTrue(app.buttons["list.doneReordering"].waitForExistence(timeout: 5))
        screenshot(app, "A45-reorder-mode-green-theme")
        app.buttons["list.doneReordering"].tap()

        // White theme.
        app.tab("المزيد")   // still on Settings
        let themeRow = app.element("settings.theme")
        if !themeRow.waitForExistence(timeout: 3) || !themeRow.isHittable {
            app.swipeDown()
            app.swipeDown()
        }
        themeRow.tap()
        app.element("theme.theme2").tap()
        app.tab("الأذكار")
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 5))
        screenshot(app, "A46-list-white-theme")
    }

    @MainActor
    func testA6ArabicSupporterThemes() throws {
        let app = launchApp(LaunchOptions(language: "ar", supporter: true, demoData: true))
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        for (theme, font, name) in [("theme8", "reemkufi", "A41"), ("theme9", "cairo", "A43")] {
            app.openSettings(moreLabel: "المزيد")
            app.element("settings.theme").tap()
            app.element("theme.\(theme)").tap()
            app.element("settings.font").tap()
            app.element("font.\(font)").tap()
            app.tab("الأذكار")
            XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 5))
            screenshot(app, "\(name)-list-\(theme)-\(font)")
            app.openCard("سبحان الله")
            app.count(9)
            let counterName = name == "A41" ? "A42" : "A44"
            screenshot(app, "\(counterName)-counter-\(theme)-\(font)")
            app.goBack()
            app.tab("المزيد")
            app.goBack()
        }
        app.tab("الأذكار")
        app.cardMenu("الحمد لله", choose: "ترتيب")
        XCTAssertTrue(app.buttons["list.doneReordering"].waitForExistence(timeout: 5))
        screenshot(app, "A47-reorder-mode-theme9")
    }

    @MainActor
    func testA7ArabicWirdForSupporters() throws {
        let app = launchApp(LaunchOptions(language: "ar", supporter: true, demoData: true))
        app.tab("الأوراد")
        XCTAssertTrue(app.wirdCard("أذكار الصباح").waitForExistence(timeout: 10))
        screenshot(app, "A48-wird-list-defaults")

        app.openWird("أذكار الصباح")
        screenshot(app, "A49-wird-session-first-zikr")
        app.element("counter.current").tap()   // target 1: moves on to the next zikr
        screenshot(app, "A50-wird-session-next-zikr")
        app.count(2)
        screenshot(app, "A51-wird-session-counting")
        app.buttons["counter.more"].tap()
        XCTAssertTrue(app.buttons["إعادة الورد من البداية"].waitForExistence(timeout: 5))
        screenshot(app, "A52-wird-session-menu")
        app.tapItem("إعادة الورد من البداية")
        screenshot(app, "A53-wird-reset-dialog")
        app.dismissPopover(cancelLabel: "الغاء")
        app.goBack()
        screenshot(app, "A54-wird-list-in-progress")

        app.wirdMenu("أذكار الصباح", choose: "تعديل")
        XCTAssertTrue(app.buttons["wird.editor.save"].waitForExistence(timeout: 5))
        screenshot(app, "A55-wird-editor")
        app.buttons["wird.editor.cancel"].tap()

        app.element("wird.add").tap()
        XCTAssertTrue(app.buttons["wird.editor.save"].waitForExistence(timeout: 5))
        app.buttons["wird.editor.save"].tap()
        screenshot(app, "A56-wird-new-with-error")
        app.buttons["wird.editor.cancel"].tap()

        app.wirdMenu("أذكاري", choose: "ترتيب")
        XCTAssertTrue(app.buttons["list.doneReordering"].waitForExistence(timeout: 5))
        screenshot(app, "A57-wird-reorder-mode")
        app.buttons["list.doneReordering"].tap()

        // A small wird to show the "completed" moment.
        app.element("wird.add").tap()
        app.field("wird.editor.name").tap()
        app.field("wird.editor.name").typeText("Short wird")
        app.field("wird.editor.zikr").tap()
        app.field("wird.editor.zikr").typeText("Subhan Allah")
        app.field("wird.editor.target").tap()
        app.field("wird.editor.target").typeText("1")
        app.buttons["wird.editor.save"].tap()
        app.openWird("Short wird")
        app.element("counter.current").tap()
        XCTAssertTrue(app.element("wird.completed").waitForExistence(timeout: 3))
        screenshot(app, "A58-wird-completed")
        XCTAssertTrue(app.element("wird.add").waitForExistence(timeout: 6))
        screenshot(app, "A59-wird-list-done")
    }

    @MainActor
    func testA8ArabicSupportAndBackup() throws {
        let app = launchApp(LaunchOptions(language: "ar", demoData: true))
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        app.openSupport(moreLabel: "المزيد")
        _ = app.buttons["support.buyOnce"].waitForExistence(timeout: 15)
        screenshot(app, "A60-support-screen")
        app.swipeUp()
        screenshot(app, "A61-support-screen-bottom")
        app.goBack()

        app.element("more.settings").tap()
        let export = app.element("settings.export")
        app.swipeUpUntil(export)
        screenshot(app, "A62-settings-backup")
        export.tap()
        sleep(2)
        screenshot(app, "A63-backup-share-sheet")
    }

    // MARK: English

    @MainActor
    func testEnglishTour() throws {
        let app = launchApp(LaunchOptions(language: "en", demoData: true))
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))
        screenshot(app, "E01-list")
        app.openCard("Subhan Allah")
        app.count(12)
        screenshot(app, "E02-counter")
        app.buttons["counter.more"].tap()
        XCTAssertTrue(app.buttons["Today count"].waitForExistence(timeout: 5))
        screenshot(app, "E03-counter-menu")
        app.tapItem("Today count")
        app.goBack()
        app.openCard(ayatAlKursi)
        screenshot(app, "E04-long-dhikr")
        app.goBack()
        app.openSettings()
        screenshot(app, "E05-settings")
        app.goBack()
        screenshot(app, "E06-more")
    }
}
