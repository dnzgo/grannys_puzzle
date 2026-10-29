# Backlog

Planned changes that aren't scheduled yet. When one is picked up, it moves
into the work (and into `Release.md` if it's needed for 1.0).

## Home screen

- [ ] New icons for the settings and daily treat buttons (art to come).
- [ ] Leaderboard button with its own icon, opening the daily
      leaderboards (see `Achievements.md`).
- [ ] Grandma's speech bubble with a tail, so it visibly comes from her.
- [x] Knitting happens on the home screen, not in a separate screen:
      grandma rocks, a yarn ball spins, the item appears and flies into
      the wardrobe, vanishing in sparkles (Home/KnittingOnStage.swift).
- [ ] Knitting animation with real art (Rive), replacing the rocking
      grandma and spinning ball.

## Sound

- [x] Sound and music players, with placeholder sounds (docs/Audio.md).
- [ ] Real sound effects and music, recorded or licensed, replacing the
      placeholders.
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
