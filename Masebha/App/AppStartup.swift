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
                                             database: database)
            Localizer.shared.setLanguage(environment.settings.language)
            if environment.settings.languageChosen {
                // Completes a first launch that was interrupted after the language choice.
                try environment.seedIfNeeded()
            }
            #if DEBUG
            try UITestHooks.configure(environment)
            #endif
            environment.settings.launchCount += 1   // one real launch (Android launch_count)
            environment.supportStore.start()   // listens for purchases from launch (Apple's rule)
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
            environment.entitlements.debugSupporter = true
        }
        if values["UITEST_SKIP_POPUPS"] == "1" {
            environment.launchPopupsEnabled = false
        }
        if values["UITEST_ANNOUNCEMENT"] == "1" {
            environment.settings.welcomeShown = true
            environment.announcementOverride = Data(sampleAnnouncement.utf8)
        }
        if values["UITEST_SKIP_COACH"] == "1" {
            environment.settings.coachMarkSeen = true
        }
        if values["UITEST_DEMO_DATA"] == "1" {
            try addDemoData(environment.store)
        }
    }

    /// Realistic list for screenshots: varied totals, every kind of "last opened" label, and a
    /// very long dhikr (Ayat al-Kursi) to check the long-text layout.
    private static func addDemoData(_ store: DhikrStore) throws {
        let items = try store.allDhikr()
        guard items.count >= 5 else { return }
        let day = DayKey.today()
        let now = Date()
        let demo: [(index: Int, total: Int, opened: Date)] = [
            (0, 1_234, now.addingTimeInterval(-60)),           // "Just now"
            (1, 33, now.addingTimeInterval(-4 * 60)),          // "Today HH:mm"
            (2, 5_420, now.addingTimeInterval(-86_400)),       // "Yesterday HH:mm"
            (4, 100_250, now.addingTimeInterval(-10 * 86_400)), // a date
        ]
        for entry in demo {
            let id = items[entry.index].id
            try store.applyDelta(entry.total, to: id, day: day)
            try store.markOpened(id, at: entry.opened)
        }
        _ = try store.add(name: ayatAlKursi, loopSize: 1, initialTotal: 7)
        _ = try store.add(name: mediumLongDhikr, loopSize: 100, initialTotal: 0)
    }

    /// A Firestore document like the real one, to see the announcement popup in UI tests.
    private static let sampleAnnouncement = """
        {"fields": {"enabled": {"booleanValue": true}, "version": {"integerValue": "1"},
         "title": {"stringValue": "ميزة جديدة: الأوراد"}, "title_en": {"stringValue": "New: Wirds"},
         "description": {"stringValue": "أنشئ أورادك اليومية وتابع تقدّمك فيها كل يوم."},
         "description_en": {"stringValue": "Build your daily routines and follow your progress every day."},
         "buttonText": {"stringValue": "تابعنا على تيليجرام"}, "buttonText_en": {"stringValue": "Follow us on Telegram"},
         "buttonLink": {"stringValue": "https://t.me/nafiapp"}}}
        """

    static let mediumLongDhikr = "لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، يحيي ويميت، وهو حي لا يموت، بيده الخير، وهو على كل شيء قدير"

    static let ayatAlKursi = "{اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ}"
}
#endif
