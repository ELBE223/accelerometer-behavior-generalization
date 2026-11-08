# fox_dataset_1.py
#
# Loader for Fox_dataset_1 (Giese MSc thesis, captive foxes); burst rules in loaders/bursts.py.
# - Input: data/raw/Fox_dataset_1/Data_Fox_Raw/<name>_ACC_master.xlsx, sheet "data"
#   (sheet "qa" is the summary of the merge).
# - Columns used: Tier (fox), Datum and Uhrzeit (burst start or, in some recordings, the
#   time of each sample), X, Y, Z (raw counts), Verhalten_ueberkategorie (original label),
#   Verhalten_unterkategorie (name of the recording file, e.g. "34uFka.13-ACC"; a change
#   starts a new burst).
# - 110-sample bursts at 33.33 Hz.

from __future__ import annotations

from pathlib import Path

import pandas as pd

from loaders.bursts import burst_length, burst_samples, date_time, read_excel
from loaders.common import native_hz

DATASET = "Fox_dataset_1"
DATA_DIR = "Data_Fox_Raw"
SHEET = "data"


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    files = sorted(p for p in (raw_dir / DATA_DIR).glob("*_ACC_master.xlsx") if not p.name.startswith("._"))
    if not files:
        raise FileNotFoundError(f"No '*_ACC_master.xlsx' files in {raw_dir / DATA_DIR}")

    parts, notes = [], []
    for path in files:
        df = read_excel(path, SHEET)
        time = date_time(df["Datum"], df["Uhrzeit"])
        names = sorted(df["Tier"].dropna().astype(str).unique())
        notes.append(f"{path.name}: {len(df):,} rows, fox {', '.join(names)}, "
                     f"{df['Verhalten_unterkategorie'].nunique()} recording files, "
                     f"{int(time.isna().sum()):,} rows with unreadable date or time")
        parts.append(pd.DataFrame({
            "individual_id": df["Tier"],
            "time": time,
            "sample_time": time,
            "burst_key": df["Verhalten_unterkategorie"],
            "x_raw": df["X"], "y_raw": df["Y"], "z_raw": df["Z"],
            "label": df["Verhalten_ueberkategorie"],
            "source_file": f"{DATA_DIR}/{path.name} [{SHEET}]",
        }))

    table = pd.concat(parts, ignore_index=True)
    samples, segments, burst_notes = burst_samples(table, native_hz(DATASET), burst_length(DATASET))
    return samples, segments, burst_notes + notes
