# Notes for working on this repo

## Keep the reference docs up to date

- `docs/RemoteConfig.md` lists every Remote Config key (from
  `ArrowwordCore/.../Tuning/GameTuning.swift`).
- `docs/Analytics.md` lists every analytics event and parameter (from
  `grannys_puzzle/Services/GameEvents.swift`).
- `docs/Achievements.md` lists every Game Center achievement: its ID (as
  entered in App Store Connect), target, points and texts.
- `docs/LevelDelivery.md` describes how level and daily packs are named,
  numbered, downloaded and published.
- `docs/Audio.md` lists every sound and music file: its name, when it
  plays, its volume, its status (placeholder or real) and its license
  (from `grannys_puzzle/Audio/SoundEffects.swift` and `MusicPlayer.swift`).

Any change that adds, removes or renames a key, event, parameter or
achievement or sound, or changes a default, range or meaning, updates the matching
doc in the same change.
