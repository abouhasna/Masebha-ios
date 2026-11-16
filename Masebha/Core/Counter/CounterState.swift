import Foundation

/// The numbers on the counter screen and the rules that change them (the counting part of
/// MainActivity2 on Android). Pure logic: no UI, no database, fully unit-tested.
///
/// Invariant: `session == current + loops * loopSize` (each tap in this visit is in exactly one place).
nonisolated struct CounterState: Equatable, Sendable {
    /// Lifetime count (mirrors the database).
    var total: Int
    /// Position inside the current loop, 0..<loopSize.
    var current: Int
    /// Loops completed during this visit.
    var loops: Int
    /// Taps in this visit ("jalsa"). Undo and "reset session" act on it.
    var session: Int
    /// Today's count for this dhikr (mirrors the database).
    var today: Int
    let loopSize: Int

    /// State when the screen opens. With "Resume loop", the unfinished loop continues: the current
    /// count and the session both start at `total % loopSize` (Android behavior D1, by design).
    static func opening(total: Int, loopSize: Int, today: Int, resumeLoop: Bool) -> CounterState {
        let size = max(1, loopSize)
        let current = resumeLoop ? max(0, total) % size : 0
        return CounterState(total: max(0, total), current: current, loops: 0, session: current,
                            today: max(0, today), loopSize: size)
    }

    /// One count. Returns true when it completed a loop.
    mutating func tap() -> Bool {
        session += 1
        current += 1
        total += 1
        today += 1
        if current >= loopSize {
            current = 0
            loops += 1
            return true
        }
        return false
    }

    /// Steps back one count. Returns nil when there is nothing to undo, otherwise the change to
    /// apply to the stored counts (-1).
    mutating func undo() -> Int? {
        if current == 0 && loops == 0 { return nil }
        if current > 0 {
            current -= 1
        } else {
            loops -= 1
            current = loopSize - 1
        }
        guard session > 0 else { return 0 }
        session -= 1
        total = max(0, total - 1)
        today = max(0, today - 1)
        return -1
    }

    /// Removes every count of this visit. Returns how many were removed (subtract them when saving).
    mutating func resetSession() -> Int {
        let removed = session
        total = max(0, total - removed)
        today = max(0, today - removed)
        session = 0
        current = 0
        loops = 0
        return removed
    }

    /// Everything to 0, including the lifetime total and today's count.
    mutating func resetAll() {
        total = 0
        today = 0
        session = 0
        current = 0
        loops = 0
    }

    /// Takes the stored values after a save (the database is the source of truth).
    mutating func sync(with snapshot: CountSnapshot) {
        total = snapshot.total
        today = snapshot.today
    }
}
