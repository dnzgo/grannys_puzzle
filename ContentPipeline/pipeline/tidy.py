"""Tidying hand-written (or drafted) clues on import, so small slips in the
words workbook don't reach the game: a clue written all in lowercase, a
blank written with two underscores.

The workbook keeps what was written; these fixes are applied each time it's
imported, so the result is the same on every machine and every run.

Names (Berlin, Spanish, Monday) get their capital from a list saved in
the repo, data/<lang>/names.txt (`build-names` makes it from SCOWL's lists
of names and capitalised words). A word that is also an ordinary word
(may, turkey, china, bill) isn't in it, so it's never capitalised by
mistake: a clue that means the country then needs fixing by hand.
"""

from __future__ import annotations

import re
from pathlib import Path

from .textcase import upper

# A blank in a fill-in clue is three underscores (CLUE_STYLE.md, rule 5).
_BLANK = re.compile(r"_{2,}")
# Any run of letters, in any alphabet: with A-Z only, the "i" in Turkish
# "içilir" would be cut off by the "ç" and read as the English word "i".
_WORD = re.compile(r"[^\W\d_]+")
# The letters a clue may start with and be capitalised: the language's own.
# A clue starting with another letter (π, an emoji) is left as written:
# "π = 3.14" mustn't become "Π = 3.14".
_LOWERCASE = {
    "en": set("abcdefghijklmnopqrstuvwxyz"),
    "tr": set("abcçdefgğhıijklmnoöprsştuüvyz"),
}


def read_names(path: Path) -> dict[str, str]:
    """data/<lang>/names.txt: one name per line as it's written ("Berlin").
    Keyed by its lowercase form. Missing file: no names."""
    if not path.exists():
        return {}
    names = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        name = line.strip()
        if name and not name.startswith("#"):
            names[name.lower()] = name
    return names


def tidy_clue(clue: str, names: dict[str, str] | None = None, language: str = "en") -> str:
    """The clue as the game should show it: names capitalised, a lone "i"
    as "I" (English), blanks as ___, and the first letter capitalised
    (sentence case, with the language's own capitals: Turkish i → İ).
    Everything else is left exactly as written."""
    text = _BLANK.sub("___", clue.strip())

    def fix(match: re.Match) -> str:
        word = match.group(0)
        if word == "i" and language == "en":
            return "I"
        if names and word.islower():
            return names.get(word, word)
        return word

    text = _WORD.sub(fix, text)
    # Only when it opens with an all-lowercase word: "___ the left" stays
    # as it is (not "___ The left"), and so does "pH level" (not "PH").
    first = _WORD.match(text)
    own_letters = _LOWERCASE.get(language, set())
    if first and first.group(0).islower() and text[0] in own_letters:
        text = upper(text[0], language) + text[1:]
    return text


def build_names(scowl_final: Path, max_common_size: int = 50) -> list[str]:
    """Names from SCOWL (its proper-name and capitalised-word lists) that
    aren't everyday lowercase words (SCOWL size up to `max_common_size`, in
    any spelling), so capitalising them can't change a word's meaning. Up
    to 50, not further: the bigger lists hold rare homonyms ("berlin", a
    carriage) that would stop real names from being capitalised. Words of fewer than
    three letters, and word endings SCOWL lists capitalised (Th, Ing), are
    left out."""
    names: dict[str, str] = {}
    for pattern in ("*-proper-names.*", "*-upper.*"):
        for path in sorted(scowl_final.glob(pattern)):
            for line in path.read_text(encoding="iso-8859-1").splitlines():
                word = line.strip()
                if len(word) >= 3 and word.isalpha() and word[0].isupper():
                    names.setdefault(word.lower(), word)
    common: set[str] = set()
    for path in scowl_final.glob("*-words.*"):
        size = path.suffix.lstrip(".")
        if size.isdigit() and int(size) <= max_common_size:
            for line in path.read_text(encoding="iso-8859-1").splitlines():
                word = line.strip()
                if word.islower():
                    common.add(word)
    # Abbreviations and word endings that SCOWL lists capitalised but a
    # clue uses as ordinary text.
    not_names = {"ing", "tech", "ott"}
    return sorted(name for key, name in names.items() if key not in common and key not in not_names)
