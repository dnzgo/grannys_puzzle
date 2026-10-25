# Content pipeline

Makes the levels the app plays: word lists, level generation, validation,
and the clue-writing workflow. Python 3.10+, standard library only (nothing
to install).

```
ContentPipeline/
  pipeline/        the code (see each file's top comment)
  tests/           python3 -m unittest discover -s tests -t .
  sources/         downloaded word sources (not in git, see below)
  data/en/         words.tsv, clues.tsv, exclude.txt, packs/  (in git)
  clue-batches/    CSV files for clue writers (in git)
  CLUE_STYLE.md    how to write clues
```

The level rules live in `../Shared/level-rules.json`, shared with the app.
Change them there; an app test fails if the Swift side disagrees.

## 1. Download the sources (once)

The pipeline can't download these itself. Get them in a browser and unpack
into `sources/` so the paths match:

| Source | Get | Put here |
|---|---|---|
| SCOWL | Latest release zip from the *Downloads* page of wordlist.aspell.net | `sources/scowl/final/` (the `final` folder from the zip) |
| 12dicts | `12dicts` zip from the same Downloads page | `sources/12dicts/2+2+3cmn.txt` (in the zip's `Lemmatized` folder) |
| WordNet 3.0 | `WordNet-3.0.tar.gz` from wordnet.princeton.edu (Download page) | `sources/wordnet/dict/` (the `dict` folder) |
| LDNOOBW | The `en` file from github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words | `sources/badwords/en` |

If a file name differs from this table, keep the folder layout and adjust the
command below.

## 2. Build the word list

```
python3 -m pipeline.cli build-words --lang en \
  --scowl sources/scowl/final --core sources/12dicts/2+2+3cmn.txt \
  --wordnet sources/wordnet/dict --badwords sources/badwords/en
```

Writes `data/en/words.tsv`. Read through it: any word that shouldn't be in
the game goes into `data/en/exclude.txt` (one per line, `#` comments
allowed), then rebuild. Never edit `words.tsv` by hand; it's regenerated.

## 3. Generate levels

```
python3 -m pipeline.cli generate --lang en --count 100 --pack en-001
python3 -m pipeline.cli validate data/en/packs/en-001.json
```

Options: `--sizes 7x9,6x8,7x7,5x6` (columns x rows, cycled, up to 10x12),
`--max-answer-length 6` (raise it for bigger boards: 8 fits 8x10 and 9x11
well), `--max-familiarity 20` (lower = only more common words; 35 adds
harder words like ARIA and LEVEE), `--first-number`, `--seed`. The same
command always makes the same levels.

A blocking cell with no clue to hold is written as a gap (`.`): left out
of the board in the app, like a black square in a crossword. Gaps are
capped (`maxGapShare` in `Shared/level-rules.json`, 12% of the cells).
The layout search uses them where they avoid a two-letter word or an
unchecked letter: about 2 per board, which halves two-letter answers.

**Shaped boards.** `--shape-every 10` makes every 10th level (10, 20, …)
a shaped board, taking `--shapes circle,diamond,h` in turn, each on its
own size (circle 9x11, diamond 8x10, H 10x10; see `pipeline/shapes.py`,
where a new shape is one function). The cells outside the shape are gaps,
and the level gets a `"shape"` field, which allows it more gaps in all
(`maxShapeGapShare`). If a shaped level fails to fill, run again with
another `--seed`: a pack must end up with exactly 100 levels.

Words without a real clue get a placeholder cut from the dictionary
definition, so packs are playable straight away.

## 4. Write clues (shared work)

```
python3 -m pipeline.cli clue-batches --lang en --pack data/en/packs/en-001.json
```

Writes `clue-batches/en-001-001.csv`, `-002.csv`, … (300 words each) for the
words in that pack that still need clues.

- **Claim a batch before starting** (tell your teammate, or commit an empty
  change with "claim en-001-002"), so two people never edit the same file.
- Fill in `clue_1`–`clue_3` following `CLUE_STYLE.md`. Its prompt section is
  ready to paste into Claude with the batch.
- Import when done; rejected clues are listed with the reason:

```
python3 -m pipeline.cli import-clues --lang en clue-batches/en-001-002.csv
```

Then regenerate the pack: real clues replace the placeholders.

## 5. Ship a pack

Packs hold 100 levels and are named `en-001`, `en-002`, … (levels) and
`daily-en-001`, … (daily puzzles). Only pack 1 of each goes in the app;
pack 2 onwards goes on the content server and is downloaded by the app
(see `docs/LevelDelivery.md`, including the rule that published packs are
never resized or reordered):

```
cp data/en/packs/en-002.json ../Firebase/public/packs/
```

Pack 1 goes into the app's `Levels` folder (Xcode picks it up
automatically):

```
cp data/en/packs/en-001.json ../grannys_puzzle/Levels/
```

Then run the ArrowwordCore tests (⌘U). `testEveryShippedPackLoads` checks
every pack in that folder with the app's own Swift rules, a second opinion
on top of the Python validator.

## Credits the app must show

These licences require a notice. They go in the app's Acknowledgements
screen (Settings):

- **SCOWL**: Copyright 2000–2020 by Kevin Atkinson; permission to use, copy,
  modify, distribute and sell. Includes material from 12dicts (Alan Beale)
  and AGID.
- **WordNet 3.0**: Copyright 2006 by Princeton University. All rights
  reserved. (Include the full WordNet licence text.)
- **LDNOOBW**: List of Dirty, Naughty, Obscene, and Otherwise Bad Words, by
  Shutterstock, CC BY 4.0.

Check each source's own licence file when downloading: the exact notice text
comes from there.

## Turkish (and other hand-written languages)

There are no open Turkish word lists and dictionaries we can use freely in a
paid or ad-funded app, so Turkish words are written by us, each with its
clues, in the workbook `data/tr/source/turkish_words.xlsx`: one sheet per
word length, columns Word, Difficulty (Easy/Medium/Hard = familiarity
10/20/35), Clue 1–3 (no part of speech: one spelling can be several kinds
of word, MÖ "milattan önce" and a cow's moo, and nothing downstream uses it), with the ID and length columns calculated and
over-long or duplicate entries coloured. Its Guide sheet explains the
colours; its Summary sheet counts words per length against our goals.
Plain `.tsv` files in the same folder (columns: word, familiarity,
part_of_speech, clue_1..clue_3) import too; the first Turkish batches,
written that way, are kept in `source/archive/`, which isn't read. (The
current `words.tsv` and `clues.tsv` were built from them; an import that
reads no words leaves those files alone.)
The source folder is the record; everything else is built from it:

    python3 -m pipeline.cli import-word-list --lang tr     # -> words.tsv, clues.tsv
    python3 -m pipeline.cli generate --lang tr --count 100 --pack tr-001
    python3 -m pipeline.cli validate data/tr/packs/tr-001.json

`import-word-list` applies the same clue checks as `import-clues`, with
Turkish casing (i → İ, ı → I; see `pipeline/textcase.py`), and lists every
line it rejects (a workbook line reads "4 letters row 12"). Save and close
the workbook before importing: the importer reads the values Excel last
saved. To change a word or a clue, edit its source line and run the
three commands again. Copy the pack to `grannys_puzzle/Levels/` to ship it.

