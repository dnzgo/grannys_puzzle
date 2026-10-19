# Remote Config keys

Every number the game lets you change from the Firebase console without an
App Store update. **Keep this file in step with the code:** whenever a key is
added, removed, renamed or its default or range changes, update it in the
same commit.

Source of truth: `GameTuning.swift` in ArrowwordCore (key names in
`GameTuning.Key`, defaults on the properties, ranges in `resolved(from:)`).
A test fails if a key is listed there but never read.

## How it works

- **Where:** Firebase console → Remote Config. Add a parameter with the exact
  key name and a **Number** value. Set only the ones you want to change;
  anything not set keeps the default below.
- **When it applies:** on the player's *next* launch. The game downloads
  values during one launch and uses them from the next, so rules never
  change mid-session.
- **A bad value is ignored, not applied.** Outside its range, or a fraction
  where a whole number is needed: the default stays and the key is logged.
- **Some keys only work as a group.** The scoring thresholds must step down
  (3 balls ≥ 2 balls ≥ 1 ball) and the jar's hint min/max must not cross; if
  a group doesn't fit, the whole group keeps its defaults.
- **Shares are written 0–1:** 0.8 means 80%, never 80.

## Ads

An interstitial shows only when both the level rules and the time rules
allow it. A time of 0 leaves only the level rule.

| Key | What it controls | Default | Allowed |
| --- | --- | --- | --- |
| `rewarded_ads_per_day` | Helper videos a player may watch per day (cat and grandma combined). 0 turns them off. The streak-save video doesn't count toward it. | 3 | 0–20 |
| `cat_hints_per_ad` | Cat hints one video gives, when the player picks cats | 3 | 1–10 |
| `grandmas_per_ad` | Grandma helpers one video gives, when the player picks grandma | 1 | 1–5 |
| `ad_break_first_level` | Interstitials can start after this level; earlier ones are ad-free | 10 | 1–1000 |
| `ad_break_levels_between` | Levels passed between two interstitials | 2 | 1–50 |
| `ad_break_min_seconds` | Least time between two interstitials, in seconds | 180 | 0–3600 |
| `ad_break_seconds_after_rewarded` | No interstitial this many seconds after a rewarded video | 120 | 0–3600 |

## Scoring

Shares of correct letters. Applied as a group (see above).

| Key | What it controls | Default | Allowed |
| --- | --- | --- | --- |
| `pass_threshold` | Share needed to pass a level | 0.8 | 0–1 |
| `three_ball_threshold` | Share needed for 3 yarn balls | 1.0 | 0–1 |
| `two_ball_threshold` | Share needed for 2 yarn balls | 0.9 | 0–1 |
| `one_ball_threshold` | Share needed for 1 yarn ball | 0.8 | 0–1 |

## Daily jar

The jar is collected once a day on a 7-day calendar. The big reward is also
what a finished wardrobe set gives. Hint min and max are a group.

| Key | What it controls | Default | Allowed |
| --- | --- | --- | --- |
| `jar_grandma_chance` | Chance an ordinary day's jar holds a grandma instead of cat hints | 0.25 | 0–1 |
| `jar_hints_min` | Fewest cat hints in an ordinary day's jar | 1 | 1–10 |
| `jar_hints_max` | Most cat hints in an ordinary day's jar | 3 | 1–10 |
| `jar_big_reward_hints` | Cat hints in the day-7 jar and a finished set's jar | 3 | 0–20 |
| `jar_big_reward_grandmas` | Grandma helpers in the day-7 jar and a finished set's jar | 1 | 0–5 |

## Prompts

At least 1 each, so neither can come straight after the tutorial.

| Key | What it controls | Default | Allowed |
| --- | --- | --- | --- |
| `review_min_levels` | Levels passed before the App Store rating prompt may be asked for | 5 | 1–500 |
| `reminder_ask_min_levels` | Levels passed before grandma asks whether she may send reminders | 3 | 1–100 |

## Fixed in code (not remote)

- Wait between rating prompts: 120 days (`ReviewPromptRules`).
- Reminders: at most one a day, 10:00–20:00, quiet after 7 days away
  (`ReminderRules` in NotifyKit); schedule in `GrannyReminders`.
- Daily jar cycle length: 7 days (`DailyJarRules.streakLength`).
- Knitting prices (`KnittingCatalog.catPrices`).
