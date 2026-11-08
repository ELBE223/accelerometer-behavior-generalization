# raccoon_dataset_2.py
#
# Loader for Raccoon_dataset_2 (Geiger BSc thesis); burst rules in loaders/bursts.py.
# - Input: data/raw/Raccoon_dataset_2/Data_Raccoon_Raw/<name>.xlsx, sheet "merged", one
#   file per raccoon. Carlo and Emma are filled with empty rows down to the last Excel row;
#   these are dropped.
# - Columns used: Tiername (raccoon), Datum and Uhrzeit (burst start), X, Y, Z (raw counts),
#   Verhalten (original label), ID where it numbers the recordings (Carlo, Emma: one
#   value per day; a change starts a new burst). In Wilbert ID numbers the rows and is
#   not used.
# - 110-sample bursts at 33.3 Hz.

from __future__ import annotations

from pathlib import Path

import pandas as pd

from loaders.bursts import burst_length, burst_samples, date_time, read_excel
from loaders.common import native_hz

DATASET = "Raccoon_dataset_2"
DATA_DIR = "Data_Raccoon_Raw"
SHEET = "merged"


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    files = sorted(p for p in (raw_dir / DATA_DIR).glob("*.xlsx") if not p.name.startswith(("._", "~$")))
    if not files:
        raise FileNotFoundError(f"No .xlsx files in {raw_dir / DATA_DIR}")

    parts, notes = [], []
    for path in files:
        df = read_excel(path, SHEET)
        n_read = len(df)
        df = df.dropna(subset=["X", "Y", "Z"]).reset_index(drop=True)
        # A recording number repeats over whole bursts; a row number does not.
        id_is_tag = df["ID"].nunique() < len(df) / 50
        time = date_time(df["Datum"], df["Uhrzeit"])
        notes.append(f"{path.name}: {n_read:,} rows, {n_read - len(df):,} without acceleration dropped, "
                     f"ID {'used as recording number' if id_is_tag else 'is a row number, not used'}, "
                     f"{int(time.isna().sum()):,} rows with unreadable date or time")
        part = pd.DataFrame({
            "individual_id": df["Tiername"],
            "time": time,
            "x_raw": df["X"], "y_raw": df["Y"], "z_raw": df["Z"],
            "label": df["Verhalten"],
            "source_file": f"{DATA_DIR}/{path.name} [{SHEET}]",
        })
        part["burst_key"] = df["ID"].astype("Int64").astype(str) if id_is_tag else ""
        parts.append(part)

    samples, segments, burst_notes = burst_samples(pd.concat(parts, ignore_index=True),
                                                   native_hz(DATASET), burst_length(DATASET))
    return samples, segments, burst_notes + notes
