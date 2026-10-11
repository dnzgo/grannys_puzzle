"""Upper- and lowercasing that respects the language.

Python's str.upper() and str.lower() follow English-like rules, which are
wrong for Turkish: Turkish has a dotted and a dotless i, so "i" must become
"İ" (not "I") and "I" must become "ı" (not "i"). Getting this wrong would
turn İÇ (inside) into IÇ, a different letter, and the app would reject the
level because the letters don't match its alphabet.
"""

from __future__ import annotations

_TURKISH_UPPER = str.maketrans({"i": "İ", "ı": "I"})
_TURKISH_LOWER = str.maketrans({"İ": "i", "I": "ı"})


def upper(text: str, language: str) -> str:
    if language == "tr":
        return text.translate(_TURKISH_UPPER).upper()
    return text.upper()


def lower(text: str, language: str) -> str:
    if language == "tr":
        return text.translate(_TURKISH_LOWER).lower()
    return text.lower()
