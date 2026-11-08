# hedgehog_dataset_1.py
#
# Loader for Hedgehog_dataset_1 (Cibis MSc thesis); burst rules in loaders/bursts.py.
# - Input: data/raw/Hedgehog_dataset_1/Data_Hedgehog_Raw/Hedgehog.xlsx, sheet "final".
# - Columns used: Name (hedgehog; tags were moved between animals), ID (tag; a change starts
#   a new burst), Datum (burst start), X, Y, Z (raw counts), Verhalten (original label).
# - Bursts of up to 264 samples at 100 Hz; many bursts in the file are shorter.

from __future__ import annotations

from pathlib import Path

import pandas as pd

from loaders.bursts import burst_length, burst_samples, read_excel
from loaders.common import native_hz

DATASET = "Hedgehog_dataset_1"
XLSX = "Data_Hedgehog_Raw/Hedgehog.xlsx"
SHEET = "final"


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    df = read_excel(raw_dir / XLSX, SHEET)
    time = pd.to_datetime(df["Datum"], errors="coerce")
    tags = df.groupby("Name")["ID"].agg(lambda s: ", ".join(sorted(s.astype(str).unique())))
    notes = [f"{XLSX} [{SHEET}]: {len(df):,} rows, {int(time.isna().sum()):,} with unreadable Datum",
             "Tags per hedgehog: " + "; ".join(f"{n}: {t}" for n, t in tags.items())]
    table = pd.DataFrame({
        "individual_id": df["Name"],
        "time": time,
        "burst_key": df["ID"],
        "x_raw": df["X"], "y_raw": df["Y"], "z_raw": df["Z"],
        "label": df["Verhalten"],
        "source_file": f"{XLSX} [{SHEET}]",
    })
    samples, segments, burst_notes = burst_samples(table, native_hz(DATASET), burst_length(DATASET))
    return samples, segments, notes + burst_notes
