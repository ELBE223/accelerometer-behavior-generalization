# check_paper_outputs.py
#
# Purpose:
# - Checks that 05_Paper_Outputs matches its manifest and that the numbering is consistent:
#   1. every file in output_manifest.csv (and its caption) exists;
#   2. every generated file in main/, supplementary/ and additional/ is in the manifest
#      (no file with an outdated number left behind);
#   3. Tables 1-3, Figures 1-3, the supplementary tables, figures and texts are numbered
#      1..n without gaps or duplicates;
#   4. each table and caption starts with its own label ("Table S4. ...");
#   5. every reference to a table, figure or text inside the outputs points to an item that
#      exists (an additional item has no number and cannot be cited);
#   6. numbered items that the manuscript does not cite are listed as warnings.
# - Standard library only; exit code 1 if a check fails.
#
# Usage (from the project folder):
#   python tests/check_paper_outputs.py

from __future__ import annotations

import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "05_Paper_Outputs"
MANIFEST = OUT_DIR / "output_manifest.csv"
SECTIONS = ("main", "supplementary", "additional")
REF = re.compile(r"\b(Table|Figure|Text)s? (S?\d+)(?:\s*(?:and|[–-])\s*(S?\d+))?")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    if not MANIFEST.exists():
        print(f"[ERROR] {MANIFEST.relative_to(ROOT)} not found (run 05_Paper_Outputs/paper_figures.R)")
        return 1
    with MANIFEST.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))

    # 1. Files of the manifest exist.
    listed = set()
    for row in rows:
        for col in ("file", "caption_file"):
            if row[col]:
                listed.add(row[col])
                if not (ROOT / row[col]).exists():
                    errors.append(f"{row['item']}: {row[col]} is in the manifest but missing")

    # 2. No generated file outside the manifest.
    for section in SECTIONS:
        for path in sorted((OUT_DIR / section).glob("*")):
            rel = path.relative_to(ROOT).as_posix()
            if path.is_file() and rel not in listed:
                errors.append(f"{rel} is not in the manifest (outdated output?)")

    # 3. Numbering without gaps or duplicates.
    numbers: dict[str, list[int]] = defaultdict(list)
    for row in rows:
        m = re.fullmatch(r"(Table|Figure|Text) (S?)(\d+)", row["item"])
        if m:
            numbers[f"{m.group(1)} {m.group(2)}"].append(int(m.group(3)))
    for group, values in sorted(numbers.items()):
        expected = list(range(1, len(values) + 1))
        if sorted(values) != expected:
            errors.append(f"{group.strip()}: numbers {sorted(values)} are not 1..{len(values)}")
    items = {row["item"] for row in rows if not row["item"].startswith("Additional")}

    # 4. Each table and caption starts with its label.
    for row in rows:
        for col in ("file", "caption_file"):
            path = ROOT / row[col] if row[col] else None
            if path is None or path.suffix != ".txt" or not path.exists():
                continue
            first = path.read_text(encoding="utf-8").split("\n", 1)[0]
            if not first.startswith(row["item"] + ". "):
                errors.append(f"{row[col]}: starts with '{first[:40]}', expected '{row['item']}. '")

    # 5. Cross-references point to existing items.
    for path in sorted(OUT_DIR.glob("*/*.txt")) + sorted(OUT_DIR.glob("*/*.md")):
        text = path.read_text(encoding="utf-8")
        for m in REF.finditer(text):
            kind, first, last = m.group(1), m.group(2), m.group(3)
            refs = [first]
            if last and first.startswith("S") == last.startswith("S"):
                prefix = "S" if first.startswith("S") else ""
                lo, hi = int(first.lstrip("S")), int(last.lstrip("S"))
                refs = [f"{prefix}{n}" for n in range(lo, hi + 1)]
            elif last:
                refs.append(last)
            for ref in refs:
                if f"{kind} {ref}" not in items:
                    errors.append(f"{path.relative_to(ROOT)}: refers to {kind} {ref}, which does not exist")

    # 6. Numbered items without a citation in the manuscript.
    for row in rows:
        if row["section"] != "additional" and row["cited_in"] == "not cited yet":
            warnings.append(f"{row['item']} ({row['title']}) is not cited in the manuscript")

    n_items = defaultdict(int)
    for row in rows:
        n_items[row["section"]] += 1
    print("Paper outputs: " + ", ".join(f"{n_items[s]} {s}" for s in SECTIONS))
    for w in warnings:
        print(f"[WARN] {w}")
    for e in errors:
        print(f"[ERROR] {e}")
    if errors:
        return 1
    print("[OK] Manifest, files, numbering and cross-references are consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
