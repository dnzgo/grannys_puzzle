"""Board shapes: which cells of the rectangle belong to the board.

Most levels use the whole rectangle. A shaped level leaves the cells outside
its shape out of the board (they're written as gaps, "."), so the board
reads as a circle, a diamond or an H. Shapes are for variety: an occasional
level that looks different, not the everyday board.

Each shape is a function of the board size returning the set of cells that
are *outside* it. Kept as plain geometry so a new shape is one function.
"""

from __future__ import annotations

from collections.abc import Callable

Cell = tuple[int, int]


def _circle(rows: int, columns: int) -> set[Cell]:
    """An ellipse touching all four sides: the corners are cut away."""
    centre_r, centre_c = (rows - 1) / 2, (columns - 1) / 2
    # A little over half the size, so the edge cells' centres fall inside
    # and the outline doesn't look nibbled.
    radius_r, radius_c = rows / 2 + 0.3, columns / 2 + 0.3
    return {
        (r, c)
        for r in range(rows)
        for c in range(columns)
        if ((r - centre_r) / radius_r) ** 2 + ((c - centre_c) / radius_c) ** 2 > 1
    }


def _diamond(rows: int, columns: int) -> set[Cell]:
    """Points at the middle of each side; the corner triangles are cut away.
    Softened (the 1.25) so the points stay wide enough to hold words."""
    centre_r, centre_c = (rows - 1) / 2, (columns - 1) / 2
    return {
        (r, c)
        for r in range(rows)
        for c in range(columns)
        if abs(r - centre_r) / (rows / 2) + abs(c - centre_c) / (columns / 2) > 1.25
    }


def _h(rows: int, columns: int) -> set[Cell]:
    """Two uprights joined by a crossbar: the middle of the top and the
    bottom are cut away. Uprights and crossbar are about a third each."""
    upright = max(2, round(columns * 0.35))
    bar_top = round(rows * 0.35)
    bar_bottom = rows - bar_top
    return {
        (r, c)
        for r in range(rows)
        for c in range(upright, columns - upright)
        if r < bar_top or r >= bar_bottom
    }


SHAPES: dict[str, Callable[[int, int], set[Cell]]] = {
    "circle": _circle,
    "diamond": _diamond,
    "h": _h,
}

#: The board size (rows, columns) each shape is made on by default: the
#: sizes that filled reliably and still read as the shape when tried. A
#: shape's edges make many short words, so smaller boards often can't be
#: filled, and bigger ones (10x12) rarely fill at all with today's words.
DEFAULT_SIZES: dict[str, tuple[int, int]] = {
    "circle": (11, 9),
    "diamond": (10, 8),
    "h": (10, 10),
}


def outside_cells(shape: str | None, rows: int, columns: int) -> frozenset[Cell]:
    """The cells left out of the board for this shape (none for a plain
    rectangle, `shape` None)."""
    if shape is None:
        return frozenset()
    try:
        return frozenset(SHAPES[shape](rows, columns))
    except KeyError:
        raise ValueError(f"Unknown shape {shape!r}; known: {', '.join(SHAPES)}") from None
