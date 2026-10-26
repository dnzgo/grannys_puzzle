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

The current files are the **Audio V3 pack**: temporary, not final. Many
will change; the knitting, cat-helper and grandma-helper sounds are known
to be wrong. The source pack (with its README) is kept outside the repo.

## Sound effects

One per `FeedbackEvent`. The V3 files come already mixed against each
other (the frequent board sounds much quieter than the stingers), so every
moment plays at volume 1 (`Audio/SoundEffects.swift`). The volume there
can only turn a file down; a sound that's too quiet needs a louder file.

| Name | Plays when | From V3 | Status |
|---|---|---|---|
| `select` | A cell is tapped, or the clue changes | `SFX/Board/cell_select` | temporary |
| `letter-placed-1`…`-4` | A letter is placed from the tray | `SFX/Board/letter_placed_01`…`04` | temporary |
| `letter-erased` | A letter is erased | `SFX/Board/letter_erased` | temporary |
| `submit` | Submit accepted (sound only, no vibration) | `SFX/Board/submit_v4` | temporary |
| `cells-judged-1`…`-4` | Each group of cells lights up after Submit | `SFX/Board/correct_wave_01`…`04` | temporary |
| `reveal` | The cat **or** grandma fills in letters | `SFX/Helpers/granny_knitting_needles_only` | **to replace** |
| `helper-earned` | Helpers earned from a video | `SFX/Helpers/helper_earned` | temporary |
| `level-passed` | The level passes | `Stingers/level_complete` | temporary |
| `level-failed` | The level fails | `Stingers/level_failed` | temporary |
| `item-knitted` | A knitted item is revealed | `Stingers/item_knitted` | **to replace** |
| `jar-shaken` | A tapped jar wobbles | `SFX/Rewards/jar_shaken` | temporary |
| `jar-opened` | A jar's treat is revealed | `SFX/Rewards/jar_opened` | temporary |
| `prize-landed` | A helper from a jar reaches its counter | `SFX/Rewards/prize_landing` | temporary |
| `yarn-landed-1`…`-3` | A yarn ball drops into the bag | `SFX/Rewards/yarn_landing_01`…`03` | temporary |

Several takes (`-1`…`-4`) are for sounds that repeat quickly: the player
picks one at random, never the one that just played, because an identical
sound repeated is noticed far sooner than a slightly different one.

The cat and grandma share `reveal` because the game has one "reveal"
moment for both. Real voices (a meow, grandma's "hmm") need the two split
into separate moments; the V3 pack's `Character_Voices/RECORDING_BRIEF.txt`
lists the recordings wanted.

## Music

Plays through `MusicPlayer`. The screen decides the track (`GameView`);
the music fades out for the background, full-screen ads, phone calls, and
while the player's own music or podcast is playing.

| Name | Plays on | From V3 | Status |
|---|---|---|---|
| `music-home` | Home | `Music/home_v3.m4a` | temporary |
| `music-puzzle` | Levels | `Music/puzzle_v3.m4a` | temporary |
| `music-daily` | The daily puzzle | `Music/daily_v3.m4a` | temporary |

## In the V3 pack, not used yet

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
| `SFX/Rewards/wardrobe_shake` | The wardrobe shaking |
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
| V3 effects and four stingers | Generated (procedural), per the V3 README: no third-party samples | Ours, to confirm before release | V3 `README.md` |
| V3 music and `level_failed` | Kept from earlier project files, per the V3 README | **Unknown: find out where they came from and under what terms before release** | — |
