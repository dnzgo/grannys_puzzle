# Backlog

Planned changes that aren't scheduled yet. When one is picked up, it moves
into the work (and into `Release.md` if it's needed for 1.0).

## Home screen

- [ ] New icons for the settings and daily treat buttons (art to come).
- [ ] Leaderboard button with its own icon, opening the daily
      leaderboards (see `Achievements.md`).
- [ ] Grandma's speech bubble with a tail, so it visibly comes from her.
- [ ] Knitting happens on the home screen, not in a separate screen.
      Afterwards the finished item appears, flies into the wardrobe, and
      the wardrobe shakes.

## Sound

- [ ] Sound effects and music, made and added. (Settings already has the
      music and sound switches.)

## Remote content

Changeable without an app update. Both need images on the content server
(Firebase Hosting, like the level packs), with Remote Config only saying
which one to use, plus a fallback built into the app for when the
download isn't there yet or fails.

- [ ] Home background image chosen remotely (seasons, holidays).
- [ ] New wardrobe items, and new wardrobes, added remotely: their art
      and their catalog entries (prices, sets) downloaded, like packs.
      Needs care with progress: a player who owns an item must keep it
      even if it's later removed from the catalog.
