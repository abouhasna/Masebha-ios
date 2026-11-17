import Foundation
import Observation

/// State and actions of the wird session screen (≈ WirdSessionActivity).
///
/// - Every tap and skip is saved first; the screen then shows the stored zikr.
/// - `day` is fixed when the screen opens: taps after midnight still count for that day.
/// - Previous / next only change the zikr on screen, never the progress.
@Observable
final class WirdSessionModel {
    enum Phase: Equatable {
        /// The wird was left unfinished on an earlier day: continue or start over?
        case askContinue
        case counting
        /// No zikr is pending any more; the screen closes after a short "done" message.
        case finished
    }

    enum Problem: Identifiable {
        case missing, saveFailed
        var id: Self { self }
    }

    let wirdID: Int64
    let day: String
    private(set) var name: String
    private(set) var phase: Phase
    private(set) var items: [WirdItem] = []
    private(set) var index = 0
    var problem: Problem?

    var isTimerRunning: Bool { timer.isRunning }

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let timer = AutoTapper()
    private var store: WirdStore { environment.wirdStore }
    private var settings: AppSettings { environment.settings }

    /// Returns nil if the wird does not exist (anymore).
    init?(wirdID: Int64, environment: AppEnvironment, now: Date = Date()) {
        guard let name = try? environment.wirdStore.name(of: wirdID) else { return nil }
        self.wirdID = wirdID
        self.environment = environment
        self.name = name
        let day = DayKey.of(now)
        self.day = day
        let unfinished = (try? environment.wirdStore.hasUnfinishedEarlierDay(wirdID, day: day)) ?? false
        phase = unfinished ? .askContinue : .counting
        if !unfinished { open(carryOver: false) }
    }

    // MARK: What the screen shows

    var current: WirdItem? { items.indices.contains(index) ? items[index] : nil }
    var hasPrevious: Bool { index > 0 }
    var hasNext: Bool { index + 1 < items.count }
    var currentDelayMs: Int { current?.timerDelayMs ?? 1000 }

    /// Progress of the whole wird: finished azkar count fully, pending ones by their count.
    var progress: Double {
        let total = items.reduce(0) { $0 + $1.target }
        guard total > 0 else { return 0 }
        let done = items.reduce(0) { $0 + ($1.isFinished ? $1.target : min($1.count, $1.target)) }
        return Double(done) / Double(total)
    }

    // MARK: Actions

    /// The answer to "continue where you stopped, or start over?".
    func choose(continueWhereStopped: Bool) {
        guard phase == .askContinue else { return }
        phase = .counting
        open(carryOver: continueWhereStopped)
    }

    /// A tap on the screen. Ignored while the auto-timer counts (like the counter).
    func tap() {
        guard !isTimerRunning else { return }
        count()
    }

    func skip() {
        guard phase == .counting, let item = current, !item.isFinished else { return }
        guard let result = save({ try $0.skip(item: item.id, of: wirdID, day: day, now: Date()) }) else { return }
        items[index] = result.item
        switch result.step {
        case .wirdFinished: finish()
        case .itemFinished: moveToNextPending()
        case .counted, .ignored: break
        }
    }

    /// Starts the wird over for today.
    func reset() {
        stopTimer()
        guard save({ try $0.resetDay(wirdID, day: day) }) != nil,
              let reloaded = save({ try $0.items(of: wirdID) }) else { return }
        items = reloaded
        index = 0
        phase = .counting
    }

    func showPrevious() {
        stopTimer()
        if hasPrevious { index -= 1 }
    }

    func showNext() {
        stopTimer()
        if hasNext { index += 1 }
    }

    // MARK: Auto-timer (each zikr has its own interval)

    func toggleTimer() {
        isTimerRunning ? stopTimer() : startTimer()
    }

    func startTimer() {
        guard phase == .counting, problem == nil else { return }
        if current?.isFinished == true {
            guard let next = nextPendingIndex() else { return }
            index = next
        }
        guard let item = current else { return }
        timer.start(intervalMs: item.timerDelayMs) { [weak self] in
            self?.count()
        }
    }

    func stopTimer() {
        timer.stop()
    }

    /// From the timer dialog: saves the interval of the zikr on screen and starts the timer.
    func startTimer(withDelay milliseconds: Int) {
        stopTimer()
        guard let item = current else { return }
        let value = max(TimerDelay.minimumMs, milliseconds)
        guard save({ try $0.setTimerDelay(value, forItem: item.id) }) != nil else { return }
        items[index].timerDelayMs = value
        startTimer()
    }

    // MARK: Screen lifecycle

    func screenDisappeared() {
        stopTimer()
        try? store.markOpened(wirdID, at: Date())
    }

    // MARK: Internals

    private func open(carryOver: Bool) {
        guard let loaded = save({ try $0.open(wirdID, day: day, carryOver: carryOver, now: Date()) }) else { return }
        guard !loaded.isEmpty else {
            problem = .missing
            return
        }
        items = loaded
        index = loaded.firstIndex { !$0.isFinished } ?? 0
    }

    private func count() {
        guard phase == .counting, let item = current else { return }
        guard let result = save({ try $0.tap(item: item.id, of: wirdID, day: day, now: Date()) }) else { return }
        items[index] = result.item
        switch result.step {
        case .ignored:
            stopTimer()   // a finished zikr: nothing left to count on it
        case .counted:
            tapFeedback()
        case .itemFinished:
            tapFeedback()
            finishedFeedback()
            moveToNextPending()
        case .wirdFinished:
            tapFeedback()
            finishedFeedback()
            finish()
        }
    }

    /// Goes to the next pending zikr, wrapping around (Android). A running timer continues with
    /// that zikr's own interval.
    private func moveToNextPending() {
        guard let next = nextPendingIndex() else { return }
        index = next
        if isTimerRunning {
            timer.stop()
            startTimer()
        }
    }

    private func nextPendingIndex() -> Int? {
        guard !items.isEmpty else { return nil }
        for offset in 1...items.count {
            let candidate = (index + offset) % items.count
            if !items[candidate].isFinished { return candidate }
        }
        return nil
    }

    private func finish() {
        stopTimer()
        phase = .finished
    }

    private func tapFeedback() {
        if settings.tapSound { environment.sound.playTap() }
        if settings.vibrateOnTap { environment.haptics.vibrate(milliseconds: settings.tapVibrationMs) }
    }

    /// A zikr reached its target: the "next" sound and the loop vibration (Android).
    private func finishedFeedback() {
        if settings.loopSound { environment.sound.playNext() }
        if settings.vibrateOnLoop { environment.haptics.vibrate(milliseconds: settings.loopVibrationMs) }
    }

    /// Runs a database call. On failure the timer stops and the screen reports the problem.
    private func save<T>(_ work: (WirdStore) throws -> T) -> T? {
        do {
            return try work(store)
        } catch WirdError.notFound {
            stopTimer()
            problem = .missing
        } catch {
            stopTimer()
            problem = .saveFailed
        }
        return nil
    }
}
