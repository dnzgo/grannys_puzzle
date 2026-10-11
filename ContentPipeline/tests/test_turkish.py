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
        words, clues, problems = self.read("çay\t10\tnoun\tDemlenip içilir\tKüçük ırmak\t\n")
        self.assertEqual(problems, [])
        self.assertEqual([(w.word, w.familiarity, w.definition) for w in words], [("ÇAY", 10, "Demlenip içilir")])
        self.assertEqual(clues, [("ÇAY", "Demlenip içilir"), ("ÇAY", "Küçük ırmak")])

    def test_problems_leave_the_word_out_and_say_why(self):
        words, _, problems = self.read(
            "çay\t10\tnoun\tÇay bardağı\t\t\n"      # gives the answer away
            "ev\t15\tnoun\tYuva\t\t\n"              # not a familiarity level
            "battaniye\t10\tnoun\tÖrtü\t\t\n"       # too long for a grid
            "su\t10\tnoun\t\t\t\n"                  # no clue at all
        )
        self.assertEqual(words, [])
        self.assertEqual(len(problems), 4)

    def test_a_word_listed_twice_is_reported(self):
        words, _, problems = self.read("ev\t10\tnoun\tYuva\t\t\nev\t10\tnoun\tKonut\t\t\n")
        self.assertEqual(len(words), 1)
        self.assertEqual([p.reason for p in problems], ["listed twice"])


if __name__ == "__main__":
    unittest.main()
