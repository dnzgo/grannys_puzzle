"""Word lists kept in a words workbook (or TSV files), for both languages.

The source files in data/<lang>/source/ are the record; `words.tsv` and
`clues.tsv` are built from them by `import-word-list`, so editing a word
means editing its row and importing again.

Turkish has no open word list we can use freely in a commercial app, so
its words are written by us. English words were first taken from SCOWL,
12dicts and WordNet (`build-words`), then moved into a workbook where clues
and extra words are added by hand; from then on the workbook is the record.

Columns (workbook header / TSV header):
    Word / word                 lowercase, as written ("çay", "iğne")
    Difficulty / familiarity    Easy 10, Medium 20, Hard 35, Rare 50: the
                                SCOWL size scale, so `--max-familiarity 20`
                                means the same in both languages
    Definition / definition     optional: what the word means (English has
                                WordNet's); a help when writing clues
    Clue 1..3 / clue_1..clue_3  the clues; empty ones are fine
    part_of_speech (TSV only)   optional: noun, verb, adjective, adverb,
                                abbreviation, other. Nothing downstream
                                needs it, and one spelling can be several
                                kinds of word (MÖ: "milattan önce", or a
                                cow's moo), so the workbook has no column.

A word with no clue yet is "waiting" rather than wrong: words are listed
first and clued over time. A waiting word with a definition still goes into
words.tsv (the generator can place it, shown with its definition, for test
packs; `clue-batches` lists the ones a pack needs real clues for). A
waiting word with neither stays out until it's clued.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple

from .clues import CLUE_COLUMNS, check_clue
from .xlsx import read_sheets
from .textcase import lower, upper
from .wordlist import WordEntry

FAMILIARITY_LEVELS = (10, 20, 35, 50)

# The words workbook (data/<lang>/source/*.xlsx) uses friendlier headers
# and labels than the TSV files; this maps them onto the TSV columns.
_WORKBOOK_COLUMNS = {
    "Word": "word", "Difficulty": "familiarity", "Definition": "definition",
    "Clue 1": "clue_1", "Clue 2": "clue_2", "Clue 3": "clue_3",
}
_DIFFICULTY = {"Easy": "10", "Medium": "20", "Hard": "35", "Rare": "50"}


def _source_rows(path: Path):
    """(line, row) pairs of a source file, the row keyed by the TSV column
    names whatever the file type. A workbook row's line is "sheet row"."""
    if path.suffix == ".xlsx":
        for sheet, number, row in read_sheets(path):
            if not row.get("Word"):
                continue  # rows prepared for writing, still empty
            mapped = {key: row.get(header, "") for header, key in _WORKBOOK_COLUMNS.items()}
            mapped["familiarity"] = _DIFFICULTY.get(mapped["familiarity"], mapped["familiarity"])
            yield f"{sheet} row {number}", mapped
        return
    with path.open(encoding="utf-8", newline="") as file:
        for number, row in enumerate(csv.DictReader(file, delimiter="\t"), start=2):
            yield number, row
PARTS_OF_SPEECH = ("noun", "verb", "adjective", "adverb", "abbreviation", "other")


@dataclass(frozen=True)
class SourceProblem:
    file: str
    line: int | str  # a TSV line number, or "sheet row N" in a workbook
    word: str
    reason: str


class SourceRead(NamedTuple):
    words: list[WordEntry]
    clues: list[tuple[str, str]]
    problems: list[SourceProblem]
    # Listed, but with no clue (and no definition) yet.
    waiting: list[str]


def read_sources(
    paths: list[Path],
    language: str,
    alphabet: str,
    min_length: int,
    max_length: int,
    clue_max_length: int,
    blocked: set[str] | frozenset[str] = frozenset(),
) -> SourceRead:
    """Reads and checks source files. A word with a problem is left out (and
    reported) rather than half-imported. `blocked` is lowercase words that
    must never be answers (the bad-word lists): checked here too, because
    words typed into the workbook by hand never went through build-words."""
    allowed = set(alphabet)
    entries: dict[str, WordEntry] = {}
    seen: set[str] = set()
    clues: list[tuple[str, str]] = []
    problems: list[SourceProblem] = []
    waiting: list[str] = []

    for path in paths:
        for number, row in _source_rows(path):
            raw = (row.get("word") or "").strip()
            word = upper(raw, language)

            def problem(reason: str) -> None:
                problems.append(SourceProblem(path.name, number, word or raw, reason))

            if not word:
                problem("no word")
                continue
            if not set(word) <= allowed:
                problem(f"letters outside the {language} alphabet: {''.join(sorted(set(word) - allowed))}")
                continue
            if not min_length <= len(word) <= max_length:
                problem(f"length {len(word)} outside {min_length}–{max_length}")
                continue
            if word in seen:
                problem("listed twice")
                continue
            seen.add(word)
            if lower(word, language) in blocked:
                problem("on the blocked-words list (exclude.txt or LDNOOBW)")
                continue

            word_clues: list[str] = []
            bad_clue = False
            for column in CLUE_COLUMNS:
                clue = (row.get(column) or "").strip()
                if not clue:
                    continue
                reason = check_clue(word, clue, clue_max_length, language)
                if reason:
                    problem(f"{column} {clue!r}: {reason}")
                    bad_clue = True
                elif clue not in word_clues:
                    word_clues.append(clue)
            if bad_clue:
                continue
            definition = (row.get("definition") or "").strip()
            if not word_clues and not definition:
                # Listed but not clued yet: normal while the list is being
                # written, so counted rather than reported. Checked before
                # the difficulty, which may be left empty until then.
                waiting.append(word)
                continue

            try:
                familiarity = int(row.get("familiarity") or "")
            except ValueError:
                problem("no difficulty" if not row.get("familiarity") else "familiarity isn't a number")
                continue
            if familiarity not in FAMILIARITY_LEVELS:
                problem(f"familiarity {familiarity} isn't one of {FAMILIARITY_LEVELS}")
                continue
            part = (row.get("part_of_speech") or "").strip()
            if part and part not in PARTS_OF_SPEECH:
                problem(f"part of speech {part!r} isn't one of {PARTS_OF_SPEECH}")
                continue

            entries[word] = WordEntry(word, familiarity, part, definition or word_clues[0])
            clues += [(word, clue) for clue in word_clues]

    words = sorted(entries.values(), key=lambda entry: (entry.familiarity, entry.word))
    return SourceRead(words, clues, problems, waiting)


def write_clue_bank(pairs: list[tuple[str, str]], path: Path) -> None:
    """Writes clues.tsv from scratch: for authored languages the sources are
    the record, so the bank is rebuilt rather than appended to."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, delimiter="\t", lineterminator="\n")
        writer.writerow(["word", "clue"])
        for word, clue in sorted(pairs):
            writer.writerow([word, clue])
