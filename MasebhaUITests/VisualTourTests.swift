import XCTest

/// Walks through every screen and state and saves numbered screenshots for the owner's review.
/// Arabic first ("A…"), with a shorter English set ("E…").
final class VisualTourTests: XCTestCase {
    private let ayatAlKursi = "{اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ}"

    override func setUpWithError() throws {
        continueAfterFailure = false
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

        // "Scroll long dhikr" on (default): a 4-line window that scrolls, full-size ring.
        app.openCard(ayatAlKursi)
        screenshot(app, "A21-long-dhikr-scroll-mode")
        app.element("counter.textWindow").swipeUp()
        screenshot(app, "A22-long-dhikr-scroll-mode-text-scrolled")
        app.goBack()

        // Biggest font: the window gets smaller, the ring stays at least its minimum size.
        app.openSettings(moreLabel: "المزيد")
        app.element("settings.fontSize").tap()
        app.tapItem("كبير جداً")
        app.tab("الأذكار")
        app.openCard(ayatAlKursi)
        screenshot(app, "A23-long-dhikr-huge-font")
        app.goBack()
        app.openCard("سبحان الله وبحمده سبحان الله العظيم")
        screenshot(app, "A24-medium-dhikr-huge-font")
        app.goBack()

        // "Scroll long dhikr" off: the text is shown in full; the page scrolls down to the ring.
        app.tab("المزيد")
        app.element("settings.fontSize").tap()
        app.tapItem("متوسط")
        app.setSwitch("settings.scrollableText", on: false)
        app.tab("الأذكار")
        app.openCard(ayatAlKursi)
        screenshot(app, "A25-long-dhikr-no-scroll-top")
        app.element("counter.page").swipeUp()
        screenshot(app, "A26-long-dhikr-no-scroll-scrolled-down")
        app.count(3)
        XCTAssertEqual(app.value("counter.total"), "10")   // demo total 7 + 3 taps: taps still count
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
        screenshot(app, "A38-wird-placeholder")
        app.tab("الأذكار")
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 5))
        screenshot(app, "A39-list-green-theme")
        app.openCard("سبحان الله")
        app.count(5)
        screenshot(app, "A40-counter-green-theme")
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
