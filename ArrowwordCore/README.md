# ArrowwordCore

The game rules for the arrowword app, as a Swift package with no UI, ads or
network code. The iOS app depends on this package; everything here is
covered by unit tests.

## Layout

```
Sources/ArrowwordCore/
  Level/    Loading and validating levels
    LevelFile.swift    The JSON format of a level (storage shape)
    Level.swift        A validated level with precomputed lookups
    LevelRules.swift   Format limits (grid size, 16 tray letters…) and alphabets
    LevelError.swift   Why a level was rejected
    Answer.swift, Coordinate.swift, Direction.swift
  Puzzle/   Playing a level
    PuzzleState.swift  Board, selection, place / erase, cat and grandma reveals, submit
    Scoring.swift      Stars and pass/fail thresholds
Tests/ArrowwordCoreTests/
  Fixtures/level-100.json   The 7×9 level from the design canvas
```

## Running the tests

- **Xcode:** open `Package.swift`, choose any Mac or iOS simulator destination, press ⌘U.
- **Terminal (Mac):** `swift test`

## Design rules worth keeping

- `LevelFile` (what's stored) and `Level` (what the game uses) are separate,
  so the JSON format can change without touching game logic.
- Tray counts are derived from the board, never stored separately.
- `PuzzleState` knows what a reveal does to the board, not whether the
  player can afford it. Wallets and ads live outside this package.
- `LevelRules` must match the level generator's rules.
