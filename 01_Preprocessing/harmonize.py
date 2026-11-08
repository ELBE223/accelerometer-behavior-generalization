# harmonize.py
#
# Purpose:
# - Runs the loader of each dataset (01_Preprocessing/loaders/<dataset_id lower case>.py), checks the
#   harmonized format and writes it to data/processed/<dataset>/:
#   samples.parquet  one row per sample (individual, segment, time, x/y/z in g, original label)
#   segments.parquet one row per segment (native rate, length, source file, sensor setting)
# - Writes a check report to 01_Preprocessing/reports/pipeline_reports/<dataset>_harmonized.txt.
#   If a loader fails, the report holds the error, the old output of that dataset is
#   removed, and the other datasets are still processed.
#
# Usage (from the project folder, venv active):
#   python 01_Preprocessing/harmonize.py Cattle_dataset_1     # one or more datasets
#   python 01_Preprocessing/harmonize.py                      # all datasets with a loader

from __future__ import annotations

import argparse
import importlib
import sys
import time
import traceback
from pathlib import Path

import numpy as np
import pandas as pd

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))

from loaders.common import check_format  # noqa: E402

ROOT = CODE_DIR.parent
RAW_DIR = ROOT / "data" / "raw"
PROCESSED_DIR = ROOT / "data" / "processed"
REPORT_DIR = ROOT / "01_Preprocessing" / "reports" / "pipeline_reports"
WIDTH = 100


def log(msg: str) -> None:
    print(msg, flush=True)


def section(title: str) -> list[str]:
    return ["", "=" * WIDTH, title, "=" * WIDTH]


def available_loaders() -> list[str]:
    names = []
    for p in sorted((CODE_DIR / "loaders").glob("*.py")):
        # "._*" files are macOS metadata on external drives.
        if p.stem in {"__init__", "common"} or p.name.startswith("."):
            continue
        module = importlib.import_module(f"loaders.{p.stem}")
        if hasattr(module, "DATASET"):  # shared helper modules have none
            names.append(module.DATASET)
    return names


def fmt_stats(values: pd.Series) -> str:
    q = values.quantile([0, 0.5, 1])
    return f"min {q.iloc[0]:.3g}, median {q.iloc[1]:.3g}, max {q.iloc[2]:.3g}"


def report(dataset: str, samples: pd.DataFrame, segments: pd.DataFrame, notes: list[str], seconds: float) -> list[str]:
    lines = [
        f"HARMONIZATION REPORT: {dataset}",
        f"Created: {time.strftime('%Y-%m-%d %H:%M:%S')} with 01_Preprocessing/harmonize.py ({seconds:.0f} s)",
        f"Output: data/processed/{dataset}/samples.parquet, segments.parquet",
    ]
    lines += section("1. OVERVIEW")
    labeled = samples["label"].notna()
    lines += [
        f"  Samples: {len(samples):,} ({labeled.mean():.1%} labeled)",
        f"  Individuals: {samples['individual_id'].nunique()}",
        f"  Segments: {len(segments):,}; duration {fmt_stats(segments['duration_s'])} s",
        "  Native rate(s): " + ", ".join(f"{hz:g} Hz ({n:,} segments)" for hz, n in segments["native_hz"].value_counts().items()),
    ]

    lines += section("2. LOADER NOTES")
    lines += [f"  {n}" for n in notes] or ["  (none)"]

    lines += section("3. ACCELERATION (g)")
    rows = []
    for axis in "xyz":
        v = samples[axis].astype("float64")
        q = v.quantile([0.01, 0.5, 0.99])
        rows.append(f"  {axis}: min {v.min():.3f}, p1 {q.iloc[0]:.3f}, median {q.iloc[1]:.3f}, p99 {q.iloc[2]:.3f}, max {v.max():.3f}")
    lines += rows
    magnitude = np.sqrt((samples[["x", "y", "z"]].astype("float64") ** 2).sum(axis=1))
    lines.append(f"  Median vector magnitude: {magnitude.median():.3f} g (about 1 g expected)")

    lines += section("4. LABELS (original, samples)")
    counts = samples["label"].fillna("(unlabeled)").value_counts()
    lines += [f"  {k:<30} {v:>12,}  {v / len(samples):6.1%}" for k, v in counts.items()]

    lines += section("5. INDIVIDUALS")
    per_ind = samples.groupby("individual_id").agg(samples=("x", "size"), labeled=("label", lambda s: s.notna().mean()))
    seg_ind = segments.groupby("individual_id").agg(segments=("segment_id", "size"), hours=("duration_s", lambda d: d.sum() / 3600))
    table = per_ind.join(seg_ind)
    lines += [f"  {r.Index:<20} {int(r.samples):>10,} samples  {r.labeled:6.1%} labeled  {int(r.segments):>7,} segments  {r.hours:6.2f} h"
              for r in table.itertuples()]
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description="Harmonize raw datasets with their loaders.")
    parser.add_argument("datasets", nargs="*", help="Dataset IDs (default: all with a loader)")
    args = parser.parse_args()

    loaders = available_loaders()
    datasets = args.datasets or loaders
    missing = [d for d in datasets if d not in loaders]
    if missing:
        log(f"[ERROR] No loader for: {', '.join(missing)}. Loaders exist for: {', '.join(loaders)}")
        return 1

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    failed = []
    for dataset in datasets:
        start = time.time()
        log(f"[INFO] {dataset}: loading")
        report_file = REPORT_DIR / f"{dataset}_harmonized.txt"
        out_dir = PROCESSED_DIR / dataset
        try:
            module = importlib.import_module(f"loaders.{dataset.lower()}")
            samples, segments, notes = module.load(RAW_DIR / dataset)
            check_format(samples, segments)
        except Exception as exc:
            failed.append(dataset)
            # Old output would be windowed as if it were current.
            for name in ["samples.parquet", "segments.parquet"]:
                (out_dir / name).unlink(missing_ok=True)
            report_file.write_text(f"HARMONIZATION REPORT: {dataset}\nCreated: {time.strftime('%Y-%m-%d %H:%M:%S')} "
                                   f"with 01_Preprocessing/harmonize.py\n\nFAILED\n\n{traceback.format_exc()}", encoding="utf-8")
            log(f"[ERROR] {dataset}: {type(exc).__name__}: {exc} (details in {report_file.relative_to(ROOT)})")
            continue

        out_dir.mkdir(parents=True, exist_ok=True)
        samples.to_parquet(out_dir / "samples.parquet", index=False)
        segments.to_parquet(out_dir / "segments.parquet", index=False)

        lines = report(dataset, samples, segments, notes, time.time() - start)
        report_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        log(f"[OK] {dataset}: {len(samples):,} samples, {len(segments):,} segments ({time.time() - start:.0f} s)")
    if failed:
        log(f"[ERROR] Harmonization failed for: {', '.join(failed)}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
