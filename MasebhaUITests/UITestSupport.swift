import XCTest

/// The long dhikr added by the demo data (UITEST_DEMO_DATA), in every language.
let ayatAlKursi = "{اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ}"

/// A medium-long dhikr added by the demo data (fits at the user's size with a smaller ring).
let mediumLongDhikr = "لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، يحيي ويميت، وهو حي لا يموت، بيده الخير، وهو على كل شيء قدير"

/// Launch options understood by the app's debug-only test hooks (UITestHooks).
struct LaunchOptions {
    var reset = true
    var language: String? = "en"
    var supporter = false
    var skipCoachMark = true
    var demoData = false
    /// Welcome / announcement / promos and the rating prompt (off unless a test looks at them).
    var popups = false
    /// A sample announcement instead of the real Firestore document (implies popups).
    var announcement = false
    /// Pretends this is the n-th launch (implies popups), e.g. 13 for the Telegram invitation.
    var launchCount: Int?
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
        if options.demoData { app.launchEnvironment["UITEST_DEMO_DATA"] = "1" }
        if options.announcement { app.launchEnvironment["UITEST_ANNOUNCEMENT"] = "1" }
        if let count = options.launchCount { app.launchEnvironment["UITEST_LAUNCH_COUNT"] = String(count) }
        if !options.popups && !options.announcement && options.launchCount == nil {
            app.launchEnvironment["UITEST_SKIP_POPUPS"] = "1"
        }
        app.launch()
        return app
    }

    /// Relaunches without resetting anything (like the user opening the app again).
    @MainActor
    @discardableResult
    func relaunch(_ app: XCUIApplication) -> XCUIApplication {
        app.terminate()
        app.launchEnvironment = ["UITEST_DISABLE_ANIMATIONS": "1", "UITEST_SKIP_POPUPS": "1"]
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
        scrollTo(card(name), maxSwipes: maxSwipes)
    }

    /// Scrolls until the element is visible and not under the floating tab bar.
    @discardableResult
    func scrollTo(_ target: XCUIElement, maxSwipes: Int = 6) -> XCUIElement {
        _ = target.waitForExistence(timeout: 5)
        var swipes = 0
        while !isClear(target) && swipes < maxSwipes {
            swipeUp()
            swipes += 1
        }
        return target
    }

    private func isClear(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let bar = tabBars.firstMatch
        return !bar.exists || element.frame.maxY <= bar.frame.minY
    }

    /// Whether a card with this name exists anywhere in the list (scrolling if needed).
    func hasCard(_ name: String) -> Bool {
        scrollToCard(name).exists
    }

    /// The names of the Azkar cards, in list order.
    func cardNames() -> [String] {
        descendants(matching: .any).matching(identifier: "card.name").allElementsBoundByIndex.map { $0.label }
    }

    /// Press and hold a card until iOS lifts it, then drag it onto another card. A slow CI
    /// simulator sometimes drops the synthesized long press, so it tries once more if nothing moved.
    func drag(_ name: String, onto target: String) {
        let before = cardNames()
        for _ in 0..<2 {
            card(name).press(forDuration: 1.0, thenDragTo: card(target),
                             withVelocity: .slow, thenHoldForDuration: 0.6)
            if cardNames() != before { return }
        }
    }

    func openCard(_ name: String) {
        let title = scrollToCard(name).staticTexts.matching(identifier: "card.name").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Card \(name) not found")
        title.tap()
        let counter = element("counter.current")
        // A slow CI simulator sometimes drops a synthesized tap. Tap again only while the list is
        // still showing, so a retry can never land on (and count on) the counter screen.
        if !counter.waitForExistence(timeout: 5) && title.exists && title.isHittable {
            title.tap()
        }
        XCTAssertTrue(counter.waitForExistence(timeout: 10), "Counter did not open")
    }

    /// The card of the Wird list showing `name`.
    func wirdCard(_ name: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: "wird.card")
            .containing(NSPredicate(format: "label == %@", name)).firstMatch
    }

    func openWird(_ name: String) {
        let title = scrollTo(wirdCard(name)).staticTexts.matching(identifier: "wird.card.name").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Wird \(name) not found")
        title.tap()
        XCTAssertTrue(element("counter.current").waitForExistence(timeout: 10), "Wird session did not open")
    }

    func wirdMenu(_ name: String, choose action: String) {
        let menu = scrollTo(wirdCard(name)).buttons.matching(identifier: "wird.card.menu").firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        tapItem(action)
    }

    func wirdStatus(_ name: String) -> String {
        scrollTo(wirdCard(name)).descendants(matching: .any).matching(identifier: "wird.card.status").firstMatch.label
    }

    /// A text field or, for multi-line fields, a text view, by identifier (the n-th one).
    func field(_ identifier: String, at index: Int = 0) -> XCUIElement {
        let fields = textFields.matching(identifier: identifier)
        return fields.count > index ? fields.element(boundBy: index)
            : textViews.matching(identifier: identifier).element(boundBy: index)
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

    /// Taps the navigation bar's back button (works in English and Arabic).
    func goBack() {
        let back = navigationBars.buttons.matching(
            NSPredicate(format: "identifier == 'BackButton' OR label IN {'Back', 'رجوع', 'السابق'}")).firstMatch
        (back.exists ? back : navigationBars.buttons.element(boundBy: 0)).tap()
    }

    /// Taps a menu item / dialog button by its visible text.
    func tapItem(_ label: String) {
        let item = buttons[label].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Item \(label) not found")
        item.tap()
    }

    /// Closes a popover-style dialog (iOS 26 shows some dialogs as popovers without a Cancel button).
    func dismissPopover(cancelLabel: String) {
        let region = otherElements["PopoverDismissRegion"].firstMatch
        if region.exists {
            region.tap()
        } else if buttons[cancelLabel].exists {
            buttons[cancelLabel].firstMatch.tap()
        }
    }

    /// A button of the bottom tab bar, by its visible title.
    func tabButton(_ label: String) -> XCUIElement {
        tabBars.buttons[label]
    }

    func tab(_ label: String) {
        let button = tabButton(label)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Tab \(label) not found")
        button.tap()
    }

    /// Opens the Support screen from the More tab.
    func openSupport(moreLabel: String = "More") {
        tab(moreLabel)
        let row = element("more.support")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(element("support.status").waitForExistence(timeout: 5))
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
