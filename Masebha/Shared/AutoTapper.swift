import UIKit
import Observation

/// The auto-timer loop shared by the counter and the wird session: calls `tick` at a fixed rate
/// (see `FixedRate`) and keeps the screen awake while it runs, like Android.
@Observable
final class AutoTapper {
    @ObservationIgnored private var task: Task<Void, Never>?
    private(set) var isRunning = false

    /// Starts (or restarts) ticking every `intervalMs`. The first tick comes after one interval.
    /// `tick` may call `start` again (a new interval) or `stop`.
    func start(intervalMs: Int, tick: @escaping @MainActor () -> Void) {
        stop()
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        let interval = Double(max(TimerDelay.minimumMs, intervalMs)) / 1000
        task = Task { [weak self] in
            var planned = ProcessInfo.processInfo.systemUptime + interval
            while true {
                let wait = planned - ProcessInfo.processInfo.systemUptime
                if wait > 0 {
                    do {
                        try await Task.sleep(for: .seconds(wait), tolerance: .milliseconds(5))
                    } catch {
                        return   // cancelled: stopped or restarted
                    }
                }
                // Stopped while sleeping? Then this tick must not count.
                guard !Task.isCancelled, let self, self.isRunning else { return }
                tick()
                planned = FixedRate.nextTick(afterPlanned: planned, interval: interval,
                                             now: ProcessInfo.processInfo.systemUptime)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if isRunning {
            isRunning = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
