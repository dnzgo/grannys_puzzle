"""Turkish casing and the hand-written word list importer."""

import tempfile
import unittest
from pathlib import Path

from pipeline.authored import read_sources
from pipeline.clues import check_clue
from pipeline.textcase import lower, upper

TR = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"


class TurkishCaseTests(unittest.TestCase):
    def test_dotted_and_dotless_i_keep_their_dots(self):
        # Python's own upper() would make "iç" into "IÇ", a different word.
        self.assertEqual(upper("iç", "tr"), "İÇ")
        self.assertEqual(upper("ılık", "tr"), "ILIK")
        self.assertEqual(lower("İĞNE", "tr"), "iğne")
        self.assertEqual(lower("KIRMIZI", "tr"), "kırmızı")

    def test_english_is_unchanged(self):
        self.assertEqual(upper("kit", "en"), "KIT")

    def test_giveaway_check_works_with_turkish_capitals(self):
        # "İçeri" starts with the answer İÇ; a naive lower() would miss it.
        self.assertEqual(check_clue("İÇ", "İçeri", 20, "tr"), "contains the answer")
        self.assertIsNone(check_clue("İÇ", "Dış karşıtı", 20, "tr"))


class AuthoredImportTests(unittest.TestCase):
    def read(self, text: str):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "words.tsv"
            path.write_text("word\tfamiliarity\tpart_of_speech\tclue_1\tclue_2\tclue_3\n" + text, encoding="utf-8")
            return read_sources([path], "tr", TR, min_length=2, max_length=8, clue_max_length=20)

    def test_a_good_line_becomes_a_word_and_its_clues(self):
        words, clues, problems, _ = self.read("çay\t10\tnoun\tDemlenip içilir\tKüçük ırmak\t\n")
        self.assertEqual(problems, [])
        self.assertEqual([(w.word, w.familiarity, w.definition) for w in words], [("ÇAY", 10, "Demlenip içilir")])
        self.assertEqual(clues, [("ÇAY", "Demlenip içilir"), ("ÇAY", "Küçük ırmak")])

    def test_problems_leave_the_word_out_and_say_why(self):
        words, _, problems, _ = self.read(
            "çay\t10\tnoun\tÇay bardağı\t\t\n"      # gives the answer away
            "ev\t15\tnoun\tYuva\t\t\n"              # not a familiarity level
            "battaniye\t10\tnoun\tÖrtü\t\t\n"       # too long for a grid
        )
        self.assertEqual(words, [])
        self.assertEqual(len(problems), 3)

    def test_a_word_without_a_clue_is_waiting_not_wrong(self):
        # Words are listed first and clued over time: an unclued word is
        # counted as waiting, and its difficulty can still be empty.
        words, _, problems, waiting = self.read("su\t\t\t\t\t\nev\t10\tnoun\tYuva\t\t\n")
        self.assertEqual(problems, [])
        self.assertEqual([w.word for w in words], ["EV"])
        self.assertEqual(waiting, ["SU"])

    def test_a_clued_word_needs_a_difficulty(self):
        _, _, problems, _ = self.read("ev\t\tnoun\tYuva\t\t\n")
        self.assertEqual([p.reason for p in problems], ["no difficulty"])

    def test_a_blocked_word_is_refused_even_when_typed_in_by_hand(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "words.tsv"
            path.write_text("word\tfamiliarity\tpart_of_speech\tclue_1\tclue_2\tclue_3\nev\t10\t\tYuva\t\t\n", encoding="utf-8")
            result = read_sources([path], "tr", TR, min_length=2, max_length=8, clue_max_length=20, blocked={"ev"})
        self.assertEqual(result.words, [])
        self.assertIn("blocked", result.problems[0].reason)

    def test_a_word_listed_twice_is_reported(self):
        words, _, problems, _ = self.read("ev\t10\tnoun\tYuva\t\t\nev\t10\tnoun\tKonut\t\t\n")
        self.assertEqual(len(words), 1)
        self.assertEqual([p.reason for p in problems], ["listed twice"])


if __name__ == "__main__":
    unittest.main()
