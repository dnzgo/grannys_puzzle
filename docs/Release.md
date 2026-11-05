# Release checklist (1.0)

What's left before the first App Store release. Tick items off here as
they're done, so the list stays the one place to look.

## Move to Deniz's accounts

Nothing is released yet, so every account moved now rather than through
Apple's app transfer later.

- [x] Dengo Labs' Apple Developer membership (team `GF38VK467T`)
- [x] Bundle ID `com.dengolabs.grannyspuzzle` with Game Center, and the
      App Store Connect app for it (build 1 uploaded)
- [x] The 27 achievements in App Store Connect (same IDs, see Achievements.md)
- [x] New Firebase project `granny-s-puzzle` (company account as owner),
      iOS app `com.dengolabs.grannyspuzzle`, Analytics, Hosting, the Remote
      Config keys
- [x] The app uses the new Firebase project (`GoogleService-Info.plist`
      for `granny-s-puzzle`)
- [x] Firebase on the Blaze plan (done 4 November 2026, before the
      15 November deadline), with a €10-a-month budget alert. Business
      billing account in EUR on the company card; the invoices come from
      Google Cloud EMEA Ltd (reverse charge, for the Steuerberater)
- [x] Crashlytics opened in the new project's console (app detected)
- [x] AdMob account under Deniz: the app and its rewarded, interstitial
      and banner units; real IDs in `Ads/AdsSetup.swift` (release builds)
      and the app ID in `Config/grannys_puzzle-Info.plist`
- [x] `app-ads.txt` line with the publisher ID in the website repo
      (`public/app-ads.txt`); deploy the site
- [ ] Restrict the Firebase iOS API key to the app (Google Cloud → APIs &
      Services → Credentials → the "auto created by Firebase" iOS key →
      Application restrictions → iOS apps → `com.dengolabs.grannyspuzzle`).
      GitHub's secret alert for this key is closed as "won't fix": the key
      is public by design
- [x] Signing: `Config/Signing.xcconfig`, `docs/Signing.md`
- [ ] After TestFlight works: retire Barış's App Store Connect app
      (`com.bgorkem.grannyscrossword`) and the old Firebase iOS app

## Features

- [x] Daily challenge leaderboard: scores sent to Game Center
      (`GameCenter.submitDailyScore`, docs/Achievements.md). Using the cat
      or grandma costs no time.
- [x] The two daily leaderboards created in App Store Connect
      (docs/Achievements.md)
- [ ] Leaderboards show their titles in the game (they showed "missing
      title"), then test a submission on TestFlight
- [x] Word and clue list, English (workbook, 10 level packs, 4 daily packs)
- [x] Word and clue list, Turkish (4,289 words, 3 level packs, 2 daily packs)
- [ ] Review the Turkish difficulty ratings (Difficulty column in
      `data/tr/source/turkish_words.xlsx`, rated by Claude); after
      changes: re-import and rebuild the packs
- [ ] Turkish daily pack 3 before day 200: 8 June 2027 with a 20 November
      launch (docs/LevelDelivery.md)
- [x] Loading screen: the Dengo Labs logo (1 s), then the game logo
      (granny and the cat, made with ChatGPT) with the walking cat on a
      filling bar (`Launch/LaunchSplash.swift`). Logo files for the website
      and the store: `granny_puzzle_assets_V1/logo/`
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
- [x] Turkish packs 2–3 and daily pack 2 published (`firebase deploy --only hosting`,
      4 November 2026)
- [ ] Turkish pack download tested on a phone (TestFlight, Turkish, level 91+
      or `-GPStartLevel 95` in a debug build)
- [x] The daily's first day = the planned release day, 20 November 2026
      (`DailyDay.firstDay`)
- [ ] `daily_first_day` set to 20261120 in the Remote Config console (not
      "Use in-app default"), so the date is moved there if it has to be
- [ ] During App Review, `daily_first_day` is 20261105 so the reviewer can
      play the daily (a "soon" button risks a 2.1 rejection). **Before
      pressing Release, set it back to 20261120** (or the actual day).
      Version Release is set to manual, so approval doesn't publish it
- [ ] If the release slips: `daily_first_day` in Remote Config to the
      actual day (e.g. 20261124) before pressing Release, and in the code
      for the next build. Never change either after launch
      (docs/RemoteConfig.md, "Daily challenge").

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
- [x] App Privacy answers published (8 data types; tracking declared)
- [x] Screenshots (EN, TR in Turkish), header and search artwork,
      promotional text and keywords (assets in `granny_puzzle_assets_V1/app-store/`)
- [ ] Subtitle and description, English and Turkish
- [x] Price Free; available everywhere except China mainland; not on Mac
      or Vision Pro for 1.0
- [ ] Achievements (and leaderboard) attached to version 1.0
- [ ] In-app purchases NOT attached to 1.0 (shop off, see
      docs/Monetization.md); App Review note explains it

## Polish and checks

- [x] Home background: kept at 639×1280. A sharper 886×1775 version was
      tried and looked worse: its crisp room competed with the furniture
      and characters on top; the softer one keeps them in front
- [ ] TestFlight pass: Game Center, notifications, real ads, tutorial on
      an SE-sized phone
- [ ] Firebase DebugView shows the analytics events; Remote Config
      defaults published
- [ ] Analytics custom definitions registered before launch (the ★
      parameters in docs/Analytics.md). Reports only show a parameter from
      the day it's registered, so launch-week data is lost otherwise
- [x] AdMob linked to Firebase, impression-level ad revenue on
      (`ad_impression` events, docs/Analytics.md)
- [ ] AdMob Privacy & messaging: Google consent mode on, so EU consent
      choices reach Analytics (GameServices/README.md, step 4)
- [ ] Crashlytics shows the TestFlight build's dSYM as uploaded (no
      "missing dSYM" warning)
- [x] App name: "Granny's Puzzle" in Turkish too (no translation)

## Music and sounds

- [x] Final pack in for 13 effects and both music tracks (levels and the
      daily share one track)
- [ ] Final sounds for the four V3 files still in the app: `reveal` (cat and
      grandma helpers) first, then `jar-shaken`, `yarn-landed`, `wardrobe-shake`
- [ ] Both music loops listened to at the loop point on a phone
- [x] Every shipped file has its source in docs/Audio.md (made with ChatGPT)
- [ ] The "Planned" moments in docs/Audio.md: a sound each, or dropped
- [ ] Volumes checked on a phone with the final files (music is 0.25 now)

## After launch, to watch

- Firebase Hosting: 10 GB a month free, even on Blaze. Packs go out
  gzipped at about 33 KB, so roughly 300,000 pack downloads a month
  before it costs anything. The €10 budget alert emails if it does.
- The daily uses the phone's clock: a player who moves the clock
  forward can play tomorrow's puzzle early, learn it, and score
  perfectly on the day. Accepted for 1.0; if the leaderboards show it,
  the fix is checking the day against server time (Game Center's
  leaderboard period) before playing and submitting.
