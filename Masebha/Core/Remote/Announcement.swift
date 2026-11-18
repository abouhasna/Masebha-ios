import Foundation

/// The announcement popup, read from one public Firestore document (same fields as Android's
/// popup document). Nothing is sent: the app only reads it.
///
/// Every value is checked (Android trusted it, see its known issue R1): a missing, disabled or
/// broken document simply shows nothing, and a broken image is left out instead of crashing.
nonisolated struct Announcement: Equatable, Sendable, Identifiable {
    let version: Int
    let title: String
    let message: String
    let buttonText: String?
    let buttonLink: URL?
    /// Base64-decoded image bytes, if any (the screen shows them only if they are a real image).
    let image: Data?

    var id: Int { version }

    static let maximumImageBytes = 1_000_000

    /// Reads a Firestore REST document. nil when it is disabled, has no version above 0, or no text.
    /// English reads `<field>_en` and falls back to the Arabic field (Android rule).
    static func parse(_ data: Data, english: Bool) -> Announcement? {
        guard let fields = (try? JSONDecoder().decode(JSONValue.self, from: data))?.object?["fields"]?.object else {
            return nil
        }
        func raw(_ key: String) -> [String: JSONValue]? { fields[key]?.object }
        func text(_ key: String) -> String? {
            let value = raw(key)?["stringValue"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        }
        func localized(_ key: String) -> String? { (english ? text(key + "_en") : nil) ?? text(key) }

        let integer = raw("version")?["integerValue"]?.string.flatMap { Int($0) }
            ?? raw("version")?["doubleValue"]?.int.map { Int($0) }
        guard raw("enabled")?["booleanValue"]?.bool == true, let version = integer, version > 0 else { return nil }

        let title = localized("title") ?? ""
        let message = localized("description") ?? ""
        guard !title.isEmpty || !message.isEmpty else { return nil }

        var link: URL?
        if let address = text("buttonLink"), let url = URL(string: address),
           let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            link = url
        }
        var image: Data?
        if let encoded = text("image"), let decoded = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters),
           !decoded.isEmpty, decoded.count <= maximumImageBytes {
            image = decoded
        }
        return Announcement(version: version, title: title, message: message, buttonText: localized("buttonText"),
                            buttonLink: link, image: image)
    }
}

/// Where the announcement lives: Firestore project "masebhaproject" (the Android app's project),
/// collection "masebha", document "ios_popup" (iOS only, so the two apps can announce separately).
nonisolated enum RemoteContent {
    static let announcementURL = URL(string:
        "https://firestore.googleapis.com/v1/projects/masebhaproject/databases/(default)/documents/masebha/ios_popup")!

    /// The current announcement, or nil (no network, no document, disabled, invalid).
    static func fetchAnnouncement(english: Bool) async -> Announcement? {
        let request = URLRequest(url: announcementURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        guard let result = try? await URLSession.shared.data(for: request),
              (result.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return Announcement.parse(result.0, english: english)
    }
}
