//
//  grannys_puzzleApp.swift
//  grannys_puzzle
//
//  Created by Deniz Gözcü on 09.10.26.
//

import SwiftUI
import NotifyKit

@main
struct grannys_puzzleApp: App {
    /// Created with the app, before any screen: when a reminder tap launches
    /// the game, iOS reports it during launch, and only a listener already
    /// in place hears it.
    private let reminderTaps = ReminderTapRelay()
    /// Made once with the app too, after the audio session is set (the
    /// players' first sounds should already follow its rules). Kept here
    /// rather than as a view's @State: SwiftUI may create a view struct
    /// several times, and each time would load every sound again.
    private let sounds: SoundPlayer
    private let music: MusicPlayer

    init() {
        AudioSession.configureForGame()
        sounds = SoundPlayer()
        music = MusicPlayer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(reminderTaps: reminderTaps)
                .environment(sounds)
                .environment(music)
                // A game is the whole screen: no clock, battery or signal
                // over grandma's room. On phones with a notch or Dynamic
                // Island the space stays reserved, so the layout doesn't
                // move; on an SE the screen gains the bar's 20pt. The home
                // indicator stays: hiding it makes swiping home harder, and
                // players expect it.
                .statusBarHidden()
        }
    }
}
