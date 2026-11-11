import Foundation

/// Facts about the running build, read from Info.plist.
enum AppInfo {
    /// User-facing version (≈ versionName), e.g. "0.1.0".
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    /// Build number (≈ versionCode), e.g. "1".
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}
