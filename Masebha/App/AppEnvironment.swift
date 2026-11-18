import SwiftUI
import Observation

/// The app's shared services, created once at launch (≈ an Application class on Android).
/// Screens receive it through the SwiftUI environment.
@Observable
final class AppEnvironment {
    let settings: AppSettings
    let entitlements: Entitlements
    let store: DhikrStore
    let wirdStore: WirdStore
    let backupStore: BackupStore
    let supportStore: SupportStore
    let sound: SoundPlayer
    let haptics: Haptics
    let reminders: ReminderScheduler
    /// The reminder as iOS really has it (refreshed at launch and after every change).
    var reminderStatus: ReminderStatus = .off
    /// UI tests turn the launch popups and the rating prompt off.
    @ObservationIgnored var launchPopupsEnabled = true
    /// Debug builds only: a sample announcement document instead of the real one (UI tests).
    @ObservationIgnored var announcementOverride: Data?
    @ObservationIgnored private var launchPopupDecided = false

    init(settings: AppSettings, entitlements: Entitlements, database: AppDatabase,
         sound: SoundPlayer = SoundPlayer(), haptics: Haptics = Haptics(),
         reminders: ReminderScheduler = ReminderScheduler()) {
        self.settings = settings
        self.entitlements = entitlements
        self.store = DhikrStore(database: database)
        self.wirdStore = WirdStore(database: database)
        self.backupStore = BackupStore(database: database)
        self.supportStore = SupportStore(entitlements: entitlements)
        self.sound = sound
        self.haptics = haptics
        self.reminders = reminders
    }

    // MARK: Appearance currently in effect

    var palette: ThemePalette { settings.effectivePalette(isSupporter: entitlements.isSupporter) }
    var showsPattern: Bool { settings.showsPattern(isSupporter: entitlements.isSupporter) }
    var fontFamily: FontFamily { settings.effectiveFont(isSupporter: entitlements.isSupporter) }

    // MARK: Language

    /// First launch: the user picked a language. Creates the starter adhkar in that language.
    func completeOnboarding(with language: AppLanguage) throws {
        applyLanguage(language)
        try seedIfNeeded()
        settings.languageChosen = true
    }

    /// Switches the app language instantly (Settings → Language).
    func changeLanguage(to language: AppLanguage) {
        guard language != settings.language else { return }
        applyLanguage(language)
        Task { await refreshReminder() }  // the reminder text follows the language
    }

    private func applyLanguage(_ language: AppLanguage) {
        settings.language = language
        Localizer.shared.setLanguage(language)
        // System screens (share sheet, file picker…) follow this from the next launch.
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }

    /// Creates the 7 starter adhkar once. Safe to call again: it never duplicates them and never
    /// re-creates them after the user deleted them.
    func seedIfNeeded() throws {
        guard !settings.didSeed else { return }
        try store.seedIfEmpty(SeedData.items())
        settings.didSeed = true
    }

    // MARK: Wird

    /// Adds the default wirds the first time a supporter opens the Wird tab (all or nothing).
    /// If it fails, the flag stays off and it is tried again next time.
    func addDefaultWirdsIfNeeded(now: Date = Date()) throws {
        guard !settings.wirdDefaultsAdded else { return }
        var wirds: [NewWird] = []
        if let myAzkar = WirdDefaults.myAzkar(named: tr("wird.default_azkar_name"), from: try store.allDhikr()) {
            wirds.append(myAzkar)
        }
        wirds += try WirdDefaults.builtIn()
        try wirdStore.addAll(wirds, now: now)
        settings.wirdDefaultsAdded = true
    }

    // MARK: Backup

    /// Writes a backup file into a temporary folder (older ones are removed) and returns it.
    func exportBackup(now: Date = Date()) throws -> URL {
        let data = try backupStore.read()
        let file = BackupFile(dhikr: data.dhikr, colors: settings.backupColors(),
                              settings: settings.backupSettings(), wird: data.wird)
        let json = try BackupCodec.encode(file, exportedAt: now, versionCode: Int(AppInfo.build) ?? 0)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(BackupCodec.fileName(for: now))
        try json.write(to: url, options: .atomic)
        return url
    }

    /// Reads and fully checks a backup file. Nothing is changed yet.
    func readBackup(at url: URL) throws -> BackupFile {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > BackupCodec.maximumBytes {
            throw BackupError.tooLarge
        }
        return try BackupCodec.decode(Data(contentsOf: url))
    }

    /// Replaces the user's data with a checked backup (a full replace, like Android).
    /// The database part is one transaction: if it fails, nothing changes at all.
    /// Wird data is always restored (it stays locked until the user is a supporter).
    func importBackup(_ file: BackupFile) throws {
        try backupStore.replace(dhikr: file.dhikr, wird: file.wird)
        settings.applyBackup(settings: file.settings, colors: file.colors)
        settings.didSeed = true
        settings.languageChosen = true
        if file.wird != nil {
            settings.wirdDefaultsAdded = true   // the backup holds the user's own wird list
        }
        if let code = file.settings[AppSettings.Keys.language]?.string, let language = AppLanguage(rawValue: code),
           language != settings.language {
            applyLanguage(language)
        }
        Task { await refreshReminder() }
    }

    // MARK: Launch popups, promos and rating

    /// The one popup of this launch (at most), already marked as shown. Call it once per launch.
    func nextLaunchPopup() async -> LaunchPopup? {
        guard launchPopupsEnabled, !launchPopupDecided else { return nil }
        launchPopupDecided = true
        let state = LaunchState(launchCount: settings.launchCount, welcomeShown: settings.welcomeShown,
                                announcementVersionShown: settings.announcementVersionShown,
                                telegramPromoShown: settings.telegramPromoShown)
        var announcement: Announcement?
        if LaunchPopups.needsAnnouncement(state) {
            let english = settings.language == .english
            if let announcementOverride {
                announcement = Announcement.parse(announcementOverride, english: english)
            } else {
                announcement = await RemoteContent.fetchAnnouncement(english: english)
            }
        }
        guard let popup = LaunchPopups.choose(state, announcement: announcement) else { return nil }
        switch popup {   // shown once, whatever the user answers (Android)
        case .welcome: settings.welcomeShown = true
        case .announcement(let item): settings.announcementVersionShown = item.version
        case .telegram: settings.telegramPromoShown = true
        }
        return popup
    }

    /// True once, from the 7th launch: time to show Apple's rating prompt (after counting).
    func takeReviewTurn() -> Bool {
        guard launchPopupsEnabled,
              LaunchPopups.shouldAskForReview(launchCount: settings.launchCount, alreadyAsked: settings.reviewRequested) else {
            return false
        }
        settings.reviewRequested = true
        return true
    }

    // MARK: Reminder

    func refreshReminder() async {
        reminderStatus = await reminders.refresh(
            enabled: settings.reminderEnabled, title: reminderTitle, body: tr("reminder.body"),
            hour: settings.reminderHour, minute: settings.reminderMinute)
    }

    func saveReminder(enabled: Bool, title: String, hour: Int, minute: Int) async {
        settings.reminderEnabled = enabled
        settings.reminderTitle = title
        settings.reminderHour = hour
        settings.reminderMinute = minute
        reminderStatus = await reminders.apply(
            enabled: enabled, title: reminderTitle, body: tr("reminder.body"), hour: hour, minute: minute)
    }

    /// A blank title falls back to the app name, like Android.
    private var reminderTitle: String {
        let title = settings.reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? tr("app.name") : title
    }
}

/// The 7 adhkar created on first launch, in the chosen language (same list as Android).
enum SeedData {
    static func items() -> [(name: String, loopSize: Int)] {
        [
            (tr("seed.subhan_allah"), 33),
            (tr("seed.alhamdulillah"), 33),
            (tr("seed.allahu_akbar"), 33),
            (tr("seed.salah_muhammad"), 33),
            (tr("seed.istighfar"), 100),
            (tr("seed.la_ilaha_illallah"), 33),
            (tr("seed.subhan_allah_wabihamdih"), 33),
        ]
    }
}
