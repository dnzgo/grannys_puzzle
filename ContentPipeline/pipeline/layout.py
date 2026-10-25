"""Grid layouts: where the clue cells go, and which answer slots that makes.

A layout is a grid of booleans (True = clue cell). It's searched for before
any words are placed, because whether a layout is fillable and pleasant
depends only on its shape: short runs, crossings, and clue placement.

A blocking cell that ends up with no clue to hold becomes a gap: left out
of the board ("." in the level file), like a black square in a crossword.
Gaps let the search place a blocker where a word can't continue without
needing a clue there: at a board's edge, say, instead of forcing a
two-letter word. Fewer short words means fewer repeats, since there are
only a few dozen of them. Gaps are capped (Rules.max_gaps).

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


def base_layout(rows: int, columns: int, outside: frozenset[Cell] = frozenset()) -> Layout:
    """The starting point of the search. A rectangle gets clue cells in
    every other cell of the top row and left column. A shaped board gets
    them in every other cell along its top and left edges (any cell whose
    neighbour above or to the left is outside the board), and its outside
    cells are blocking for good."""
    layout = [[False] * columns for _ in range(rows)]
    if not outside:
        for column in range(columns):
            layout[0][column] = column % 2 == 0
        for row in range(rows):
            layout[row][0] = row % 2 == 0
        return layout
    for r in range(rows):
        for c in range(columns):
            if (r, c) in outside:
                layout[r][c] = True
            elif _is_edge(r, c, outside) and (r + c) % 2 == 0:
                layout[r][c] = True
    return layout


def _is_edge(r: int, c: int, outside: frozenset[Cell]) -> bool:
    """A cell with the board's edge (or outside) directly above or to its left."""
    return r == 0 or c == 0 or (r - 1, c) in outside or (r, c - 1) in outside


def find_slots(layout: Layout, min_length: int = 2, outside: frozenset[Cell] = frozenset()) -> list[Slot]:
    """Every maximal run of letter cells of `min_length` or more, with the clue
    cell that can point at it.

    The clue sits just before the run (a straight arrow) when that cell is a
    blocking cell on the board. When it isn't (the board's edge, or a cell
    outside a shaped board), the clue can sit beside the run's first cell
    instead, with a bent arrow: above it for an across answer (`downRight`),
    to its left for a down answer (`rightDown`). Outside cells never hold
    clues."""
    rows, columns = len(layout), len(layout[0])
    slots: list[Slot] = []

    def can_hold_clue(r: int, c: int) -> bool:
        return 0 <= r < rows and 0 <= c < columns and layout[r][c] and (r, c) not in outside

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
            if can_hold_clue(row, start - 1):
                slots.append(Slot(cells, (row, start - 1), "right"))
            elif can_hold_clue(row - 1, start):
                slots.append(Slot(cells, (row - 1, start), "downRight"))
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
            if can_hold_clue(start - 1, column):
                slots.append(Slot(cells, (start - 1, column), "down"))
            elif can_hold_clue(start, column - 1):
                slots.append(Slot(cells, (start, column - 1), "rightDown"))
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
    # A gap holds neither a letter nor a clue. Free, or nearly: measured on
    # 24 levels, free gaps (about 2 a board) halved the two-letter answers
    # (7.9% to 4.0% of answers) and cut repeated words, for 2% fewer
    # letters; costly ones (8) were never used. They're still only placed
    # where they lower another penalty, and Rules.max_gaps caps them.
    gap_cell: float = 0

    @classmethod
    def random(cls, rng: random.Random) -> "LayoutWeights":
        return cls(
            unchecked_cell=rng.uniform(4, 8),
            two_letter_answer=rng.uniform(3, 6),
            interior_clue_cell=rng.uniform(1, 4),
            long_answer_letter=rng.uniform(0, 4),
            gap_cell=rng.uniform(0, 1),
        )


def letters_connected(layout: Layout) -> bool:  # outside cells are blocking, so they count as walls
    """True if every letter cell can reach every other one through
    side-by-side letter cells (a flood fill from the first letter cell)."""
    rows, columns = len(layout), len(layout[0])
    letters = {(r, c) for r in range(rows) for c in range(columns) if not layout[r][c]}
    if not letters:
        return False
    start = next(iter(letters))
    reached, to_visit = {start}, [start]
    while to_visit:
        row, column = to_visit.pop()
        for neighbour in ((row + 1, column), (row - 1, column), (row, column + 1), (row, column - 1)):
            if neighbour in letters and neighbour not in reached:
                reached.add(neighbour)
                to_visit.append(neighbour)
    return len(reached) == len(letters)


def gap_cells(layout: Layout, slots: list[Slot]) -> set[Cell]:
    """The blocking cells no answer is clued from: these become gaps
    (including a shaped board's outside cells)."""
    clued = {slot.clue_cell for slot in slots if slot.clue_cell is not None}
    return {
        (r, c)
        for r, row in enumerate(layout)
        for c, blocking in enumerate(row)
        if blocking and (r, c) not in clued
    }


def layout_key(layout: Layout) -> str:
    """A compact text form of a layout, for remembering ones that failed."""
    return "/".join("".join("#" if cell else "." for cell in row) for row in layout)


def layout_problems(
    layout: Layout,
    rules: Rules,
    max_answer_length: int,
    weights: LayoutWeights = LayoutWeights(),
    outside: frozenset[Cell] = frozenset(),
) -> float:
    """A penalty score: 0 means the layout is usable, higher is worse.

    Hard problems (an answer nobody can clue, a letter in no answer) cost
    100 each, so any layout with one is never chosen. Soft ones steer the
    search toward nicer grids: fewer cells checked by only one answer, few
    two-letter answers, not too many clue cells.
    """
    rows, columns = len(layout), len(layout[0])
    slots = find_slots(layout, rules.min_answer_length, outside)
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
            if cell in outside:
                continue
            if layout[row][column]:
                arrows = clues_in_cell.get(cell, [])
                if len(arrows) > rules.max_clues_per_cell:
                    penalty += 100
                # Two arrows leaving through the same edge would overlap.
                if len(arrows) == 2 and _EXITS_BOTTOM[arrows[0]] == _EXITS_BOTTOM[arrows[1]]:
                    penalty += 100
            else:
                count = coverage.get(cell, 0)
                if count == 0:
                    penalty += 100
                elif count == 1:
                    penalty += weights.unchecked_cell

    # Blocking cells with no clue become gaps: fine where needed, but each
    # costs a little and there's a cap, so boards don't look moth-eaten.
    # A shaped board's outside cells don't count: the cap is for gaps on
    # the board itself, as a share of the shape's own cells.
    gaps = gap_cells(layout, slots) - outside
    if len(gaps) > rules.max_gaps(rows, columns, outside=len(outside)):
        penalty += 100
    penalty += weights.gap_cell * len(gaps)
    # On a shaped board, a gap at the shape's edge eats into its outline
    # (a circle turns into a blob), so there gaps are strongly discouraged.
    if outside:
        penalty += SHAPE_GAP_PENALTY * sum(1 for (r, c) in gaps if _touches_outside(r, c, outside, rows, columns))

    # A wall of clue cells can cut the board into separate mini-puzzles that
    # never cross, which feels broken to play.
    if not letters_connected(layout):
        penalty += 100

    two_letter = sum(1 for slot in slots if len(slot.cells) == 2)
    penalty += weights.two_letter_answer * two_letter
    if two_letter > rules.max_two_letter_answers:
        penalty += 100
    penalty += weights.interior_clue_cell * sum(
        layout[r][c] for r in range(1, rows) for c in range(1, columns) if (r, c) not in outside
    )
    return penalty


#: Cost of a gap on a shaped board's outline (see layout_problems).
SHAPE_GAP_PENALTY = 25


def _touches_outside(r: int, c: int, outside: frozenset[Cell], rows: int, columns: int) -> bool:
    """A cell on the shape's outline: next to an outside cell or the board's edge."""
    for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
        if not (0 <= nr < rows and 0 <= nc < columns) or (nr, nc) in outside:
            return True
    return False


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
    outside: frozenset[Cell] = frozenset(),
) -> tuple[Layout, float]:
    """Simulated annealing over the interior cells: flip one cell at a time,
    keep the change if it lowers the penalty, and sometimes keep a worse one
    early on (the "temperature") so the search doesn't get stuck. Layouts in
    `avoid` (ones that already failed to fill) count as unusable. Returns the
    best layout found and its penalty."""

    def score_of(candidate: Layout) -> float:
        score = layout_problems(candidate, rules, max_answer_length, weights, outside)
        if avoid and layout_key(candidate) in avoid:
            score += UNUSABLE
        return score

    layout = base_layout(rows, columns, outside)
    current = score_of(layout)
    # Which cells the search may flip: a rectangle keeps its top row and
    # left column (the clue edge); a shape's edges are irregular, so any
    # cell on the board may change, and its outside cells never do.
    if outside:
        flippable = [(r, c) for r in range(rows) for c in range(columns) if (r, c) not in outside]
    else:
        flippable = [(r, c) for r in range(1, rows) for c in range(1, columns)]
    best, best_score = [row[:] for row in layout], current
    temperature = 20.0
    for _ in range(iterations):
        row, column = flippable[rng.randrange(len(flippable))]
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
