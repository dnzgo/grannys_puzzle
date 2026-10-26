import AVFoundation
import Observation
import os

/// The background music loops. CaseIterable so a test can check every
/// track's file is in the app.
enum MusicTrack: String, CaseIterable {
    case home = "music-home"
    /// Levels: calm, for thinking.
    case puzzle = "music-puzzle"
    /// The daily puzzle, which is timed: a little livelier.
    case daily = "music-daily"
}

/// Plays the music: the track the current screen asks for, unless
/// something says to be quiet.
///
/// The design: instead of every caller pausing and resuming the music
/// directly (and two of them disagreeing), each one only states a fact:
/// "this screen wants the home track", "an ad is showing", "the app is in
/// the background". `update()` works out from all of them together what
/// should be playing. So an ad ending while the app is in the background
/// can't start the music by mistake: the background hold is still there.
@Observable
final class MusicPlayer {
    /// Reasons to be quiet. Any one is enough.
    enum Hold: Hashable {
        case background
        /// A full-screen ad, which plays its own sound.
        case ad
        /// A phone call, an alarm, Siri.
        case interruption
        /// The player's own music or podcast is playing. iOS's hint for
        /// exactly this: "secondary" audio like a game's soundtrack should
        /// step aside. Sound effects still play; they're short.
        case otherAudio
    }

    /// Low on purpose: music in a puzzle game is a background mood, and the
    /// player is reading and thinking over it. The scale is linear (half
    /// the number is about 6 dB quieter), so 0.25 is roughly 12 dB below the
    /// file's own level. The effects play at full volume above it.
    private static let volume: Float = 0.25
    /// Long enough to feel smooth between screens, short enough that the
    /// home track is gone by the time the board is up.
    private static let fadeSeconds: TimeInterval = 0.8

    @ObservationIgnored private var wanted: MusicTrack?
    @ObservationIgnored private var isEnabled = true
    @ObservationIgnored private var holds: Set<Hold> = []
    /// What's actually sounding (or fading in) right now.
    @ObservationIgnored private var playing: MusicTrack?
    @ObservationIgnored private var players: [MusicTrack: AVAudioPlayer] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private let logger = Logger(subsystem: "grannys_puzzle", category: "audio")

    // Lives as long as the app, so the observers are never removed.
    init(bundle: Bundle = .main) {
        self.bundle = bundle
        observeTheSystem()
        checkOtherAudio()
    }

    /// The track the current screen wants.
    func play(_ track: MusicTrack) {
        wanted = track
        update()
    }

    /// The Music switch in Settings.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        update()
    }

    func hold(_ reason: Hold, _ isHeld: Bool) {
        if isHeld { holds.insert(reason) } else { holds.remove(reason) }
        if reason == .background, !isHeld {
            // The player may have started their own music while we were
            // away, and iOS only sends the "other audio" hint to apps in
            // the foreground, so ask again on coming back.
            checkOtherAudio()
        }
        update()
    }

    // MARK: - Working out what plays

    private func update() {
        let shouldPlay = (isEnabled && holds.isEmpty) ? wanted : nil
        guard shouldPlay != playing else { return }
        if let old = playing { fadeOut(old) }
        playing = shouldPlay
        if let new = shouldPlay { fadeIn(new) }
    }

    private func fadeIn(_ track: MusicTrack) {
        guard let player = player(for: track) else { return }
        if !player.isPlaying {
            player.volume = 0
            player.play()
        }
        player.setVolume(Self.volume, fadeDuration: Self.fadeSeconds)
    }

    /// Pauses rather than stops, so after an ad or a phone call the track
    /// carries on where it was instead of starting over.
    private func fadeOut(_ track: MusicTrack) {
        guard let player = players[track] else { return }
        player.setVolume(0, fadeDuration: Self.fadeSeconds)
        Task {
            try? await Task.sleep(for: .seconds(Self.fadeSeconds))
            // It may have been asked back while fading (a quick return to
            // home); then it's fading in again and must keep playing.
            if playing != track { player.pause() }
        }
    }

    private func player(for track: MusicTrack) -> AVAudioPlayer? {
        if let player = players[track] { return player }
        guard let url = ["m4a", "caf", "wav"].lazy.compactMap({ self.bundle.url(forResource: track.rawValue, withExtension: $0) }).first else {
            // Missing music is logged and then silence, never a crash.
            logger.error("Music file missing: \(track.rawValue, privacy: .public)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1  // forever
            player.prepareToPlay()
            players[track] = player
            return player
        } catch {
            logger.error("Music \(track.rawValue, privacy: .public) unreadable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - What the phone tells us

    private func checkOtherAudio() {
        let othersPlaying = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        if othersPlaying { holds.insert(.otherAudio) } else { holds.remove(.otherAudio) }
        update()
    }

    private func observeTheSystem() {
        let center = NotificationCenter.default
        // Delivered on the main queue, so handling them on the main actor
        // (where everything here lives) is safe.
        observers.append(center.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt
            let began = raw.flatMap(AVAudioSession.SilenceSecondaryAudioHintType.init(rawValue:)) == .begin
            MainActor.assumeIsolated { self?.hold(.otherAudio, began) }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let began = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began
            MainActor.assumeIsolated { self?.hold(.interruption, began) }
        })
    }
}
