import Foundation
import Testing
@testable import Masebha

private final class BackupBundleToken {}

/// Backup files: Android compatibility in both directions, full validation before any change,
/// and an all-or-nothing import.
@MainActor
struct BackupTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func freshDefaults() -> UserDefaults {
        let name = "backup-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeEnvironment() throws -> AppEnvironment {
        AppEnvironment(settings: AppSettings(defaults: freshDefaults()), entitlements: Entitlements(defaults: freshDefaults()),
                       database: try AppDatabase.inMemory())
    }

    private func androidFile() throws -> Data {
        let url = try #require(Bundle(for: BackupBundleToken.self).url(forResource: "android_backup", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    /// The Android fixture as an editable JSON object.
    private func androidObject() throws -> [String: JSONValue] {
        try #require(try JSONDecoder().decode(JSONValue.self, from: androidFile()).object)
    }

    private func data(_ object: [String: JSONValue]) throws -> Data {
        try JSONEncoder().encode(JSONValue.object(object))
    }

    // MARK: Importing an Android file

    @Test func anAndroidBackupImportsEverything() throws {
        let environment = try makeEnvironment()
        try environment.store.seedIfEmpty([("Old", 33)])
        let old = try environment.store.allDhikr()[0].id
        try environment.store.applyDelta(5, to: old, day: "2026-11-17")

        try environment.importBackup(BackupCodec.decode(androidFile()))

        // Adhkar: replaced, ids and positions kept, Android's normalizations applied.
        let adhkar = try environment.store.allDhikr()
        #expect(adhkar.map(\.id) == [3, 7, 9])
        #expect(adhkar.map(\.name) == ["سبحان الله", "الحمد لله", "أستغفر الله"])
        #expect(adhkar.map(\.total) == [1234, 0, 100_250])
        #expect(adhkar.map(\.loopSize) == [33, 33, 100])
        #expect(adhkar.map(\.position) == [0, 1, 2])
        #expect(adhkar[0].lastOpenedAt == Date(timeIntervalSince1970: 1_731_230_000))
        #expect(adhkar[1].lastOpenedAt == nil)          // 0 = never opened
        #expect(adhkar.map(\.timerDelayMs) == [1000, 1000, 2500])   // under 100 ms means 1 s
        #expect(try environment.store.dhikr(id: old) == nil)

        // Settings: Android's text values become numbers, every value checked.
        let settings = environment.settings
        #expect(settings.themeKey == "theme3")
        #expect(settings.fontSize == 36)
        #expect(settings.fontKey == "tajawal")
        #expect(settings.tapSound == true && settings.loopSound == false)
        #expect(settings.vibrateOnTap == true && settings.vibrateOnLoop == false)
        #expect(settings.tapVibrationMs == 250 && settings.loopVibrationMs == 600)
        #expect(settings.resumeLoop == true)
        #expect(settings.hijriOffset == -1)
        #expect(settings.reminderEnabled && settings.reminderTitle == "ورد اليوم")
        #expect(settings.reminderHour == 6 && settings.reminderMinute == 30)
        #expect(settings.language == .arabic)
        #expect(settings.languageChosen && settings.didSeed)
        // Colors: signed Android integers; a 0 means that color's default.
        #expect(settings.palette == ThemeRegistry.theme("theme3")!.palette)

        // Wird: restored as is (also the deleted wird and its history), defaults never added on top.
        let wird = try #require(try environment.backupStore.read().wird)
        #expect(wird.wirds.map(\.id) == [1, 2])
        #expect(wird.wirds.map(\.deleted) == [false, true])
        #expect(wird.items.map(\.count) == [2, 1])
        #expect(wird.items.map(\.totalTaps) == [40, 12])
        #expect(wird.items.map(\.timerDelayMs) == [1000, 1000])
        #expect(wird.days.count == 2)
        #expect(settings.wirdDefaultsAdded)
        try environment.addDefaultWirdsIfNeeded(now: now)
        #expect(try environment.wirdStore.summaries(day: "2026-11-17").map(\.name) == ["أذكار الصباح"])
    }

    /// The owner's real export from the Android app (Nov 2026, app version 46; times and counts
    /// replaced for the public repo, everything else exactly as exported).
    @Test func theOwnersRealAndroidExportImports() throws {
        let url = try #require(Bundle(for: BackupBundleToken.self).url(forResource: "android_real_backup", withExtension: "json"))
        var file = try BackupCodec.decode(Data(contentsOf: url))
        #expect(file.settings["app_language"]?.string == "en")
        // The UI language is shared by tests running in parallel; switching it is tested on its own
        // (theBackupsLanguageIsApplied), so this import keeps Arabic.
        file.settings["app_language"] = .string("ar")
        let environment = try makeEnvironment()
        try environment.importBackup(file)

        let adhkar = try environment.store.allDhikr()
        #expect(adhkar.map(\.id) == [1, 5, 2, 3, 4])
        #expect(adhkar.map(\.name) == ["سبحان الله", "لا اله الا الله ", "الحمد لله", "الله أكبر", "اللهم صل على محمد"])
        #expect(adhkar.map(\.total) == [700, 60, 5, 10, 40])
        #expect(adhkar.map(\.loopSize) == [33, 100, 33, 33, 33])
        #expect(adhkar.map(\.position) == [0, 1, 2, 3, 4])
        #expect(adhkar.map(\.timerDelayMs) == [5000, 1000, 826, 713, 1601])
        #expect(adhkar[0].lastOpenedAt == Date(timeIntervalSince1970: 1_790_000_000))

        let settings = environment.settings
        #expect(settings.themeKey == "theme9")
        #expect(settings.palette == ThemeRegistry.theme("theme9")!.palette)   // the same colors as Android
        #expect(settings.fontSize == 30)
        #expect(settings.tapSound && settings.loopSound && settings.vibrateOnLoop)
        #expect(settings.tapVibrationMs == 180 && settings.loopVibrationMs == 400)
        #expect(settings.resumeLoop == false && settings.hijriOffset == 0)

        // Wird: the 6 lists and 81 azkar, no history yet; the iOS defaults are not added on top.
        let wird = try #require(try environment.backupStore.read().wird)
        #expect(wird.wirds.map(\.name) == ["My Azkar", "أذكار الصباح", "أذكار المساء", "أذكار النوم", "أذكار الاستيقاظ",
                                           "أذكار بعد الصلاة"])
        #expect(wird.items.count == 81)
        #expect(wird.days.isEmpty)
        try environment.addDefaultWirdsIfNeeded(now: now)
        #expect(try environment.wirdStore.summaries(day: "2026-11-20").map(\.itemCount) == [5, 23, 22, 15, 4, 12])
    }

    @Test func theBackupsLanguageIsApplied() throws {
        let original = Localizer.shared.language
        let systemLanguages = UserDefaults.standard.object(forKey: "AppleLanguages")
        defer {
            Localizer.shared.setLanguage(original)
            UserDefaults.standard.set(systemLanguages, forKey: "AppleLanguages")
        }
        let environment = try makeEnvironment()
        var object = try androidObject()
        var settings = try #require(object["settings"]?.object)
        settings["app_language"] = .string("en")
        object["settings"] = .object(settings)
        try environment.importBackup(BackupCodec.decode(data(object)))
        #expect(environment.settings.language == .english)
        #expect(Localizer.shared.language == .english)
    }

    @Test func wirdDataIsImportedEvenForNonSupporters() throws {
        let environment = try makeEnvironment()
        #expect(environment.entitlements.isSupporter == false)
        try environment.importBackup(BackupCodec.decode(androidFile()))
        #expect(try environment.backupStore.read().wird?.wirds.count == 2)   // kept, locked until support
    }

    @Test func aFileWithoutAWirdSectionKeepsTheCurrentWirds() throws {
        let environment = try makeEnvironment()
        try environment.wirdStore.add(NewWird(name: "Mine", items: [WirdDraft(body: "x", target: 1)]), now: now)
        var object = try androidObject()
        object["wird"] = nil
        try environment.importBackup(BackupCodec.decode(data(object)))
        #expect(try environment.wirdStore.summaries(day: "2026-11-17").map(\.name) == ["Mine"])
        #expect(environment.settings.wirdDefaultsAdded == false)
    }

    @Test func anEmptyWirdSectionReplacesTheWirdsLikeAndroid() throws {
        let environment = try makeEnvironment()
        try environment.wirdStore.add(NewWird(name: "Mine", items: [WirdDraft(body: "x", target: 1)]), now: now)
        var object = try androidObject()
        object["wird"] = .object(["wirds": .array([]), "items": .array([]), "days": .array([])])
        try environment.importBackup(BackupCodec.decode(data(object)))
        #expect(try environment.wirdStore.summaries(day: "2026-11-17").isEmpty)
    }

    @Test func invalidOrUnknownSettingsKeepTheCurrentValues() throws {
        let environment = try makeEnvironment()
        var object = try androidObject()
        object["settings"] = .object([
            "font_size": .string("31"), "theme": .string("theme99"), "hijri_offset": .string("abc"),
            "reminder_hour": .int(30), "vibration_on_tap": .string("yes"), "app_font": .string("comicsans"),
            "app_language": .string("fr"),
        ])
        object["colors"] = nil
        let before = environment.settings.palette
        try environment.importBackup(BackupCodec.decode(data(object)))
        let settings = environment.settings
        #expect(settings.fontSize == 30)
        #expect(settings.themeKey == "theme1")
        #expect(settings.hijriOffset == 0)
        #expect(settings.reminderHour == 8)
        #expect(settings.vibrateOnTap == false)
        #expect(settings.fontKey == "ibmplexsansarabic")
        #expect(settings.palette == before)   // no colors in the file: colors untouched
    }

    // MARK: Invalid files change nothing

    @Test(arguments: [
        "format", "zekerMissing", "columnMissing", "zeroLoop", "negativeTotal", "duplicateId", "nameNotText",
        "wirdOrphanItem", "wirdDuplicateDay", "wirdBadStatus", "wirdBadDay", "wirdEmptyName", "wirdZeroTarget",
    ])
    func anInvalidFileIsRejectedBeforeAnyChange(_ problem: String) throws {
        var object = try androidObject()
        var zeker = try #require(object["zeker"]?.array)
        var row = try #require(zeker[0].object)
        var wird = try #require(object["wird"]?.object)
        var items = try #require(wird["items"]?.array)
        var days = try #require(wird["days"]?.array)
        var wirds = try #require(wird["wirds"]?.array)
        switch problem {
        case "format": object["format"] = .int(2)
        case "zekerMissing": object["zeker"] = nil
        case "columnMissing": row["dawra"] = nil
        case "zeroLoop": row["dawra"] = .int(0)
        case "negativeTotal": row["total"] = .int(-1)
        case "duplicateId": zeker.append(.object(row))
        case "nameNotText": row["name"] = .int(5)
        case "wirdOrphanItem":
            var item = try #require(items[0].object)
            item["wird_id"] = .int(99)
            items[0] = .object(item)
        case "wirdDuplicateDay": days.append(days[0])
        case "wirdBadStatus":
            var item = try #require(items[0].object)
            item["status"] = .int(7)
            items[0] = .object(item)
        case "wirdBadDay":
            var entry = try #require(days[0].object)
            entry["day"] = .string("2026-1-9")
            days[0] = .object(entry)
        case "wirdEmptyName":
            var entry = try #require(wirds[0].object)
            entry["name"] = .string(" ")
            wirds[0] = .object(entry)
        case "wirdZeroTarget":
            var item = try #require(items[0].object)
            item["target"] = .int(0)
            items[0] = .object(item)
        default: Issue.record("unknown case \(problem)")
        }
        if problem != "duplicateId" { zeker[0] = .object(row) }
        if problem != "zekerMissing" { object["zeker"] = .array(zeker) }
        wird["items"] = .array(items)
        wird["days"] = .array(days)
        wird["wirds"] = .array(wirds)
        object["wird"] = .object(wird)

        let file = try data(object)
        #expect(throws: BackupError.self) { try BackupCodec.decode(file) }
    }

    @Test func notABackupAtAll() {
        #expect(throws: BackupError.unreadable) { try BackupCodec.decode(Data("hello".utf8)) }
        #expect(throws: BackupError.unreadable) { try BackupCodec.decode(Data("[1, 2]".utf8)) }
        #expect(throws: BackupError.unsupportedFormat) { try BackupCodec.decode(Data(#"{"zeker": []}"#.utf8)) }
        #expect(throws: BackupError.tooLarge) { try BackupCodec.decode(Data(count: BackupCodec.maximumBytes + 1)) }
    }

    @Test func aFailingImportRollsBackCompletely() throws {
        let environment = try makeEnvironment()
        try environment.store.seedIfEmpty([("Keep me", 33)])
        try environment.wirdStore.add(NewWird(name: "Mine", items: [WirdDraft(body: "x", target: 1)]), now: now)
        let before = try environment.backupStore.read()

        // Bypasses the file checks to prove the database itself refuses and rolls back.
        let broken = WirdBackup(wirds: [.init(id: 1, name: "W", position: 0, createdAt: 0, lastOpenedAt: 0, deleted: false)],
                                items: [.init(id: 1, wirdID: 1, position: 0, body: "x", target: 1, timerDelayMs: 1000,
                                              totalTaps: 0, count: 0, status: 9)],
                                days: [])
        #expect(throws: (any Error).self) {
            try environment.backupStore.replace(dhikr: [Dhikr(id: 50, name: "New", total: 0, loopSize: 33, position: 0,
                                                             lastOpenedAt: nil, timerDelayMs: 1000)], wird: broken)
        }
        let after = try environment.backupStore.read()
        #expect(after.dhikr == before.dhikr)
        #expect(after.wird == before.wird)
    }

    // MARK: Exporting for Android

    @Test func exportUsesAndroidKeysAndTypes() throws {
        let environment = try makeEnvironment()
        try environment.store.seedIfEmpty([("A", 33)])
        let url = try environment.exportBackup(now: now)
        let root = try #require(try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url)).object)

        #expect(root["format"] == .int(1))
        let settings = try #require(root["settings"]?.object)
        #expect(settings["font_size"] == .string("30"))               // Android list values are text
        #expect(settings["hijri_offset"] == .string("0"))
        #expect(settings["vibration_tap_duration"] == .string("180"))
        #expect(settings["reminder_hour"] == .int(8))                 // the reminder time is a number
        #expect(settings["vibration_on_loop"] == .bool(true))
        #expect(settings["theme"] == .string("theme1"))
        #expect(settings["app_language"] != nil)
        let colors = try #require(root["colors"]?.object)
        #expect(colors.count == 11)
        #expect(colors["cardSelectedColor"] == .int(-16_777_216))     // black as a signed 32-bit integer
        let row = try #require(root["zeker"]?.array?.first?.object)
        #expect(Set(row.keys) == ["_id", "name", "total", "dawra", "position", "last_opened_at", "timer_delay_ms"])
        #expect(row["last_opened_at"] == .int(0))
        #expect(root["wird"] == nil)   // never had a wird: no section, so Android keeps its own wirds
    }

    @Test func exportIncludesWirdDataOnceThereIsAny() throws {
        let environment = try makeEnvironment()
        let id = try environment.wirdStore.add(NewWird(name: "W", items: [WirdDraft(body: "x", target: 2)]), now: now)
        try environment.wirdStore.delete(id: id)   // even only a deleted wird keeps its history
        let file = try environment.readBackup(at: try environment.exportBackup(now: now))
        #expect(file.wird?.wirds.map(\.deleted) == [true])
    }

    @Test func aRoundTripKeepsEverything() throws {
        let first = try makeEnvironment()
        try first.importBackup(BackupCodec.decode(androidFile()))
        let exported = try first.readBackup(at: try first.exportBackup(now: now))

        let second = try makeEnvironment()
        try second.importBackup(exported)
        #expect(try second.backupStore.read().dhikr == first.backupStore.read().dhikr)
        #expect(try second.backupStore.read().wird == first.backupStore.read().wird)
        #expect(second.settings.backupSettings() == first.settings.backupSettings())
        #expect(second.settings.palette == first.settings.palette)
    }

    @Test func theFileNameMatchesAndroid() {
        let name = BackupCodec.fileName(for: now)
        #expect(name.hasPrefix("misbaha-backup-") && name.hasSuffix(".json"))
        #expect(name.count == "misbaha-backup-20261117-1430.json".count)
    }

    @Test func dayKeysMustBeExact() {
        #expect(BackupCodec.isDayKey("2026-11-09"))
        #expect(!BackupCodec.isDayKey("2026-1-09"))
        #expect(!BackupCodec.isDayKey("26-11-09"))
        #expect(!BackupCodec.isDayKey("2026/11/09"))
        #expect(!BackupCodec.isDayKey("٢٠٢٦-١١-٠٩"))
    }
}
