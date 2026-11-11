import XCTest

/// Launches the real app in the simulator in each language,
/// checks what is on screen, and keeps a screenshot for review.
final class LaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchInArabic() throws {
        try launchAndCapture(language: "ar", locale: "ar_SA", expectedTitle: "مسبحة")
    }

    @MainActor
    func testLaunchInEnglish() throws {
        try launchAndCapture(language: "en", locale: "en_US", expectedTitle: "Tasbeeh")
    }

    @MainActor
    private func launchAndCapture(language: String, locale: String, expectedTitle: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()

        let title = app.staticTexts["pipeline.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20), "The title never appeared")
        XCTAssertEqual(title.label, expectedTitle)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "launch-\(language)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
