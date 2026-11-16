import UIKit

/// Builds the app's services at launch. If the database cannot be opened, the app shows an error
/// screen instead of starting with empty data (it never replaces an existing database).
enum AppStartup {
    static func makeEnvironment() -> Result<AppEnvironment, Error> {
        #if DEBUG
        UITestHooks.prepareBeforeLaunch()
        #endif
        do {
            let database = try AppDatabase.openDefault()
            let environment = AppEnvironment(settings: AppSettings(), entitlements: Entitlements(),
                                             store: DhikrStore(database: database))
            Localizer.shared.setLanguage(environment.settings.language)
            if environment.settings.languageChosen {
                // Completes a first launch that was interrupted after the language choice.
                try environment.seedIfNeeded()
            }
            #if DEBUG
            try UITestHooks.configure(environment)
            #endif
            return .success(environment)
        } catch {
            return .failure(error)
        }
    }
}

#if DEBUG
/// Switches used only by the automated UI tests (debug builds only, never in the App Store app).
enum UITestHooks {
    private static var values: [String: String] { ProcessInfo.processInfo.environment }

    /// Runs before anything reads the stored data.
    static func prepareBeforeLaunch() {
        guard values["UITEST_RESET"] == "1" else { return }
        if let url = try? AppDatabase.defaultURL() {
            for suffix in ["", "-wal", "-shm", "-journal"] {
                try? FileManager.default.removeItem(atPath: url.path + suffix)
            }
        }
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
    }

    static func configure(_ environment: AppEnvironment) throws {
        if values["UITEST_DISABLE_ANIMATIONS"] == "1" {
            UIView.setAnimationsEnabled(false)
        }
        if let code = values["UITEST_LANGUAGE"], let language = AppLanguage(rawValue: code) {
            try environment.completeOnboarding(with: language)
        }
        if values["UITEST_SUPPORTER"] == "1" {
            environment.entitlements.isSupporter = true
        }
        if values["UITEST_SKIP_COACH"] == "1" {
            environment.settings.coachMarkSeen = true
        }
    }
}
#endif
