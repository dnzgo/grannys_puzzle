"""Command line for the content pipeline. Run from the ContentPipeline folder:

    python3 -m pipeline.cli build-words  --lang en --scowl sources/scowl/final \\
        --core sources/12dicts/2+2+3cmn.txt --wordnet sources/wordnet/dict \\
        --badwords sources/badwords/en
    python3 -m pipeline.cli generate     --lang en --count 100 --pack en-001
    python3 -m pipeline.cli validate     data/en/packs/en-001.json
    python3 -m pipeline.cli clue-batches --lang en --pack data/en/packs/en-001.json
    python3 -m pipeline.cli import-clues --lang en clue-batches/en-001-001.csv

Every command prints what it did and exits non-zero on failure, so it can run
in a script or CI later.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import sources
from .authored import read_sources, write_clue_bank
from .clues import ClueBank, append_to_bank, import_batch, write_batches
from .generator import LevelGenerator, LevelSpec
from .rules import load_rules
from .shapes import DEFAULT_SIZES
from .validator import validate_level
from .wordlist import WordListSettings, build_word_list, read_blocked_words, read_word_list, write_word_list

PIPELINE_ROOT = Path(__file__).resolve().parents[1]
PACK_FORMAT_VERSION = 1


def data_dir(language: str) -> Path:
    return PIPELINE_ROOT / "data" / language


# MARK: - Commands

def cmd_build_words(args: argparse.Namespace) -> int:
    rules = load_rules()
    familiarity = sources.read_scowl(Path(args.scowl))
    core = sources.read_word_lines(Path(args.core))
    definitions = sources.read_wordnet(Path(args.wordnet))
    blocked = read_blocked_words(Path(args.badwords), data_dir(args.lang) / "exclude.txt")
    settings = WordListSettings(
        min_length=rules.min_answer_length,
        max_length=rules.max_rows - 1,
        max_familiarity=args.max_familiarity,
    )
    entries = build_word_list(
        core_words=core,
        familiarity=familiarity,
        definitions=definitions,
        blocked=blocked,
        alphabet=rules.alphabet(args.lang),
        settings=settings,
    )
    out = data_dir(args.lang) / "words.tsv"
    write_word_list(entries, out)
    print(f"Sources: {len(core)} core words, {len(familiarity)} SCOWL words, "
          f"{len(definitions)} WordNet words, {len(blocked)} blocked")
    print(f"Wrote {len(entries)} words to {out}")
    return 0


def parse_sizes(text: str) -> list[tuple[int, int]]:
    """'7x9,6x7' -> [(9, 7), (7, 6)]: columns x rows, as people say grid sizes."""
    sizes = []
    for part in text.split(","):
        columns, rows = part.lower().split("x")
        sizes.append((int(rows), int(columns)))
    return sizes


def cmd_generate(args: argparse.Namespace) -> int:
    rules = load_rules()
    words = read_word_list(data_dir(args.lang) / "words.tsv")
    clue_bank = ClueBank.load(data_dir(args.lang) / "clues.tsv")
    generator = LevelGenerator(args.lang, words, clue_bank, rules)
    sizes = parse_sizes(args.sizes)
    shapes = [name.strip() for name in args.shapes.split(",") if name.strip()]
    shape_size = parse_sizes(args.shape_size)[0] if args.shape_size else None

    levels, failures = [], 0
    for offset in range(args.count):
        number = args.first_number + offset
        rows, columns = sizes[offset % len(sizes)]
        # Every Nth level (by level number) is a shaped one, taking the
        # shapes in turn, on its own board size.
        shape = None
        if args.shape_every and number % args.shape_every == 0:
            shape = shapes[(number // args.shape_every - 1) % len(shapes)]
            rows, columns = shape_size or DEFAULT_SIZES[shape]
        spec = LevelSpec(
            rows=rows, columns=columns, max_familiarity=args.max_familiarity,
            max_answer_length=args.max_answer_length, shape=shape,
        )
        level_id = f"{args.lang}-{number:06d}"
        # The seed comes from the level number, so the same command always
        # makes the same pack. (A level also depends on the ones before it,
        # which steer it away from recently used words; regenerate the whole
        # pack, not a single level, to reproduce it.)
        level = generator.generate(level_id, spec, seed=args.seed * 1_000_003 + number)
        if level is None:
            failures += 1
            print(f"  {level_id}: no fill found ({columns}x{rows})", file=sys.stderr)
            continue
        problems = validate_level(level, rules)
        if problems:
            failures += 1
            print("\n".join(f"  {p}" for p in problems), file=sys.stderr)
            continue
        levels.append(level)
        print(f"  {level_id}: {columns}x{rows}" + (f" {shape}" if shape else ""))

    out = data_dir(args.lang) / "packs" / f"{args.pack}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    pack = {"formatVersion": PACK_FORMAT_VERSION, "packId": args.pack, "language": args.lang, "levels": levels}
    out.write_text(json.dumps(pack, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    stats = generator.stats
    print(f"Wrote {len(levels)} levels to {out} ({failures} failed). "
          f"Layouts tried: {stats.layouts_tried}, fills tried: {stats.fills_tried}, "
          f"placeholder clues: {stats.placeholder_clues}, distinct words: {len(generator.used_words)}")
    return 0 if failures == 0 else 1


def _load_levels(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return data["levels"] if "levels" in data else [data]


def cmd_validate(args: argparse.Namespace) -> int:
    rules = load_rules()
    total, bad = 0, 0
    for name in args.paths:
        for level in _load_levels(Path(name)):
            total += 1
            problems = validate_level(level, rules)
            if problems:
                bad += 1
                print("\n".join(problems))
    print(f"Checked {total} levels: {total - bad} valid, {bad} with problems")
    return 0 if bad == 0 else 1


def cmd_clue_batches(args: argparse.Namespace) -> int:
    """Batches of words used in a pack that don't have real clues yet."""
    words = {entry.word: entry for entry in read_word_list(data_dir(args.lang) / "words.tsv")}
    bank = ClueBank.load(data_dir(args.lang) / "clues.tsv")
    needed: set[str] = set()
    for level in _load_levels(Path(args.pack)):
        grid = level["grid"]
        for clue in level["clues"]:
            needed.add(_answer_of(grid, clue))
    missing = sorted((words[w] for w in needed if w in words and not bank.has_clue(w)),
                     key=lambda entry: (entry.familiarity, entry.word))
    prefix = Path(args.pack).stem
    paths = write_batches(missing, PIPELINE_ROOT / "clue-batches", args.batch_size, prefix)
    print(f"{len(needed)} words in the pack, {len(missing)} need clues: wrote {len(paths)} batch files")
    for path in paths:
        print(f"  {path.relative_to(PIPELINE_ROOT)}")
    return 0


def _answer_of(grid: list[str], clue: dict) -> str:
    start = {"right": (0, 1), "rightDown": (0, 1), "down": (1, 0), "downRight": (1, 0)}[clue["arrow"]]
    step = (0, 1) if clue["arrow"] in ("right", "downRight") else (1, 0)
    r, c = clue["row"] + start[0], clue["column"] + start[1]
    letters = []
    while r < len(grid) and c < len(grid[0]) and grid[r][c] not in "#.":
        letters.append(grid[r][c])
        r, c = r + step[0], c + step[1]
    return "".join(letters)


def cmd_import_clues(args: argparse.Namespace) -> int:
    rules = load_rules()
    all_accepted, all_problems = [], []
    for name in args.paths:
        accepted, problems = import_batch(Path(name), rules.clue_max_length, args.lang)
        all_accepted += accepted
        all_problems += problems
    added = append_to_bank(all_accepted, data_dir(args.lang) / "clues.tsv")
    for p in all_problems:
        print(f"  rejected {p.word}: {p.clue!r} ({p.reason})")
    print(f"Accepted {len(all_accepted)} clues ({added} new), rejected {len(all_problems)}")
    return 0 if not all_problems else 1


def cmd_import_word_list(args: argparse.Namespace) -> int:
    """Builds words.tsv and clues.tsv from hand-written source files."""
    rules = load_rules()
    folder = data_dir(args.lang) / "source"
    paths = sorted(folder.glob("*.tsv"))
    if not paths:
        print(f"No source files in {folder}", file=sys.stderr)
        return 1
    words, clues, problems = read_sources(
        paths,
        language=args.lang,
        alphabet=rules.alphabet(args.lang),
        min_length=rules.min_answer_length,
        max_length=rules.max_rows - 1,
        clue_max_length=rules.clue_max_length,
    )
    for p in problems:
        print(f"  {p.file}:{p.line} {p.word}: {p.reason}")
    write_word_list(words, data_dir(args.lang) / "words.tsv")
    write_clue_bank(clues, data_dir(args.lang) / "clues.tsv")
    print(f"Read {len(paths)} source files: {len(words)} words, {len(clues)} clues, {len(problems)} problems")
    return 0 if not problems else 1


# MARK: - Entry point

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="pipeline", description="Granny's Puzzle content pipeline")
    commands = parser.add_subparsers(dest="command", required=True)

    build = commands.add_parser("build-words", help="build data/<lang>/words.tsv from the sources")
    build.add_argument("--lang", required=True)
    build.add_argument("--scowl", required=True, help="SCOWL final/ folder")
    build.add_argument("--core", required=True, help="12dicts 2+2+3cmn.txt")
    build.add_argument("--wordnet", required=True, help="WordNet dict/ folder")
    build.add_argument("--badwords", required=True, help="LDNOOBW list for the language")
    build.add_argument("--max-familiarity", type=int, default=50, help="SCOWL size cut-off (default 50)")
    build.set_defaults(run=cmd_build_words)

    authored = commands.add_parser(
        "import-word-list", help="build words.tsv and clues.tsv from data/<lang>/source/*.tsv"
    )
    authored.add_argument("--lang", required=True)
    authored.set_defaults(run=cmd_import_word_list)

    generate = commands.add_parser("generate", help="generate a level pack")
    generate.add_argument("--lang", required=True)
    generate.add_argument("--count", type=int, required=True)
    generate.add_argument("--pack", required=True, help="pack name, e.g. en-001")
    generate.add_argument("--first-number", type=int, default=1)
    generate.add_argument("--sizes", default="7x9,6x8,7x7,5x6", help="columns x rows, cycled")
    generate.add_argument(
        "--max-familiarity", type=int, default=20,
        help="SCOWL size cut-off (default 20: everyday words; 35 adds crossword-veteran words like ARIA, LEVEE)",
    )
    generate.add_argument(
        "--max-answer-length", type=int, default=6,
        help="longest answer allowed (default 6); longer answers need bigger --sizes and fill less easily",
    )
    generate.add_argument(
        "--shape-every", type=int, default=0,
        help="make every Nth level (by number) a shaped board, e.g. 10; 0 = none",
    )
    generate.add_argument("--shapes", default="circle,diamond,h", help="shapes to take in turn")
    generate.add_argument(
        "--shape-size", default=None,
        help="board size for every shaped level (columns x rows); default: each shape's own, see shapes.py",
    )
    generate.add_argument("--seed", type=int, default=1)
    generate.set_defaults(run=cmd_generate)

    validate = commands.add_parser("validate", help="check level or pack files")
    validate.add_argument("paths", nargs="+")
    validate.set_defaults(run=cmd_validate)

    batches = commands.add_parser("clue-batches", help="write clue-writing batches for a pack")
    batches.add_argument("--lang", required=True)
    batches.add_argument("--pack", required=True)
    batches.add_argument("--batch-size", type=int, default=300)
    batches.set_defaults(run=cmd_clue_batches)

    imports = commands.add_parser("import-clues", help="check filled batches and add them to clues.tsv")
    imports.add_argument("--lang", required=True)
    imports.add_argument("paths", nargs="+")
    imports.set_defaults(run=cmd_import_clues)

    args = parser.parse_args(argv)
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
