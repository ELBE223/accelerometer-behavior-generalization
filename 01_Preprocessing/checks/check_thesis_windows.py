# check_thesis_windows.py
#
# Purpose:
# - Read-only check of the windowed thesis data (Data_Processed/data_processed_final),
#   on which the thesis models were trained.
# - Per dataset: number of windows, window length, metadata columns, the split unit
#   the thesis models used (same rule as choose_split_var in the thesis model
#   scripts) with its values and behavior counts, value range of the signal, and
#   windows whose signal occurs more than once (e.g. copied from summary sheets).
#
# Usage (from the project folder, venv active):
#   python 01_Preprocessing/checks/check_thesis_windows.py
#   python 01_Preprocessing/checks/check_thesis_windows.py --thesis-base "/Volumes/Z Slim/11_05_2026_Data_Analysis"
#
# Output: 01_Preprocessing/reports/thesis_checks/thesis_windows_check.txt

from __future__ import annotations

import argparse
import re
import time
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT_FILE = ROOT / "01_Preprocessing" / "reports" / "thesis_checks" / "thesis_windows_check.txt"
DEFAULT_THESIS_BASE = Path("/Volumes/Z Slim/11_05_2026_Data_Analysis")

# Same order as choose_split_var in the thesis model scripts.
SPLIT_CANDIDATES = ["individual_key", "individual_id", "individual_name", "name", "subject_key", "source_file"]
BEHAVIOR_CANDIDATES = ["behavior", "behavior_en", "main_class"]
MAX_VALUES = 40
MAX_COUNTED_VALUES = 12
WIDTH = 100


def log(msg: str) -> None:
    print(msg, flush=True)


def section(title: str) -> list[str]:
    return ["", "=" * WIDTH, title, "=" * WIDTH]


def clean(series: pd.Series) -> pd.Series:
    return series.fillna("").astype(str).str.strip()


def choose_split_var(df: pd.DataFrame) -> str | None:
    for col in SPLIT_CANDIDATES:
        if col in df.columns:
            vals = clean(df[col])
            if vals[vals != ""].nunique() >= 2:
                return col
    return None


def behavior_column(df: pd.DataFrame) -> pd.Series:
    # As in add_analysis_columns of the thesis model scripts.
    out = pd.Series("", index=df.index)
    for col in BEHAVIOR_CANDIDATES:
        if col in df.columns:
            out = out.mask(out == "", clean(df[col]))
    return out.str.capitalize()


def signal_columns(df: pd.DataFrame) -> list[str]:
    cols = []
    for axis in "xyz":
        cols += sorted(c for c in df.columns if re.fullmatch(rf"{axis}_\d{{3}}", str(c)))
    return cols


def check_file(path: Path) -> tuple[list[str], pd.DataFrame]:
    df = pd.read_parquet(path)
    sig = signal_columns(df)
    meta = [c for c in df.columns if c not in sig]
    lines = [f"Windows: {len(df):,}   Signal columns: {len(sig)} ({len(sig) // 3} samples per axis)   Other columns: {len(meta)}"]

    lines += ["", "Other columns (distinct values, first values; counts for up to 12 values):"]
    for col in meta:
        vals = df[col].dropna()
        if 1 < vals.nunique() <= MAX_COUNTED_VALUES:
            first = ", ".join(f"{k} ({n:,})" for k, n in vals.value_counts().items())
        else:
            first = ", ".join(str(v)[:25] for v in vals.unique()[:5])
        lines.append(f"  {str(col)[:35]:<35} {str(df[col].dtype):<16} {vals.nunique():>8,}  {first}")

    split_var = choose_split_var(df)
    lines += ["", f"Split unit chosen by the thesis rule: {split_var}"]
    behavior = behavior_column(df)
    if split_var is not None:
        unit = clean(df[split_var])
        counts = pd.crosstab(unit.rename(split_var), behavior.rename("behavior"))
        counts["total"] = counts.sum(axis=1)
        lines.append(f"Distinct split units: {unit.nunique():,}")
        lines += ["", f"Windows per split unit and behavior (first {MAX_VALUES} units):", ""]
        lines += ["  " + ln for ln in counts.sort_values("total", ascending=False).head(MAX_VALUES).to_string().splitlines()]

    if sig:
        values = df[sig].to_numpy(dtype=float)
        lines += ["", f"Signal values: min {np.nanmin(values):.4g}, p1 {np.nanpercentile(values, 1):.4g}, "
                      f"median {np.nanmedian(values):.4g}, p99 {np.nanpercentile(values, 99):.4g}, max {np.nanmax(values):.4g}"]

    hashes = pd.util.hash_pandas_object(df[sig], index=False) if sig else pd.Series(dtype="uint64")
    dup = hashes.duplicated(keep=False)
    lines += ["", f"Windows whose signal occurs more than once: {int(dup.sum()):,} of {len(df):,}"]
    if dup.any() and split_var is not None:
        groups = pd.DataFrame({"hash": hashes[dup], "unit": clean(df.loc[dup, split_var])})
        pattern = groups.groupby("hash")["unit"].apply(lambda u: " + ".join(sorted(u))).value_counts().head(15)
        lines += ["Split units that share identical windows (most frequent combinations):"]
        lines += [f"  {n:>8,}x  {combo[:80]}" for combo, n in pattern.items()]

    summary = pd.DataFrame({"dataset": path.stem, "hash": hashes})
    return lines, summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Check the windowed thesis data.")
    parser.add_argument("--thesis-base", type=Path, default=DEFAULT_THESIS_BASE)
    args = parser.parse_args()

    final_dir = args.thesis_base / "Data_Processed" / "data_processed_final"
    files = sorted(p for p in final_dir.glob("*.parquet") if not p.name.startswith("._"))
    if not files:
        log(f"[ERROR] No parquet files in {final_dir}")
        return 1

    report = [
        "THESIS WINDOW CHECK",
        f"Created: {time.strftime('%Y-%m-%d %H:%M:%S')} with 01_Preprocessing/checks/check_thesis_windows.py",
        f"Input: {final_dir}",
    ]
    all_hashes = []
    for path in files:
        log(f"[INFO] Reading {path.name}")
        try:
            lines, hashes = check_file(path)
        except Exception as exc:
            lines, hashes = [f"Could not read: {type(exc).__name__}: {exc}"], None
        report += section(path.stem) + lines
        if hashes is not None:
            all_hashes.append(hashes)

    if all_hashes:
        both = pd.concat(all_hashes, ignore_index=True)
        per_hash = both.groupby("hash")["dataset"].nunique()
        shared = both[both["hash"].isin(per_hash[per_hash > 1].index)]
        report += section("WINDOWS SHARED BETWEEN DATASETS")
        report.append(f"Windows with a signal that also occurs in another dataset: {len(shared):,}")
        if not shared.empty:
            report += ["  " + ln for ln in shared["dataset"].value_counts().to_string().splitlines()]

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text("\n".join(report) + "\n", encoding="utf-8")
    log(f"[OK] {OUT_FILE.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
