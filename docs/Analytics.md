# Analytics events

Every event the game sends to Firebase Analytics, with its parameters and
the question it answers. **Keep this file in step with the code:** whenever
an event or parameter is added, removed, renamed or changes meaning, update
it in the same commit.

Source of truth: `GameEvents.swift` in the app (every event is built
there); they're sent from `Game.swift`. An event nobody will look at is
noise, so add one only with the question it answers.

## Before reading reports

- **Register custom parameters.** Parameters are collected either way, but
  only appear in reports once registered: Analytics → Admin → Custom
  definitions (a *dimension* for text/yes-no, a *metric* for numbers you
  add up). The ones marked ★ below are worth registering.
- **Google's game events** (`level_start`, `level_end`, `tutorial_begin`,
  `tutorial_complete`) use Google's names and parameters, so the built-in
  game reports understand them.
- Firebase also logs its own automatic events (`first_open`,
  `session_start`, `app_remove`, …); they aren't listed here.
- `level` is the player's current level number in the pack being played,
  also during the daily challenge (where it's the level they'd play next).

## Levels

| Event | When | Parameters | Answers |
| --- | --- | --- | --- |
| `level_start` | A level opens | `level_name` ("en-12"), `level`, `language`, `resumed` (came back to a half-done board) | Where players start, and how often they leave levels halfway |
| `level_end` | A board is submitted (a retry after a fail is another one) | `level_name`, `level`, `language`, `success`, ★`score_percent`, ★`mistakes`, ★`revealed_letters` (cat/grandma letters), `yarn`, ★`seconds` (includes time in the background: use medians) | Which levels are too hard: low pass rate, many mistakes, many helpers |

## Helpers and ads

| Event | When | Parameters | Answers |
| --- | --- | --- | --- |
| `helper_used` | A cat hint or grandma is spent | ★`helper` (`cat` / `grandma`), `level` | Which helper is used more, and on which levels |
| `ad_offer` | The "watch a video, pick a treat" card opens (a helper ran out and a video was ready) | ★`out_of` (`cat_hints` / `grandma`), `level`, ★`videos_today` | How often players run out, and of what |
| `ad_offer_cancel` | That card is closed without a video | `out_of`, `level` | How many say no to the offer |
| `rewarded_video` | A helper video ends | ★`reward` (what they picked: `cat_hints` / `grandma`), ★`out_of`, `earned` (watched to the end), `level`, ★`videos_today` (helper videos today, this one included if earned) | Which helper players value more (`reward` vs `out_of`); whether the daily cap (`rewarded_ads_per_day`) is reached |
| `rewarded_video` | A streak-save video ends | `reward` = `streak_save`, `earned`, ★`streak_days` | How often streaks are saved, and how long they were |
| `ad_break` | An interstitial was actually shown between levels | `level` (the level just passed) | How many interstitials a player really sees |

Funnel for helper videos: `ad_offer` → `rewarded_video` (earned true/false)
or `ad_offer_cancel`.

## Home: jars, knitting, streak

| Event | When | Parameters | Answers |
| --- | --- | --- | --- |
| `jar_collected` | Today's daily jar collected | `hints`, `grandmas`, ★`jar_source` (`daily`), ★`streak_day` | Whether the jar brings players back, day by day |
| `jar_opened` | A kept jar is opened | `hints`, `grandmas`, `jar_source` (`daily` / `set`), `streak_day` (daily jars), ★`still_unopened` | Whether players save jars up |
| `item_knitted` | An item is knitted | ★`item_id` ("cat.scarf.red"), `cost` | How fast players progress through the wardrobe |
| `set_completed` | The last colour of a garment is knitted (its jar then waits in the wardrobe) | `member` ("cat"), ★`garment` | How many finish each set |
| `language_switched` | The game language is changed in Settings | `language` | How many play in a second language |

## Reminders

| Event | When | Parameters | Answers |
| --- | --- | --- | --- |
| `reminder_permission` | The player answered iOS's notification prompt | `allowed` | How many allow notifications after grandma's question |
| `reminder_ask_declined` | "Not now" to grandma's own question | — | Whether her question is put at the right moment |
| `reminder_opened` | A reminder was tapped and opened the game | ★`kind`: `jar`, `streak`, `streak_save`, `unfinished`, `knit`, `yarn`, `daily`, `miss_you` | Which reminders bring players back |

## Rating and tutorial

| Event | When | Parameters | Answers |
| --- | --- | --- | --- |
| `review_prompt_requested` | The game asked iOS for the rating prompt (iOS decides whether it shows, and never says) | `moment` (`perfect_board` / `item_knitted`) | How often, and after which happy moment, players are asked |
| `tutorial_begin` | The lesson starts | — | Tutorial funnel |
| `tutorial_complete` | The lesson's board is solved | — | Tutorial funnel |
| `tutorial_skip` | The lesson is left before it's solved | — | How many skip it |

## Not tracked yet

- Daily challenge start and result (`daily_start` / `daily_end` with
  percent and time).
- Play streak gained or lost.
