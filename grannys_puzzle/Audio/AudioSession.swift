import AVFoundation
import os

/// How the game's audio fits in with the rest of the phone. Set once, at launch.
enum AudioSession {
    /// "Ambient": the game's sounds and music
    /// - go quiet with the silent switch (people play puzzles in bed, on
    ///   the bus, in waiting rooms), and
    /// - mix with whatever the player is already listening to instead of
    ///   stopping their podcast. The music player goes further and stays
    ///   silent while other audio plays (MusicPlayer.Hold.otherAudio).
    /// The opposite, "playback", is for apps whose sound is the point (a
    /// music app): it ignores the silent switch, which a game shouldn't.
    static func configureForGame() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Not fatal: iOS then uses its default (which is also silenced
            // by the switch, but stops other apps' audio). Logged so it's seen.
            Logger(subsystem: "grannys_puzzle", category: "audio")
                .error("Audio session not set: \(error.localizedDescription, privacy: .public)")
        }
    }
}
