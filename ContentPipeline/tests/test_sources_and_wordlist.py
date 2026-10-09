"""Reading the sources and building the word list, using small fixture copies
of each source format (tests/fixtures)."""

import unittest
from pathlib import Path

from pipeline import sources
from pipeline.rules import load_rules
from pipeline.wordlist import WordListSettings, build_word_list, read_blocked_words

FIXTURES = Path(__file__).parent / "fixtures"


class ScowlTests(unittest.TestCase):
    def setUp(self):
        self.familiarity = sources.read_scowl(FIXTURES / "scowl" / "final")

    def test_keeps_the_most_common_size_for_each_word(self):
        # "cat" is in both the 10 and 35 lists; 10 (more common) wins.
        self.assertEqual(self.familiarity["cat"], 10)
        self.assertEqual(self.familiarity["garden"], 35)

    def test_reads_american_spellings_but_not_british(self):
        self.assertEqual(self.familiarity["color"], 20)
        self.assertNotIn("colour", self.familiarity)

    def test_skips_names_and_possessives(self):
        self.assertNotIn("Cairo", self.familiarity)
        self.assertNotIn("cairo", self.familiarity)
        self.assertNotIn("cat's", self.familiarity)


class WordNetTests(unittest.TestCase):
    def setUp(self):
        self.definitions = sources.read_wordnet(FIXTURES / "wordnet" / "dict")

    def test_uses_the_first_sense_without_examples(self):
        cat = self.definitions["cat"]
        self.assertEqual(cat.part_of_speech, "noun")
        self.assertEqual(cat.gloss, "feline mammal usually having thick soft fur")

    def test_picks_the_most_used_part_of_speech(self):
        # "dog" is tagged more often as a verb (9) than a noun (7) in the fixture.
        self.assertEqual(self.definitions["dog"].part_of_speech, "verb")

    def test_skips_multi_word_entries(self):
        self.assertNotIn("ice_cream", self.definitions)

    def test_skips_an_offensive_first_sense_for_the_next_one(self):
        # The fixture lists "shrimp" with a disparaging sense first, as WordNet does.
        self.assertEqual(self.definitions["shrimp"].gloss, "small edible crustacean")

    def test_drops_words_whose_only_sense_is_offensive(self):
        self.assertNotIn("puss", self.definitions)

    def test_offensive_check_ignores_the_military_meaning(self):
        # "offensive" alone also means "attacking"; that must not count.
        self.assertFalse(sources.is_offensive_gloss("an offensive against an enemy"))
        self.assertTrue(sources.is_offensive_gloss("(ethnic slur) offensive term for a person"))


class WordListTests(unittest.TestCase):
    def build(self, max_familiarity=50):
        rules = load_rules()
        return build_word_list(
            core_words=sources.read_word_lines(FIXTURES / "core.txt"),
            familiarity=sources.read_scowl(FIXTURES / "scowl" / "final"),
            definitions=sources.read_wordnet(FIXTURES / "wordnet" / "dict"),
            blocked=read_blocked_words(FIXTURES / "badwords.txt"),
            alphabet=rules.alphabet("en"),
            settings=WordListSettings(min_length=2, max_length=8, max_familiarity=max_familiarity),
        )

    def test_keeps_only_words_every_source_agrees_on(self):
        words = [entry.word for entry in self.build()]
        # zymurgy: too rare. slur: blocked. qat: no SCOWL entry or definition.
        # "ice cream", "well-known": not single plain words.
        self.assertEqual(words, ["CAT", "DOG", "COLOR", "GARDEN"])

    def test_most_familiar_words_come_first(self):
        familiarities = [entry.familiarity for entry in self.build()]
        self.assertEqual(familiarities, sorted(familiarities))

    def test_familiarity_cut_off(self):
        words = [entry.word for entry in self.build(max_familiarity=20)]
        self.assertNotIn("GARDEN", words)


if __name__ == "__main__":
    unittest.main()
