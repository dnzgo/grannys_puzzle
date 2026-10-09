"""Clues: the clue bank, placeholder clues, and the batch workflow for writing
real clues by hand or with Claude.

Clues belong to words, not levels: a common word appears in hundreds of
levels, so each word gets several clues and levels rotate through them.

Workflow:
1. `clue-batch` writes CSV files of words that still need clues, with their
   definitions as a starting point.
2. A person (with Claude) fills in clue_1..clue_3 following CLUE_STYLE.md.
3. `import-clues` checks every clue and adds the good ones to clues.tsv.
   Rejected clues are listed with the reason, so they can be fixed.
"""

from __future__ import annotations

import csv
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from .wordlist import WordEntry

CLUE_COLUMNS = ["clue_1", "clue_2", "clue_3"]
BATCH_FIELDS = ["word", "length", "part_of_speech", "definition", *CLUE_COLUMNS, "notes"]


def placeholder_clue(definition: str, max_length: int) -> str:
    """A temporary clue from a dictionary definition, so generated levels can
    be played before real clues exist. Cut at a word boundary to fit."""
    text = definition.strip()
    text = text[:1].upper() + text[1:]
    if len(text) <= max_length:
        return text
    cut = text[: max_length - 1].rsplit(" ", 1)[0].rstrip(" ,;:-")
    return cut + "…"


class ClueBank:
    """Real clues per word, handing them out in rotation so the same clue
    doesn't come back level after level."""

    def __init__(self, clues: dict[str, list[str]]):
        self._clues = clues
        self._uses: dict[tuple[str, str], int] = defaultdict(int)

    @classmethod
    def load(cls, path: Path) -> "ClueBank":
        clues: dict[str, list[str]] = defaultdict(list)
        if path.exists():
            with path.open(encoding="utf-8", newline="") as file:
                for row in csv.DictReader(file, delimiter="\t"):
                    clues[row["word"]].append(row["clue"])
        return cls(dict(clues))

    def has_clue(self, word: str) -> bool:
        return bool(self._clues.get(word))

    def next_clue(self, word: str) -> str | None:
        options = self._clues.get(word)
        if not options:
            return None
        clue = min(options, key=lambda option: self._uses[(word, option)])
        self._uses[(word, clue)] += 1
        return clue


# MARK: - Writing batches

def write_batches(entries: list[WordEntry], out_dir: Path, batch_size: int, prefix: str) -> list[Path]:
    """Splits words into CSV batches for clue writers. Each batch is a file
    one person can take, so two people never edit the same file."""
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    for start in range(0, len(entries), batch_size):
        chunk = entries[start : start + batch_size]
        path = out_dir / f"{prefix}-{start // batch_size + 1:03d}.csv"
        with path.open("w", encoding="utf-8", newline="") as file:
            writer = csv.DictWriter(file, fieldnames=BATCH_FIELDS)
            writer.writeheader()
            for entry in chunk:
                writer.writerow({
                    "word": entry.word,
                    "length": len(entry.word),
                    "part_of_speech": entry.part_of_speech,
                    "definition": entry.definition,
                })
        paths.append(path)
    return paths


# MARK: - Checking clues

@dataclass(frozen=True)
class ClueProblem:
    word: str
    clue: str
    reason: str


def check_clue(word: str, clue: str, max_length: int) -> str | None:
    """Why a clue is rejected, or None if it passes the automatic checks.
    These catch mechanical mistakes; whether a clue is *good* is still a
    person's call (see CLUE_STYLE.md)."""
    text = clue.strip()
    if not text:
        return "empty"
    if len(text) > max_length:
        return f"too long ({len(text)} > {max_length} characters)"
    if "\n" in text or "\t" in text:
        return "contains a line break or tab"
    lowered = text.lower()
    answer = word.lower()
    if re.search(rf"\b{re.escape(answer)}", lowered):
        return "contains the answer"
    # "Running" as a clue for RUN gives it away too. Checking a 4-letter stem
    # catches most of these without flagging unrelated short words.
    if len(answer) >= 5 and re.search(rf"\b{re.escape(answer[:4])}", lowered):
        return "contains the start of the answer"
    return None


def import_batch(path: Path, max_length: int) -> tuple[list[tuple[str, str]], list[ClueProblem]]:
    """Reads a filled-in batch. Returns accepted (word, clue) pairs and the
    problems found."""
    accepted: list[tuple[str, str]] = []
    problems: list[ClueProblem] = []
    with path.open(encoding="utf-8", newline="") as file:
        for row in csv.DictReader(file):
            word = row["word"].strip().upper()
            seen: set[str] = set()
            for column in CLUE_COLUMNS:
                clue = (row.get(column) or "").strip()
                if not clue:
                    continue
                reason = check_clue(word, clue, max_length)
                if reason is None and clue.lower() in seen:
                    reason = "same clue twice for this word"
                if reason:
                    problems.append(ClueProblem(word, clue, reason))
                else:
                    seen.add(clue.lower())
                    accepted.append((word, clue))
    return accepted, problems


def append_to_bank(pairs: list[tuple[str, str]], path: Path) -> int:
    """Adds new clues to clues.tsv, skipping exact duplicates. Returns how
    many were added."""
    existing: set[tuple[str, str]] = set()
    if path.exists():
        with path.open(encoding="utf-8", newline="") as file:
            existing = {(row["word"], row["clue"]) for row in csv.DictReader(file, delimiter="\t")}
    new_pairs = [pair for pair in pairs if pair not in existing]
    write_header = not path.exists()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, delimiter="\t", lineterminator="\n")
        if write_header:
            writer.writerow(["word", "clue"])
        for word, clue in new_pairs:
            writer.writerow([word, clue])
    return len(new_pairs)
