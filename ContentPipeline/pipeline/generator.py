"""Generates complete levels: layout, fill, clues and starter letters.

Every level is produced from a seed, so the same command always makes the
same levels. That matters: if a level has a problem, it can be regenerated
exactly to investigate it.
"""

from __future__ import annotations

import random
from collections import Counter, deque
from dataclasses import dataclass

from .clues import ClueBank, placeholder_clue
from .filler import WordIndex, fill_slots
from .layout import UNUSABLE, Cell, Layout, LayoutWeights, Slot, find_slots, gap_cells, layout_key, search_layout
from .rules import Rules
from .shapes import outside_cells
from .wordlist import WordEntry

FORMAT_VERSION = 1


@dataclass(frozen=True)
class LevelSpec:
    rows: int
    columns: int
    max_familiarity: int  # only words at least this common (SCOWL size)
    starter_share: float = 0.08  # share of letter cells shown from the start
    # Longer answers make grids much harder to fill (fewer words cross well),
    # and 7–8 letter answers rarely fit a 7-column grid nicely anyway.
    max_answer_length: int = 6
    # None for the whole rectangle, or a name from shapes.SHAPES.
    shape: str | None = None


@dataclass
class GenerationStats:
    layouts_tried: int = 0
    fills_tried: int = 0
    placeholder_clues: int = 0


class LevelGenerator:
    """Holds the word list and clue bank for one language. Word indexes are
    built once per familiarity cut-off and reused for every level, because
    building them is the slow part."""

    def __init__(self, language: str, words: list[WordEntry], clue_bank: ClueBank, rules: Rules):
        self.language = language
        self.rules = rules
        self.clue_bank = clue_bank
        self.entries = {entry.word: entry for entry in words}
        self._full_index = WordIndex.build({entry.word: entry.familiarity for entry in words})
        self._indexes: dict[int, WordIndex] = {}
        self.stats = GenerationStats()
        self.used_words: set[str] = set()
        # Word usage so far in this run, so later levels prefer words the
        # player hasn't just seen. `recent` covers the last few levels (a
        # word shouldn't come back right away); `total` the whole run (use
        # the whole vocabulary before repeating). Because levels are made in
        # order, the same command still gives the same pack. The trade-off:
        # regenerating one level on its own no longer reproduces it exactly,
        # since its result now depends on the levels made before it.
        self.recent_window = 15
        # Words from this many latest levels are kept out entirely, as long
        # as the level can still be filled without them.
        self.block_window = 8
        self._recent: deque[set[str]] = deque(maxlen=self.recent_window)
        self._total_uses: Counter[str] = Counter()

    def _index(self, max_familiarity: int) -> WordIndex:
        if max_familiarity not in self._indexes:
            self._indexes[max_familiarity] = self._full_index.restricted(max_familiarity)
        return self._indexes[max_familiarity]

    def generate(self, level_id: str, spec: LevelSpec, seed: int, max_attempts: int = 40) -> dict | None:
        """One level in the app's JSON format, or None if no fill was found."""
        rng = random.Random(seed)
        index = self._index(spec.max_familiarity)
        # A layout can't ask for answers longer than any word we have.
        max_answer_length = min(spec.max_answer_length, index.longest_word_length)

        outside = outside_cells(spec.shape, spec.rows, spec.columns)
        failed_layouts: set[str] = set()
        for attempt in range(max_attempts):
            self.stats.layouts_tried += 1
            # The first attempt uses the default preferences; later ones vary
            # them, so retries explore different layouts.
            weights = LayoutWeights() if attempt == 0 else LayoutWeights.random(rng)
            layout, penalty = search_layout(
                spec.rows, spec.columns, self.rules, rng, max_answer_length,
                weights=weights, avoid=frozenset(failed_layouts), outside=outside,
            )
            if penalty >= UNUSABLE:
                continue  # a hard problem remains: not playable
            slots = find_slots(layout, self.rules.min_answer_length, outside)
            # A few quick fills per layout, each with a fresh random word order.
            # The first ones keep recently used words out; the last allows
            # them, so a hard layout can still be filled.
            blocked = self._recently_used()
            for fill_attempt in range(4):
                self.stats.fills_tried += 1
                assignment = fill_slots(
                    slots, index, rng, self.rules.max_distinct_letters,
                    freshness=self._freshness,
                    blocked=blocked if fill_attempt < 3 else frozenset(),
                )
                if assignment is not None:
                    return self._build(level_id, spec, layout, slots, assignment, rng)
            failed_layouts.add(layout_key(layout))
        return None

    def _recently_used(self) -> frozenset[str]:
        latest = list(self._recent)[-self.block_window:]
        return frozenset().union(*latest) if latest else frozenset()

    def _freshness(self, word: str) -> tuple[int, int]:
        recent = sum(word in level for level in self._recent)
        return (recent, self._total_uses[word])

    def _build(
        self,
        level_id: str,
        spec: LevelSpec,
        layout: Layout,
        slots: list[Slot],
        assignment: dict[int, str],
        rng: random.Random,
    ) -> dict:
        letters: dict[Cell, str] = {}
        clues = []
        for position, slot in enumerate(slots):
            word = assignment[position]
            self.used_words.add(word)
            for cell, letter in zip(slot.cells, word):
                letters[cell] = letter
            clue = self.clue_bank.next_clue(word)
            if clue is None:
                clue = placeholder_clue(self.entries[word].definition, self.rules.clue_max_length)
                self.stats.placeholder_clues += 1
            assert slot.clue_cell is not None, "layouts with unclued answers are rejected earlier"
            row, column = slot.clue_cell
            clues.append({"row": row, "column": column, "arrow": slot.arrow, "text": clue})

        gaps = gap_cells(layout, slots)

        def character(r: int, c: int) -> str:
            if not layout[r][c]:
                return letters[(r, c)]
            return "." if (r, c) in gaps else "#"

        grid = ["".join(character(r, c) for c in range(spec.columns)) for r in range(spec.rows)]
        level_words = {assignment[position] for position in range(len(slots))}
        self._recent.append(level_words)
        self._total_uses.update(level_words)

        letter_cells = sorted(letters)
        starter_count = max(1, round(len(letter_cells) * spec.starter_share))
        givens = sorted(rng.sample(letter_cells, starter_count))

        level = {
            "formatVersion": FORMAT_VERSION,
            "id": level_id,
            "clueLanguage": self.language,
            "answerLanguage": self.language,
            "grid": grid,
            "clues": clues,
            "givens": [{"row": r, "column": c} for r, c in givens],
        }
        # Only shaped levels say so; a plain rectangle has no "shape" key.
        if spec.shape is not None:
            level["shape"] = spec.shape
        return level
