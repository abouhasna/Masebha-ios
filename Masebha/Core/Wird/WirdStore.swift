import Foundation
import GRDB

/// All reads and writes of the Wird feature (≈ WirdStore.java, same rules).
///
/// Key rule: a wird's item progress (`count`, `status`) always belongs to the last day the wird
/// was opened. The first open on a new day (`open`) either keeps it ("continue") or clears it.
/// Every change runs in one transaction. Times are epoch milliseconds.
nonisolated final class WirdStore: Sendable {
    private let database: AppDatabase
    private var writer: any DatabaseWriter { database.writer }

    static let maximumTarget = 99_999   // 5 digits, like Android

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: The list

    func summaries(day: String) throws -> [WirdSummary] {
        try writer.read { db in
            try Row.fetchAll(db, sql: """
                SELECT w.id, w.name,
                       (SELECT COUNT(*) FROM wirdItem i WHERE i.wirdId = w.id) AS itemCount,
                       (SELECT COUNT(*) FROM wirdItem i WHERE i.wirdId = w.id AND i.status != 0) AS finished,
                       COALESCE(d.state, 0) AS state
                FROM wird w LEFT JOIN wirdDay d ON d.wirdId = w.id AND d.day = ?
                WHERE w.deleted = 0
                ORDER BY w.position, w.id
                """, arguments: [day]).map { row in
                WirdSummary(id: row["id"], name: row["name"], itemCount: row["itemCount"],
                            finishedCount: row["finished"],
                            state: WirdDayState(rawValue: row["state"]) ?? .notStarted)
            }
        }
    }

    /// The wird's name, or nil if it does not exist or was deleted.
    func name(of id: Int64) throws -> String? {
        try writer.read { db in
            try String.fetchOne(db, sql: "SELECT name FROM wird WHERE id = ? AND deleted = 0", arguments: [id])
        }
    }

    /// The editor's starting point.
    func drafts(of id: Int64) throws -> [WirdDraft] {
        try writer.read { db in
            try Row.fetchAll(db, sql: "SELECT id, body, target FROM wirdItem WHERE wirdId = ? ORDER BY position, id",
                             arguments: [id]).map { WirdDraft(itemID: $0["id"], body: $0["body"], target: $0["target"]) }
        }
    }

    // MARK: Creating and editing

    @discardableResult
    func add(_ wird: NewWird, now: Date) throws -> Int64 {
        try Self.validate(wird)
        return try writer.write { db in try Self.insert(wird, db: db, now: now) }
    }

    /// Several wirds at once, appended at the end: all are written or none (the default wirds).
    func addAll(_ wirds: [NewWird], now: Date) throws {
        for wird in wirds { try Self.validate(wird) }
        try writer.write { db in
            for wird in wirds { try Self.insert(wird, db: db, now: now) }
        }
    }

    /// Edits a wird in place (Android rules): a zikr that keeps its id keeps its progress, even if
    /// its text changes; changing its target restarts that zikr; removed azkar are deleted and new
    /// ones inserted. Today's state is recomputed.
    func update(id: Int64, with wird: NewWird, day: String, now: Date) throws {
        try Self.validate(wird)
        try writer.write { db in
            try db.execute(sql: "UPDATE wird SET name = ? WHERE id = ? AND deleted = 0", arguments: [wird.name, id])
            guard db.changesCount == 1 else { throw WirdError.notFound }

            var targets: [Int64: Int] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT id, target FROM wirdItem WHERE wirdId = ?", arguments: [id]) {
                let itemID: Int64 = row["id"]
                let target: Int = row["target"]
                targets[itemID] = target
            }
            var kept = Set<Int64>()
            for (position, item) in wird.items.enumerated() {
                if let oldTarget = targets[item.itemID], !kept.contains(item.itemID) {
                    let restart = oldTarget != item.target
                    try db.execute(sql: """
                        UPDATE wirdItem SET position = ?, body = ?, target = ?,
                               count = CASE WHEN ? THEN 0 ELSE count END,
                               status = CASE WHEN ? THEN 0 ELSE status END
                        WHERE id = ?
                        """, arguments: [position, item.body, item.target, restart, restart, item.itemID])
                    kept.insert(item.itemID)
                } else {
                    try Self.insertItem(item, wirdID: id, position: position, db: db)
                }
            }
            for itemID in targets.keys where !kept.contains(itemID) {
                try db.execute(sql: "DELETE FROM wirdItem WHERE id = ?", arguments: [itemID])
            }
            _ = try Self.syncDayState(wirdID: id, day: day, db: db, now: now)
        }
    }

    /// Soft delete (Android): the wird leaves the list, its day history is kept for statistics,
    /// its azkar (only current progress) are removed.
    func delete(id: Int64) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE wird SET deleted = 1 WHERE id = ? AND deleted = 0", arguments: [id])
            guard db.changesCount == 1 else { throw WirdError.notFound }
            try db.execute(sql: "DELETE FROM wirdItem WHERE wirdId = ?", arguments: [id])
            try Self.renumber(db)
        }
    }

    /// Saves a new order. `orderedIDs` must contain exactly the listed (not deleted) wirds.
    func reorder(_ orderedIDs: [Int64]) throws {
        try writer.write { db in
            let current = try Int64.fetchAll(db, sql: "SELECT id FROM wird WHERE deleted = 0")
            guard current.count == orderedIDs.count, Set(current) == Set(orderedIDs) else {
                throw WirdError.listChanged
            }
            for (position, id) in orderedIDs.enumerated() {
                try db.execute(sql: "UPDATE wird SET position = ? WHERE id = ?", arguments: [position, id])
            }
        }
    }

    func markOpened(_ id: Int64, at date: Date) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE wird SET lastOpenedAt = ? WHERE id = ?", arguments: [Self.ms(date), id])
        }
    }

    func setTimerDelay(_ milliseconds: Int, forItem itemID: Int64) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE wirdItem SET timerDelayMs = ? WHERE id = ?",
                           arguments: [max(TimerDelay.minimumMs, milliseconds), itemID])
        }
    }

    // MARK: A day of a wird

    /// True when the wird was not opened yet `day`, and the last earlier day it was opened was left
    /// unfinished. The session then asks: continue where you stopped, or start over?
    func hasUnfinishedEarlierDay(_ id: Int64, day: String) throws -> Bool {
        try writer.read { db in
            let openedToday = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM wirdDay WHERE wirdId = ? AND day = ?)",
                                                arguments: [id, day]) ?? false
            guard !openedToday else { return false }
            let previous = try Int.fetchOne(db, sql: """
                SELECT state FROM wirdDay WHERE wirdId = ? AND day < ? ORDER BY day DESC LIMIT 1
                """, arguments: [id, day])
            return previous == WirdDayState.started.rawValue
        }
    }

    /// Opens the wird for `day` and returns its azkar. The first open of a day creates the day's
    /// row and either keeps the progress (`carryOver`, "Continue") or clears it. Opening it again
    /// the same day changes nothing.
    func open(_ id: Int64, day: String, carryOver: Bool, now: Date) throws -> [WirdItem] {
        try writer.write { db in
            let exists = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM wird WHERE id = ? AND deleted = 0)",
                                           arguments: [id]) ?? false
            guard exists else { throw WirdError.notFound }
            try db.execute(sql: "INSERT OR IGNORE INTO wirdDay (wirdId, day) VALUES (?, ?)", arguments: [id, day])
            if db.changesCount == 1 {
                if carryOver {
                    _ = try Self.syncDayState(wirdID: id, day: day, db: db, now: now)
                } else {
                    try db.execute(sql: "UPDATE wirdItem SET count = 0, status = 0 WHERE wirdId = ?", arguments: [id])
                }
            }
            return try Self.items(of: id, db: db)
        }
    }

    func items(of id: Int64) throws -> [WirdItem] {
        try writer.read { db in try Self.items(of: id, db: db) }
    }

    /// One tap, counted toward `day` (the day the session started). Accepted on a pending or a
    /// skipped zikr until it reaches its target. Returns what happened and the zikr as stored.
    func tap(item itemID: Int64, of wirdID: Int64, day: String, now: Date) throws -> (step: WirdStep, item: WirdItem) {
        try writer.write { db in
            let item = try Self.item(itemID, wirdID: wirdID, db: db)
            guard item.status != .done, item.count < item.target else { return (.ignored, item) }
            let count = item.count + 1
            let finished = count >= item.target
            try db.execute(sql: "UPDATE wirdItem SET count = ?, status = ?, totalTaps = totalTaps + 1 WHERE id = ?",
                           arguments: [count, finished ? WirdItemStatus.done.rawValue : WirdItemStatus.pending.rawValue, itemID])
            try Self.markActivity(wirdID: wirdID, day: day, taps: 1, db: db, now: now)
            let state = try Self.syncDayState(wirdID: wirdID, day: day, db: db, now: now)
            let step: WirdStep = !finished ? .counted : (state == .done ? .wirdFinished : .itemFinished)
            let updated = try Self.item(itemID, wirdID: wirdID, db: db)
            return (step, updated)
        }
    }

    /// Marks a pending zikr as skipped: it counts as finished, and tapping it later continues it.
    func skip(item itemID: Int64, of wirdID: Int64, day: String, now: Date) throws -> (step: WirdStep, item: WirdItem) {
        try writer.write { db in
            let item = try Self.item(itemID, wirdID: wirdID, db: db)
            guard item.status == .pending else { return (.ignored, item) }
            try db.execute(sql: "UPDATE wirdItem SET status = ? WHERE id = ?",
                           arguments: [WirdItemStatus.skipped.rawValue, itemID])
            try Self.markActivity(wirdID: wirdID, day: day, taps: 0, db: db, now: now)
            let state = try Self.syncDayState(wirdID: wirdID, day: day, db: db, now: now)
            let updated = try Self.item(itemID, wirdID: wirdID, db: db)
            return (state == .done ? .wirdFinished : .itemFinished, updated)
        }
    }

    /// Starts the wird over for `day`: all progress cleared, the day back to "not started".
    /// The day's tap count is kept (those taps happened). Creates the day's row if needed, so an
    /// older unfinished day does not trigger "Continue?" later.
    func resetDay(_ id: Int64, day: String) throws {
        try writer.write { db in
            try db.execute(sql: "INSERT OR IGNORE INTO wirdDay (wirdId, day) VALUES (?, ?)", arguments: [id, day])
            try db.execute(sql: "UPDATE wirdItem SET count = 0, status = 0 WHERE wirdId = ?", arguments: [id])
            try db.execute(sql: "UPDATE wirdDay SET state = 0, completedAt = 0 WHERE wirdId = ? AND day = ?",
                           arguments: [id, day])
        }
    }

    // MARK: Helpers (inside a transaction)

    static func validate(_ wird: NewWird) throws {
        guard !wird.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !wird.items.isEmpty,
              wird.items.allSatisfy({ !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && (1...maximumTarget).contains($0.target) }) else {
            throw WirdError.invalidValue
        }
    }

    @discardableResult
    private static func insert(_ wird: NewWird, db: Database, now: Date) throws -> Int64 {
        let position = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(position) + 1, 0) FROM wird WHERE deleted = 0") ?? 0
        try db.execute(sql: "INSERT INTO wird (name, position, createdAt) VALUES (?, ?, ?)",
                       arguments: [wird.name, position, ms(now)])
        let id = db.lastInsertedRowID
        for (index, item) in wird.items.enumerated() {
            try insertItem(item, wirdID: id, position: index, db: db)
        }
        return id
    }

    private static func insertItem(_ item: WirdDraft, wirdID: Int64, position: Int, db: Database) throws {
        try db.execute(sql: "INSERT INTO wirdItem (wirdId, position, body, target) VALUES (?, ?, ?, ?)",
                       arguments: [wirdID, position, item.body, item.target])
    }

    private static func items(of id: Int64, db: Database) throws -> [WirdItem] {
        try Row.fetchAll(db, sql: """
            SELECT id, body, target, count, status, timerDelayMs FROM wirdItem
            WHERE wirdId = ? ORDER BY position, id
            """, arguments: [id]).map(makeItem)
    }

    private static func item(_ itemID: Int64, wirdID: Int64, db: Database) throws -> WirdItem {
        guard let row = try Row.fetchOne(db, sql: """
            SELECT id, body, target, count, status, timerDelayMs FROM wirdItem WHERE id = ? AND wirdId = ?
            """, arguments: [itemID, wirdID]) else {
            throw WirdError.notFound
        }
        return makeItem(row)
    }

    private static func makeItem(_ row: Row) -> WirdItem {
        WirdItem(id: row["id"], body: row["body"], target: row["target"], count: row["count"],
                 status: WirdItemStatus(rawValue: row["status"]) ?? .pending,
                 timerDelayMs: TimerDelay.sanitized(row["timerDelayMs"]))
    }

    /// Derives the day's state from the azkar and stores it (no-op if the day has no row):
    /// nothing pending → done (completion time kept if already set); some progress → started;
    /// otherwise not started.
    private static func syncDayState(wirdID: Int64, day: String, db: Database, now: Date) throws -> WirdDayState {
        var total = 0, pending = 0, progressed = 0
        if let row = try Row.fetchOne(db, sql: """
            SELECT COUNT(*) AS total,
                   COALESCE(SUM(status = 0), 0) AS pending,
                   COALESCE(SUM(count > 0 OR status != 0), 0) AS progressed
            FROM wirdItem WHERE wirdId = ?
            """, arguments: [wirdID]) {
            total = row["total"]
            pending = row["pending"]
            progressed = row["progressed"]
        }
        let state: WirdDayState = total > 0 && pending == 0 ? .done : (progressed > 0 ? .started : .notStarted)

        var completedAt: Int64 = 0
        if state == .done {
            completedAt = try Int64.fetchOne(db, sql: "SELECT completedAt FROM wirdDay WHERE wirdId = ? AND day = ?",
                                             arguments: [wirdID, day]) ?? 0
            if completedAt == 0 { completedAt = ms(now) }
        }
        try db.execute(sql: "UPDATE wirdDay SET state = ?, completedAt = ? WHERE wirdId = ? AND day = ?",
                       arguments: [state.rawValue, completedAt, wirdID, day])
        return state
    }

    private static func markActivity(wirdID: Int64, day: String, taps: Int, db: Database, now: Date) throws {
        try db.execute(sql: """
            UPDATE wirdDay SET taps = taps + ?, lastActivityAt = ?,
                   state = CASE WHEN state = 0 THEN 1 ELSE state END
            WHERE wirdId = ? AND day = ?
            """, arguments: [taps, ms(now), wirdID, day])
    }

    private static func renumber(_ db: Database) throws {
        let ids = try Int64.fetchAll(db, sql: "SELECT id FROM wird WHERE deleted = 0 ORDER BY position, id")
        for (position, id) in ids.enumerated() {
            try db.execute(sql: "UPDATE wird SET position = ? WHERE id = ?", arguments: [position, id])
        }
    }

    static func ms(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
