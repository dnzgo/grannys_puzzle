"""Builds the answer word list for a language from the downloaded sources.

A word makes the list only if every check agrees:
- it's in the core vocabulary list (12dicts 2+2+3cmn: dictionary forms
  most people know, so no "cats" or "running" as separate answers);
- SCOWL rates it common enough (its size, used as a familiarity score);
- WordNet has a definition for it (the starting point for its clues);
- it fits the grid, uses only the language's alphabet, and isn't on the
  offensive-word list or our own exclude list.

The result is a plain TSV file that's easy to read, diff and review.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path

from .sources import Definition


@dataclass(frozen=True)
class WordEntry:
    word: str  # uppercase, as it appears in the grid
    familiarity: int  # SCOWL size: lower is more common
    part_of_speech: str
    definition: str


@dataclass(frozen=True)
class WordListSettings:
    min_length: int
    max_length: int
    max_familiarity: int  # SCOWL size cut-off, e.g. 50


def build_word_list(
    *,
    core_words: set[str],
    familiarity: dict[str, int],
    definitions: dict[str, Definition],
    blocked: set[str],
    alphabet: str,
    settings: WordListSettings,
) -> list[WordEntry]:
    allowed_letters = set(alphabet)
    entries: list[WordEntry] = []
    for word in sorted(core_words):
        size = familiarity.get(word)
        definition = definitions.get(word)
        upper = word.upper()
        if size is None or size > settings.max_familiarity:
            continue
        if definition is None:
            continue
        if not settings.min_length <= len(word) <= settings.max_length:
            continue
        if not set(upper) <= allowed_letters:
            continue
        if word in blocked:
            continue
        entries.append(WordEntry(upper, size, definition.part_of_speech, definition.gloss))
    # Most familiar first, then alphabetical, so the file reads naturally.
    entries.sort(key=lambda entry: (entry.familiarity, entry.word))
    return entries


def read_blocked_words(*paths: Path) -> set[str]:
    """Offensive and excluded words, lowercase. Multi-word entries can't be
    grid answers anyway; only single words matter here. Lines starting with
    `#` are comments, so the exclude file can explain each entry."""
    blocked: set[str] = set()
    for path in paths:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            entry = line.split("#", 1)[0].strip().lower()
            if entry and " " not in entry:
                blocked.add(entry)
    return blocked


FIELDS = ["word", "familiarity", "part_of_speech", "definition"]


def write_word_list(entries: list[WordEntry], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, delimiter="\t", lineterminator="\n")
        writer.writerow(FIELDS)
        for entry in entries:
            writer.writerow([entry.word, entry.familiarity, entry.part_of_speech, entry.definition])


def read_word_list(path: Path) -> list[WordEntry]:
    with path.open(encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file, delimiter="\t")
        return [
            WordEntry(row["word"], int(row["familiarity"]), row["part_of_speech"], row["definition"])
            for row in reader
        ]
