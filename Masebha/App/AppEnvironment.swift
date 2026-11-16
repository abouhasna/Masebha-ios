import SwiftUI
import Observation

/// The app's shared services, created once at launch (≈ an Application class on Android).
/// Screens receive it through the SwiftUI environment.
@Observable
final class AppEnvironment {
    let settings: AppSettings
    let entitlements: Entitlements
    let store: DhikrStore
    let sound: SoundPlayer
    let haptics: Haptics
    let reminders: ReminderScheduler
    /// The reminder as iOS really has it (refreshed at launch and after every change).
    var reminderStatus: ReminderStatus = .off

    init(settings: AppSettings, entitlements: Entitlements, store: DhikrStore,
         sound: SoundPlayer = SoundPlayer(), haptics: Haptics = Haptics(),
         reminders: ReminderScheduler = ReminderScheduler()) {
        self.settings = settings
        self.entitlements = entitlements
        self.store = store
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
