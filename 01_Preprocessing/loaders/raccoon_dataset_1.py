# raccoon_dataset_1.py
#
# Loader for Raccoon_dataset_1 (Mardaus MSc thesis); burst rules in loaders/bursts.py.
# - Input: data/raw/Raccoon_dataset_1/Data_Raccoon_Raw/R-Daten_3.xlsx, first sheet.
# - Columns used: Tier (raccoon), Nummer (recording number; a change starts a new burst), Datum and Zeit
#   (burst start), x, y, z (raw counts), Verhalten (original label).
# - 33.33 Hz; setting 1 had 54-sample bursts, setting 2 96-sample bursts. The setting of a
#   burst is taken from its length (more than 54 samples: setting 2).

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from loaders.bursts import burst_length, burst_samples, date_time, read_excel
from loaders.common import native_hz

DATASET = "Raccoon_dataset_1"
XLSX = "Data_Raccoon_Raw/R-Daten_3.xlsx"


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    df = read_excel(raw_dir / XLSX, 0)
    time = date_time(df["Datum"], df["Zeit"])
    notes = [f"{XLSX}: {len(df):,} rows, {int(time.isna().sum()):,} with unreadable date or time"]
    table = pd.DataFrame({
        "individual_id": df["Tier"],
        "time": time,
        "burst_key": df["Nummer"],
        "x_raw": df["x"], "y_raw": df["y"], "z_raw": df["z"],
        "label": df["Verhalten"],
        "source_file": XLSX,
    })
    samples, segments, burst_notes = burst_samples(table, native_hz(DATASET, "2"), burst_length(DATASET, None))
    short = burst_length(DATASET, "1")
    segments["setting"] = np.where(segments["n_samples"] > short, "2", "1")
    by_setting = segments["setting"].value_counts().sort_index()
    burst_notes.append("Bursts by setting (from length): " + ", ".join(f"setting {k}: {v:,}" for k, v in by_setting.items()))
    return samples, segments, notes + burst_notes
