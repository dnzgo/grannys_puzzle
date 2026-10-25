"""Reads the rows of an .xlsx workbook with the standard library only.

The pipeline installs nothing (see README), so instead of openpyxl this
reads the parts of the file format it needs: an .xlsx is a zip of XML
files, one per sheet, with most text stored once in a shared table.
Formula cells are read as the value Excel last calculated and saved.
"""

from __future__ import annotations

import re
import zipfile
import xml.etree.ElementTree as ET
from collections.abc import Iterator
from pathlib import Path

_NS = {
    "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "rel": "http://schemas.openxmlformats.org/package/2006/relationships",
}


def _column_index(reference: str) -> int:
    """"C12" -> 2 (zero-based column)."""
    letters = re.match(r"[A-Z]+", reference).group(0)
    index = 0
    for letter in letters:
        index = index * 26 + (ord(letter) - ord("A") + 1)
    return index - 1


def _text(element: ET.Element) -> str:
    """All the text in a string element, including rich-text runs."""
    return "".join(node.text or "" for node in element.iter(f"{{{_NS['m']}}}t"))


def read_sheets(path: Path) -> Iterator[tuple[str, int, dict[str, str]]]:
    """Every data row of every sheet: (sheet name, row number, {header: text}).

    The first row of a sheet is its header; rows below it come back as
    dictionaries keyed by those headers, every value as stripped text
    ("" when empty). Sheets without a header row are skipped."""
    with zipfile.ZipFile(path) as archive:
        shared: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            shared = [_text(item) for item in root.findall("m:si", _NS)]

        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        relations = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        targets = {rel.get("Id"): rel.get("Target") for rel in relations.findall("rel:Relationship", _NS)}

        for sheet in workbook.findall("m:sheets/m:sheet", _NS):
            name = sheet.get("name")
            target = targets[sheet.get(f"{{{_NS['r']}}}id")].lstrip("/")
            part = target if target.startswith("xl/") else f"xl/{target}"
            root = ET.fromstring(archive.read(part))

            headers: list[str] | None = None
            for row in root.findall("m:sheetData/m:row", _NS):
                values: dict[int, str] = {}
                for cell in row.findall("m:c", _NS):
                    kind = cell.get("t")
                    if kind == "inlineStr":
                        value = _text(cell)
                    else:
                        raw = cell.findtext("m:v", default="", namespaces=_NS)
                        value = shared[int(raw)] if kind == "s" and raw else raw
                    values[_column_index(cell.get("r"))] = value.strip()
                if headers is None:
                    headers = [values.get(i, "") for i in range(max(values, default=-1) + 1)]
                    continue
                yield name, int(row.get("r")), {
                    header: values.get(i, "") for i, header in enumerate(headers) if header
                }
