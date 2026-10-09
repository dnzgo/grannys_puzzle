"""Placeholder clues, the clue checks, and the batch round trip."""

import csv
import tempfile
import unittest
from pathlib import Path

from pipeline.clues import ClueBank, append_to_bank, check_clue, import_batch, placeholder_clue, write_batches
from pipeline.wordlist import WordEntry


class PlaceholderTests(unittest.TestCase):
    def test_short_definitions_are_kept_and_capitalised(self):
        self.assertEqual(placeholder_clue("frozen dessert", 20), "Frozen dessert")

    def test_long_definitions_are_cut_at_a_word_boundary(self):
        clue = placeholder_clue("a plot of ground where plants are cultivated", 20)
        self.assertLessEqual(len(clue), 20)
        self.assertTrue(clue.endswith("…"))
        self.assertEqual(clue, "A plot of ground…")


class CheckClueTests(unittest.TestCase):
    def test_a_good_clue_passes(self):
        self.assertIsNone(check_clue("CAT", "Purring pet", 20))

    def test_rejects_empty_and_too_long(self):
        self.assertEqual(check_clue("CAT", "  ", 20), "empty")
        self.assertIn("too long", check_clue("CAT", "A small furry animal that purrs", 20))

    def test_rejects_clues_that_give_the_answer_away(self):
        self.assertEqual(check_clue("CAT", "Cat food brand", 20), "contains the answer")
        self.assertEqual(check_clue("GARDEN", "Gardener's place", 20), "contains the answer")
        self.assertEqual(check_clue("GARDEN", "Garde-manger", 20), "contains the start of the answer")

    def test_does_not_flag_unrelated_words_containing_the_letters(self):
        # "concatenate" contains "cat" but not as a word start.
        self.assertIsNone(check_clue("CAT", "Concatenate, e.g.", 20))


class BatchRoundTripTests(unittest.TestCase):
    def test_write_fill_import(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            entries = [WordEntry("CAT", 10, "noun", "feline mammal"), WordEntry("DOG", 10, "noun", "canine")]
            [batch] = write_batches(entries, folder, batch_size=10, prefix="test")

            # Simulate a clue writer filling in the batch.
            with batch.open(encoding="utf-8") as file:
                rows = list(csv.DictReader(file))
            rows[0].update(clue_1="Purring pet", clue_2="Cat nap taker", clue_3="Purring pet")
            rows[1].update(clue_1="Loyal companion")
            with batch.open("w", encoding="utf-8", newline="") as file:
                writer = csv.DictWriter(file, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)

            accepted, problems = import_batch(batch, max_length=20)
            self.assertEqual(accepted, [("CAT", "Purring pet"), ("DOG", "Loyal companion")])
            self.assertEqual([p.reason for p in problems], ["contains the answer", "same clue twice for this word"])

            bank_path = folder / "clues.tsv"
            self.assertEqual(append_to_bank(accepted, bank_path), 2)
            self.assertEqual(append_to_bank(accepted, bank_path), 0, "duplicates are skipped")
            bank = ClueBank.load(bank_path)
            self.assertEqual(bank.next_clue("CAT"), "Purring pet")


class ClueRotationTests(unittest.TestCase):
    def test_hands_out_the_least_used_clue(self):
        bank = ClueBank({"CAT": ["Purring pet", "Mouser"]})
        self.assertEqual([bank.next_clue("CAT") for _ in range(4)],
                         ["Purring pet", "Mouser", "Purring pet", "Mouser"])


if __name__ == "__main__":
    unittest.main()
