import Foundation
import GRDB

/// All reads and writes of the adhkar and their daily counts (≈ the SQL in MainActivity,
/// MainActivity2 and CounterStore on Android).
///
/// Rules that protect the data:
/// - Every change that touches several rows runs in one transaction: it fully happens or not at all.
/// - Counts are changed with "add N" (`total = total + N`), never by writing a number held by a
///   screen, so an out-of-date screen can never overwrite newer counts (fixes Android issue D2).
/// - Counts never go below 0, and the loop size is always > 0 (also enforced by the schema).
nonisolated final class DhikrStore: Sendable {
    private let database: AppDatabase
    private var writer: any DatabaseWriter { database.writer }

    static let minimumTimerDelayMs = 100
    static let defaultTimerDelayMs = 1000

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: Reading

    func allDhikr() throws -> [Dhikr] {
        try writer.read { db in
            try Dhikr.fetchAll(db, sql: "SELECT * FROM dhikr ORDER BY position, id")
        }
    }

    func dhikr(id: Int64) throws -> Dhikr? {
        try writer.read { db in
            try Dhikr.fetchOne(db, sql: "SELECT * FROM dhikr WHERE id = ?", arguments: [id])
        }
    }

    /// Sum of all lifetime counts (the "Total" in the More tab).
    func grandTotal() throws -> Int {
        try writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(total), 0) FROM dhikr") ?? 0
        }
    }

    func todayCount(id: Int64, day: String) throws -> Int {
        try writer.read { db in
            try Int.fetchOne(db, sql: "SELECT count FROM dailyCount WHERE dhikrId = ? AND day = ?",
                             arguments: [id, day]) ?? 0
        }
    }

    /// The ids just before and after `id` in list order (nil at the ends).
    func neighbors(of id: Int64) throws -> (previous: Int64?, next: Int64?) {
        let ids = try writer.read { db in
            try Int64.fetchAll(db, sql: "SELECT id FROM dhikr ORDER BY position, id")
        }
        guard let index = ids.firstIndex(of: id) else { return (nil, nil) }
        let previous = index > 0 ? ids[index - 1] : nil
        let next = index + 1 < ids.count ? ids[index + 1] : nil
        return (previous, next)
    }

    // MARK: Creating and editing

    /// Creates the starter adhkar, only if the list is completely empty. Returns whether it did.
    @discardableResult
    func seedIfEmpty(_ items: [(name: String, loopSize: Int)]) throws -> Bool {
        try writer.write { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM dhikr") ?? 0
            guard count == 0 else { return false }
            for (index, item) in items.enumerated() {
                try db.execute(sql: "INSERT INTO dhikr (name, total, loopSize, position) VALUES (?, 0, ?, ?)",
                               arguments: [item.name, item.loopSize, index])
            }
            return true
        }
    }

    /// Adds a dhikr at the end of the list.
    func add(name: String, loopSize: Int, initialTotal: Int) throws -> Dhikr {
        guard !name.isEmpty, loopSize > 0, initialTotal >= 0 else { throw StoreError.invalidValue }
        return try writer.write { db in
            let position = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(position) + 1, 0) FROM dhikr") ?? 0
            try db.execute(sql: "INSERT INTO dhikr (name, total, loopSize, position) VALUES (?, ?, ?, ?)",
                           arguments: [name, initialTotal, loopSize, position])
            let id = db.lastInsertedRowID
            guard let created = try Dhikr.fetchOne(db, sql: "SELECT * FROM dhikr WHERE id = ?", arguments: [id]) else {
                throw StoreError.dhikrNotFound
            }
            return created
        }
    }

    /// Edits the name, loop size and total (the total is directly editable, like on Android).
    func update(id: Int64, name: String, loopSize: Int, total: Int) throws {
        guard !name.isEmpty, loopSize > 0, total >= 0 else { throw StoreError.invalidValue }
        try writer.write { db in
            try db.execute(sql: "UPDATE dhikr SET name = ?, loopSize = ?, total = ? WHERE id = ?",
                           arguments: [name, loopSize, total, id])
            guard db.changesCount == 1 else { throw StoreError.dhikrNotFound }
        }
    }

    /// Deletes a dhikr (its daily counts go with it) and closes the gap in the positions.
    func delete(id: Int64) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM dhikr WHERE id = ?", arguments: [id])
            guard db.changesCount == 1 else { throw StoreError.dhikrNotFound }
            try Self.renumberPositions(db)
        }
    }

    /// Saves a new list order. `orderedIDs` must contain exactly the current adhkar.
    func reorder(_ orderedIDs: [Int64]) throws {
        try writer.write { db in
            let current = try Int64.fetchAll(db, sql: "SELECT id FROM dhikr")
            guard Set(current) == Set(orderedIDs), current.count == orderedIDs.count else {
                throw StoreError.listChanged
            }
            for (index, id) in orderedIDs.enumerated() {
                try db.execute(sql: "UPDATE dhikr SET position = ? WHERE id = ?", arguments: [index, id])
            }
        }
    }

    // MARK: Counting

    /// Adds `delta` (may be negative) to the lifetime total and to `day`'s count, both floored at 0.
    /// Returns the stored values afterwards.
    @discardableResult
    func applyDelta(_ delta: Int, to id: Int64, day: String) throws -> CountSnapshot {
        try writer.write { db in
            try db.execute(sql: "UPDATE dhikr SET total = MAX(0, total + ?) WHERE id = ?", arguments: [delta, id])
            guard db.changesCount == 1 else { throw StoreError.dhikrNotFound }
            if delta != 0 {
                try db.execute(sql: "INSERT OR IGNORE INTO dailyCount (dhikrId, day, count) VALUES (?, ?, 0)",
                               arguments: [id, day])
                try db.execute(sql: "UPDATE dailyCount SET count = MAX(0, count + ?) WHERE dhikrId = ? AND day = ?",
                               arguments: [delta, id, day])
            }
            return try Self.snapshot(db, id: id, day: day)
        }
    }

    /// Sets the lifetime total and `day`'s count to 0. Older days are history and are kept.
    @discardableResult
    func resetCount(of id: Int64, day: String) throws -> CountSnapshot {
        try writer.write { db in
            try db.execute(sql: "UPDATE dhikr SET total = 0 WHERE id = ?", arguments: [id])
            guard db.changesCount == 1 else { throw StoreError.dhikrNotFound }
            try db.execute(sql: "UPDATE dailyCount SET count = 0 WHERE dhikrId = ? AND day = ?", arguments: [id, day])
            return try Self.snapshot(db, id: id, day: day)
        }
    }

    /// "Reset all": every lifetime total and every count of `day` go to 0.
    func resetAll(day: String) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE dhikr SET total = 0")
            try db.execute(sql: "UPDATE dailyCount SET count = 0 WHERE day = ?", arguments: [day])
        }
    }

    /// Records that the counter screen was open at `date`.
    func markOpened(_ id: Int64, at date: Date) throws {
        let ms = Int64((date.timeIntervalSince1970 * 1000).rounded())
        try writer.write { db in
            try db.execute(sql: "UPDATE dhikr SET lastOpenedAt = ? WHERE id = ?", arguments: [ms, id])
        }
    }

    /// Saves this dhikr's auto-timer interval (raised to the 100 ms minimum).
    func setTimerDelay(_ milliseconds: Int, for id: Int64) throws {
        let value = max(Self.minimumTimerDelayMs, milliseconds)
        try writer.write { db in
            try db.execute(sql: "UPDATE dhikr SET timerDelayMs = ? WHERE id = ?", arguments: [value, id])
        }
    }

    // MARK: Helpers (inside a transaction)

    private static func snapshot(_ db: Database, id: Int64, day: String) throws -> CountSnapshot {
        let total = try Int.fetchOne(db, sql: "SELECT total FROM dhikr WHERE id = ?", arguments: [id]) ?? 0
        let today = try Int.fetchOne(db, sql: "SELECT count FROM dailyCount WHERE dhikrId = ? AND day = ?",
                                     arguments: [id, day]) ?? 0
        return CountSnapshot(total: total, today: today)
    }

    private static func renumberPositions(_ db: Database) throws {
        let ids = try Int64.fetchAll(db, sql: "SELECT id FROM dhikr ORDER BY position, id")
        for (index, id) in ids.enumerated() {
            try db.execute(sql: "UPDATE dhikr SET position = ? WHERE id = ?", arguments: [index, id])
        }
    }
}
