import XCTest

/// The counter screen: counting, undo, resets, persistence, navigation, overlays, auto-timer.
final class CounterTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCountingLoopsUndoAndPersistence() throws {
        let app = launchApp()
        app.openCard("Subhan Allah")   // loop of 33
        XCTAssertEqual(app.value("counter.current"), "0")

        app.count(35)
        XCTAssertEqual(app.value("counter.current"), "2")
        XCTAssertEqual(app.value("counter.loops"), "1")
        XCTAssertEqual(app.value("counter.total"), "35")

        // Undo steps back; past 0 it rolls back the completed loop.
        app.element("counter.undo").tap()
        XCTAssertEqual(app.value("counter.current"), "1")
        XCTAssertEqual(app.value("counter.total"), "34")
        app.element("counter.undo").tap()
        app.element("counter.undo").tap()
        XCTAssertEqual(app.value("counter.current"), "32")
        XCTAssertEqual(app.value("counter.loops"), "0")
        XCTAssertEqual(app.value("counter.total"), "32")

        // The list shows the saved total and "Just now".
        app.goBack()
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 5))
        XCTAssertEqual(app.cardTotal("Subhan Allah"), "32")
        XCTAssertEqual(app.card("Subhan Allah").staticTexts.matching(identifier: "card.lastOpened").firstMatch.label,
                       "Just now")

        // Killing the app loses nothing.
        relaunch(app)
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))
        XCTAssertEqual(app.cardTotal("Subhan Allah"), "32")
        app.openCard("Subhan Allah")
        XCTAssertEqual(app.value("counter.total"), "32")
        XCTAssertEqual(app.value("counter.current"), "0")   // "Resume loop" is off by default
    }

    @MainActor
    func testResetSessionAndResetAll() throws {
        let app = launchApp()
        app.openCard("Alhamdulillah")
        app.count(5)
        openResetDialog(app)
        app.buttons["Reset"].firstMatch.tap()
        XCTAssertEqual(app.value("counter.total"), "0")

        app.count(3)
        app.goBack()
        app.openCard("Alhamdulillah")
        app.count(2)   // total 5, session 2
        openResetDialog(app)
        app.buttons["Reset"].firstMatch.tap()
        XCTAssertEqual(app.value("counter.total"), "3")   // only this visit was removed

        openResetDialog(app)
        app.buttons["Reset all"].firstMatch.tap()
        XCTAssertEqual(app.value("counter.total"), "0")
    }

    /// ⋮ → Reset, then waits for the dialog (its "Reset all" button) to be on screen.
    @MainActor
    private func openResetDialog(_ app: XCUIApplication) {
        app.element("counter.more").tap()
        let menuItem = app.buttons["Reset"].firstMatch
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
        menuItem.tap()
        XCTAssertTrue(app.buttons["Reset all"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testResumeLoopAndTodayCount() throws {
        let app = launchApp()
        app.openSettings()
        app.setSwitch("settings.resumeLoop", on: true)
        app.tab("Azkar")
        app.openCard("Allahu Akbar")
        app.count(40)                // 1 loop + 7
        app.goBack()
        app.openCard("Allahu Akbar")
        XCTAssertEqual(app.value("counter.current"), "7")   // continues the unfinished loop

        // Today / session row from the ⋮ menu.
        app.element("counter.more").tap()
        app.buttons["Today count"].firstMatch.tap()
        XCTAssertTrue(app.element("counter.today").waitForExistence(timeout: 5))
        XCTAssertEqual(app.value("counter.today"), "40")
        XCTAssertEqual(app.value("counter.session"), "7")

        // "Today count" is an on/off setting: it stays on for every dhikr and after a relaunch.
        app.goBack()
        app.openCard("Subhan Allah")
        XCTAssertTrue(app.element("counter.today").waitForExistence(timeout: 5))
        relaunch(app)
        XCTAssertTrue(app.card("Allahu Akbar").waitForExistence(timeout: 10))
        app.openCard("Allahu Akbar")
        XCTAssertTrue(app.element("counter.today").waitForExistence(timeout: 5))
        XCTAssertEqual(app.value("counter.today"), "40")
        app.element("counter.more").tap()
        app.buttons["Today count"].firstMatch.tap()
        XCTAssertFalse(app.element("counter.today").waitForExistence(timeout: 2))
    }

    /// Taps count everywhere, on the dhikr text too; a swipe (scrolling the text or the page)
    /// never counts. Checked with "Scroll long dhikr" on and off.
    @MainActor
    func testTapsOnTheTextCountAndSwipesDoNot() throws {
        let app = launchApp(LaunchOptions(demoData: true))
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))

        // On (default): the long text sits in a small window that scrolls by itself.
        app.openCard(ayatAlKursi)
        XCTAssertEqual(app.value("counter.total"), "7")
        let window = app.element("counter.textWindow")
        for _ in 0..<3 { window.tap() }
        XCTAssertEqual(app.value("counter.total"), "10")
        window.swipeUp()
        XCTAssertEqual(app.value("counter.total"), "10")
        window.tap()
        XCTAssertEqual(app.value("counter.total"), "11")
        app.goBack()

        // Off: the text is shown in full and the whole page scrolls instead.
        app.openSettings()
        app.setSwitch("settings.scrollableText", on: false)
        app.tab("Azkar")
        app.openCard(ayatAlKursi)
        let text = app.element("counter.dhikrText")
        for _ in 0..<2 { text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap() }
        XCTAssertEqual(app.value("counter.total"), "13")
        app.element("counter.tapArea").swipeUp()   // scrolls the page
        XCTAssertEqual(app.value("counter.total"), "13")
        app.count(1)
        XCTAssertEqual(app.value("counter.total"), "14")
    }

    @MainActor
    func testPreviousNextAndHiddenButtons() throws {
        let app = launchApp()
        app.openCard("Subhan Allah")   // first in the list: no "Previous"
        XCTAssertFalse(app.element("counter.previous").exists)
        // The bar sits at the bottom of the screen (a missing button must not change the layout).
        let next = app.element("counter.next")
        XCTAssertGreaterThan(next.frame.maxY, app.frame.height - 140, "Previous/next bar is not at the bottom")
        next.tap()
        XCTAssertTrue(app.text("Alhamdulillah").waitForExistence(timeout: 5))
        app.element("counter.previous").tap()
        XCTAssertTrue(app.text("Subhan Allah").waitForExistence(timeout: 5))
        app.goBack()

        app.openSettings()
        app.setSwitch("settings.hideNav", on: true)
        app.tab("Azkar")
        app.openCard("Subhan Allah")
        XCTAssertFalse(app.element("counter.next").exists)
    }

    @MainActor
    func testNextDhikrWhenALoopCompletes() throws {
        let app = launchApp()
        app.openSettings()
        app.setSwitch("settings.nextOnLoop", on: true)
        app.tab("Azkar")
        app.openCard("Subhan Allah")
        app.count(33)
        XCTAssertTrue(app.text("Alhamdulillah").waitForExistence(timeout: 5))
        XCTAssertEqual(app.value("counter.current"), "0")
    }

    @MainActor
    func testCoachMarkAppearsOnlyOnceAndDoesNotCount() throws {
        let app = launchApp(LaunchOptions(skipCoachMark: false))
        app.openCard("Subhan Allah")
        let coach = app.element("counter.coachMark")
        XCTAssertTrue(coach.waitForExistence(timeout: 5))
        coach.tap()
        XCTAssertFalse(coach.waitForExistence(timeout: 1))
        XCTAssertEqual(app.value("counter.current"), "0")
        app.goBack()
        app.openCard("Subhan Allah")
        XCTAssertFalse(app.element("counter.coachMark").waitForExistence(timeout: 1))
    }

    @MainActor
    func testPowerModeKeepsCounting() throws {
        let app = launchApp()
        app.openCard("Subhan Allah")
        app.element("counter.power").tap()
        XCTAssertTrue(app.element("counter.powerClose").waitForExistence(timeout: 5))
        app.count(3)
        app.element("counter.powerClose").tap()
        XCTAssertEqual(app.value("counter.current"), "3")
        XCTAssertTrue(app.buttons["counter.timer"].exists)
    }

    @MainActor
    func testAutoTimerCountsStopsAndSaves() throws {
        let app = launchApp()
        app.openCard("Subhan Allah")
        app.element("counter.more").tap()
        app.buttons["Edit timer"].firstMatch.tap()
        XCTAssertTrue(app.element("timer.value").waitForExistence(timeout: 5))
        XCTAssertEqual(app.value("timer.value"), "1.0")
        for _ in 0..<5 { app.element("timer.minusTenth").tap() }
        XCTAssertEqual(app.value("timer.value"), "0.5")
        app.buttons["timer.start"].tap()

        let timer = app.buttons["counter.timer"]
        XCTAssertEqual(timer.value as? String, "running")
        sleep(3)
        // Manual taps are ignored while the timer counts.
        timer.tap()   // stop
        XCTAssertEqual(timer.value as? String, "stopped")
        let counted = Int(app.value("counter.total")) ?? 0
        XCTAssertTrue((3...8).contains(counted), "Expected ~6 counts at 0.5 s, got \(counted)")
        sleep(2)
        XCTAssertEqual(Int(app.value("counter.total")), counted, "Counted after stop")

        app.goBack()
        XCTAssertEqual(app.cardTotal("Subhan Allah"), String(counted))
    }

    @MainActor
    func testLeavingTheAppPausesTheTimer() throws {
        let app = launchApp()
        app.openCard("Subhan Allah")
        app.buttons["counter.timer"].tap()
        XCTAssertEqual(app.buttons["counter.timer"].value as? String, "running")
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(3)
        app.activate()
        let timer = app.buttons["counter.timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        XCTAssertEqual(timer.value as? String, "stopped")
        let total = app.value("counter.total")
        sleep(2)
        XCTAssertEqual(app.value("counter.total"), total)
        XCTAssertGreaterThan(Int(total) ?? 0, 0)
    }
}
