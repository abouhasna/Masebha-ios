import Foundation
import Testing
@testable import Masebha

/// Leap 0 checks: the app is built with the right identity and both languages.
@MainActor
struct PipelineTests {
    @Test func usesTheRealBundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "nafii.masebha")
    }

    @Test func versionAndBuildAreReadFromInfoPlist() {
        #expect(AppInfo.version != "?")
        #expect(AppInfo.build != "?")
    }

    @Test(arguments: zip(["ar", "en"], ["مسبحة", "Tasbeeh"]))
    func bothLanguagesAreCompiledIntoTheApp(language: String, expectedTitle: String) throws {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let title = bundle.localizedString(forKey: "pipeline.title", value: "MISSING", table: nil)
        #expect(title == expectedTitle)
    }
}
