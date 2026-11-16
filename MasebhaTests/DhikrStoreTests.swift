import Foundation
import Testing
@testable import Masebha

/// Database behavior: everything the app saves, and the rules that protect the data.
struct DhikrStoreTests {
    private let day = "2026-11-16"
    private let nextDay = "2026-11-17"

    private func makeStore() throws -> DhikrStore {
        DhikrStore(database: try AppDatabase.inMemory())
    }

    private let seeds: [(name: String, loopSize: Int)] = [("A", 33), ("B", 33), ("C", 100)]

    // MARK: Seeding

    @Test func seedsOnlyAnEmptyList() throws {
        let store = try makeStore()
        #expect(try store.seedIfEmpty(seeds) == true)
        #expect(try store.seedIfEmpty(seeds) == false)   // never duplicates
        let all = try store.allDhikr()
        #expect(all.map(\.name) == ["A", "B", "C"])
        #expect(all.map(\.position) == [0, 1, 2])
        #expect(all.map(\.loopSize) == [33, 33, 100])
        #expect(all.allSatisfy { $0.total == 0 && $0.lastOpenedAt == nil && $0.timerDelayMs == 1000 })
    }

    // MARK: Add / edit / delete / reorder

    @Test func addPutsTheNewDhikrAtTheEnd() throws {
        let store = try makeStore()
        try store.seedIfEmpty(seeds)
        let added = try store.add(name: "D", loopSize: 7, initialTotal: 250)
        #expect(added.position == 3)
        #expect(added.total == 250)
        #expect(try store.allDhikr().last == added)
    }

    @Test func addRejectsInvalidValues() throws {
        let store = try makeStore()
        #expect(throws: StoreError.invalidValue) { try store.add(name: "", loopSize: 33, initialTotal: 0) }
        #expect(throws: StoreError.invalidValue) { try store.add(name: "X", loopSize: 0, initialTotal: 0) }
        #expect(throws: StoreError.invalidValue) { try store.add(name: "X", loopSize: 33, initialTotal: -1) }
        #expect(try store.allDhikr().isEmpty)
    }

    @Test func updateChangesNameLoopAndTotal() throws {
        let store = try makeStore()
        let item = try store.add(name: "Old", loopSize: 33, initialTotal: 5)
        try store.update(id: item.id, name: "New", loopSize: 99, total: 1234)
        let updated = try #require(try store.dhikr(id: item.id))
        #expect(updated.name == "New" && updated.loopSize == 99 && updated.total == 1234)
    }

    @Test func updateOfAMissingDhikrFails() throws {
        let store = try makeStore()
        #expect(throws: StoreError.dhikrNotFound) { try store.update(id: 42, name: "X", loopSize: 1, total: 0) }
    }

    @Test func deleteClosesTheGapAndRemovesDailyCounts() throws {
        let store = try makeStore()
        try store.seedIfEmpty(seeds)
        let items = try store.allDhikr()
        try store.applyDelta(5, to: items[1].id, day: day)
        try store.delete(id: items[1].id)
        let after = try store.allDhikr()
        #expect(after.map(\.name) == ["A", "C"])
        #expect(after.map(\.position) == [0, 1])
        #expect(try store.todayCount(id: items[1].id, day: day) == 0)   // cascade-deleted
        #expect(throws: StoreError.dhikrNotFound) { try store.delete(id: items[1].id) }
    }

    @Test func idsAreNeverReusedAfterDelete() throws {
        let store = try makeStore()
        let first = try store.add(name: "A", loopSize: 1, initialTotal: 0)
        try store.delete(id: first.id)
        let second = try store.add(name: "B", loopSize: 1, initialTotal: 0)
        #expect(second.id > first.id)
    }

    @Test func reorderSavesTheNewOrder() throws {
        let store = try makeStore()
        try store.seedIfEmpty(seeds)
        let ids = try store.allDhikr().map(\.id)
        try store.reorder([ids[2], ids[0], ids[1]])
        #expect(try store.allDhikr().map(\.name) == ["C", "A", "B"])
        #expect(try store.allDhikr().map(\.position) == [0, 1, 2])
    }

    @Test func reorderWithAnOutdatedListIsRefused() throws {
        let store = try makeStore()
        try store.seedIfEmpty(seeds)
        let ids = try store.allDhikr().map(\.id)
        #expect(throws: StoreError.listChanged) { try store.reorder([ids[0], ids[1]]) }
        #expect(try store.allDhikr().map(\.name) == ["A", "B", "C"])   // nothing changed
    }

    @Test func neighborsFollowTheListOrder() throws {
        let store = try makeStore()
        try store.seedIfEmpty(seeds)
        let ids = try store.allDhikr().map(\.id)
        let first = try store.neighbors(of: ids[0])
        #expect(first.previous == nil && first.next == ids[1])
        let middle = try store.neighbors(of: ids[1])
        #expect(middle.previous == ids[0] && middle.next == ids[2])
        let last = try store.neighbors(of: ids[2])
        #expect(last.previous == ids[1] && last.next == nil)
        let unknown = try store.neighbors(of: 999)
        #expect(unknown.previous == nil && unknown.next == nil)
    }

    // MARK: Counting

    @Test func applyDeltaUpdatesTotalAndToday() throws {
        let store = try makeStore()
        let item = try store.add(name: "A", loopSize: 33, initialTotal: 10)
        let snapshot = try store.applyDelta(1, to: item.id, day: day)
        #expect(snapshot == CountSnapshot(total: 11, today: 1))
        #expect(try store.applyDelta(1, to: item.id, day: day) == CountSnapshot(total: 12, today: 2))
    }

    @Test func countsNeverGoBelowZero() throws {
        let store = try makeStore()
        let item = try store.add(name: "A", loopSize: 33, initialTotal: 3)
        try store.applyDelta(2, to: item.id, day: day)
        let snapshot = try store.applyDelta(-10, to: item.id, day: day)
        #expect(snapshot == CountSnapshot(total: 0, today: 0))
    }

    @Test func eachDayHasItsOwnCount() throws {
        let store = try makeStore()
        let item = try store.add(name: "A", loopSize: 33, initialTotal: 0)
        try store.applyDelta(3, to: item.id, day: day)
        try store.applyDelta(2, to: item.id, day: nextDay)
        #expect(try store.todayCount(id: item.id, day: day) == 3)
        #expect(try store.todayCount(id: item.id, day: nextDay) == 2)
        #expect(try store.dhikr(id: item.id)?.total == 5)
    }

    @Test func countingAMissingDhikrFailsAndSavesNothing() throws {
        let store = try makeStore()
        #expect(throws: StoreError.dhikrNotFound) { try store.applyDelta(1, to: 77, day: day) }
    }

    @Test func manyTapsAreAllSaved() throws {
        // Deltas, not absolute totals: nothing can be lost or overwritten (Android issue D2).
        let store = try makeStore()
        let item = try store.add(name: "A", loopSize: 33, initialTotal: 0)
        for _ in 0..<500 { try store.applyDelta(1, to: item.id, day: day) }
        #expect(try store.dhikr(id: item.id)?.total == 500)
        #expect(try store.todayCount(id: item.id, day: day) == 500)
    }

    @Test func resetCountKeepsPastDays() throws {
        let store = try makeStore()
        let item = try store.add(name: "A", loopSize: 33, initialTotal: 0)
        try store.applyDelta(4, to: item.id, day: day)
        try store.applyDelta(6, to: item.id, day: nextDay)
        let snapshot = try store.resetCount(of: item.id, day: nextDay)
        #expect(snapshot == CountSnapshot(total: 0, today: 0))
        #expect(try store.todayCount(id: item.id, day: day) == 4)   // history kept
    }

    @Test func resetAllZeroesEveryTotalAndToday() throws {
        let store = try makeStore()
        try store.seedIfEmpty(seeds)
        let ids = try store.allDhikr().map(\.id)
        for id in ids { try store.applyDelta(9, to: id, day: day) }
        try store.resetAll(day: day)
        #expect(try store.grandTotal() == 0)
        for id in ids { #expect(try store.todayCount(id: id, day: day) == 0) }
    }

    @Test func grandTotalSumsAllAdhkar() throws {
        let store = try makeStore()
        _ = try store.add(name: "A", loopSize: 1, initialTotal: 1000)
        _ = try store.add(name: "B", loopSize: 1, initialTotal: 234)
        #expect(try store.grandTotal() == 1234)
    }

    // MARK: Other fields

    @Test func markOpenedStoresTheTime() throws {
        let store = try makeStore()
        let item = try store.add(name: "A", loopSize: 1, initialTotal: 0)
        let date = Date(timeIntervalSince1970: 1_731_230_000.123)
        try store.markOpened(item.id, at: date)
        let stored = try #require(try store.dhikr(id: item.id)?.lastOpenedAt)
        #expect(abs(stored.timeIntervalSince(date)) < 0.001)
    }

    @Test func timerDelayHasAMinimumOf100ms() throws {
        let store = try makeStore()
        let item = try store.add(name: "A", loopSize: 1, initialTotal: 0)
        try store.setTimerDelay(40, for: item.id)
        #expect(try store.dhikr(id: item.id)?.timerDelayMs == 100)
        try store.setTimerDelay(2300, for: item.id)
        #expect(try store.dhikr(id: item.id)?.timerDelayMs == 2300)
    }

    // MARK: Persistence on disk

    @Test func dataSurvivesClosingAndReopeningTheFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = folder.appendingPathComponent("masebha.sqlite")
        defer { try? FileManager.default.removeItem(at: folder) }

        var id: Int64 = 0
        do {
            let store = DhikrStore(database: try AppDatabase.open(at: url))
            id = try store.add(name: "Persisted", loopSize: 33, initialTotal: 0).id
            for _ in 0..<7 { try store.applyDelta(1, to: id, day: day) }
        }
        // A brand-new connection, like the next app launch (migrations must not touch the data).
        let reopened = DhikrStore(database: try AppDatabase.open(at: url))
        let item = try #require(try reopened.dhikr(id: id))
        #expect(item.name == "Persisted")
        #expect(item.total == 7)
        #expect(try reopened.todayCount(id: id, day: day) == 7)
    }
}
