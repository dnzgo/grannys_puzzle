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
- [x] The app uses the new Firebase project (`GoogleService-Info.plist`
      for `granny-s-puzzle`; its bundle ID already says
      `com.dengolabs.grannyspuzzle`, so nothing to change when the bundle
      ID switches)
- [ ] Firebase on the Blaze plan before 15 November 2026 (Remote Config
      becomes usage-based; upgrading by then delays billing to February
      2027), with a budget alert (e.g. €10 a month). Company card, so the
      Google invoices go into the business books
- [x] Crashlytics opened in the new project's console (app detected)
- [x] AdMob account under Deniz: the app and its rewarded, interstitial
      and banner units; real IDs in `Ads/AdsSetup.swift` (release builds)
      and the app ID in `Config/grannys_puzzle-Info.plist`
- [x] `app-ads.txt` line with the publisher ID in the website repo
      (`public/app-ads.txt`); deploy the site
- [ ] After the bundle ID switch: restrict the Firebase iOS API key to the
      app (Google Cloud → APIs & Services → Credentials → the "auto created
      by Firebase" iOS key → Application restrictions → iOS apps →
      `com.dengolabs.grannyspuzzle`). Not before: test builds with the old
      bundle ID would lose Firebase. GitHub's secret alert for this key is
      closed as "won't fix": the key is public by design
- [ ] Repo: `Config/Signing.xcconfig` (team, bundle ID
      `com.dengolabs.grannyspuzzle`), `docs/Signing.md`
- [ ] After TestFlight works: retire Barış's App Store Connect app and the
      old Firebase iOS app

## Features

- [x] Daily challenge leaderboard: scores sent to Game Center
      (`GameCenter.submitDailyScore`, docs/Achievements.md). Using the cat
      or grandma costs no time.
- [ ] Create the two daily leaderboards in App Store Connect
      (docs/Achievements.md), then test a submission on TestFlight
- [x] Word and clue list, English (workbook, 10 level packs, 4 daily packs)
- [x] Word and clue list, Turkish (3,799 words, 2 level packs, 2 daily packs)
- [ ] Review the Turkish difficulty ratings (Difficulty column in
      `data/tr/source/turkish_words.xlsx`, rated by Claude); after
      changes: re-import and rebuild the packs
- [ ] Turkish daily pack 3 before day 200 after launch
      (docs/LevelDelivery.md)
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
- [x] English daily pack 1 full (100); 400 English dailies in all
- [x] Turkish daily pack 1 full (100); 200 Turkish dailies in all
- [x] English packs 2–10 and daily packs 2–4 published (download
      tested on a phone)
- [ ] Turkish pack 2 and daily pack 2 published (`firebase deploy --only hosting`)
      and download tested on a phone
- [ ] The daily's first day = the release day (that day plays daily 1):
      set `DailyDay.firstDay` in the release build to the planned day, and
      `daily_first_day` in Remote Config (e.g. 20261201) to the actual
      day before pressing Release, if it slipped. Never change either
      after launch (docs/RemoteConfig.md, "Daily challenge").

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
- [x] `PrivacyInfo.xcprivacy` for the app's own code (UserDefaults;
      Google's SDKs bring their own). Check Xcode's privacy report
      (Organizer → archive → Generate Privacy Report) against the App
      Privacy answers
- [x] `ITSAppUsesNonExemptEncryption = NO` (only HTTPS), so uploads
      skip the export-compliance question
- [x] AdMob: GDPR and US-states consent messages published; ad content
      rating Teens; blocked: dating, get rich quick, references to sex,
      sexual & reproductive health (alcohol and gambling were blocked
      already)
- [ ] After launch: link the app to its App Store listing in AdMob
      (mediation plan: docs/Monetization.md)
- [x] "Remove ads" purchase built; its App Store Connect steps are in
      docs/Monetization.md
- [ ] App Store listing in English and Turkish: description, keywords,
      subtitle, screenshots, age rating, App Privacy answers. Marketing
      URL: https://dengolabs.com/games/grannys-puzzle/ (AdMob finds
      app-ads.txt through it); support URL: the game's help page
- [ ] Achievements (and leaderboard) attached to version 1.0

## Polish and checks

- [ ] Full-size home background (about 1290×2796)
- [ ] TestFlight pass: Game Center, notifications, real ads, tutorial on
      an SE-sized phone
- [ ] Firebase DebugView shows the analytics events; Remote Config
      defaults published
- [x] App name: "Granny's Puzzle" in Turkish too (no translation)

## Music and sounds

- [ ] Final sound effects and music replace every V3 placeholder (the
      knitting, cat helper and grandma helper sounds first)
- [ ] Every shipped file has its license or source in docs/Audio.md
- [ ] The "Planned" moments in docs/Audio.md: a sound each, or dropped
- [ ] Volumes checked on a phone with the final files (music is 0.25 now)

## After launch, to watch

- Firebase Hosting on the free plan: 10 GB a month. Packs go out
  gzipped at about 33 KB, so roughly 300,000 pack downloads a month.
  Move to Blaze (pay as you go) before that, with a budget alert.
- The daily uses the phone's clock: a player who moves the clock
  forward can play tomorrow's puzzle early, learn it, and score
  perfectly on the day. Accepted for 1.0; if the leaderboards show it,
  the fix is checking the day against server time (Game Center's
  leaderboard period) before playing and submitting.
