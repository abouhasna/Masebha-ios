import Foundation
import Observation

/// Allowed values of the list settings (same values as the Android app).
nonisolated enum SettingOptions {
    static let fontSizes = [14, 24, 30, 36, 42]
    static let defaultFontSize = 30
    static let tapVibrationMs = [60, 100, 180, 250, 400]
    static let defaultTapVibrationMs = 180
    static let loopVibrationMs = [100, 200, 400, 600, 900]
    static let defaultLoopVibrationMs = 400
    static let hijriOffsets = [-2, -1, 0, 1, 2]
}

/// Every user preference (≈ the default SharedPreferences + ColorsPrefs on Android).
///
/// Each property saves itself to UserDefaults as soon as it changes, so nothing is lost if the
/// app is killed. Values read back are validated: an unexpected value falls back to the default
/// instead of crashing (Android trusted the stored types).
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    // MARK: Language and first run

    var languageChosen: Bool { didSet { defaults.set(languageChosen, forKey: Keys.languageChosen) } }
    var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: Keys.language) } }
    /// True once the 7 starter adhkar were created (never re-created, even if the user deletes them).
    var didSeed: Bool { didSet { defaults.set(didSeed, forKey: Keys.didSeed) } }

    // MARK: Appearance

    var themeKey: String { didSet { defaults.set(themeKey, forKey: Keys.theme) } }
    var palette: ThemePalette { didSet { savePalette() } }
    var fontKey: String { didSet { defaults.set(fontKey, forKey: Keys.font) } }
    var fontSize: Int { didSet { defaults.set(fontSize, forKey: Keys.fontSize) } }

    // MARK: Counter

    var resumeLoop: Bool { didSet { defaults.set(resumeLoop, forKey: Keys.resumeLoop) } }
    var stopTimerOnLoop: Bool { didSet { defaults.set(stopTimerOnLoop, forKey: Keys.stopTimerOnLoop) } }
    var nextDhikrOnLoop: Bool { didSet { defaults.set(nextDhikrOnLoop, forKey: Keys.nextDhikrOnLoop) } }
    var hideNavButtons: Bool { didSet { defaults.set(hideNavButtons, forKey: Keys.hideNavButtons) } }
    var tapSound: Bool { didSet { defaults.set(tapSound, forKey: Keys.tapSound) } }
    var loopSound: Bool { didSet { defaults.set(loopSound, forKey: Keys.loopSound) } }
    var vibrateOnTap: Bool { didSet { defaults.set(vibrateOnTap, forKey: Keys.vibrateOnTap) } }
    var vibrateOnLoop: Bool { didSet { defaults.set(vibrateOnLoop, forKey: Keys.vibrateOnLoop) } }
    var tapVibrationMs: Int { didSet { defaults.set(tapVibrationMs, forKey: Keys.tapVibrationMs) } }
    var loopVibrationMs: Int { didSet { defaults.set(loopVibrationMs, forKey: Keys.loopVibrationMs) } }
    var showTodayCount: Bool { didSet { defaults.set(showTodayCount, forKey: Keys.showTodayCount) } }
    var coachMarkSeen: Bool { didSet { defaults.set(coachMarkSeen, forKey: Keys.coachMarkSeen) } }

    // MARK: Wird

    /// True once the default wirds were added (or a backup with wird data was restored), so they
    /// are never added twice.
    var wirdDefaultsAdded: Bool { didSet { defaults.set(wirdDefaultsAdded, forKey: Keys.wirdDefaultsAdded) } }

    // MARK: Launch popups and promos (never in backups, like Android)

    /// Real launches of the app (Android launch_count).
    var launchCount: Int { didSet { defaults.set(launchCount, forKey: Keys.launchCount) } }
    var welcomeShown: Bool { didSet { defaults.set(welcomeShown, forKey: Keys.welcomeShown) } }
    /// The newest announcement version already shown.
    var announcementVersionShown: Int {
        didSet { defaults.set(announcementVersionShown, forKey: Keys.announcementVersionShown) }
    }
    var reviewRequested: Bool { didSet { defaults.set(reviewRequested, forKey: Keys.reviewRequested) } }
    var telegramPromoShown: Bool { didSet { defaults.set(telegramPromoShown, forKey: Keys.telegramPromoShown) } }

    // MARK: Hijri date

    var hijriOffset: Int { didSet { defaults.set(hijriOffset, forKey: Keys.hijriOffset) } }

    // MARK: Daily reminder

    var reminderEnabled: Bool { didSet { defaults.set(reminderEnabled, forKey: Keys.reminderEnabled) } }
    var reminderTitle: String { didSet { defaults.set(reminderTitle, forKey: Keys.reminderTitle) } }
    var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: Keys.reminderHour) } }
    var reminderMinute: Int { didSet { defaults.set(reminderMinute, forKey: Keys.reminderMinute) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let read = Reader(defaults: defaults)

        languageChosen = read.bool(Keys.languageChosen, default: false)
        language = AppLanguage(storedValue: defaults.string(forKey: Keys.language))
        didSeed = read.bool(Keys.didSeed, default: false)

        let storedTheme = defaults.string(forKey: Keys.theme) ?? ThemeRegistry.defaultKey
        themeKey = ThemeRegistry.theme(storedTheme) != nil ? storedTheme : ThemeRegistry.defaultKey
        palette = read.palette(fallback: ThemeRegistry.defaultTheme.palette)
        let storedFont = defaults.string(forKey: Keys.font) ?? FontRegistry.defaultKey
        fontKey = FontRegistry.all.contains { $0.key == storedFont } ? storedFont : FontRegistry.defaultKey
        fontSize = read.int(Keys.fontSize, allowed: SettingOptions.fontSizes, default: SettingOptions.defaultFontSize)

        resumeLoop = read.bool(Keys.resumeLoop, default: false)
        stopTimerOnLoop = read.bool(Keys.stopTimerOnLoop, default: false)
        nextDhikrOnLoop = read.bool(Keys.nextDhikrOnLoop, default: false)
        hideNavButtons = read.bool(Keys.hideNavButtons, default: false)
        tapSound = read.bool(Keys.tapSound, default: false)
        loopSound = read.bool(Keys.loopSound, default: false)
        vibrateOnTap = read.bool(Keys.vibrateOnTap, default: false)
        vibrateOnLoop = read.bool(Keys.vibrateOnLoop, default: true)
        tapVibrationMs = read.int(Keys.tapVibrationMs, allowed: SettingOptions.tapVibrationMs,
                                  default: SettingOptions.defaultTapVibrationMs)
        loopVibrationMs = read.int(Keys.loopVibrationMs, allowed: SettingOptions.loopVibrationMs,
                                   default: SettingOptions.defaultLoopVibrationMs)
        showTodayCount = read.bool(Keys.showTodayCount, default: false)
        coachMarkSeen = read.bool(Keys.coachMarkSeen, default: false)

        wirdDefaultsAdded = read.bool(Keys.wirdDefaultsAdded, default: false)

        launchCount = max(0, defaults.object(forKey: Keys.launchCount) as? Int ?? 0)
        welcomeShown = read.bool(Keys.welcomeShown, default: false)
        announcementVersionShown = max(0, defaults.object(forKey: Keys.announcementVersionShown) as? Int ?? 0)
        reviewRequested = read.bool(Keys.reviewRequested, default: false)
        telegramPromoShown = read.bool(Keys.telegramPromoShown, default: false)

        hijriOffset = read.int(Keys.hijriOffset, allowed: SettingOptions.hijriOffsets, default: 0)

        reminderEnabled = read.bool(Keys.reminderEnabled, default: false)
        reminderTitle = defaults.string(forKey: Keys.reminderTitle) ?? ""
        reminderHour = read.int(Keys.reminderHour, allowed: Array(0...23), default: 8)
        reminderMinute = read.int(Keys.reminderMinute, allowed: Array(0...59), default: 0)
    }

    /// Selecting a preset theme writes all 11 colors and the theme key.
    func applyTheme(_ theme: Theme) {
        palette = theme.palette
        themeKey = theme.key
    }

    private func savePalette() {
        for slot in ColorSlot.allCases {
            defaults.set(Int(palette[slot]), forKey: slot.rawValue)
        }
    }

    // MARK: Effective appearance

    /// The colors actually shown. A supporter theme without entitlement shows the default theme,
    /// but the stored colors are kept (Android overwrote them; see known issue D5).
    func effectivePalette(isSupporter: Bool) -> ThemePalette {
        if ThemeRegistry.isPaid(themeKey) && !isSupporter { return ThemeRegistry.defaultTheme.palette }
        return palette
    }

    /// The theme whose name is shown in Settings.
    func effectiveThemeKey(isSupporter: Bool) -> String {
        ThemeRegistry.isPaid(themeKey) && !isSupporter ? ThemeRegistry.defaultKey : themeKey
    }

    /// Supporter themes add the geometric pattern behind the screens.
    func showsPattern(isSupporter: Bool) -> Bool {
        ThemeRegistry.isPaid(themeKey) && isSupporter
    }

    /// A supporter font without entitlement shows the default font; the choice is kept.
    func effectiveFont(isSupporter: Bool) -> FontFamily {
        let family = FontRegistry.family(fontKey)
        return family.isPaid && !isSupporter ? FontRegistry.defaultFamily : family
    }

    /// Counter toolbar: the ring color on free themes, the tools color on supporter themes.
    func counterToolbarColor(isSupporter: Bool) -> ARGB {
        let colors = effectivePalette(isSupporter: isSupporter)
        return showsPattern(isSupporter: isSupporter) ? colors.tools : colors.ring
    }

    // MARK: Storage keys (the Android preference keys, for backup compatibility)

    enum Keys {
        static let languageChosen = "language_chosen"
        static let language = "app_language"
        static let didSeed = "ios_did_seed"
        static let theme = "theme"
        static let font = "app_font"
        static let fontSize = "font_size"
        static let resumeLoop = "save_counts"
        static let stopTimerOnLoop = "dawra_stop_timer"
        static let nextDhikrOnLoop = "dawra_next_zeker"
        static let hideNavButtons = "hide_nav_buttons"
        static let tapSound = "default_sound"
        static let loopSound = "dawra_sound"
        static let vibrateOnTap = "vibration_on_tap"
        static let vibrateOnLoop = "vibration_on_loop"
        static let tapVibrationMs = "vibration_tap_duration"
        static let loopVibrationMs = "vibration_loop_duration"
        static let showTodayCount = "today_count"
        static let coachMarkSeen = "coach_mark_tapped"
        static let hijriOffset = "hijri_offset"
        static let wirdDefaultsAdded = "wird_defaults_added"
        static let launchCount = "launch_count"
        static let welcomeShown = "welcome_shown"
        static let announcementVersionShown = "popup_version_shown"
        static let reviewRequested = "promo_rate_done"
        static let telegramPromoShown = "promo_telegram_done"
        static let reminderEnabled = "reminder_enabled"
        static let reminderTitle = "reminder_title"
        static let reminderHour = "reminder_hour"
        static let reminderMinute = "reminder_minute"
    }
}

/// Reads stored values defensively: wrong types or out-of-range values give the default.
private struct Reader {
    let defaults: UserDefaults

    func bool(_ key: String, default value: Bool) -> Bool {
        (defaults.object(forKey: key) as? Bool) ?? value
    }

    func int(_ key: String, allowed: [Int], default value: Int) -> Int {
        guard let stored = defaults.object(forKey: key) as? Int, allowed.contains(stored) else { return value }
        return stored
    }

    func palette(fallback: ThemePalette) -> ThemePalette {
        var result = fallback
        for slot in ColorSlot.allCases {
            guard let stored = defaults.object(forKey: slot.rawValue) as? Int,
                  stored >= 0, stored <= Int(UInt32.max) else {
                return fallback  // incomplete set: use the whole default palette, never a mix
            }
            result[slot] = ARGB(stored)
        }
        return result
    }
}
