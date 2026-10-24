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
- [x] New Firebase project `granny-s-puzzle` (company account as owner),
      iOS app `com.dengolabs.grannyspuzzle`, Analytics, Hosting, the Remote
      Config keys
- [ ] When the bundle ID switches: put the new project's
      `GoogleService-Info.plist` (waiting in the assets folder; git ignores
      it) into the app folder, replacing the old project's
- [x] AdMob account under Deniz: the app and its rewarded, interstitial
      and banner units; real IDs in `Ads/AdsSetup.swift` (release builds)
      and the app ID in `Config/grannys_puzzle-Info.plist`
- [x] `app-ads.txt` line with the publisher ID in the website repo
      (`public/app-ads.txt`); deploy the site
- [ ] Repo: `Config/Signing.xcconfig` (team, bundle ID
      `com.dengolabs.grannyspuzzle`), `docs/Signing.md`
- [ ] After TestFlight works: retire Barış's App Store Connect app and the
      old Firebase iOS app

## Features

- [ ] Daily challenge leaderboard (decide: time penalty for cat/grandma?)
- [ ] Word and clue list
- [x] Loading screen: logo and the walking cat on a filling bar
      (`Launch/LaunchSplash.swift`)
- [ ] Optional: the logo (`company-logo`) is from a compressed JPG,
      cleaned up; a vector or PNG export of the original would be sharper
- [x] iPhone-only for 1.0 (`TARGETED_DEVICE_FAMILY = 1`). A real iPad
      layout is planned for 1.1; support can be added in an update but
      never removed again.
- [x] Level and daily packs of 100, pack 1 bundled, later ones downloaded
      (docs/LevelDelivery.md)
- [x] Content server: Firebase Hosting on Deniz's project
      (https://granny-s-puzzle.web.app, in `PackDownloader.contentBaseURL`)
- [ ] Daily pack 1 has only 30 puzzles per language: fill it to 100
- [ ] Publish level pack 2 (and daily pack 2) per language before release,
      so early players never wait
- [ ] Check `DailyDay.firstDay` (1 November 2026) is still right for the
      release: the day it names plays daily 1

## Store, privacy and ads

- [x] Feedback email: support@dengolabs.com (`SupportLinks`)
- [x] Privacy policy and terms on dengolabs.com, linked in `SupportLinks`
- [x] Privacy policy covers Crashlytics, the level-pack downloads, Game
      Center, reminders and the Feedback email; help page uses support@
      (dengo_labs website repo)
- [ ] Legal review of the privacy policy and terms, including the CHECK
      notes in the website's .mdx files (`npm run check:launch` lists
      them). Options to compare: a lawyer's fixed-price review of the
      existing texts (likely best), IT-Recht Kanzlei (subscription, app
      texts, updates), eRecht24 Premium, Datenschutz-Generator.de. Worth
      paying for once: a German Abmahnung costs more.
- [ ] On dengolabs.com:
- [ ] `PrivacyInfo.xcprivacy` for the app (UserDefaults reason, tracking)
- [x] AdMob: GDPR and US-states consent messages published; ad content
      rating Teens; blocked: dating, get rich quick, references to sex,
      sexual & reproductive health (alcohol and gambling were blocked
      already)
- [ ] After launch: link the app to its App Store listing in AdMob, then
      set up mediation (more ad networks bidding) to win back fill and
      price; later, test the content rating per request through Remote
      Config
- [ ] App Store listing in English and Turkish: description, keywords,
      subtitle, screenshots, age rating, App Privacy answers
- [ ] Achievements (and leaderboard) attached to version 1.0

## Polish and checks

- [ ] Full-size home background (about 1290×2796)
- [ ] TestFlight pass: Game Center, notifications, real ads, tutorial on
      an SE-sized phone
- [ ] Firebase DebugView shows the analytics events; Remote Config
      defaults published
