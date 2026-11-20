import XCTest

/// The owner's walkthrough, filmed: CI records the Simulator screen while this test runs
/// (scripts/ci/record-walkthrough.sh) and uploads it as "walkthrough.mp4".
///
/// It runs like a person would: in Arabic, with animations, the welcome popup and the first-time
/// hint, and with pauses so each step can be followed. Every step is still checked, so a wrong
/// number stops the video right there. The normal test run skips it (run-tests.sh).
final class WalkthroughVideoTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWalkthrough() throws {
        let app = launchApp(LaunchOptions(language: nil, skipCoachMark: false, popups: true, animations: true))

        // 1. First launch: choose Arabic; the welcome popup.
        let arabic = app.element("language.arabic")
        XCTAssertTrue(arabic.waitForExistence(timeout: 20))
        pause(2)
        arabic.tap()
        let welcome = app.element("popup.button")
        XCTAssertTrue(welcome.waitForExistence(timeout: 10), "No welcome popup")
        pause(4)
        welcome.tap()
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        pause(2)

        // 2. Open سبحان الله (33 per loop); the first-time hint; turn on today's count.
        app.openCard("سبحان الله")
        let coach = app.element("counter.coachMark")
        if coach.waitForExistence(timeout: 5) {
            pause(3)
            coach.tap()
            XCTAssertTrue(waitUntilGone(coach), "The hint did not close")
        }
        pause(1)
        app.element("counter.more").tap()
        app.tapItem("عدد اليوم")
        XCTAssertTrue(app.element("counter.today").waitForExistence(timeout: 5))
        pause(1.5)

        // 3. Tap, tap, tap: +1 each time.
        for expected in 1...3 {
            app.count(1)
            XCTAssertEqual(app.value("counter.current"), String(expected))
            pause(0.8)
        }
        // Up to one full loop (33) and 3 more.
        app.count(30)
        pause(1)
        app.count(3)
        checkCounter(app, current: 3, loops: 1, total: 36, today: 36)
        pause(2)

        // 4. Undo 4 times: back to 32, and the loop goes back to 0.
        for _ in 0..<4 {
            app.element("counter.undo").tap()
            pause(0.9)
        }
        checkCounter(app, current: 32, loops: 0, total: 32, today: 32)
        pause(2)

        // 5. The timer (1 second) for 5 seconds, then stop.
        let timer = app.buttons["counter.timer"]
        timer.tap()
        XCTAssertTrue(waitFor(timer, value: "running"))
        pause(5)
        timer.tap()
        XCTAssertTrue(waitFor(timer, value: "stopped"))
        let subhanTotal = number(app.value("counter.total"))
        XCTAssertTrue((32 + 3...32 + 8).contains(subhanTotal), "Expected about 37 after 5 s at 1 s, got \(subhanTotal)")
        pause(2)
        XCTAssertEqual(number(app.value("counter.total")), subhanTotal, "Counted after stop")

        // 6. Next: الحمد لله. Edit timer → Auto (4 taps measure the pace) → then 0.2 s by hand.
        app.element("counter.next").tap()
        XCTAssertTrue(app.text("الحمد لله").waitForExistence(timeout: 5))
        XCTAssertEqual(app.value("counter.total"), "0")
        pause(1.5)
        app.element("counter.more").tap()
        app.tapItem("تعديل المؤقت")
        let value = app.element("timer.value")
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        pause(1.5)
        app.buttons["تلقائي"].firstMatch.tap()
        let tapHere = app.element("timer.tapHere")
        XCTAssertTrue(tapHere.waitForExistence(timeout: 5))
        pause(1.5)
        for _ in 0..<4 {
            tapHere.tap()
            pause(0.2)
        }
        XCTAssertTrue(app.element("timer.autoResult").waitForExistence(timeout: 5), "Auto pace was not calculated")
        pause(3)
        app.buttons["يدوي"].firstMatch.tap()
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        pause(1)
        for _ in 0..<60 {
            let seconds = Double(value.label) ?? 0
            if abs(seconds - 0.2) < 0.01 { break }
            app.element(seconds - 0.2 >= 1 ? "timer.minusSecond" : seconds > 0.2 ? "timer.minusTenth" : "timer.plusTenth").tap()
        }
        XCTAssertEqual(value.label, "0.2")
        pause(2)
        app.element("timer.start").tap()
        XCTAssertTrue(waitFor(timer, value: "running"))
        pause(5)

        // 7. Next without stopping: the timer stops, nothing is counted on the next dhikr.
        app.element("counter.next").tap()
        XCTAssertTrue(app.text("الله أكبر").waitForExistence(timeout: 5))
        XCTAssertTrue(waitFor(timer, value: "stopped"))
        pause(2)
        XCTAssertEqual(app.value("counter.total"), "0", "The timer kept counting on the next dhikr")

        // 8. Previous: الحمد لله kept what the timer counted (about 25 at 0.2 s), and nothing more.
        app.element("counter.previous").tap()
        XCTAssertTrue(app.text("الحمد لله").waitForExistence(timeout: 5))
        let hamdTotal = number(app.value("counter.total"))
        XCTAssertTrue((12...80).contains(hamdTotal), "Expected about 25 counts at 0.2 s, got \(hamdTotal)")
        pause(2)
        XCTAssertEqual(number(app.value("counter.total")), hamdTotal, "Counted after leaving the dhikr")

        // 9. Home, then More: the total of everything.
        app.goBack()
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 5))
        pause(2)
        app.tab("المزيد")
        let total = app.element("more.total")
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(number(total.label), subhanTotal + hamdTotal)
        pause(3)

        // 10. Delete three adhkar (الحمد لله had counts); the total drops by its count.
        app.tab("الأذكار")
        for name in ["الحمد لله", "الله أكبر", "اللهم صل على محمد"] {
            app.cardMenu(name, choose: "حذف")
            let confirm = app.alerts.firstMatch.buttons["حذف"]
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            pause(1.5)
            confirm.tap()
            XCTAssertTrue(waitUntilGone(app.card(name)), "\(name) was not deleted")
            pause(1)
        }
        app.tab("المزيد")
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(number(total.label), subhanTotal)
        pause(3)

        // 11. Press and hold a dhikr, then drag it to a new place.
        app.tab("الأذكار")
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 5))
        pause(1.5)
        let before = app.cardNames()
        app.drag("سبحان الله", onto: "لا إله إلا الله")
        XCTAssertNotEqual(app.cardNames(), before, "The order did not change")
        pause(2.5)

        // 12. Add a dhikr: without a name, then without beads per loop (both refused),
        //     then without a previous count (optional: added with 0).
        let name = "Subhan Rabbi al-Azim"   // typed on the Simulator's English keyboard
        openNewDhikr(app)
        typeInto(app.textFields["editor.loopSize"], "33")
        typeInto(app.textFields["editor.total"], "10")
        saveExpectingProblem(app, "الرجاء ملء الخانات")
        app.element("editor.cancel").tap()
        pause(1)

        openNewDhikr(app)
        typeInto(app.field("editor.name"), name)
        typeInto(app.textFields["editor.total"], "10")
        saveExpectingProblem(app, "الرجاء ملء الخانات")
        app.element("editor.cancel").tap()
        pause(1)

        openNewDhikr(app)
        typeInto(app.field("editor.name"), name)
        typeInto(app.textFields["editor.loopSize"], "33")
        pause(1)
        app.element("editor.save").tap()
        XCTAssertTrue(app.hasCard(name), "The new dhikr was not added")
        XCTAssertEqual(app.cardTotal(name), "0")
        pause(4)
    }

    // MARK: Helpers

    /// A pause, so a person can follow the video.
    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// "1,234" -> 1234 (0 if it is not a number, which then fails the check).
    private func number(_ text: String) -> Int {
        Int(text.replacingOccurrences(of: ",", with: "")) ?? -1
    }

    @MainActor
    private func checkCounter(_ app: XCUIApplication, current: Int, loops: Int, total: Int, today: Int,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.value("counter.current"), String(current), "current", file: file, line: line)
        XCTAssertEqual(app.value("counter.loops"), String(loops), "loops", file: file, line: line)
        XCTAssertEqual(app.value("counter.total"), String(total), "total", file: file, line: line)
        XCTAssertEqual(app.value("counter.today"), String(today), "today", file: file, line: line)
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while element.exists && Date() < deadline { pause(0.2) }
        return !element.exists
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, value: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while (element.value as? String) != value && Date() < deadline { pause(0.2) }
        return (element.value as? String) == value
    }

    @MainActor
    private func openNewDhikr(_ app: XCUIApplication) {
        app.element("list.add").tap()
        XCTAssertTrue(app.element("editor.save").waitForExistence(timeout: 5))
        pause(1)
    }

    @MainActor
    private func typeInto(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        pause(0.6)
    }

    @MainActor
    private func saveExpectingProblem(_ app: XCUIApplication, _ message: String) {
        pause(1)
        app.element("editor.save").tap()
        let problem = app.element("editor.problem")
        XCTAssertTrue(problem.waitForExistence(timeout: 5))
        XCTAssertEqual(problem.label, message)
        pause(2.5)
    }
}
