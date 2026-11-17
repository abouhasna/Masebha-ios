import SwiftUI
import UIKit
import Observation

/// State and actions of the counter screen (≈ the logic of MainActivity2 + TimerService).
///
/// Every count is saved to the database *before* the screen shows it: what you see is always
/// what is stored, even if the app is killed right after a tap.
@Observable
final class CounterModel {
    private(set) var dhikr: Dhikr
    private(set) var state: CounterState
    private(set) var timerDelayMs: Int
    var isTimerRunning: Bool { timer.isRunning }
    private(set) var previousID: Int64?
    private(set) var nextID: Int64?
    /// Set when the dhikr disappeared or the database refused a write; the screen shows an alert.
    var problem: Problem?

    enum Problem: Identifiable {
        case missing, saveFailed
        var id: Self { self }
    }

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let timer = AutoTapper()
    private var settings: AppSettings { environment.settings }
    private var store: DhikrStore { environment.store }

    /// Returns nil if the dhikr does not exist (anymore).
    init?(dhikrID: Int64, environment: AppEnvironment) {
        guard let dhikr = try? environment.store.dhikr(id: dhikrID) else { return nil }
        self.environment = environment
        self.dhikr = dhikr
        self.timerDelayMs = TimerDelay.sanitized(dhikr.timerDelayMs)
        let today = (try? environment.store.todayCount(id: dhikr.id, day: DayKey.today())) ?? 0
        self.state = .opening(total: dhikr.total, loopSize: dhikr.loopSize, today: today,
                              resumeLoop: environment.settings.resumeLoop)
        refreshNeighbors()
    }

    // MARK: Counting

    /// A tap on the screen. Ignored while the auto-timer counts (Android behavior).
    func tap() {
        guard !isTimerRunning else { return }
        count()
    }

    func undo() {
        var next = state
        guard let delta = next.undo() else { return }
        if delta != 0 {
            guard let snapshot = save({ try $0.applyDelta(delta, to: dhikr.id, day: DayKey.today()) }) else { return }
            next.sync(with: snapshot)
        }
        state = next
    }

    /// Removes the counts of this visit from the total and today's count.
    func resetSession() {
        var next = state
        let removed = next.resetSession()
        if removed > 0 {
            guard let snapshot = save({ try $0.applyDelta(-removed, to: dhikr.id, day: DayKey.today()) }) else { return }
            next.sync(with: snapshot)
        }
        state = next
    }

    /// Lifetime total and today's count to 0.
    func resetAll() {
        guard let snapshot = save({ try $0.resetCount(of: dhikr.id, day: DayKey.today()) }) else { return }
        var next = state
        next.resetAll()
        next.sync(with: snapshot)
        state = next
    }

    private func count() {
        var next = state
        let completedLoop = next.tap()
        guard let snapshot = save({ try $0.applyDelta(1, to: dhikr.id, day: DayKey.today()) }) else { return }
        next.sync(with: snapshot)
        state = next

        if settings.tapSound { environment.sound.playTap() }
        if settings.vibrateOnTap { environment.haptics.vibrate(milliseconds: settings.tapVibrationMs) }
        if completedLoop {
            if settings.vibrateOnLoop { environment.haptics.vibrate(milliseconds: settings.loopVibrationMs) }
            if settings.loopSound { environment.sound.playLoop() }
            loopCompleted()
        }
    }

    /// "Go to next dhikr" / "Stop the timer" when a loop completes (Android onDawraReached).
    private func loopCompleted() {
        if settings.nextDhikrOnLoop, let nextID {
            open(nextID)
            return
        }
        if settings.stopTimerOnLoop || settings.nextDhikrOnLoop {
            stopTimer()
        }
    }

    // MARK: Auto-timer

    func toggleTimer() {
        isTimerRunning ? stopTimer() : startTimer()
    }

    /// Starts counting automatically every `timerDelayMs`, at a fixed rate (screen kept on).
    func startTimer() {
        guard !isTimerRunning, problem == nil else { return }
        timer.start(intervalMs: timerDelayMs) { [weak self] in
            self?.count()
        }
    }

    func stopTimer() {
        timer.stop()
    }

    /// From the timer dialog: saves the new interval for this dhikr and starts the timer.
    func startTimer(withDelay milliseconds: Int) {
        stopTimer()
        timerDelayMs = max(TimerDelay.minimumMs, milliseconds)
        _ = save({ try $0.setTimerDelay(self.timerDelayMs, for: self.dhikr.id) })
        startTimer()
    }

    // MARK: Previous / next

    func openPrevious() { if let previousID { open(previousID) } }
    func openNext() { if let nextID { open(nextID) } }

    /// Switches this screen to another dhikr (the session restarts, like Android).
    private func open(_ id: Int64) {
        stopTimer()
        markOpened()
        guard let target = try? store.dhikr(id: id) else {
            refreshNeighbors()
            return
        }
        dhikr = target
        timerDelayMs = TimerDelay.sanitized(target.timerDelayMs)
        let today = (try? store.todayCount(id: target.id, day: DayKey.today())) ?? 0
        state = .opening(total: target.total, loopSize: target.loopSize, today: today, resumeLoop: settings.resumeLoop)
        refreshNeighbors()
        markOpened()
    }

    private func refreshNeighbors() {
        let neighbors: (previous: Int64?, next: Int64?) = (try? store.neighbors(of: dhikr.id)) ?? (nil, nil)
        previousID = neighbors.previous
        nextID = neighbors.next
    }

    // MARK: Screen lifecycle

    func screenAppeared() {
        markOpened()
        refreshNeighbors()
    }

    /// Leaving the screen or the app: the timer stops (counts are already saved).
    func screenDisappeared() {
        stopTimer()
        markOpened()
    }

    private func markOpened() {
        try? store.markOpened(dhikr.id, at: Date())
    }

    /// Runs a database write. On failure the timer stops and the screen reports the problem.
    private func save<T>(_ write: (DhikrStore) throws -> T) -> T? {
        do {
            return try write(store)
        } catch StoreError.dhikrNotFound {
            stopTimer()
            problem = .missing
        } catch {
            stopTimer()
            problem = .saveFailed
        }
        return nil
    }
}
