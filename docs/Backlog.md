# Backlog

Planned changes that aren't scheduled yet. When one is picked up, it moves
into the work (and into `Release.md` if it's needed for 1.0).

## Home screen

- [x] New icons for the settings and daily treat buttons.
- [x] Leaderboard button with its own icon (the trophy at the top left
      of the room), opening Game Center's leaderboards. Shows them once
      the daily leaderboards exist in App Store Connect (`Achievements.md`).
- [x] Grandma's speech bubble with a tail, so it visibly comes from her,
      always on top (HomeView's GrandmaBubble).
- [x] Knitting happens on the home screen, not in a separate screen:
      grandma rocks, a yarn ball spins, the item appears and flies into
      the wardrobe, vanishing in sparkles (Home/KnittingOnStage.swift).
- [ ] Knitting animation with real art (Rive), replacing the rocking
      grandma and spinning ball.

## Sound

- [x] Sound and music players, with placeholder sounds (docs/Audio.md).
- [x] Final sound effects and music (made with ChatGPT), except four
      V3 placeholders (docs/Audio.md).
- [ ] The planned moments without a sound yet (docs/Audio.md, "Planned").

## Remote content

Changeable without an app update. Both need images on the content server
(Firebase Hosting, like the level packs), with Remote Config only saying
which one to use, plus a fallback built into the app for when the
download isn't there yet or fails.

- [ ] Home background image chosen remotely (seasons, holidays).
- [ ] More family wardrobes after the grandson's (five are built in: the
      cat, daughter, son, granddaughter, grandson; see KnittingCatalog).
      Possibly achievements per finished wardrobe.
- [ ] New wardrobe items, and new wardrobes, added remotely: their art
      and their catalog entries (prices, sets) downloaded, like packs.
      Needs care with progress: a player who owns an item must keep it
      even if it's later removed from the catalog.

## Retention (v2)

Ordered by expected effect for the effort. Before building any: a
retention view in Firebase (day 1, 7 and 30, and where in the level
funnel players stop). Its numbers decide the order: if most players
leave by level 5, the early levels come first.

- [ ] Streak protection: a freeze (earned, or for a rewarded ad) and a
      repair for a missed day. A lost long streak is a common reason to
      quit for good.
- [ ] Daily archive: missed dailies playable, unlocked with a rewarded ad
      (the 400 dailies are there already).
- [ ] Progress in iCloud (Game Center saved games or CloudKit): a new
      phone shouldn't mean starting over.
- [ ] Smarter reminders: at the hour the player usually plays; "your
      streak ends tonight".
- [ ] Remote seasonal content (see Remote content above).
- [ ] Grandma's story: lines or family moments unlocked by progress (a
      letter from a grandchild when their wardrobe is done).
- [ ] Weekly goals (15 levels this week → a special yarn colour), between
      one level and a whole wardrobe.
- [ ] iPad layout (planned for 1.1).

## Accessibility

Not declared on the App Store for 1.0 (its accessibility answers are
voluntary, and a feature may only be ticked once every common task works
with it). Worth building, in this order, since the game suits older players:

- [ ] Larger Text: text follows the iPhone text-size setting (today's
      fonts are fixed sizes).
- [ ] VoiceOver: a whole level solvable by VoiceOver (64 labels exist,
      never tested end to end).
- [ ] Reduced Motion: checked on every screen (15 already follow it), then
      declared.
- [ ] Right/wrong letters shown by more than colour; contrast of the light
      inks (e.g. `quietInk` on cream) up to Apple's minimum.
- [ ] Maybe: a home-screen widget with today's daily and the streak.
      Uncertain: few players add widgets for games; worth it only if
      the daily turns out to be the main reason players come back.
