# Audio

Every sound and music file the game plays, where it plays, and what a
real recording needs. Code: `grannys_puzzle/Audio/` (players) and
`grannys_puzzle/Design/GameFeedback.swift` (which moments exist).

## How a file gets into the game

Files live in `grannys_puzzle/Audio/Sounds/` and are found by **name**: the
player looks for `<name>.caf`, then `.m4a`, then `.wav` (music: `.m4a`,
`.caf`, `.wav`). To replace a placeholder, add the real file under the same
name and remove the placeholder `.wav` (two files with the same name and
different extensions would leave which one plays up to that order, which
is easy to forget).

A missing or unreadable file is logged (`audio` category) and then silent;
the game never crashes over a sound.

The current files are the **final pack** (Nov 2026, `~/Downloads/music`,
kept outside the repo) for most moments, plus four V3 files that the final
pack has no replacement for yet (marked V3 below).

Converting the final pack: effects to mono 44.1 kHz 16-bit WAV with the
silence before the sound cut (5 ms kept, 3 ms fade-in so the cut can't
click); music to AAC `.m4a` at 160 kbps, ends untouched (they are the loop
point).

## Sound effects

One per `FeedbackEvent`. Every moment plays at volume 1
(`Audio/SoundEffects.swift`), so the balance is in the files: the final
pack came unbalanced (the button press was about 30x quieter than the
level jingle), so each file was set to the loudness of the V3 file it
replaces, which had been tried on a phone, and the whole set then raised
10 dB. Louder files give room to tune by ear, because the code volume can
only turn a file down.

| Name | Plays when | From | Gain |
|---|---|---|---|
| `select` | A cell is tapped, or the clue changes | `select_soft_tick` | 0 dB (the quietest board sound: it plays the most) |
| `letter-placed-1`…`-4` | A letter is placed from the tray | `piano_placement_1`…`4` (piano notes G3, C4, E4, G4: one chord, so any order sounds right) | +2.9 dB (raised 4 dB after a phone test: the piano music hid them) |
| `letter-erased` | A letter is erased | `remove` | -2.1 dB (a little under placing a letter) |
| `submit` | Submit accepted (sound only, no vibration) | `soft_wooden_button_press_0_2s` | +19.1 dB (set to the letter level, not V3's loud submit) |
| `cells-judged` | Each group of cells lights up after Submit | `correct_answer_soft_pluck_0_4s` | -0.1 dB |
| `level-passed` | The level passes | `cozy_level_complete_jingle_1_5s` | -2.1 dB |
| `level-failed` | The level fails | `cozy_level_failed_grandma_1_5s` | +2.6 dB |
| `item-knitted` | A knitted item is revealed | `cozy_biggest_reward_knitting_fanfare_5s` | +6.8 dB |
| `helper-earned` | Helpers earned from a video | `cozy_reward_magic_sparkle_1_5s` | +8.7 dB |
| `jar-opened` | A jar's treat is revealed | `cozy_daily_reward_jingle_3s` | -1.5 dB |
| `prize-landed` | A helper from a jar reaches its counter | `cozy_item_pickup_soft_pluck_0_5s` | -1.2 dB |
| `reveal` | The cat **or** grandma fills in letters | V3 `SFX/Helpers/granny_knitting_needles_only` | **to replace** |
| `jar-shaken` | A tapped jar wobbles | V3 `SFX/Rewards/jar_shaken` | V3 |
| `yarn-landed-1`…`-3` | A yarn ball drops into the bag | V3 `SFX/Rewards/yarn_landing_01`…`03` | V3 |
| `wardrobe-shake` | A finished family member's wardrobe shakes before it's swapped | V3 `SFX/Rewards/wardrobe_shake` | V3 |

Several takes (`-1`…`-4`) are for sounds that repeat quickly: the player
picks one at random, never the one that just played, because an identical
sound repeated is noticed far sooner than a slightly different one.
`cells-judged` plays several times in a row after Submit but has only one
take in the final pack; if the repeat stands out on a phone, it needs more.

The cat and grandma share `reveal` because the game has one "reveal"
moment for both. Real voices (a meow, grandma's "hmm") need the two split
into separate moments; the V3 pack's `Character_Voices/RECORDING_BRIEF.txt`
lists the recordings wanted.

## Music

Plays through `MusicPlayer`, at 0.25 under the effects. The screen decides
the track (`GameView`); the music fades out for the background, full-screen
ads, phone calls, and while the player's own music or podcast is playing.

Levels and the daily puzzle share one track: they're the same activity, and
a change of music between them would only be noticed as a jump.

| Name | Plays on | From | Gain |
|---|---|---|---|
| `music-home` | Home | `grandmas_living_room_loop` (27 s, mono 22 kHz) | +1.5 dB |
| `music-puzzle` | Levels and the daily puzzle | `cozy_puzzle_felt_piano_guitar_75bpm` (48 s, stereo) | -7.6 dB (lowered 6 dB after a phone test: it's piano too, so it covered the letter notes) |

Both loops need a listen on a phone at the loop point: AAC can leave a tiny
gap there that the WAV source doesn't have.

## In the final pack, not used yet

Each needs a moment in the code first (a `FeedbackEvent` case, or a call
from the view that shows it), so they're not in the app yet:

| File | For |
|---|---|
| `wool_yarn_wrong_answer_0_3s` | A judged group with a wrong letter |
| `cozy_new_high_score_jingle_1_5s` | A new daily best |
| `cozy_retry_cue_1_5s` | The retry offer after a failed level |
| `cozy_biggest_reward_fanfare_4_8s` | The biggest reward (a whole family member finished) |

## In the V3 pack, not used yet (older)

These need a moment in the code first (a `FeedbackEvent` case, or a call
from the view that shows it), so they're not in the app bundle yet:

| V3 file | For |
|---|---|
| `SFX/UI/button_tap` | Button taps |
| `SFX/UI/card_open`, `card_close` | Cards opening and closing |
| `SFX/UI/settings_toggle` | Settings switches |
| `SFX/Board/wrong_cells_v4` (+ `_alt`) | A judged group with a wrong letter |
| `SFX/Board/submit_alt_v4` | Alternative submit |
| `SFX/Rewards/knitting_loop` | Looping under the knitting animation (**to replace**) |
| `SFX/Rewards/streak_plus_one`, `streak_saved` | Streak +1, streak saved |
| `SFX/Daily/score_counting`, `total_lands` | The daily score counting up, and its total |
| `Stingers/achievement` | Achievement unlocked |
| `Stingers/daily_best` | A new daily best |

Also planned, with no file yet: grandma's speech-bubble "voice", real cat
and grandma voices, home ambience (fireplace, clock).

## File specs

- **Sound effects:** WAV, 44.1 or 48 kHz, 16-bit, **mono**, trimmed tight
  (no silence before the sound: it would feel late). Converted to `.caf`
  for the app (`afconvert -f caff -d LEI16 in.wav out.caf` on a Mac).
- **Music:** stereo `.m4a` (AAC, about 128–160 kbps), with a clean loop
  point: the end must run straight into the start.
- **Loudness:** either all effects equally loud and mixed in code, or
  (as V3 does) mixed against each other in the files. Pick one per pack;
  the code volume only turns down. Music mastered quieter than the effects.
- **Sample rate:** 24 kHz mono is fine for effects (V3 uses it); 44.1 kHz
  for anything with a lot of high sparkle.

## Rules the code follows

- **Silent switch:** respected (audio session "ambient", `AudioSession.swift`).
  Video ads play under the same session (`GoogleAdNetwork.start`), so they
  respect it too.
- **The player's own audio** is never stopped; our music steps aside.
- **Settings:** Music, Sounds and Haptics are separate switches.

## Licenses

Every file needs a commercial, perpetual license for use in an app, with
no royalties per download. Record each file here before it ships, and keep
the license itself next to it (`docs/licenses/audio/`).

Avoid music registered with YouTube Content ID: players' videos of the
game would be flagged.

| File | Source | License | Proof |
|---|---|---|---|
| Final pack: every effect and both music tracks, plus the piano letter notes, `select_soft_tick` and `remove` | Made with ChatGPT (OpenAI), Nov 2026 | OpenAI's terms give the output's rights to the user, commercial use included. Not exclusive: someone else could get a similar sound | Keep the chat links (or exports) in `docs/licenses/audio/` |
| V3 `reveal`, `jar-shaken`, `yarn-landed-1`…`-3`, `wardrobe-shake` (still in the app) | Generated (procedural), per the V3 README: no third-party samples | Ours, to confirm before release | V3 `README.md` |

The V3 music and V3 `level_failed`, whose origin was unknown, are no longer
in the app.
