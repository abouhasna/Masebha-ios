import Foundation
import GRDB

/// One dhikr counter: a row of the `dhikr` table (≈ the `zeker` table / CardData on Android).
nonisolated struct Dhikr: Identifiable, Equatable, Sendable, FetchableRecord {
    var id: Int64
    var name: String
    /// Lifetime count.
    var total: Int
    /// Beads per loop ("dawra"). Always > 0.
    var loopSize: Int
    /// 0-based order in the list.
    var position: Int
    /// When the counter screen was last opened; nil = never.
    var lastOpenedAt: Date?
    /// Auto-timer interval for this dhikr, in milliseconds (>= 100).
    var timerDelayMs: Int

    init(id: Int64, name: String, total: Int, loopSize: Int, position: Int, lastOpenedAt: Date?, timerDelayMs: Int) {
        self.id = id
        self.name = name
        self.total = total
        self.loopSize = loopSize
        self.position = position
        self.lastOpenedAt = lastOpenedAt
        self.timerDelayMs = timerDelayMs
    }

    init(row: Row) throws {
        id = row["id"]
        name = row["name"]
        total = row["total"]
        loopSize = row["loopSize"]
        position = row["position"]
        let openedMs: Int64? = row["lastOpenedAt"]
        lastOpenedAt = openedMs.map { Date(timeIntervalSince1970: Double($0) / 1000) }
        timerDelayMs = row["timerDelayMs"]
    }
}

/// The counts after a change, read back from the database (the single source of truth).
nonisolated struct CountSnapshot: Equatable, Sendable {
    let total: Int
    let today: Int
}

nonisolated enum StoreError: Error, Equatable {
    case dhikrNotFound
    case invalidValue
    case listChanged
}
