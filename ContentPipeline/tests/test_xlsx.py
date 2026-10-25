"""The words workbook importer: reading .xlsx without openpyxl, and turning
its rows into the same words and clues a TSV source gives."""

import tempfile
import unittest
import zipfile
from pathlib import Path

from pipeline.authored import read_sources
from pipeline.xlsx import read_sheets

TR = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"
MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
RELS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def _cell(reference: str, value, shared: list[str]) -> str:
    """A cell the way Excel saves it: text in the shared-string table, a
    number as is, and ("=formula", cached) as a formula with its result."""
    if isinstance(value, tuple):
        formula, cached = value
        return f'<c r="{reference}"><f>{formula}</f><v>{cached}</v></c>'
    if isinstance(value, (int, float)):
        return f'<c r="{reference}"><v>{value}</v></c>'
    shared.append(value)
    return f'<c r="{reference}" t="s"><v>{len(shared) - 1}</v></c>'


def write_workbook(path: Path, sheets: dict[str, list[list]]) -> None:
    """A minimal but real .xlsx: just the parts read_sheets reads. Building
    it here keeps the test independent of any spreadsheet library."""
    shared: list[str] = []
    parts: dict[str, str] = {}
    for number, rows in enumerate(sheets.values(), start=1):
        xml_rows = []
        for row_number, row in enumerate(rows, start=1):
            cells = "".join(
                _cell(f"{chr(ord('A') + column)}{row_number}", value, shared)
                for column, value in enumerate(row) if value is not None
            )
            xml_rows.append(f'<row r="{row_number}">{cells}</row>')
        parts[f"xl/worksheets/sheet{number}.xml"] = (
            f'<worksheet xmlns="{MAIN}"><sheetData>{"".join(xml_rows)}</sheetData></worksheet>'
        )
    sheet_list = "".join(
        f'<sheet name="{name}" sheetId="{n}" r:id="rId{n}"/>' for n, name in enumerate(sheets, start=1)
    )
    parts["xl/workbook.xml"] = f'<workbook xmlns="{MAIN}" xmlns:r="{RELS}"><sheets>{sheet_list}</sheets></workbook>'
    parts["xl/_rels/workbook.xml.rels"] = (
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + "".join(f'<Relationship Id="rId{n}" Target="worksheets/sheet{n}.xml"/>' for n in range(1, len(sheets) + 1))
        + "</Relationships>"
    )
    strings = "".join(f"<si><t>{text}</t></si>" for text in shared)
    parts["xl/sharedStrings.xml"] = f'<sst xmlns="{MAIN}">{strings}</sst>'
    with zipfile.ZipFile(path, "w") as archive:
        for name, xml in parts.items():
            archive.writestr(name, xml)


HEADER = ["ID", "Word", "Letters", "Difficulty", "Clue 1", "Len", "Clue 2", "Len", "Clue 3", "Len", "Notes"]


class ReadSheetsTests(unittest.TestCase):
    def test_rows_come_back_keyed_by_header_with_formula_results(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "words.xlsx"
            write_workbook(path, {"3 letters": [
                HEADER,
                [("ROW()-1", 1), "çay", ("LEN(B2)", 3), "Easy", "Demlenip içilir"],
            ]})
            [(sheet, row_number, row)] = list(read_sheets(path))
        self.assertEqual((sheet, row_number), ("3 letters", 2))
        self.assertEqual(row["Word"], "çay")
        self.assertEqual(row["ID"], "1")        # the formula's saved result
        self.assertEqual(row["Clue 2"], "")     # a missing cell reads as empty


class WorkbookImportTests(unittest.TestCase):
    def read(self, sheets):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "words.xlsx"
            write_workbook(path, sheets)
            return read_sources([path], "tr", TR, min_length=2, max_length=8, clue_max_length=20)

    def test_a_workbook_row_imports_like_a_tsv_line(self):
        words, clues, problems = self.read({"3 letters": [
            HEADER,
            [1, "çay", 3, "Medium", "Demlenip içilir", 15, "Küçük ırmak", 11],
        ]})
        self.assertEqual(problems, [])
        self.assertEqual([(w.word, w.familiarity) for w in words], [("ÇAY", 20)])
        self.assertEqual(clues, [("ÇAY", "Demlenip içilir"), ("ÇAY", "Küçük ırmak")])

    def test_rows_prepared_for_writing_are_skipped(self):
        # The workbook has ID and length formulas down to row 2000; a row
        # with no word yet isn't a problem, it just hasn't been written.
        words, _, problems = self.read({"2 letters": [
            HEADER,
            [1, "ev", 2, "Easy", "Yuva"],
            [("ROW()-1", 2), None, ("LEN(B3)", 0)],
        ]})
        self.assertEqual(len(words), 1)
        self.assertEqual(problems, [])

    def test_problems_name_the_sheet_and_row(self):
        _, _, problems = self.read({
            "2 letters": [HEADER, [1, "ev", 2, "Easy", "Yuva"]],
            "4 letters": [HEADER, [1, "ev", 2, "Easy", "Konut"], [2, "masa", 4, "Easy", ""]],
        })
        self.assertEqual(
            [(p.line, p.word, p.reason) for p in problems],
            [("4 letters row 2", "EV", "listed twice"), ("4 letters row 3", "MASA", "no clue")],
        )

    def test_one_spelling_can_carry_clues_for_different_meanings(self):
        # MÖ is an abbreviation and a cow's moo: with no Type column there's
        # nothing forcing one kind of word, so both clues are kept.
        words, clues, problems = self.read({"2 letters": [
            HEADER, [1, "mö", 2, "Easy", "Milattan önce", 13, "İneğin sesi", 11],
        ]})
        self.assertEqual(problems, [])
        self.assertEqual(words[0].part_of_speech, "")
        self.assertEqual(clues, [("MÖ", "Milattan önce"), ("MÖ", "İneğin sesi")])

    def test_an_unknown_difficulty_is_reported(self):
        _, _, problems = self.read({"2 letters": [HEADER, [1, "ev", 2, "Very easy", "Yuva"]]})
        self.assertEqual(len(problems), 1)
        self.assertIn("familiarity", problems[0].reason)


if __name__ == "__main__":
    unittest.main()
