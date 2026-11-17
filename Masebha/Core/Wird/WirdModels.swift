import Foundation

/// Progress of one zikr inside a wird (wirdItem.status, same values as Android).
nonisolated enum WirdItemStatus: Int, Sendable {
    case pending = 0
    /// Target reached.
    case done = 1
    /// Finished with "Skip"; tapping it later continues it (it becomes pending again).
    case skipped = 2
}

/// Progress of a wird on one day (wirdDay.state). No row for the day also means "not started".
nonisolated enum WirdDayState: Int, Sendable {
    case notStarted = 0, started = 1, done = 2
}

/// A wird as shown on the list.
nonisolated struct WirdSummary: Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    let itemCount: Int
    /// Done or skipped azkar (shown while the wird is in progress).
    let finishedCount: Int
    let state: WirdDayState
}

/// One zikr of a wird with its current progress.
nonisolated struct WirdItem: Identifiable, Equatable, Sendable {
    let id: Int64
    var body: String
    var target: Int
    var count: Int
    var status: WirdItemStatus
    var timerDelayMs: Int

    var isFinished: Bool { status != .pending }
}

/// A zikr as the editor sends it. `itemID` 0 means a new zikr.
nonisolated struct WirdDraft: Equatable, Sendable {
    var itemID: Int64 = 0
    var body: String
    var target: Int
}

/// A wird to create: its name and azkar (the editor, the default wirds).
nonisolated struct NewWird: Equatable, Sendable {
    var name: String
    var items: [WirdDraft]
}

/// What a tap or a skip did.
nonisolated enum WirdStep: Equatable, Sendable {
    /// Nothing changed (the zikr was already done).
    case ignored
    case counted
    /// This zikr is finished (target reached or skipped); others are still pending.
    case itemFinished
    /// No zikr is pending any more: the wird is done for the day.
    case wirdFinished
}

nonisolated enum WirdError: Error, Equatable {
    case notFound
    case invalidValue
    case listChanged
}
