# check_paper_outputs.py
#
# Purpose:
# - Checks that 05_Paper_Outputs matches its manifest, the manuscript and the supplement:
#   1. every file in output_manifest.csv (and its caption) exists;
#   2. every file in main/ and supplementary/ is in the manifest (no file with an outdated
#      number left behind);
#   3. Tables 1-3, Figures 1-3, the supplementary tables, figures and texts are numbered
#      1..n without gaps or duplicates;
#   4. each table and caption starts with its own label ("Table S4. ..."), each text with
#      "# Supplementary Text S1. ...";
#   5. every reference to a table, figure or text inside the outputs points to an item that
#      exists;
#   6. numbered items that the manuscript does not cite are listed as warnings;
#   7. exactly the items of the manuscript and the supplement exist, with their titles
#      (EXPECTED below: Tables 1-3, Figures 1-3, Tables S1-S17, Figures S1-S3, Texts S1-S2);
#   8. the analyses removed from the final export (D51: gawdis, trunk motion amplitude,
#      directional change tendency) appear in no output;
#   9. every row of a table has as many cells as its header.
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
SECTIONS = ("main", "supplementary")
REF = re.compile(r"\b(Table|Figure|Text)s? (S?\d+)(?:\s*(?:and|[–-])\s*(S?\d+))?")

# Items and titles as in the manuscript and the supplement (version of 2026-11-22).
EXPECTED = {
    "Table 1": "Paired comparison of within- and cross-dataset Macro-F1.",
    "Table 2": "Behavioral differences in cross-dataset F1.",
    "Table 3": "Associations between biological distance and cross-species Macro-F1.",
    "Figure 1": "Within- and cross-dataset Macro-F1.",
    "Figure 2": "Cross-dataset F1 by behavioral class.",
    "Figure 3": "Cross-species Macro-F1 in relation to functional-biomechanical distance.",
    "Table S1": "Datasets and recording conditions.",
    "Table S2": "Analytical units and window counts for the primary analysis.",
    "Table S3": "Mapping of original behavior labels to harmonized classes.",
    "Table S4": "Dataset-specific preprocessing and conversion.",
    "Table S5": "Handcrafted features used by Random Forest and LightGBM.",
    "Table S6": "Classifier implementations and training settings.",
    "Table S7": "Functional-biomechanical traits: definitions, coding and sources.",
    "Table S8": "Species-specific functional-biomechanical trait values.",
    "Table S9": "Sensitivity analysis of within- and cross-dataset Macro-F1 in seven fully eligible datasets.",
    "Table S10": "Pairwise post-hoc comparisons of behavioral classes.",
    "Table S11": "Behavior-specific transfer losses and sensitivity analysis.",
    "Table S12": "Primary mixed-effects model for cross-species transfer.",
    "Table S13": "Robustness analyses of the biological-distance association.",
    "Table S14": "Classifier-specific associations between trait distance and cross-species Macro-F1.",
    "Table S15": "Leave-one-species-out robustness analysis.",
    "Table S16": "Seed-level robustness analysis of the biological-distance association.",
    "Table S17": "Sensitivity analyses of H1–H3 using Random Forest and LightGBM.",
    "Figure S1": "Overview of the analytical workflow.",
    "Figure S2": "Transfer loss by behavioral class and classifier.",
    "Figure S3": "Row-normalized confusion matrices for cross-dataset evaluation by classifier.",
    "Text S1": "Sensitivity scenarios",
    "Text S2": "EltonTraits distance variants",
}
# D51: removed from the standard run and the final export (archived in 04_Statistics/archive/).
REMOVED = re.compile(r"gawdis|trunk motion|directional change|weighted trait distance", re.IGNORECASE)


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
    items = {row["item"] for row in rows}

    # 4. Each table and caption starts with its label; each text with its heading.
    for row in rows:
        for col in ("file", "caption_file"):
            path = ROOT / row[col] if row[col] else None
            if path is None or path.suffix not in (".txt", ".md") or not path.exists():
                continue
            first = path.read_text(encoding="utf-8").split("\n", 1)[0]
            start = f"# Supplementary {row['item']}. " if path.suffix == ".md" else row["item"] + ". "
            if not first.startswith(start):
                errors.append(f"{row[col]}: starts with '{first[:40]}', expected '{start}'")

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
        if row["cited_in"] == "not cited yet":
            warnings.append(f"{row['item']} ({row['title']}) is not cited in the manuscript")

    # 7. The items and titles of the manuscript and the supplement.
    titles = {row["item"]: row["title"] for row in rows}
    for item, title in EXPECTED.items():
        if item not in titles:
            errors.append(f"{item} ({title}) is missing (see 05_Paper_Outputs/errors.txt)")
        elif titles[item] != title:
            errors.append(f"{item}: title '{titles[item]}', expected '{title}'")
    for item in sorted(set(titles) - set(EXPECTED)):
        errors.append(f"{item} is not an item of the manuscript or the supplement")

    # 8. Removed analyses (D51) appear in no output.
    for path in sorted(OUT_DIR.glob("*/*.txt")) + sorted(OUT_DIR.glob("*/*.md")) + [MANIFEST]:
        for m in REMOVED.finditer(path.read_text(encoding="utf-8")):
            errors.append(f"{path.relative_to(ROOT)}: mentions '{m.group(0)}' (removed from the final export, D51)")

    # 9. Each table row has as many cells as the header.
    for row in rows:
        path = ROOT / row["file"]
        if not row["item"].startswith("Table") or not path.exists():
            continue
        lines = path.read_text(encoding="utf-8").split("\n")
        body = []
        for line in lines[2:]:
            if not line:
                break
            body.append(line)
        widths = {line.count("\t") + 1 for line in body}
        if len(widths) != 1:
            errors.append(f"{row['file']}: rows with different numbers of cells {sorted(widths)}")

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
    print("[OK] Manifest, files, numbering, titles and cross-references are consistent with the manuscript and supplement")
    return 0


if __name__ == "__main__":
    sys.exit(main())
