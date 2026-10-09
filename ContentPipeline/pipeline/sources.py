"""Readers for the third-party word sources.

Each reader takes a path to the source as downloaded and returns plain Python
data. Sources are never edited by hand: if a word needs removing, it goes in
`data/<lang>/exclude.txt`, so every change is visible and repeatable.

Formats are documented in each function, because they're easy to forget and
a silent parsing mistake would quietly drop words.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

_PLAIN_WORD = re.compile(r"^[a-z]+$")


def read_scowl(final_dir: Path, list_names: tuple[str, ...] = ("english-words", "american-words")) -> dict[str, int]:
    """SCOWL's `final/` folder: files named `<list>.<size>`, e.g.
    `english-words.35`, one word per line, ISO-8859-1 encoded.

    The size number says how common a word is: 10 is the most common, 95 the
    rarest. Returns each plain lowercase word with the smallest size it
    appears in (its "familiarity": lower is more familiar).

    Capitalised words (names), possessives ("cat's") and words with accents
    or hyphens are skipped by the plain-word filter.
    """
    familiarity: dict[str, int] = {}
    pattern = re.compile(r"^(?P<list>[a-z_0-9-]+)\.(?P<size>\d+)$")
    for path in sorted(final_dir.iterdir()):
        match = pattern.match(path.name)
        if not match or match.group("list") not in list_names:
            continue
        size = int(match.group("size"))
        for line in path.read_text(encoding="iso-8859-1").splitlines():
            word = line.strip()
            if _PLAIN_WORD.match(word):
                if word not in familiarity or size < familiarity[word]:
                    familiarity[word] = size
    return familiarity


def read_word_lines(path: Path) -> set[str]:
    """A one-word-per-line list, such as 12dicts' `2+2+3cmn.txt` or the
    LDNOOBW `en` file. Annotation marks some lists put after a word
    (`!`, `%`, `+` and similar) are removed; entries that still aren't a plain
    lowercase word (phrases, capitals, hyphens) are skipped."""
    words: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        word = re.sub(r"[^A-Za-z' -]", "", line).strip()
        if _PLAIN_WORD.match(word):
            words.add(word)
    return words


@dataclass(frozen=True)
class Definition:
    part_of_speech: str  # noun, verb, adjective or adverb
    gloss: str  # the first definition, without examples


_POS_FILES = {"noun": "noun", "verb": "verb", "adjective": "adj", "adverb": "adv"}


def read_wordnet(dict_dir: Path) -> dict[str, Definition]:
    """WordNet's `dict/` folder (Princeton WordNet 3.x or Open English
    WordNet in the same "WNDB" format).

    `index.<pos>` lines: `lemma pos synset_cnt p_cnt [ptr…] sense_cnt
    tagsense_cnt offset…`, with offsets in sense order, most frequent first.
    `data.<pos>` lines: `offset … | gloss`. Licence header lines start with
    spaces and are skipped.

    For each word, keeps the most-used sense across parts of speech (by
    `tagsense_cnt`, how often that word was tagged in a reference corpus) and
    returns its first definition, minus example sentences.

    Senses WordNet marks as slurs or obscene are skipped in favour of the
    word's next sense: "shrimp" should be the crustacean, not "disparaging
    terms for small people". A word with no clean sense gets no definition,
    which keeps it out of the word list entirely.
    """
    glosses: dict[tuple[str, str], str] = {}
    best: dict[str, tuple[int, Definition]] = {}

    for pos, suffix in _POS_FILES.items():
        for line in (dict_dir / f"data.{suffix}").read_text(encoding="utf-8", errors="replace").splitlines():
            if not line or line.startswith(" ") or "|" not in line:
                continue
            offset = line.split(" ", 1)[0]
            gloss = line.split("|", 1)[1].strip()
            glosses[(pos, offset)] = _first_definition(gloss)

        for line in (dict_dir / f"index.{suffix}").read_text(encoding="utf-8", errors="replace").splitlines():
            if not line or line.startswith(" "):
                continue
            fields = line.split()
            lemma = fields[0]
            if not _PLAIN_WORD.match(lemma):
                continue
            pointer_count = int(fields[3])
            tagged_count = int(fields[5 + pointer_count])
            sense_offsets = fields[6 + pointer_count:]
            gloss = next(
                (
                    candidate
                    for offset in sense_offsets
                    if (candidate := glosses.get((pos, offset))) and not is_offensive_gloss(candidate)
                ),
                None,
            )
            if not gloss:
                continue
            if lemma not in best or tagged_count > best[lemma][0]:
                best[lemma] = (tagged_count, Definition(pos, gloss))

    return {lemma: definition for lemma, (_, definition) in best.items()}


# Phrases WordNet uses to label insulting or obscene senses. Deliberately
# narrow: plain "offensive" also means "attacking" ("an offensive against an
# enemy"), and plain "slang" covers harmless words like "tummy".
_OFFENSIVE_GLOSS = re.compile(
    r"\b(slur|offensive (term|name|word)s?|obscene|disparaging|derogatory|vulgar)\b",
    re.IGNORECASE,
)


def is_offensive_gloss(gloss: str) -> bool:
    return _OFFENSIVE_GLOSS.search(gloss) is not None


def _first_definition(gloss: str) -> str:
    """WordNet glosses look like: `a feline mammal; "the cat purred"`.
    Keeps the part before the first quoted example or semicolon."""
    text = gloss.split('"', 1)[0]
    text = text.split(";", 1)[0]
    return text.strip(" ;,")
