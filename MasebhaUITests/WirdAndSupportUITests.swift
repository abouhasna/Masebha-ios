import XCTest
import StoreKitTest

/// The Wird tab: locked for non-supporters, the full flow for supporters.
final class WirdUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNonSupportersSeeAPageThatLeadsToSupport() throws {
        let app = launchApp()
        app.tab("Wird")
        let become = app.element("wird.becomeSupporter")
        XCTAssertTrue(become.waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("wird.add").exists)
        become.tap()
        XCTAssertTrue(app.element("support.status").waitForExistence(timeout: 5))
    }

    @MainActor
    func testSupporterBuildsAndCompletesAWird() throws {
        let app = launchApp(LaunchOptions(supporter: true))
        app.tab("Wird")
        // The first visit adds the defaults: My Azkar, then the five from Hisn al-Muslim.
        XCTAssertTrue(app.wirdCard("My Azkar").waitForExistence(timeout: 10))
        XCTAssertTrue(app.wirdCard("أذكار الصباح").exists)

        // A new wird: the form checks everything first.
        app.element("wird.add").tap()
        let save = app.buttons["wird.editor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertEqual(app.element("wird.editor.problem").label, "Enter a name for the wird")
        let name = app.field("wird.editor.name")
        name.tap()
        name.typeText("Test wird")
        save.tap()
        XCTAssertEqual(app.element("wird.editor.problem").label, "Fill in the text and target of every zikr")
        app.field("wird.editor.zikr").tap()
        app.field("wird.editor.zikr").typeText("One")
        app.field("wird.editor.target").tap()
        app.field("wird.editor.target").typeText("2")
        app.buttons["wird.editor.addRow"].tap()
        app.field("wird.editor.zikr", at: 1).tap()
        app.field("wird.editor.zikr", at: 1).typeText("Two")
        app.field("wird.editor.target", at: 1).tap()
        app.field("wird.editor.target", at: 1).typeText("1")
        save.tap()
        XCTAssertTrue(app.scrollTo(app.wirdCard("Test wird")).exists)
        XCTAssertEqual(app.wirdStatus("Test wird"), "Not started")

        // Through the wird: a zikr that reaches its target moves on to the next one.
        app.openWird("Test wird")
        XCTAssertEqual(app.value("wird.session.position"), "1 / 2")
        XCTAssertEqual(app.value("counter.target"), "/ 2")
        app.element("counter.textWindow").tap()   // taps on the text count too
        XCTAssertEqual(app.value("counter.current"), "1")
        app.element("counter.current").tap()
        XCTAssertEqual(app.value("wird.session.position"), "2 / 2")
        XCTAssertEqual(app.value("counter.current"), "0")
        app.element("counter.current").tap()   // the last zikr: the wird is done
        XCTAssertTrue(app.element("wird.completed").waitForExistence(timeout: 3))
        // The screen closes by itself and the list shows the wird as done.
        XCTAssertTrue(app.element("wird.add").waitForExistence(timeout: 6))
        XCTAssertEqual(app.wirdStatus("Test wird"), "Done")
    }

    @MainActor
    func testSkipResetAndProgressSurviveLeavingTheScreen() throws {
        let app = launchApp(LaunchOptions(supporter: true))
        app.tab("Wird")
        XCTAssertTrue(app.wirdCard("My Azkar").waitForExistence(timeout: 10))
        app.openWird("My Azkar")   // the 7 starter adhkar, 33 / 100 each
        XCTAssertEqual(app.value("wird.session.position"), "1 / 7")
        app.count(3)
        app.buttons["wird.skip"].tap()
        XCTAssertEqual(app.value("wird.session.position"), "2 / 7")
        app.goBack()
        XCTAssertEqual(app.wirdStatus("My Azkar"), "In progress")

        // Same day: the progress is kept.
        app.openWird("My Azkar")
        XCTAssertEqual(app.value("wird.session.position"), "2 / 7")   // opens on the first pending zikr
        app.element("counter.previous").tap()
        XCTAssertEqual(app.value("counter.current"), "3")   // the skipped zikr kept its count

        // Reset from the menu: back to the start.
        app.buttons["counter.more"].tap()
        app.tapItem("Restart the wird")
        app.tapItem("Reset")
        XCTAssertEqual(app.value("wird.session.position"), "1 / 7")
        XCTAssertEqual(app.value("counter.current"), "0")
        app.goBack()
        XCTAssertEqual(app.wirdStatus("My Azkar"), "Not started")
    }
}

/// Buying in the Simulator through Apple's local test store (StoreKit/Supporter.storekit).
final class SupportUITests: XCTestCase {
    private var session: SKTestSession?

    override func setUpWithError() throws {
        continueAfterFailure = false
        // See StoreKitTests: on CI the local test store returns no products. Remove this line to try again.
        throw XCTSkip("The CI simulator's local StoreKit test store returns no products; verified with sandbox/TestFlight instead")
        let url = try XCTUnwrap(Bundle(for: SupportUITests.self).url(forResource: "Supporter", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        self.session = session
    }

    @MainActor
    func testBuyingOnceUnlocksEverythingAndSurvivesARelaunch() throws {
        let app = launchApp()
        app.openSupport()
        let buy = app.buttons["support.buyOnce"]
        XCTAssertTrue(buy.waitForExistence(timeout: 20), "The products did not load")
        XCTAssertFalse(app.element("support.manage").exists)
        screenshot(app, "S01-support-before")
        buy.tap()
        app.allowSystemAlertIfShown()
        let thanks = app.alerts["Thank you for your support"]
        XCTAssertTrue(thanks.waitForExistence(timeout: 20), "No confirmation of the purchase")
        screenshot(app, "S02-thank-you")
        thanks.buttons.firstMatch.tap()
        XCTAssertEqual(app.value("support.status"), "You are a supporter. Thank you!")
        screenshot(app, "S03-support-after")

        app.tab("Wird")
        XCTAssertTrue(app.element("wird.add").waitForExistence(timeout: 10))

        // Next launch (no network needed): still a supporter.
        relaunch(app)
        app.tab("Wird")
        XCTAssertTrue(app.element("wird.add").waitForExistence(timeout: 10))
    }

    @MainActor
    func testMonthlySupportShowsManageSubscription() throws {
        let app = launchApp()
        app.openSupport()
        let buy = app.buttons["support.buyMonthly"]
        XCTAssertTrue(buy.waitForExistence(timeout: 20), "The products did not load")
        buy.tap()
        app.allowSystemAlertIfShown()
        XCTAssertTrue(app.alerts["Thank you for your support"].waitForExistence(timeout: 20))
        app.alerts.firstMatch.buttons.firstMatch.tap()
        XCTAssertTrue(app.element("support.manage").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["support.buyMonthly"].isEnabled)   // already subscribed
    }
}
