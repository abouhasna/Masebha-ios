import Foundation

/// Rules of the auto-timer interval and its dialog (≈ showTimerDialog on Android).
nonisolated enum TimerDelay {
    static let minimumMs = 100

    /// Interval read from storage; anything below the minimum means 1 second (Android rule).
    static func sanitized(_ ms: Int) -> Int {
        ms < minimumMs ? 1000 : ms
    }

    static func plusSecond(_ ms: Int) -> Int { ms + 1000 }

    /// Removing a second is ignored when it would reach 0 or less (Android rule).
    static func minusSecond(_ ms: Int) -> Int { ms - 1000 <= 0 ? ms : ms - 1000 }

    static func plusTenth(_ ms: Int) -> Int { ms + 100 }

    static func minusTenth(_ ms: Int) -> Int { max(minimumMs, ms - 100) }

    /// "Auto" tab: 4 taps at the user's pace; the interval is the average of the 3 gaps.
    /// Returns nil until 4 tap times are given.
    static func averageInterval(tapTimes: [TimeInterval]) -> Int? {
        guard tapTimes.count >= 4 else { return nil }
        let last4 = Array(tapTimes.suffix(4))
        let totalMs = (last4[3] - last4[0]) * 1000
        return max(minimumMs, Int(totalMs / 3))
    }

    /// "1.0", "0.4", "12.3": seconds with one decimal, ASCII digits.
    static func display(_ ms: Int) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), Double(ms) / 1000)
    }
}

/// Fixed-rate scheduling: the next tick is planned from the previous *planned* time, so the time
/// spent on a tick (saving, sound) does not slow the pace. If the app fell a whole interval behind,
/// the cadence restarts from now instead of firing the missed ticks in a burst (Android rule).
nonisolated enum FixedRate {
    static func nextTick(afterPlanned planned: TimeInterval, interval: TimeInterval, now: TimeInterval) -> TimeInterval {
        let next = planned + interval
        return next <= now ? now + interval : next
    }
}
