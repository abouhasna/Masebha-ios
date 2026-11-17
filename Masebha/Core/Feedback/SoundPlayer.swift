import AVFoundation

/// Plays the tap, loop-completion and wird "next" sounds (≈ the SoundPool code on Android).
///
/// The audio session is "ambient": sounds mix with other audio (e.g. a Quran recitation) and
/// follow the Ring/Silent switch, like other iPhone UI sounds.
final class SoundPlayer {
    private var tapPlayers: [AVAudioPlayer] = []
    private var nextTapPlayer = 0
    private var loopPlayer: AVAudioPlayer?
    private var nextPlayer: AVAudioPlayer?
    private var sessionConfigured = false

    init() {
        tapPlayers = (0..<3).compactMap { _ in SoundPlayer.makePlayer("tap") }  // overlap fast taps
        loopPlayer = SoundPlayer.makePlayer("loop")
        nextPlayer = SoundPlayer.makePlayer("next")
    }

    func playTap() {
        guard !tapPlayers.isEmpty else { return }
        configureSessionIfNeeded()
        let player = tapPlayers[nextTapPlayer]
        nextTapPlayer = (nextTapPlayer + 1) % tapPlayers.count
        player.currentTime = 0
        player.play()
    }

    func playLoop() {
        guard let loopPlayer else { return }
        configureSessionIfNeeded()
        loopPlayer.currentTime = 0
        loopPlayer.play()
    }

    /// A wird zikr reached its target (Android's wird_next sound).
    func playNext() {
        guard let nextPlayer else { return }
        configureSessionIfNeeded()
        nextPlayer.currentTime = 0
        nextPlayer.play()
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Without a session the system default (also ambient) is used; nothing to recover.
        }
    }

    private static func makePlayer(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }
}
