"""Tidying clues on import: sentence case, names, blanks."""

import unittest

from pipeline.tidy import tidy_clue

NAMES = {"berlin": "Berlin", "british": "British", "monday": "Monday"}


class TidyClueTests(unittest.TestCase):
    def test_a_lowercase_clue_gets_its_capital(self):
        self.assertEqual(tidy_clue("direction or goal"), "Direction or goal")

    def test_names_are_capitalised_and_ordinary_words_are_not(self):
        # "may" isn't in the names list (it's an ordinary word too).
        self.assertEqual(tidy_clue("the city of berlin", NAMES), "The city of Berlin")
        self.assertEqual(tidy_clue("may on monday", NAMES), "May on Monday")
        self.assertEqual(tidy_clue("british tea", NAMES), "British tea")

    def test_a_lone_i_is_capital_in_english_only(self):
        self.assertEqual(tidy_clue("as i said"), "As I said")
        self.assertEqual(tidy_clue("içilir", language="tr"), "İçilir")

    def test_blanks_become_three_underscores(self):
        self.assertEqual(tidy_clue("queen __ hearts"), "Queen ___ hearts")

    def test_a_clue_starting_with_a_blank_keeps_its_next_word_small(self):
        self.assertEqual(tidy_clue("__ the left"), "___ the left")

    def test_a_clue_starting_with_another_alphabet_is_left_alone(self):
        self.assertEqual(tidy_clue("π = 3.14"), "π = 3.14")

    def test_what_was_already_right_is_left_alone(self):
        self.assertEqual(tidy_clue("Not out"), "Not out")
        # A first word with a capital inside is written that way on purpose.
        self.assertEqual(tidy_clue("pH level, briefly"), "pH level, briefly")


if __name__ == "__main__":
    unittest.main()
