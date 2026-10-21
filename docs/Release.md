# Release checklist (1.0)

What's left before the first App Store release. Tick items off here as
they're done, so the list stays the one place to look.

## Move to Deniz's accounts

Nothing is released yet, so every account moves now rather than through
Apple's app transfer later. The bundle ID changes: the current one
(`com.bgorkem.grannyscrossword`) is tied to Barış's App Store Connect app.

- [ ] Deniz's Apple Developer membership (Individual or Organization;
      answer the EU trader-status question)
- [ ] New bundle ID with the Game Center capability, and the App Store
      Connect app for it
- [ ] Recreate the 27 achievements there (same IDs, see Achievements.md)
- [ ] Firebase: Deniz as Owner of the project, an iOS app for the new
      bundle ID, its `GoogleService-Info.plist` in the repo (also fixes
      today's mismatch: the plist is for `…grannyspuzzle`, the app builds
      as `…grannyscrossword`)
- [ ] AdMob account under Deniz: the app and its rewarded, interstitial
      and banner units
- [ ] Repo: `Config/Signing.xcconfig` (team, bundle ID), ad unit IDs in
      `Ads/AdsSetup.swift`, app ID in `Config/grannys_puzzle-Info.plist`,
      `docs/Signing.md`
- [ ] After TestFlight works: retire Barış's App Store Connect app and the
      old Firebase iOS app

## Features

- [ ] Daily challenge leaderboard (decide: time penalty for cat/grandma?)
- [ ] Word and clue list
- [ ] Loading screen with the company logo, shown at launch. iOS's own
      launch screen is a still image only, so this is a SwiftUI screen
      right after it, styled to match. Needs the logo artwork. Keep it
      short (about 1.5s) and use it to cover real start-up work rather
      than adding a wait.
- [ ] Decide on iPad: ship iPhone-only for 1.0 (`TARGETED_DEVICE_FAMILY`)
      or design and test the iPad layout
- [ ] More daily puzzles: only 30 per language are bundled; bundle a year
      or deliver them remotely

## Store, privacy and ads

- [ ] Privacy policy, terms and feedback email (`SupportLinks` in
      `Settings/GameSettings.swift`); a small website, which also hosts:
- [ ] `app-ads.txt` on the developer website
- [ ] `PrivacyInfo.xcprivacy` for the app (UserDefaults reason, tracking)
- [ ] GDPR consent message set up in the AdMob console
- [ ] App Store listing in English and Turkish: description, keywords,
      subtitle, screenshots, age rating, App Privacy answers
- [ ] Achievements (and leaderboard) attached to version 1.0

## Polish and checks

- [ ] Full-size home background (about 1290×2796)
- [ ] TestFlight pass: Game Center, notifications, real ads, tutorial on
      an SE-sized phone
- [ ] Firebase DebugView shows the analytics events; Remote Config
      defaults published
