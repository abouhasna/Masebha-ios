import XCTest

/// First launch, the Azkar list, and adding / editing / resetting / deleting / reordering.
final class OnboardingAndListTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchInArabicCreatesArabicAdhkar() throws {
        let app = launchApp(LaunchOptions(language: nil))
        let arabic = app.element("language.arabic")
        XCTAssertTrue(arabic.waitForExistence(timeout: 10))
        arabic.tap()

        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        XCTAssertEqual(app.cardTotal("سبحان الله"), "0")
        XCTAssertTrue(app.text("لم يُفتح بعد").exists)
        XCTAssertTrue(app.tabButton("الأذكار").exists)
        for name in ["الحمد لله", "الله أكبر", "اللهم صل على محمد", "أستغفر الله", "لا إله إلا الله",
                     "سبحان الله وبحمده سبحان الله العظيم"] {
            XCTAssertTrue(app.hasCard(name), "Missing starter dhikr: \(name)")
        }

        // The choice is remembered: the picker never comes back.
        relaunch(app)
        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        XCTAssertFalse(app.element("language.arabic").exists)
    }

    @MainActor
    func testFirstLaunchInEnglishCreatesEnglishAdhkar() throws {
        let app = launchApp(LaunchOptions(language: nil))
        let english = app.element("language.english")
        XCTAssertTrue(english.waitForExistence(timeout: 10))
        english.tap()
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))
        XCTAssertTrue(app.card("Astaghfirullah").exists)
        XCTAssertTrue(app.tabButton("Azkar").exists)
    }

    @MainActor
    func testAddValidationEditResetAndDelete() throws {
        let app = launchApp()
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))

        // Empty form -> "Please fill in the fields"
        app.element("list.add").tap()
        let save = app.buttons["editor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertEqual(app.element("editor.problem").label, "Please fill in the fields")

        let name = app.textFields["editor.name"].exists ? app.textFields["editor.name"] : app.textViews["editor.name"]
        name.tap()
        name.typeText("Test dhikr")
        let loop = app.textFields["editor.loopSize"]
        loop.tap()
        loop.typeText("0")
        save.tap()
        XCTAssertEqual(app.element("editor.problem").label, "Beads count cannot be zero")

        loop.tap()
        loop.typeText(XCUIKeyboardKey.delete.rawValue + "10")
        let total = app.textFields["editor.total"]
        total.tap()
        total.typeText("5")
        save.tap()

        XCTAssertTrue(app.hasCard("Test dhikr"))
        XCTAssertEqual(app.cardTotal("Test dhikr"), "5")

        // Edit: the total is directly editable.
        app.cardMenu("Test dhikr", choose: "Edit")
        let editTotal = app.textFields["editor.total"]
        XCTAssertTrue(editTotal.waitForExistence(timeout: 5))
        editTotal.tap()
        editTotal.typeText(XCUIKeyboardKey.delete.rawValue + "1234")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.hasCard("Test dhikr"))
        XCTAssertEqual(app.cardTotal("Test dhikr"), "1,234")

        // Reset asks first.
        app.cardMenu("Test dhikr", choose: "Reset")
        app.alerts.firstMatch.buttons["Reset"].tap()
        XCTAssertEqual(app.cardTotal("Test dhikr"), "0")

        // Delete: Cancel keeps it, Delete removes it.
        app.cardMenu("Test dhikr", choose: "Delete")
        app.alerts.firstMatch.buttons["Cancel"].tap()
        XCTAssertTrue(app.hasCard("Test dhikr"))
        app.cardMenu("Test dhikr", choose: "Delete")
        app.alerts.firstMatch.buttons["Delete"].tap()
        XCTAssertFalse(app.card("Test dhikr").waitForExistence(timeout: 2))
        XCTAssertTrue(app.hasCard("Subhan Allah wa bihamdihi, Subhan Allah al-Azim"))   // the others are intact

        // Survives a relaunch.
        relaunch(app)
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))
        XCTAssertFalse(app.hasCard("Test dhikr"))
    }

    @MainActor
    private func cardNames(_ app: XCUIApplication) -> [String] {
        app.descendants(matching: .any).matching(identifier: "card.name").allElementsBoundByIndex.map { $0.label }
    }

    /// ⋮ → Reorder: our ≡ handles and a hint appear instead of the ⋮ menus, a tap no longer opens
    /// a card, press-and-drag moves a card, Done ends it, and the order survives a relaunch.
    @MainActor
    func testReorderModeShowsHandlesAndMovesCards() throws {
        let app = launchApp()
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))
        app.cardMenu("Subhan Allah", choose: "Reorder")
        let done = app.buttons["list.doneReordering"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("list.reorderHint").exists)
        XCTAssertFalse(app.element("list.add").exists)   // "+" hidden while reordering
        let handles = app.descendants(matching: .any).matching(identifier: "card.handle")
        XCTAssertGreaterThanOrEqual(handles.count, 3, "No reorder handles")
        XCTAssertFalse(app.buttons["card.menu"].exists, "⋮ menus should be replaced by handles")

        // A tap does not open the counter while reordering.
        app.card("Alhamdulillah").staticTexts.matching(identifier: "card.name").firstMatch.tap()
        XCTAssertFalse(app.element("counter.current").waitForExistence(timeout: 2))

        app.card("Subhan Allah").press(forDuration: 1.0, thenDragTo: app.card("Allahu Akbar"),
                                       withVelocity: .slow, thenHoldForDuration: 0.6)
        done.tap()
        XCTAssertTrue(app.element("list.add").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("list.reorderHint").exists)
        XCTAssertTrue(app.buttons["card.menu"].firstMatch.exists)
        XCTAssertNotEqual(cardNames(app).first, "Subhan Allah", "Order did not change: \(cardNames(app))")
        let order = cardNames(app)

        relaunch(app)
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))
        XCTAssertEqual(cardNames(app), order)
    }

    /// Press-and-drag works directly too, without the reorder mode (like Android).
    @MainActor
    func testLongPressAndDragReordersAndPersists() throws {
        let app = launchApp()
        let first = app.card("Subhan Allah")
        let third = app.card("Allahu Akbar")
        XCTAssertTrue(first.waitForExistence(timeout: 10))

        first.press(forDuration: 1.0, thenDragTo: third, withVelocity: .slow, thenHoldForDuration: 0.6)
        XCTAssertFalse(app.buttons["list.doneReordering"].exists)   // no mode needed
        XCTAssertNotEqual(cardNames(app).first, "Subhan Allah", "Order did not change: \(cardNames(app))")
        let order = cardNames(app)

        relaunch(app)
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))
        XCTAssertEqual(cardNames(app), order)
    }
}
