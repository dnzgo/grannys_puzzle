"""Grid layouts: where the clue cells go, and which answer slots that makes.

A layout is a grid of booleans (True = clue cell). It's searched for before
any words are placed, because whether a layout is fillable and pleasant
depends only on its shape: short runs, crossings, and clue placement.

Arrowword conventions used here:
- the top row has clue cells in every other column, the left column in
  every other row, so edge answers always have a clue next to them;
- an answer starting on the top edge is clued from the cell to its left with
  a bent `rightDown` arrow; one starting on the left edge from the cell above
  with a bent `downRight` arrow.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass

from .rules import Rules

Cell = tuple[int, int]
Layout = list[list[bool]]


@dataclass(frozen=True)
class Slot:
    """One answer: its cells and the clue that points at it (None if nothing can)."""

    cells: tuple[Cell, ...]
    clue_cell: Cell | None
    arrow: str | None  # "right", "down", "rightDown", "downRight"

    @property
    def direction(self) -> str:
        return "across" if self.cells[1][0] == self.cells[0][0] else "down"


def base_layout(rows: int, columns: int) -> Layout:
    layout = [[False] * columns for _ in range(rows)]
    for column in range(columns):
        layout[0][column] = column % 2 == 0
    for row in range(rows):
        layout[row][0] = row % 2 == 0
    return layout


def find_slots(layout: Layout, min_length: int = 2) -> list[Slot]:
    """Every maximal run of letter cells of `min_length` or more, with the clue
    cell that can point at it."""
    rows, columns = len(layout), len(layout[0])
    slots: list[Slot] = []

    for row in range(rows):
        column = 0
        while column < columns:
            if layout[row][column]:
                column += 1
                continue
            start = column
            while column < columns and not layout[row][column]:
                column += 1
            cells = tuple((row, c) for c in range(start, column))
            if len(cells) < min_length:
                continue
            if start > 0:
                slots.append(Slot(cells, (row, start - 1), "right"))
            elif row > 0 and layout[row - 1][0]:
                slots.append(Slot(cells, (row - 1, 0), "downRight"))
            else:
                slots.append(Slot(cells, None, None))

    for column in range(columns):
        row = 0
        while row < rows:
            if layout[row][column]:
                row += 1
                continue
            start = row
            while row < rows and not layout[row][column]:
                row += 1
            cells = tuple((r, column) for r in range(start, row))
            if len(cells) < min_length:
                continue
            if start > 0:
                slots.append(Slot(cells, (start - 1, column), "down"))
            elif column > 0 and layout[0][column - 1]:
                slots.append(Slot(cells, (0, column - 1), "rightDown"))
            else:
                slots.append(Slot(cells, None, None))
    return slots


_EXITS_BOTTOM = {"down": True, "downRight": True, "right": False, "rightDown": False}


@dataclass(frozen=True)
class LayoutWeights:
    """How much the search dislikes each soft problem. Varying these between
    attempts gives different layouts; with fixed weights the search keeps
    finding the same "best" grid, even when that grid can't be filled."""

    unchecked_cell: float = 6  # a letter in only one answer
    two_letter_answer: float = 4
    interior_clue_cell: float = 3  # clue cells cost a letter each
    long_answer_letter: float = 0  # per letter beyond 5: long answers are harder to fill

    @classmethod
    def random(cls, rng: random.Random) -> "LayoutWeights":
        return cls(
            unchecked_cell=rng.uniform(4, 8),
            two_letter_answer=rng.uniform(3, 6),
            interior_clue_cell=rng.uniform(1, 4),
            long_answer_letter=rng.uniform(0, 4),
        )


def layout_key(layout: Layout) -> str:
    """A compact text form of a layout, for remembering ones that failed."""
    return "/".join("".join("#" if cell else "." for cell in row) for row in layout)


def layout_problems(
    layout: Layout,
    rules: Rules,
    max_answer_length: int,
    weights: LayoutWeights = LayoutWeights(),
) -> float:
    """A penalty score: 0 means the layout is usable, higher is worse.

    Hard problems (an answer nobody can clue, a letter in no answer) cost
    100 each, so any layout with one is never chosen. Soft ones steer the
    search toward nicer grids: fewer cells checked by only one answer, few
    two-letter answers, not too many clue cells.
    """
    rows, columns = len(layout), len(layout[0])
    slots = find_slots(layout, rules.min_answer_length)
    penalty = 0

    clues_in_cell: dict[Cell, list[str]] = {}
    coverage: dict[Cell, int] = {}
    for slot in slots:
        if slot.clue_cell is None:
            penalty += 100
            continue
        if len(slot.cells) > max_answer_length:
            penalty += 40 * (len(slot.cells) - max_answer_length)
        penalty += weights.long_answer_letter * max(0, len(slot.cells) - 5)
        clues_in_cell.setdefault(slot.clue_cell, []).append(slot.arrow or "")
        for cell in slot.cells:
            coverage[cell] = coverage.get(cell, 0) + 1

    for row in range(rows):
        for column in range(columns):
            cell = (row, column)
            if layout[row][column]:
                arrows = clues_in_cell.get(cell, [])
                if len(arrows) > rules.max_clues_per_cell:
                    penalty += 100
                # Two arrows leaving through the same edge would overlap.
                if len(arrows) == 2 and _EXITS_BOTTOM[arrows[0]] == _EXITS_BOTTOM[arrows[1]]:
                    penalty += 100
                # A clue cell with no clue looks broken, except the corner.
                if not arrows and cell != (0, 0):
                    penalty += 30
            else:
                count = coverage.get(cell, 0)
                if count == 0:
                    penalty += 100
                elif count == 1:
                    penalty += weights.unchecked_cell

    two_letter = sum(1 for slot in slots if len(slot.cells) == 2)
    penalty += weights.two_letter_answer * two_letter
    if two_letter > rules.max_two_letter_answers:
        penalty += 100
    penalty += weights.interior_clue_cell * sum(layout[r][c] for r in range(1, rows) for c in range(1, columns))
    return penalty


#: Penalty marking a layout as unusable (any single hard problem reaches it).
UNUSABLE = 100


def search_layout(
    rows: int,
    columns: int,
    rules: Rules,
    rng: random.Random,
    max_answer_length: int,
    weights: LayoutWeights = LayoutWeights(),
    avoid: frozenset[str] = frozenset(),
    iterations: int = 15000,
) -> tuple[Layout, float]:
    """Simulated annealing over the interior cells: flip one cell at a time,
    keep the change if it lowers the penalty, and sometimes keep a worse one
    early on (the "temperature") so the search doesn't get stuck. Layouts in
    `avoid` (ones that already failed to fill) count as unusable. Returns the
    best layout found and its penalty."""

    def score_of(candidate: Layout) -> float:
        score = layout_problems(candidate, rules, max_answer_length, weights)
        if avoid and layout_key(candidate) in avoid:
            score += UNUSABLE
        return score

    layout = base_layout(rows, columns)
    current = score_of(layout)
    best, best_score = [row[:] for row in layout], current
    temperature = 20.0
    for _ in range(iterations):
        row, column = rng.randrange(1, rows), rng.randrange(1, columns)
        layout[row][column] = not layout[row][column]
        score = score_of(layout)
        if score <= current or rng.random() < math.exp((current - score) / temperature):
            current = score
            if score < best_score:
                best, best_score = [r[:] for r in layout], score
        else:
            layout[row][column] = not layout[row][column]
        temperature = max(0.3, temperature * 0.9996)
    return best, best_score
