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
        screenshot(app, "01-language-picker")
        arabic.tap()

        XCTAssertTrue(app.card("سبحان الله").waitForExistence(timeout: 10))
        XCTAssertEqual(app.cardTotal("سبحان الله"), "0")
        XCTAssertTrue(app.text("لم يُفتح بعد").exists)
        XCTAssertTrue(app.tabBars.buttons["الأذكار"].exists)
        screenshot(app, "02-list-arabic")
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
        XCTAssertTrue(app.tabBars.buttons["Azkar"].exists)
        screenshot(app, "03-list-english")
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
        screenshot(app, "04-add-dhikr")
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
    func testLongPressDragReordersAndPersists() throws {
        let app = launchApp()
        let first = app.card("Subhan Allah")
        let third = app.card("Allahu Akbar")
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.press(forDuration: 1.2, thenDragTo: third)

        let names = {
            app.descendants(matching: .any).matching(identifier: "card.name").allElementsBoundByIndex.map { $0.label }
        }
        XCTAssertNotEqual(names().first, "Subhan Allah", "Order did not change: \(names())")
        let orderAfterDrag = names()
        screenshot(app, "05-after-reorder")

        relaunch(app)
        XCTAssertTrue(app.card("Subhan Allah").waitForExistence(timeout: 10))
        XCTAssertEqual(names(), orderAfterDrag)
    }
}
