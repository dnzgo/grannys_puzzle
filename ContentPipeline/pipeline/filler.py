"""Fills a layout's answer slots with real words.

Backtracking search with the "most constrained slot first" rule: at each step,
fill the slot with the fewest possible words left. Slots with few options
fail fast, which prunes dead ends early; this is the standard approach for
crossword filling.

Two things keep it fast:
- Pattern lookups are cached. The search asks "which words fit C?R??" over
  and over; each distinct pattern is worked out once.
- Searches are short. A fill that hasn't succeeded after a few thousand steps
  rarely will; the generator restarts with a new random order or a new
  layout instead (random restarts beat one long search for this problem).
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field

from .layout import Cell, Slot


@dataclass
class WordIndex:
    """Words grouped for fast lookup: by length, and by (length, position,
    letter), so "5-letter words with A in position 2" is a set lookup."""

    familiarity: dict[str, int]
    by_length: dict[int, list[str]] = field(default_factory=dict)
    by_letter: dict[tuple[int, int, str], set[str]] = field(default_factory=dict)
    _pattern_cache: dict[str, tuple[str, ...]] = field(default_factory=dict)

    @classmethod
    def build(cls, familiarity: dict[str, int]) -> "WordIndex":
        index = cls(familiarity)
        for word in familiarity:
            index.by_length.setdefault(len(word), []).append(word)
            for position, letter in enumerate(word):
                index.by_letter.setdefault((len(word), position, letter), set()).add(word)
        return index

    @property
    def longest_word_length(self) -> int:
        return max(self.by_length, default=0)

    def restricted(self, max_familiarity: int) -> "WordIndex":
        """The same index limited to words at least this familiar."""
        return WordIndex.build({w: f for w, f in self.familiarity.items() if f <= max_familiarity})

    def matching(self, pattern: str) -> tuple[str, ...]:
        """Words fitting a pattern such as "C?R??" ("?" = any letter). Cached:
        the same patterns come up again and again during a search."""
        cached = self._pattern_cache.get(pattern)
        if cached is not None:
            return cached
        length = len(pattern)
        pool: set[str] | None = None
        for position, letter in enumerate(pattern):
            if letter == "?":
                continue
            words = self.by_letter.get((length, position, letter), set())
            pool = set(words) if pool is None else pool & words
            if not pool:
                break
        # Sorted, not set order: Python shuffles string hashing on every run,
        # so set order differs between runs. The filler draws a random number
        # per word in this order, so an unsorted result would make the same
        # seed produce different levels each time.
        result = tuple(self.by_length.get(length, ())) if pool is None else tuple(sorted(pool))
        self._pattern_cache[pattern] = result
        return result


def fill_slots(
    slots: list[Slot],
    index: WordIndex,
    rng: random.Random,
    max_distinct_letters: int,
    node_limit: int = 4000,
    candidates_per_slot: int = 40,
) -> dict[int, str] | None:
    """Returns {slot position: word}, or None if no fill was found within
    `node_limit` search steps."""
    grid: dict[Cell, str] = {}
    used: set[str] = set()
    assignment: dict[int, str] = {}
    nodes = 0

    def pattern(slot: Slot) -> str:
        return "".join(grid.get(cell, "?") for cell in slot.cells)

    def options(slot: Slot) -> list[str]:
        return [word for word in index.matching(pattern(slot)) if word not in used]

    def ordered(words: list[str]) -> list[str]:
        # Prefer familiar words, with random order inside each familiarity
        # level so levels don't all reuse the same few words.
        keyed = sorted((index.familiarity[word], rng.random(), word) for word in words)
        return [word for _, _, word in keyed[:candidates_per_slot]]

    def solve() -> bool:
        nonlocal nodes
        nodes += 1
        if nodes > node_limit:
            return False
        best_slot, best_options = None, None
        for position, slot in enumerate(slots):
            if position in assignment:
                continue
            found = options(slot)
            if not found:
                return False  # some slot can no longer be filled: dead end
            if best_options is None or len(found) < len(best_options):
                best_slot, best_options = position, found
                if len(found) == 1:
                    break  # can't get more constrained than one option
        if best_slot is None:
            return True  # every slot filled

        slot = slots[best_slot]
        for word in ordered(best_options):
            previous = {cell: grid.get(cell) for cell in slot.cells}
            for cell, letter in zip(slot.cells, word):
                grid[cell] = letter
            # The letter tray holds a limited number of distinct letters.
            if len(set(grid.values())) <= max_distinct_letters:
                used.add(word)
                assignment[best_slot] = word
                if solve():
                    return True
                used.discard(word)
                del assignment[best_slot]
            for cell, letter in previous.items():
                if letter is None:
                    grid.pop(cell, None)
                else:
                    grid[cell] = letter
            if nodes > node_limit:
                return False
        return False

    return dict(assignment) if solve() else None
