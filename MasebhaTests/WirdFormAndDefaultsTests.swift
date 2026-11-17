import Foundation
import Testing
@testable import Masebha

/// The wird editor's checks (Android's messages and limits).
struct WirdFormTests {
    private func row(_ body: String, _ target: String, id: Int64 = 0) -> WirdForm.Row {
        WirdForm.Row(itemID: id, body: body, target: target)
    }

    @Test func aNameIsRequired() {
        #expect(WirdForm.validate(name: "  ", rows: [row("x", "1")]) == .failure(.nameRequired))
    }

    @Test func atLeastOneZikrIsRequired() {
        #expect(WirdForm.validate(name: "W", rows: []) == .failure(.needItem))
    }

    @Test(arguments: [("", "3"), ("  ", "3"), ("x", ""), ("x", "0"), ("x", "00"), ("x", "123456"), ("x", "1a"), ("x", "-1")])
    func everyZikrNeedsTextAndAValidTarget(body: String, target: String) {
        #expect(WirdForm.validate(name: "W", rows: [row("ok", "1"), row(body, target)]) == .failure(.fillItems))
    }

    @Test func aValidFormIsTrimmedAndKeepsIds() {
        let result = WirdForm.validate(name: "  Morning ", rows: [row(" Subhan Allah ", "33", id: 12), row("x", "99999")])
        #expect(result == .success(NewWird(name: "Morning", items: [
            WirdDraft(itemID: 12, body: "Subhan Allah", target: 33),
            WirdDraft(itemID: 0, body: "x", target: 99_999),
        ])))
    }
}

/// The default wirds: the same texts as Android, added once.
struct WirdDefaultsTests {
    @Test func theFiveHisnAlMuslimWirdsMatchAndroid() throws {
        let wirds = try WirdDefaults.builtIn()
        #expect(wirds.map(\.name) == ["أذكار الصباح", "أذكار المساء", "أذكار النوم", "أذكار الاستيقاظ", "أذكار بعد الصلاة"])
        #expect(wirds.map(\.items.count) == [23, 22, 15, 4, 12])
        for wird in wirds {
            #expect(throws: Never.self) { try WirdStore.validate(wird) }   // every one can be saved
        }
    }

    @Test func myAzkarCopiesTheListAndSkipsWhatCannotBeAZikr() {
        let adhkar = [
            Dhikr(id: 1, name: " Subhan Allah ", total: 5, loopSize: 33, position: 0, lastOpenedAt: nil, timerDelayMs: 1000),
            Dhikr(id: 2, name: "   ", total: 0, loopSize: 33, position: 1, lastOpenedAt: nil, timerDelayMs: 1000),
            Dhikr(id: 3, name: "Istighfar", total: 0, loopSize: 100, position: 2, lastOpenedAt: nil, timerDelayMs: 1000),
        ]
        let wird = WirdDefaults.myAzkar(named: "My Azkar", from: adhkar)
        #expect(wird == NewWird(name: "My Azkar", items: [WirdDraft(body: "Subhan Allah", target: 33),
                                                          WirdDraft(body: "Istighfar", target: 100)]))
        #expect(WirdDefaults.myAzkar(named: "My Azkar", from: []) == nil)
    }
}

/// Adding the default wirds the first time a supporter opens the Wird tab.
@MainActor
struct DefaultWirdsTests {
    private func makeEnvironment() throws -> AppEnvironment {
        func defaults() -> UserDefaults {
            let name = "wird-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: name)!
            defaults.removePersistentDomain(forName: name)
            return defaults
        }
        return AppEnvironment(settings: AppSettings(defaults: defaults()), entitlements: Entitlements(defaults: defaults()),
                              database: try AppDatabase.inMemory())
    }

    @Test func addedOnceWithMyAzkarFirst() throws {
        let environment = try makeEnvironment()
        try environment.store.seedIfEmpty([("A", 33), ("B", 100)])
        try environment.addDefaultWirdsIfNeeded()
        let names = try environment.wirdStore.summaries(day: "2026-11-17").map(\.name)
        #expect(names.count == 6)
        #expect(names.first == tr("wird.default_azkar_name"))
        #expect(environment.settings.wirdDefaultsAdded)

        try environment.addDefaultWirdsIfNeeded()   // never twice
        #expect(try environment.wirdStore.summaries(day: "2026-11-17").count == 6)
    }

    @Test func withoutAdhkarOnlyTheFiveAreAdded() throws {
        let environment = try makeEnvironment()
        try environment.addDefaultWirdsIfNeeded()
        #expect(try environment.wirdStore.summaries(day: "2026-11-17").count == 5)
    }

    @Test func neverAddedOverARestoredWirdList() throws {
        let environment = try makeEnvironment()
        environment.settings.wirdDefaultsAdded = true   // as after importing a backup with wird data
        try environment.addDefaultWirdsIfNeeded()
        #expect(try environment.wirdStore.summaries(day: "2026-11-17").isEmpty)
    }

    @Test func aDeletedDefaultStaysDeleted() throws {
        let environment = try makeEnvironment()
        try environment.addDefaultWirdsIfNeeded()
        let first = try #require(try environment.wirdStore.summaries(day: "2026-11-17").first)
        try environment.wirdStore.delete(id: first.id)
        try environment.addDefaultWirdsIfNeeded()
        #expect(try environment.wirdStore.summaries(day: "2026-11-17").count == 4)
    }
}
