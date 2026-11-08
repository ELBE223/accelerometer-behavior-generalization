# assign_classes.py
#
# Purpose:
# - Assigns the behavior classes of 00_Documentation/behavior_mapping.csv (D10) to the
#   windows in data/windows/<dataset>/windows.parquet, using the samples per original label
#   of each window (column label_counts, written by make_windows.py).
# - A window has a class if all its samples are labeled and map to the same class
#   (Foraging, Locomotion, Resting or Other); two original labels of one class are fine.
#   A sample with an Exclude label, an unlabeled sample or a second class leaves the window
#   without class; class_reason says why. class_majority and class_share are the most
#   frequent class and its share (majority-label sensitivity analysis, D11).
# - Two mappings: class (column class of the table) and class_sensitivity (column
#   sensitivity_class where given, otherwise class; ridden gaits as Locomotion, D11).
# - Output: data/windows/<dataset>/classes.parquet, one row per window in the order of
#   windows.parquet (window keys and class columns).
#   Report: 01_Preprocessing/reports/pipeline_reports/class_report.txt and class_summary.csv
#   (windows per dataset, individual and class).
# - --variant C: the windows of make_windows.py --variant C (data/windows_C/), reports with "_C".
#
# Usage (from the project folder, venv active):
#   python 01_Preprocessing/assign_classes.py Cattle_dataset_1   # one or more datasets
#   python 01_Preprocessing/assign_classes.py                    # all windowed datasets
#   python 01_Preprocessing/assign_classes.py --variant C        # sensitivity windows (D11)

from __future__ import annotations

import argparse
import json
import time
from collections import Counter
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
MAPPING_CSV = ROOT / "00_Documentation" / "behavior_mapping.csv"
WINDOW_DIR = ROOT / "data" / "windows"
REPORT_DIR = ROOT / "01_Preprocessing" / "reports" / "pipeline_reports"
REPORT_TXT = REPORT_DIR / "class_report.txt"
SUMMARY_CSV = REPORT_DIR / "class_summary.csv"
SETTINGS = ROOT / "config" / "pipeline_settings.json"

CLASSES = ["Foraging", "Locomotion", "Resting", "Other"]
MAIN_CLASSES = CLASSES[:3]
EXCLUDE = "Exclude"
UNLABELED_TEXT = "(unlabeled)"  # as in make_windows.py
KEYS = ["dataset_id", "individual_id", "segment_id", "window_in_segment", "non_overlapping"]
MIN_TEST_WINDOWS = 10  # thesis rule for individuals (D12 option 1)
WIDTH = 100


def log(msg: str) -> None:
    print(msg, flush=True)


def section(title: str) -> list[str]:
    return ["", "=" * WIDTH, title, "=" * WIDTH]


def read_mapping() -> pd.DataFrame:
    table = pd.read_csv(MAPPING_CSV, dtype=str, keep_default_na=False)
    bad = sorted(set(table["class"]) - set(CLASSES) - {EXCLUDE})
    bad += sorted(set(table["sensitivity_class"]) - set(CLASSES) - {EXCLUDE, ""})
    if bad:
        raise ValueError(f"Unknown classes in {MAPPING_CSV.name}: {bad}")
    dup = table.duplicated(["dataset_id", "label"])
    if dup.any():
        raise ValueError(f"Labels listed twice in {MAPPING_CSV.name}: {table.loc[dup, ['dataset_id', 'label']].values.tolist()}")
    table["sensitivity_class"] = table["sensitivity_class"].where(table["sensitivity_class"] != "", table["class"])
    return table


def classify(label_counts: str, mapping: dict[str, str]) -> tuple[str | None, str | None, float, str, set]:
    # Returns class, majority class, its share, reason (empty if the window has a class)
    # and labels missing from the mapping.
    per_class: Counter = Counter()
    unmapped = set()
    for part in label_counts.split(";"):
        label, n = part.rsplit("=", 1)
        if label == UNLABELED_TEXT:
            cls = UNLABELED_TEXT
        else:
            cls = mapping.get(label)
            if cls is None:
                unmapped.add(label)
                cls = "(unmapped)"
        per_class[cls] += int(n)
    total = sum(per_class.values())
    top, n_top = per_class.most_common(1)[0]
    majority = top if top in CLASSES else None
    share = n_top / total if majority else 0.0
    if unmapped:
        reason = "label not in the mapping"
    elif EXCLUDE in per_class:
        reason = "Exclude label"
    elif UNLABELED_TEXT in per_class:
        reason = "unlabeled samples"
    elif len(per_class) > 1:
        reason = "two or more classes"
    else:
        return top, majority, share, "", unmapped
    return None, majority, share, reason, unmapped


def assign(dataset: str, mapping_table: pd.DataFrame) -> tuple[pd.DataFrame, set]:
    path = WINDOW_DIR / dataset / "windows.parquet"
    windows = pd.read_parquet(path, columns=KEYS + ["label_counts"])
    rows = mapping_table[mapping_table["dataset_id"] == dataset]
    out = windows[KEYS].copy()
    unmapped_all: set = set()
    # Each distinct label composition is classified once.
    codes, uniques = pd.factorize(windows["label_counts"])
    for prefix, column in [("class", "class"), ("class_sensitivity", "sensitivity_class")]:
        mapping = dict(zip(rows["label"], rows[column]))
        results = [classify(u, mapping) for u in uniques]
        for r in results:
            unmapped_all |= r[4]
        out[prefix] = pd.Series([r[0] for r in results], dtype="string").take(codes).to_numpy()
        if prefix == "class":
            out["class_majority"] = pd.Series([r[1] for r in results], dtype="string").take(codes).to_numpy()
            out["class_share"] = pd.Series([r[2] for r in results], dtype="float32").take(codes).to_numpy()
            out["class_reason"] = pd.Series([r[3] for r in results], dtype="string").take(codes).to_numpy()
    return out, unmapped_all


# =========================================================
# Report
# =========================================================
def per_individual(classes: pd.DataFrame, column: str) -> pd.DataFrame:
    test = classes[classes["non_overlapping"] & classes[column].notna()]
    table = pd.crosstab(test["individual_id"], test[column]).reindex(columns=CLASSES, fill_value=0)
    all_ids = sorted(classes["individual_id"].unique())
    return table.reindex(all_ids, fill_value=0)


def dataset_report(dataset: str, classes: pd.DataFrame, unmapped: set) -> list[str]:
    lines = section(dataset)
    if unmapped:
        lines.append(f"  LABELS NOT IN THE MAPPING (windows without class): {', '.join(sorted(unmapped))}")
    for title, sub in [("all windows (training)", classes), ("non-overlapping (evaluation)", classes[classes["non_overlapping"]])]:
        counts = sub["class"].value_counts()
        reasons = sub["class_reason"][sub["class"].isna()].value_counts()
        lines.append(f"  {title}: {len(sub):,}; with class: " + ", ".join(f"{c} {int(counts.get(c, 0)):,}" for c in CLASSES)
                     + "; without class: " + (", ".join(f"{r} {n:,}" for r, n in reasons.items()) or "0"))
    sens = classes["class_sensitivity"].fillna("-") != classes["class"].fillna("-")
    if sens.any():
        test = classes[classes["non_overlapping"]]
        counts = test["class_sensitivity"].value_counts()
        lines.append("  sensitivity mapping, non-overlapping: " + ", ".join(f"{c} {int(counts.get(c, 0)):,}" for c in CLASSES)
                     + f" ({int(sens.sum()):,} windows change)")

    table = per_individual(classes, "class")
    rule = (table[MAIN_CLASSES] >= MIN_TEST_WINDOWS).all(axis=1)
    lines += ["", f"  Evaluation windows per individual and class (thesis rule, D12 option 1: all three main "
                  f"classes with at least {MIN_TEST_WINDOWS} windows):", ""]
    shown = table.assign(thesis_rule=rule.map({True: "kept", False: "LEFT OUT"}))
    lines += ["  " + ln for ln in shown.to_string().splitlines()]
    lines.append(f"  Individuals kept by the thesis rule: {int(rule.sum())} of {len(rule)}")
    return lines


def summary_rows(dataset: str, classes: pd.DataFrame) -> list[dict]:
    rows = []
    for mapping, column in [("primary", "class"), ("sensitivity", "class_sensitivity")]:
        sub = classes[classes[column].notna()]
        grouped = sub.groupby(["individual_id", column])
        for (individual, cls), g in grouped:
            rows.append({"dataset_id": dataset, "mapping": mapping, "individual_id": individual, "class": cls,
                         "windows": len(g), "test_windows": int(g["non_overlapping"].sum())})
    return rows


def main() -> int:
    global WINDOW_DIR, REPORT_TXT, SUMMARY_CSV
    variants = json.loads(SETTINGS.read_text(encoding="utf-8")).get("variants", {})
    parser = argparse.ArgumentParser(description="Assign behavior classes to the windows.")
    parser.add_argument("datasets", nargs="*", help="Dataset IDs (default: all windowed datasets)")
    parser.add_argument("--variant", choices=sorted(variants), help="window variant of pipeline_settings.json (D11)")
    args = parser.parse_args()
    if args.variant:
        WINDOW_DIR = ROOT / "data" / f"windows_{args.variant}"
        REPORT_TXT, SUMMARY_CSV = REPORT_DIR / f"class_report_{args.variant}.txt", REPORT_DIR / f"class_summary_{args.variant}.csv"

    mapping = read_mapping()
    available = sorted(p.parent.name for p in WINDOW_DIR.glob("*/windows.parquet"))
    datasets = args.datasets or available
    failed = [d for d in datasets if d not in available]
    if failed:
        log(f"[ERROR] No windows (run 01_Preprocessing/make_windows.py): {', '.join(failed)}")

    sections: dict[str, list[str]] = {}
    summary: list[dict] = []
    for dataset in [d for d in datasets if d in available]:
        start = time.time()
        try:
            classes, unmapped = assign(dataset, mapping)
        except Exception as exc:
            failed.append(dataset)
            sections[dataset] = section(dataset) + [f"  FAILED: {type(exc).__name__}: {exc}"]
            log(f"[ERROR] {dataset}: {type(exc).__name__}: {exc}")
            continue
        classes.to_parquet(WINDOW_DIR / dataset / "classes.parquet", index=False)
        sections[dataset] = dataset_report(dataset, classes, unmapped)
        summary += summary_rows(dataset, classes)
        if unmapped:
            failed.append(dataset)
            log(f"[ERROR] {dataset}: labels not in {MAPPING_CSV.name}: {', '.join(sorted(unmapped))}")
        log(f"[OK] {dataset}: {int(classes['class'].notna().sum()):,} of {len(classes):,} windows with class "
            f"({time.time() - start:.0f} s)")

    # Sections and summary rows of datasets not processed now are kept from earlier runs.
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    new = pd.DataFrame(summary, columns=["dataset_id", "mapping", "individual_id", "class", "windows", "test_windows"])
    if SUMMARY_CSV.exists():
        old = pd.read_csv(SUMMARY_CSV)
        new = pd.concat([old[~old["dataset_id"].isin(sections)], new], ignore_index=True)
    new.sort_values(["dataset_id", "mapping", "individual_id", "class"]).to_csv(SUMMARY_CSV, index=False)
    old_sections = read_sections() if REPORT_TXT.exists() else {}
    old_sections.update(sections)
    header = [
        "CLASS REPORT" + (f" (variant {args.variant})" if args.variant else ""),
        f"Updated: {time.strftime('%Y-%m-%d %H:%M:%S')} with 01_Preprocessing/assign_classes.py "
        f"(datasets of this run: {', '.join(sections) or '-'})",
        f"Mapping: 00_Documentation/{MAPPING_CSV.name} (D10); a window has a class if all its samples map to it.",
    ]
    body = [ln for d in sorted(old_sections) for ln in old_sections[d]]
    REPORT_TXT.write_text("\n".join(header + body) + "\n", encoding="utf-8")
    if failed:
        log(f"[ERROR] Classes missing or incomplete for: {', '.join(failed)}")
        return 1
    return 0


def read_sections() -> dict[str, list[str]]:
    # Dataset sections of the existing report (between the "=" lines).
    lines = REPORT_TXT.read_text(encoding="utf-8").splitlines()
    sections: dict[str, list[str]] = {}
    current = None
    for i, line in enumerate(lines):
        if line == "=" * WIDTH and i + 2 < len(lines) and lines[i + 2] == "=" * WIDTH:
            current = lines[i + 1]
            sections[current] = [""]
        if current is not None:
            sections[current].append(line)
    for lines_of in sections.values():
        while lines_of and lines_of[-1] == "":
            lines_of.pop()
    return sections


if __name__ == "__main__":
    raise SystemExit(main())
