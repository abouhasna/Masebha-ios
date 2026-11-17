import Foundation
import Testing
@testable import Masebha

/// The Wird data rules (same as Android's WirdStore), checked against the stored rows.
struct WirdStoreTests {
    private let day1 = "2026-11-16"
    private let day2 = "2026-11-17"
    private let day3 = "2026-11-18"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Fixture {
        let store: WirdStore
        let raw: BackupStore   // reads the tables exactly as stored
    }

    private func makeFixture() throws -> Fixture {
        let database = try AppDatabase.inMemory()
        return Fixture(store: WirdStore(database: database), raw: BackupStore(database: database))
    }

    private func wird(_ name: String = "Morning", targets: [Int] = [3, 1, 2]) -> NewWird {
        NewWird(name: name, items: targets.enumerated().map { WirdDraft(body: "Zikr \($0.offset)", target: $0.element) })
    }

    private func day(_ fixture: Fixture, _ id: Int64, _ day: String) throws -> WirdBackup.Day? {
        try fixture.raw.read().wird?.days.first { $0.wirdID == id && $0.day == day }
    }

    private func tapAll(_ fixture: Fixture, _ id: Int64, item: WirdItem, day: String, times: Int) throws -> WirdStep {
        var step = WirdStep.ignored
        for _ in 0..<times { step = try fixture.store.tap(item: item.id, of: id, day: day, now: now).step }
        return step
    }

    // MARK: The list

    @Test func addAppendsAtTheEnd() throws {
        let fixture = try makeFixture()
        let first = try fixture.store.add(wird("A"), now: now)
        let second = try fixture.store.add(wird("B", targets: [7]), now: now)
        let list = try fixture.store.summaries(day: day1)
        #expect(list.map(\.id) == [first, second])
        #expect(list.map(\.name) == ["A", "B"])
        #expect(list.map(\.itemCount) == [3, 1])
        #expect(list.allSatisfy { $0.state == .notStarted && $0.finishedCount == 0 })
        let drafts = try fixture.store.drafts(of: second)
        #expect(drafts.map(\.body) == ["Zikr 0"])
        #expect(drafts.map(\.target) == [7])
        #expect(drafts[0].itemID > 0)
    }

    @Test(arguments: [
        NewWird(name: "  ", items: [WirdDraft(body: "x", target: 1)]),
        NewWird(name: "A", items: []),
        NewWird(name: "A", items: [WirdDraft(body: " ", target: 1)]),
        NewWird(name: "A", items: [WirdDraft(body: "x", target: 0)]),
        NewWird(name: "A", items: [WirdDraft(body: "x", target: 100_000)]),
    ])
    func invalidWirdsAreRejected(_ invalid: NewWird) throws {
        let fixture = try makeFixture()
        #expect(throws: WirdError.invalidValue) { try fixture.store.add(invalid, now: now) }
        #expect(try fixture.store.summaries(day: day1).isEmpty)
    }

    @Test func addAllIsAllOrNothing() throws {
        let fixture = try makeFixture()
        #expect(throws: WirdError.invalidValue) {
            try fixture.store.addAll([wird("A"), NewWird(name: "B", items: [])], now: now)
        }
        #expect(try fixture.store.summaries(day: day1).isEmpty)
        try fixture.store.addAll([wird("A"), wird("B")], now: now)
        #expect(try fixture.store.summaries(day: day1).map(\.name) == ["A", "B"])
    }

    @Test func deleteIsSoftAndKeepsTheHistory() throws {
        let fixture = try makeFixture()
        let a = try fixture.store.add(wird("A"), now: now)
        let b = try fixture.store.add(wird("B"), now: now)
        let items = try fixture.store.open(a, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: a, day: day1, now: now)

        try fixture.store.delete(id: a)
        #expect(try fixture.store.summaries(day: day1).map(\.id) == [b])
        #expect(try fixture.store.name(of: a) == nil)
        let stored = try #require(try fixture.raw.read().wird)
        #expect(stored.wirds.first { $0.id == a }?.deleted == true)    // the row stays…
        #expect(try day(fixture, a, day1)?.taps == 1)                  // …with its statistics
        #expect(stored.items.allSatisfy { $0.wirdID != a })            // only the progress rows go
        #expect(stored.wirds.first { $0.id == b }?.position == 0)      // positions closed up
        #expect(throws: WirdError.notFound) { try fixture.store.open(a, day: day1, carryOver: false, now: now) }
        #expect(throws: WirdError.notFound) { try fixture.store.delete(id: a) }
    }

    @Test func reorderNeedsExactlyTheListedWirds() throws {
        let fixture = try makeFixture()
        let a = try fixture.store.add(wird("A"), now: now)
        let b = try fixture.store.add(wird("B"), now: now)
        let c = try fixture.store.add(wird("C"), now: now)
        try fixture.store.reorder([c, a, b])
        #expect(try fixture.store.summaries(day: day1).map(\.id) == [c, a, b])
        #expect(throws: WirdError.listChanged) { try fixture.store.reorder([c, a]) }
        #expect(throws: WirdError.listChanged) { try fixture.store.reorder([c, a, a]) }
        try fixture.store.delete(id: b)
        try fixture.store.reorder([a, c])   // a deleted wird is not part of the order
        #expect(try fixture.store.summaries(day: day1).map(\.id) == [a, c])
    }

    // MARK: Taps, skip, completion

    @Test func tapsCountUntilTheTargetThenAreIgnored() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [2, 1]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        #expect(try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now).step == .counted)
        let second = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        #expect(second.step == .itemFinished)
        #expect(second.item.count == 2 && second.item.status == .done)
        #expect(try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now).step == .ignored)
        #expect(try day(fixture, id, day1)?.taps == 2)   // the ignored tap is not counted
        #expect(try fixture.store.summaries(day: day1).first?.state == .started)
        #expect(try fixture.store.summaries(day: day1).first?.finishedCount == 1)
    }

    @Test func theLastZikrFinishesTheWirdOnce() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [1, 1]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        #expect(try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now).step == .itemFinished)
        let later = now.addingTimeInterval(60)
        #expect(try fixture.store.tap(item: items[1].id, of: id, day: day1, now: later).step == .wirdFinished)
        let record = try #require(try day(fixture, id, day1))
        #expect(record.state == WirdDayState.done.rawValue)
        #expect(record.completedAt == WirdStore.ms(later))
        #expect(try fixture.store.summaries(day: day1).first?.state == .done)
    }

    @Test func skipFinishesAZikrAndTappingItContinuesIt() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [3, 1]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        let skipped = try fixture.store.skip(item: items[0].id, of: id, day: day1, now: now)
        #expect(skipped.step == .itemFinished && skipped.item.status == .skipped)
        #expect(try fixture.store.skip(item: items[0].id, of: id, day: day1, now: now).step == .ignored)
        #expect(try day(fixture, id, day1)?.taps == 0)   // a skip is not a tap
        #expect(try day(fixture, id, day1)?.state == WirdDayState.started.rawValue)

        let tapped = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        #expect(tapped.step == .counted)
        #expect(tapped.item.status == .pending && tapped.item.count == 1)   // pending again
    }

    @Test func skippingTheLastPendingZikrFinishesTheWird() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [1, 5]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        #expect(try fixture.store.skip(item: items[1].id, of: id, day: day1, now: now).step == .wirdFinished)
        #expect(try day(fixture, id, day1)?.state == WirdDayState.done.rawValue)
    }

    @Test func tapsAfterMidnightCountForTheDayTheSessionStarted() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [5]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now.addingTimeInterval(86_400))
        #expect(try day(fixture, id, day1)?.taps == 1)
        #expect(try day(fixture, id, day2) == nil)
    }

    @Test func totalTapsNeverGoBack() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [5]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try tapAll(fixture, id, item: items[0], day: day1, times: 3)
        try fixture.store.resetDay(id, day: day1)
        _ = try tapAll(fixture, id, item: items[0], day: day1, times: 2)
        let stored = try #require(try fixture.raw.read().wird?.items.first)
        #expect(stored.totalTaps == 5)
        #expect(stored.count == 2)
        #expect(try day(fixture, id, day1)?.taps == 5)   // the day's taps survive a reset
    }

    @Test func aMissingZikrIsReported() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(), now: now)
        _ = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        #expect(throws: WirdError.notFound) { try fixture.store.tap(item: 9_999, of: id, day: day1, now: now) }
    }

    // MARK: The day lifecycle

    @Test func aNewDayStartsFromZero() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [1, 1]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        _ = try fixture.store.tap(item: items[1].id, of: id, day: day1, now: now)   // done on day 1
        #expect(try fixture.store.hasUnfinishedEarlierDay(id, day: day2) == false)   // finished: no question

        let today = try fixture.store.open(id, day: day2, carryOver: false, now: now)
        #expect(today.allSatisfy { $0.count == 0 && $0.status == .pending })
        #expect(try day(fixture, id, day1)?.state == WirdDayState.done.rawValue)    // history kept
        #expect(try day(fixture, id, day2)?.state == WirdDayState.notStarted.rawValue)
    }

    @Test func openingAgainTheSameDayKeepsProgress() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [3]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        let again = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        #expect(again[0].count == 1)
    }

    @Test func anUnfinishedEarlierDayAsksAndContinueKeepsProgress() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [3, 2]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)

        #expect(try fixture.store.hasUnfinishedEarlierDay(id, day: day3) == true)   // even two days later
        let continued = try fixture.store.open(id, day: day3, carryOver: true, now: now)
        #expect(continued[0].count == 1)
        #expect(try day(fixture, id, day3)?.state == WirdDayState.started.rawValue)
        #expect(try day(fixture, id, day3)?.taps == 0)   // no tap is counted twice
        #expect(try fixture.store.hasUnfinishedEarlierDay(id, day: day3) == false)   // asked once per day
    }

    @Test func startOverClearsTheProgress() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [3]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        let restarted = try fixture.store.open(id, day: day2, carryOver: false, now: now)
        #expect(restarted[0].count == 0)
        #expect(try day(fixture, id, day1)?.taps == 1)
    }

    @Test func resetTodayPreventsTheQuestionLater() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [3]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        // Reset from the list on day 2, without opening the wird first.
        try fixture.store.resetDay(id, day: day2)
        #expect(try fixture.store.hasUnfinishedEarlierDay(id, day: day2) == false)
        #expect(try fixture.store.hasUnfinishedEarlierDay(id, day: day3) == false)
        #expect(try fixture.store.items(of: id).allSatisfy { $0.count == 0 })
    }

    // MARK: Editing (Android rules)

    @Test func editingTheTextKeepsProgressAndATargetChangeRestartsThatZikr() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [3, 3]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        _ = try fixture.store.tap(item: items[1].id, of: id, day: day1, now: now)

        try fixture.store.update(id: id, with: NewWird(name: "Renamed", items: [
            WirdDraft(itemID: items[0].id, body: "New text", target: 3),   // text only: progress kept
            WirdDraft(itemID: items[1].id, body: "Zikr 1", target: 10),    // new target: restarted
        ]), day: day1, now: now)

        let edited = try fixture.store.items(of: id)
        #expect(edited.map(\.id) == items.map(\.id))
        #expect(edited[0].body == "New text" && edited[0].count == 1)
        #expect(edited[1].target == 10 && edited[1].count == 0)
        #expect(try fixture.store.name(of: id) == "Renamed")
    }

    @Test func editingRemovesAddsAndReordersAzkar() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [1, 2, 3]), now: now)
        let items = try fixture.store.items(of: id)
        try fixture.store.update(id: id, with: NewWird(name: "Morning", items: [
            WirdDraft(itemID: items[2].id, body: "Zikr 2", target: 3),
            WirdDraft(body: "Brand new", target: 4),
        ]), day: day1, now: now)
        let edited = try fixture.store.items(of: id)
        #expect(edited.count == 2)
        #expect(edited[0].id == items[2].id)
        #expect(edited[1].body == "Brand new" && edited[1].target == 4)
        #expect(!edited.contains { $0.id == items[0].id || $0.id == items[1].id })
    }

    @Test func editingRecomputesTodaysState() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [1, 5]), now: now)
        let items = try fixture.store.open(id, day: day1, carryOver: false, now: now)
        _ = try fixture.store.tap(item: items[0].id, of: id, day: day1, now: now)
        // Removing the only pending zikr: the wird is done for today.
        try fixture.store.update(id: id, with: NewWird(name: "Morning", items: [
            WirdDraft(itemID: items[0].id, body: "Zikr 0", target: 1),
        ]), day: day1, now: now)
        #expect(try day(fixture, id, day1)?.state == WirdDayState.done.rawValue)
    }

    @Test func aForeignItemIdIsInsertedAsNew() throws {
        let fixture = try makeFixture()
        let a = try fixture.store.add(wird("A", targets: [1]), now: now)
        let b = try fixture.store.add(wird("B", targets: [1]), now: now)
        let itemOfB = try fixture.store.items(of: b)[0].id
        try fixture.store.update(id: a, with: NewWird(name: "A", items: [WirdDraft(itemID: itemOfB, body: "x", target: 2)]),
                                 day: day1, now: now)
        #expect(try fixture.store.items(of: b).count == 1)   // B is untouched
        #expect(try fixture.store.items(of: a).map(\.body) == ["x"])
    }

    @Test func timerDelayIsSavedWithTheMinimum() throws {
        let fixture = try makeFixture()
        let id = try fixture.store.add(wird(targets: [1]), now: now)
        let item = try fixture.store.items(of: id)[0]
        #expect(item.timerDelayMs == 1000)
        try fixture.store.setTimerDelay(30, forItem: item.id)
        #expect(try fixture.store.items(of: id)[0].timerDelayMs == TimerDelay.minimumMs)
        try fixture.store.setTimerDelay(2500, forItem: item.id)
        #expect(try fixture.store.items(of: id)[0].timerDelayMs == 2500)
    }
}
