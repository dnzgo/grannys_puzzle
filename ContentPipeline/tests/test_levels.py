"""Layouts, the validator, and generating real levels end to end with a
sample word list of about 2,000 common words."""

import copy
import json
import unittest
from pathlib import Path

from pipeline.clues import ClueBank
from pipeline.generator import LevelGenerator, LevelSpec
from pipeline.layout import find_slots
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


class ValidatorTests(unittest.TestCase):
    def test_level_100_breaks_only_the_two_letter_rule(self):
        # Level 100 was made by hand before the limit existed: it has five
        # two-letter answers (GO, AN, ON, AT, TO). Everything else is valid.
        problems = validate_level(level_100(), RULES)
        self.assertEqual(len(problems), 1)
        self.assertIn("two-letter", problems[0])

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


class GeneratorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.words = sample_words()

    def make_generator(self) -> LevelGenerator:
        return LevelGenerator("en", self.words, ClueBank({}), RULES)

    def test_generated_levels_are_valid(self):
        generator = self.make_generator()
        for number, (rows, columns) in enumerate([(5, 5), (6, 5), (7, 6), (9, 7)], start=1):
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

    def test_real_clues_are_used_when_the_bank_has_them(self):
        # Give every word a real clue; no placeholder should be needed.
        bank = ClueBank({entry.word: ["Real clue"] for entry in self.words})
        generator = LevelGenerator("en", self.words, bank, RULES)
        level = generator.generate("en-000001", LevelSpec(6, 5, 50), seed=3)
        self.assertIsNotNone(level)
        self.assertEqual({clue["text"] for clue in level["clues"]}, {"Real clue"})
        self.assertEqual(generator.stats.placeholder_clues, 0)

    def test_starter_letters_are_letter_cells(self):
        level = self.make_generator().generate("en-000001", LevelSpec(9, 7, 50), seed=7)
        grid = level["grid"]
        self.assertGreater(len(level["givens"]), 0)
        for given in level["givens"]:
            self.assertNotEqual(grid[given["row"]][given["column"]], "#")


if __name__ == "__main__":
    unittest.main()
