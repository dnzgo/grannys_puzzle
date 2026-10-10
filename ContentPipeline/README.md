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

Options: `--sizes 7x9,6x8,7x7,5x6` (columns x rows, cycled),
`--max-familiarity 35` (lower = only more common words), `--first-number`,
`--seed`. The same command always makes the same levels.

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

## 5. Ship a pack in the app

Copy the pack into the app's `Levels` folder (Xcode picks it up
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
