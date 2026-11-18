import Foundation

/// Every link that leaves the app. The website pages open in the app's language.
enum AppLinks {
    static let email = "masebha0@gmail.com"
    static let contact = URL(string: "mailto:\(email)")!

    /// The website's suggestions page: users write ideas and vote on others' (no data goes
    /// through the app).
    static var suggestions: URL { website("suggestions/") }
    /// The privacy policy (required next to the purchase buttons).
    static var privacy: URL { website("privacy/") }
    /// Apple's standard Terms of Use (EULA), required next to a subscription.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// The app's Apple ID number (App Store Connect → App Information → Apple ID). Until it is set,
    /// sharing uses the website and "Rate" shows Apple's rating prompt.
    static let appStoreID: String? = nil
    /// What "Share the app" sends: the App Store page, or the website until the id is known.
    static var store: URL {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") } ?? website("")
    }
    static var writeReview: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }

    static let youtube = URL(string: "https://youtube.com/shorts/V6j_zEb3h5w?si=lzXx3qbB7xV1i3bw")!
    static let telegram = URL(string: "https://t.me/nafiapp")!

    private static func website(_ page: String) -> URL {
        let language = Localizer.shared.language == .english ? "en/" : ""
        return URL(string: "https://tasbeeh-app.pages.dev/\(language)\(page)")!
    }
}
