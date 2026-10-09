"""The level format rules, read from Shared/level-rules.json.

The app's Swift `LevelRules` mirrors the same file (a Swift test checks it),
so the generator and the app can never disagree about what a valid level is.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

# <repo>/ContentPipeline/pipeline/rules.py -> <repo>/Shared/level-rules.json
DEFAULT_RULES_PATH = Path(__file__).resolve().parents[2] / "Shared" / "level-rules.json"


@dataclass(frozen=True)
class Rules:
    format_version: int
    min_rows: int
    max_rows: int
    min_columns: int
    max_columns: int
    max_distinct_letters: int
    max_clues_per_cell: int
    min_answer_length: int
    max_two_letter_answers: int
    clue_max_length: int
    alphabets: dict[str, str]

    def alphabet(self, language: str) -> str:
        try:
            return self.alphabets[language]
        except KeyError:
            raise ValueError(f"Unsupported language: {language!r}") from None


def load_rules(path: Path = DEFAULT_RULES_PATH) -> Rules:
    data = json.loads(path.read_text(encoding="utf-8"))
    grid = data["grid"]
    return Rules(
        format_version=data["formatVersion"],
        min_rows=grid["minRows"],
        max_rows=grid["maxRows"],
        min_columns=grid["minColumns"],
        max_columns=grid["maxColumns"],
        max_distinct_letters=data["maxDistinctLetters"],
        max_clues_per_cell=data["maxCluesPerCell"],
        min_answer_length=data["minAnswerLength"],
        max_two_letter_answers=data["maxTwoLetterAnswers"],
        clue_max_length=data["clueMaxLength"],
        alphabets=dict(data["alphabets"]),
    )
