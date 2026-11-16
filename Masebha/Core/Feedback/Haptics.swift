import CoreHaptics

/// Vibrations of a chosen length (≈ VibrationHelper on Android), using the iPhone's Taptic Engine.
///
/// The durations are the same as on Android (60–900 ms), so settings and backups stay compatible.
/// The Simulator has no haptics: calls are silently ignored there.
final class Haptics {
    private let isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    func vibrate(milliseconds: Int) {
        guard isSupported, milliseconds > 0 else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45),
                ],
                relativeTime: 0,
                duration: Double(milliseconds) / 1000)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try startedEngine().makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // The engine can be stopped by the system (e.g. app in background). Drop it and
            // create a fresh one next time instead of relying on callbacks.
            engine = nil
        }
    }

    private func startedEngine() throws -> CHHapticEngine {
        if let engine { return engine }
        let newEngine = try CHHapticEngine()
        newEngine.playsHapticsOnly = true
        newEngine.isAutoShutdownEnabled = true
        try newEngine.start()
        engine = newEngine
        return newEngine
    }
}
