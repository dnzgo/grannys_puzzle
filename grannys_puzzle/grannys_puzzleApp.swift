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

    var body: some Scene {
        WindowGroup {
            ContentView(reminderTaps: reminderTaps)
        }
    }
}
