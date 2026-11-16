import XCTest

/// Launch options understood by the app's debug-only test hooks (UITestHooks).
struct LaunchOptions {
    var reset = true
    var language: String? = "en"
    var supporter = false
    var skipCoachMark = true
}

extension XCTestCase {
    @MainActor
    @discardableResult
    func launchApp(_ options: LaunchOptions = LaunchOptions()) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        if options.reset { app.launchEnvironment["UITEST_RESET"] = "1" }
        if let language = options.language { app.launchEnvironment["UITEST_LANGUAGE"] = language }
        if options.supporter { app.launchEnvironment["UITEST_SUPPORTER"] = "1" }
        if options.skipCoachMark { app.launchEnvironment["UITEST_SKIP_COACH"] = "1" }
        app.launch()
        return app
    }

    /// Relaunches without resetting anything (like the user opening the app again).
    @MainActor
    @discardableResult
    func relaunch(_ app: XCUIApplication) -> XCUIApplication {
        app.terminate()
        app.launchEnvironment = ["UITEST_DISABLE_ANIMATIONS": "1"]
        app.launch()
        return app
    }

    @MainActor
    func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
extension XCUIApplication {
    /// Any element whose visible text is exactly `label`.
    func text(_ label: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The card of the Azkar list showing `name`.
    func card(_ name: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: "card")
            .containing(NSPredicate(format: "label == %@", name)).firstMatch
    }

    func cardTotal(_ name: String) -> String {
        scrollToCard(name).staticTexts.matching(identifier: "card.total").firstMatch.label
    }

    /// Lists only draw the cards on screen: scrolls down until the card is visible.
    @discardableResult
    func scrollToCard(_ name: String, maxSwipes: Int = 6) -> XCUIElement {
        let target = card(name)
        if target.waitForExistence(timeout: 5) && target.isHittable { return target }
        var swipes = 0
        while !(target.exists && target.isHittable) && swipes < maxSwipes {
            swipeUp()
            swipes += 1
        }
        return target
    }

    /// Whether a card with this name exists anywhere in the list (scrolling if needed).
    func hasCard(_ name: String) -> Bool {
        scrollToCard(name).exists
    }

    func openCard(_ name: String) {
        let title = scrollToCard(name).staticTexts.matching(identifier: "card.name").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Card \(name) not found")
        title.tap()
        XCTAssertTrue(element("counter.current").waitForExistence(timeout: 10), "Counter did not open")
    }

    func cardMenu(_ name: String, choose action: String) {
        let menu = scrollToCard(name).buttons.matching(identifier: "card.menu").firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let item = buttons[action].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Menu item \(action) not found")
        item.tap()
    }

    /// Taps the counting area `times` times.
    func count(_ times: Int) {
        let target = element("counter.current")
        for _ in 0..<times { target.tap() }
    }

    func value(_ identifier: String) -> String {
        element(identifier).label
    }

    func goBack() {
        navigationBars.buttons.element(boundBy: 0).tap()
    }

    func tab(_ label: String) {
        tabBars.buttons[label].tap()
    }

    /// Opens Settings from the More tab.
    func openSettings(moreLabel: String = "More") {
        tab(moreLabel)
        let row = element("more.settings")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }

    /// Sets a SwiftUI Toggle and checks that it really changed.
    func setSwitch(_ identifier: String, on: Bool) {
        var row = switches[identifier].firstMatch
        if !row.waitForExistence(timeout: 3) {
            swipeUpUntil(row)
            row = switches[identifier].firstMatch
        }
        XCTAssertTrue(row.exists, "Switch \(identifier) not found")
        if isOn(row) == on { return }
        let inner = row.switches.firstMatch
        (inner.exists ? inner : row).tap()
        XCTAssertEqual(isOn(row), on, "Switch \(identifier) did not change")
    }

    func isOn(_ element: XCUIElement) -> Bool {
        (element.value as? String) == "1"
    }

    func swipeUpUntil(_ element: XCUIElement, maxSwipes: Int = 8) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            swipeUp()
            swipes += 1
        }
    }

    /// Accepts the iOS notification permission alert, if it appears.
    func allowSystemAlertIfShown() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 6) {
            let buttons = alert.buttons
            buttons.element(boundBy: buttons.count - 1).tap()   // "Allow" is the last button
        }
    }
}
