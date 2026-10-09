"""Checks a level against the level format spec.

This is deliberately written separately from the generator: it re-reads the
finished JSON and rebuilds every answer from the clue arrows, the same way
the app does. A bug in the generator then can't hide itself by being wrong
in the same way in its own check.

The checks mirror Swift's `Level(file:)` (same rules, same order), plus a few
quality checks the app doesn't need: clue length, no repeated answers, and
the two-letter answer limit.
"""

from __future__ import annotations

from .rules import Rules

_START = {"right": (0, 1), "rightDown": (0, 1), "down": (1, 0), "downRight": (1, 0)}
_DIRECTION = {"right": "across", "downRight": "across", "down": "down", "rightDown": "down"}


def validate_level(level: dict, rules: Rules) -> list[str]:
    """All problems found, as readable messages. An empty list means valid."""
    problems: list[str] = []
    level_id = level.get("id", "?")

    def problem(message: str) -> None:
        problems.append(f"{level_id}: {message}")

    if level.get("formatVersion") != rules.format_version:
        problem(f"unsupported format version {level.get('formatVersion')}")
        return problems
    for key in ("clueLanguage", "answerLanguage"):
        if level.get(key) not in rules.alphabets:
            problem(f"unsupported language {level.get(key)!r}")
            return problems
    alphabet = set(rules.alphabet(level["answerLanguage"]))

    grid = [list(row) for row in level.get("grid", [])]
    rows = len(grid)
    columns = len(grid[0]) if grid else 0
    if not (rules.min_rows <= rows <= rules.max_rows and rules.min_columns <= columns <= rules.max_columns):
        problem(f"grid size {rows}×{columns} out of range")
        return problems
    for r, row in enumerate(grid):
        if len(row) != columns:
            problem(f"row {r} has {len(row)} cells, expected {columns}")
            return problems
        for c, character in enumerate(row):
            if character != "#" and character not in alphabet:
                problem(f"letter {character!r} at ({r}, {c}) is not in the alphabet")
                return problems

    def is_clue(r: int, c: int) -> bool:
        return grid[r][c] == "#"

    letter_cells = [(r, c) for r in range(rows) for c in range(columns) if not is_clue(r, c)]
    if not letter_cells:
        problem("no letter cells")
        return problems

    answers: list[tuple[str, list[tuple[int, int]], dict]] = []
    clues_per_cell: dict[tuple[int, int], int] = {}
    for clue in level.get("clues", []):
        r, c, arrow = clue.get("row"), clue.get("column"), clue.get("arrow")
        if arrow not in _START:
            problem(f"unknown arrow {arrow!r} at ({r}, {c})")
            continue
        if not (0 <= r < rows and 0 <= c < columns):
            problem(f"clue outside the grid at ({r}, {c})")
            continue
        if not is_clue(r, c):
            problem(f"clue on a letter cell at ({r}, {c})")
            continue
        clues_per_cell[(r, c)] = clues_per_cell.get((r, c), 0) + 1
        if clues_per_cell[(r, c)] > rules.max_clues_per_cell:
            problem(f"too many clues at ({r}, {c})")
        dr, dc = _START[arrow]
        step = (0, 1) if _DIRECTION[arrow] == "across" else (1, 0)
        cells = []
        cr, cc = r + dr, c + dc
        while cr < rows and cc < columns and not is_clue(cr, cc):
            cells.append((cr, cc))
            cr, cc = cr + step[0], cc + step[1]
        if len(cells) < max(1, rules.min_answer_length):
            problem(f"answer too short for clue at ({r}, {c})")
            continue
        answers.append((_DIRECTION[arrow], cells, clue))

        text = str(clue.get("text", "")).strip()
        if not text:
            problem(f"empty clue text at ({r}, {c})")
        elif len(text) > rules.clue_max_length:
            problem(f"clue too long at ({r}, {c}): {text!r}")

    covered: dict[tuple[tuple[int, int], str], int] = {}
    for direction, cells, _ in answers:
        for cell in cells:
            if (cell, direction) in covered:
                problem(f"two {direction} answers overlap at {cell}")
            covered[(cell, direction)] = 1
    for cell in letter_cells:
        if (cell, "across") not in covered and (cell, "down") not in covered:
            problem(f"letter cell {cell} belongs to no answer")

    distinct = {grid[r][c] for r, c in letter_cells}
    if len(distinct) > rules.max_distinct_letters:
        problem(f"{len(distinct)} distinct letters, tray holds {rules.max_distinct_letters}")

    for given in level.get("givens", []):
        r, c = given.get("row"), given.get("column")
        if not (0 <= r < rows and 0 <= c < columns) or is_clue(r, c):
            problem(f"starter letter on a non-letter cell at ({r}, {c})")

    # Quality checks the app doesn't need, but players notice.
    words = ["".join(grid[r][c] for r, c in cells) for _, cells, _ in answers]
    repeated = sorted({word for word in words if words.count(word) > 1})
    if repeated:
        problem(f"answer used twice: {', '.join(repeated)}")
    two_letter = sum(1 for word in words if len(word) == 2)
    if two_letter > rules.max_two_letter_answers:
        problem(f"{two_letter} two-letter answers, limit is {rules.max_two_letter_answers}")
    return problems
