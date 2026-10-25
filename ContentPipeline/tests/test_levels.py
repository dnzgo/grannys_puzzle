"""Layouts, the validator, and generating real levels end to end with a
sample word list of about 2,000 common words."""

import copy
import os
import subprocess
import sys
import json
import unittest
from pathlib import Path

from pipeline.clues import ClueBank
from pipeline.generator import LevelGenerator, LevelSpec
from pipeline.layout import find_slots, letters_connected
from pipeline.rules import load_rules
from pipeline.validator import validate_level
from pipeline.wordlist import WordEntry

FIXTURES = Path(__file__).parent / "fixtures"
RULES = load_rules()


def level_100() -> dict:
    return json.loads((FIXTURES / "level-100.json").read_text(encoding="utf-8"))


def sample_words() -> list[WordEntry]:
    words = (FIXTURES / "sample_words.txt").read_text(encoding="utf-8").split()
    return [WordEntry(w.upper(), 10, "noun", f"definition of {w}") for w in words]


class LayoutTests(unittest.TestCase):
    def test_finds_every_answer_of_level_100_with_its_clue(self):
        grid = level_100()["grid"]
        layout = [[ch == "#" for ch in row] for row in grid]
        slots = find_slots(layout)

        self.assertEqual(len(slots), 25)
        by_cell = {(slot.clue_cell, slot.arrow) for slot in slots}
        clues = {((c["row"], c["column"]), c["arrow"]) for c in level_100()["clues"]}
        self.assertEqual(by_cell, clues)

    def test_a_full_row_of_clue_cells_splits_the_letters(self):
        open_grid = [[r == 0 or c == 0 for c in range(5)] for r in range(5)]
        self.assertTrue(letters_connected(open_grid))
        walled = [row[:] for row in open_grid]
        walled[2] = [True] * 5  # rows 1 and 3-4 can no longer reach each other
        self.assertFalse(letters_connected(walled))


class ValidatorTests(unittest.TestCase):
    def test_level_100_breaks_only_two_quality_rules(self):
        # Level 100 was made by hand before these rules existed: it has five
        # two-letter answers (GO, AN, ON, AT, TO), and its bottom-right block
        # (ON, AT, TO) is walled off from the rest. Structurally it's valid,
        # which is why the app still loads it.
        problems = validate_level(level_100(), RULES)
        self.assertEqual(len(problems), 2)
        self.assertTrue(any("separate groups" in p for p in problems))
        self.assertTrue(any("two-letter" in p for p in problems))

    def test_rejects_a_letter_outside_the_alphabet(self):
        level = level_100()
        level["grid"][1] = "sAGA#GO"
        self.assertTrue(any("alphabet" in p for p in validate_level(level, RULES)))

    def test_rejects_a_clue_on_a_letter_cell(self):
        level = level_100()
        level["clues"].append({"row": 1, "column": 1, "arrow": "right", "text": "Oops"})
        self.assertTrue(any("letter cell" in p for p in validate_level(level, RULES)))

    def test_rejects_a_clue_that_is_too_long(self):
        level = level_100()
        level["clues"][0]["text"] = "A clue far longer than any cell can hold"
        self.assertTrue(any("too long" in p for p in validate_level(level, RULES)))

    def test_rejects_an_uncovered_letter_cell(self):
        level = level_100()
        level["clues"] = [c for c in level["clues"] if not (c["row"] == 0 and c["column"] == 0)]
        self.assertTrue(any("no answer" in p for p in validate_level(level, RULES)))

    def test_rejects_letters_split_into_separate_groups(self):
        level = level_100()
        level["grid"][3] = "#" * len(level["grid"][3])
        self.assertTrue(any("separate groups" in p for p in validate_level(level, RULES)))


class GeneratorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.words = sample_words()

    def make_generator(self) -> LevelGenerator:
        return LevelGenerator("en", self.words, ClueBank({}), RULES)

    def test_generated_levels_are_valid(self):
        generator = self.make_generator()
        for number, (rows, columns) in enumerate([(5, 5), (6, 5), (7, 6), (8, 6), (9, 7)], start=1):
            with self.subTest(size=f"{columns}x{rows}"):
                level = generator.generate(f"en-{number:06d}", LevelSpec(rows, columns, 50), seed=number)
                self.assertIsNotNone(level, "no fill found")
                self.assertEqual(validate_level(level, RULES), [])
                self.assertEqual(len(level["grid"]), rows)

    def test_the_same_seed_makes_the_same_level(self):
        spec = LevelSpec(7, 6, 50)
        first = self.make_generator().generate("en-000001", spec, seed=42)
        second = self.make_generator().generate("en-000001", spec, seed=42)
        self.assertEqual(first, second)

    def test_the_same_seed_makes_the_same_level_in_separate_runs(self):
        # Python randomises string hashing per process, so set order differs
        # between runs. The test above can't see that (one process, one hash
        # seed); this one runs the generator in two processes with different
        # hash seeds and compares the output.
        script = (
            "import json, sys; sys.path.insert(0, '.');"
            "from tests.test_levels import sample_words, RULES;"
            "from pipeline.clues import ClueBank;"
            "from pipeline.generator import LevelGenerator, LevelSpec;"
            "g = LevelGenerator('en', sample_words(), ClueBank({}), RULES);"
            "print(json.dumps(g.generate('en-000001', LevelSpec(6, 5, 50), seed=5)))"
        )
        root = Path(__file__).parent.parent
        outputs = [
            subprocess.run(
                [sys.executable, "-c", script], cwd=root, capture_output=True, text=True, check=True,
                env={**os.environ, "PYTHONHASHSEED": hash_seed},
            ).stdout
            for hash_seed in ("1", "2")
        ]
        self.assertEqual(outputs[0], outputs[1])

    def test_real_clues_are_used_when_the_bank_has_them(self):
        # Give every word a real clue; no placeholder should be needed.
        bank = ClueBank({entry.word: ["Real clue"] for entry in self.words})
        generator = LevelGenerator("en", self.words, bank, RULES)
        level = generator.generate("en-000001", LevelSpec(6, 5, 50), seed=3)
        self.assertIsNotNone(level)
        self.assertEqual({clue["text"] for clue in level["clues"]}, {"Real clue"})
        self.assertEqual(generator.stats.placeholder_clues, 0)

    def test_every_clue_cell_holds_a_clue_and_the_rest_are_gaps(self):
        # A blocking cell nobody is clued from is written as a gap, never
        # as an empty clue cell, and there are no more gaps than allowed.
        generator = self.make_generator()
        for number, (rows, columns) in enumerate([(7, 6), (9, 7), (10, 8)], start=1):
            with self.subTest(size=f"{columns}x{rows}"):
                level = generator.generate(f"en-{number:06d}", LevelSpec(rows, columns, 50), seed=number)
                self.assertIsNotNone(level, "no fill found")
                grid = level["grid"]
                clued = {(clue["row"], clue["column"]) for clue in level["clues"]}
                hashes = {(r, c) for r, row in enumerate(grid) for c, ch in enumerate(row) if ch == "#"}
                self.assertEqual(hashes, clued)
                gaps = sum(row.count(".") for row in grid)
                self.assertLessEqual(gaps, RULES.max_gaps(rows, columns))

    def test_validator_accepts_gaps_and_rejects_misuse(self):
        level = self.make_generator().generate("en-000001", LevelSpec(9, 7, 50), seed=3)
        self.assertEqual(validate_level(level, RULES), [])

        # Turn a clue's cell into a gap: the clue now sits on a gap.
        clue_on_gap = copy.deepcopy(level)
        first = clue_on_gap["clues"][0]
        row = list(clue_on_gap["grid"][first["row"]])
        row[first["column"]] = "."
        clue_on_gap["grid"][first["row"]] = "".join(row)
        self.assertTrue(any("gap" in p for p in validate_level(clue_on_gap, RULES)))

        too_many = copy.deepcopy(level)
        too_many["grid"] = ["." * len(row) for row in level["grid"]]
        self.assertTrue(any("gaps, limit" in p for p in validate_level(too_many, RULES)))

    def test_shaped_levels_keep_their_outline(self):
        # Every cell outside the shape is a gap; the level says its shape;
        # it's valid. (Made with the sample words, on each shape's size.)
        from pipeline.shapes import DEFAULT_SIZES, outside_cells
        generator = self.make_generator()
        for number, shape in enumerate(DEFAULT_SIZES, start=1):
            with self.subTest(shape=shape):
                rows, columns = DEFAULT_SIZES[shape]
                level = generator.generate(
                    f"en-{number:06d}", LevelSpec(rows, columns, 50, shape=shape, max_answer_length=8), seed=number
                )
                self.assertIsNotNone(level, "no fill found")
                self.assertEqual(level["shape"], shape)
                self.assertEqual(validate_level(level, RULES), [])
                for r, c in outside_cells(shape, rows, columns):
                    self.assertEqual(level["grid"][r][c], ".")

    def test_a_plain_level_has_no_shape(self):
        level = self.make_generator().generate("en-000001", LevelSpec(7, 6, 50), seed=1)
        self.assertNotIn("shape", level)

    def test_starter_letters_are_letter_cells(self):
        level = self.make_generator().generate("en-000001", LevelSpec(9, 7, 50), seed=7)
        grid = level["grid"]
        self.assertGreater(len(level["givens"]), 0)
        for given in level["givens"]:
            self.assertNotIn(grid[given["row"]][given["column"]], "#.")


if __name__ == "__main__":
    unittest.main()
