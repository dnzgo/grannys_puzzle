"""Word lists written by hand, for languages without open sources we can use.

English words come from SCOWL, 12dicts and WordNet (see `build-words`).
Turkish has no equivalent we can use freely in a commercial app, so its
words are written by us: everyday Turkish, in dictionary form, each with a
familiarity rating and its clues. The source files (data/<lang>/source/*.tsv)
are the record; `words.tsv` and `clues.tsv` are built from them, so editing
a word means editing its source line and re-running `import-word-list`.

Source columns (tab-separated, with a header row):
    word            lowercase, as written ("çay", "iğne")
    familiarity     10 everyday, 20 common, 35 less common (same scale as
                    the English list, so `--max-familiarity 20` means the
                    same thing in both languages)
    part_of_speech  optional: noun, verb, adjective, adverb, abbreviation,
                    other. Nothing downstream needs it, and one spelling
                    can be several kinds of word (MÖ: "milattan önce", or
                    a cow's moo), so the words workbook has no such column.
    clue_1..clue_3  clues; clue_1 is also the definition. Empty ones are fine.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path

from .clues import CLUE_COLUMNS, check_clue
from .xlsx import read_sheets
from .textcase import upper
from .wordlist import WordEntry

FAMILIARITY_LEVELS = (10, 20, 35)

# The words workbook (data/<lang>/source/*.xlsx) uses friendlier headers
# and labels than the TSV files; this maps them onto the TSV columns.
_WORKBOOK_COLUMNS = {
    "Word": "word", "Difficulty": "familiarity",
    "Clue 1": "clue_1", "Clue 2": "clue_2", "Clue 3": "clue_3",
}
_DIFFICULTY = {"Easy": "10", "Medium": "20", "Hard": "35"}


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


def read_sources(
    paths: list[Path],
    language: str,
    alphabet: str,
    min_length: int,
    max_length: int,
    clue_max_length: int,
) -> tuple[list[WordEntry], list[tuple[str, str]], list[SourceProblem]]:
    """Reads and checks source files. Returns the words, their (word, clue)
    pairs, and every problem found. A word with a problem is left out (and
    reported) rather than half-imported."""
    allowed = set(alphabet)
    entries: dict[str, WordEntry] = {}
    clues: list[tuple[str, str]] = []
    problems: list[SourceProblem] = []

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
            if word in entries:
                problem("listed twice")
                continue
            try:
                familiarity = int(row.get("familiarity") or "")
            except ValueError:
                problem("familiarity isn't a number")
                continue
            if familiarity not in FAMILIARITY_LEVELS:
                problem(f"familiarity {familiarity} isn't one of {FAMILIARITY_LEVELS}")
                continue
            part = (row.get("part_of_speech") or "").strip()
            if part and part not in PARTS_OF_SPEECH:
                problem(f"part of speech {part!r} isn't one of {PARTS_OF_SPEECH}")
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
            if not word_clues:
                problem("no clue")
                continue

            entries[word] = WordEntry(word, familiarity, part, word_clues[0])
            clues += [(word, clue) for clue in word_clues]

    words = sorted(entries.values(), key=lambda entry: (entry.familiarity, entry.word))
    return words, clues, problems


def write_clue_bank(pairs: list[tuple[str, str]], path: Path) -> None:
    """Writes clues.tsv from scratch: for authored languages the sources are
    the record, so the bank is rebuilt rather than appended to."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, delimiter="\t", lineterminator="\n")
        writer.writerow(["word", "clue"])
        for word, clue in sorted(pairs):
            writer.writerow([word, clue])
