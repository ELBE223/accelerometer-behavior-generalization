# cattle_dataset_1.py
#
# Loader for Cattle_dataset_1 (Japanese Black Beef Cow Behavior Classification Dataset).
# - Input: data/raw/Cattle_dataset_1/JapaneseBlackBeefData/cow<n>.csv, one file per cow,
#   continuous 25 Hz recording in g (ReadMe.md).
# - Time: TimeStamp_UNIX (ms). Segments start after gaps, where time goes backwards, and at
#   repeated time stamps (D04).
# - Labels: column Label as given; empty = no video (BLN in the ReadMe), kept as unlabeled.

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from loaders.common import native_hz, pipeline_settings, segment_numbers, segments_table

DATASET = "Cattle_dataset_1"
DATA_DIR = "JapaneseBlackBeefData"
COLUMNS = ["TimeStamp_UNIX", "AccX", "AccY", "AccZ", "Label"]


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    hz = native_hz(DATASET)
    gap_factor = pipeline_settings()["gap_factor"]
    files = sorted(p for p in (raw_dir / DATA_DIR).glob("cow*.csv") if not p.name.startswith("._"))
    if not files:
        raise FileNotFoundError(f"No cow*.csv files in {raw_dir / DATA_DIR}")

    parts: list[pd.DataFrame] = []
    sources: dict[int, str] = {}
    notes: list[str] = []
    next_segment = 0

    for path in files:
        df = pd.read_csv(path, usecols=COLUMNS)
        n_read = len(df)
        df = df.dropna(subset=["AccX", "AccY", "AccZ", "TimeStamp_UNIX"]).reset_index(drop=True)

        t = df["TimeStamp_UNIX"].to_numpy(dtype="float64") / 1000.0
        numbers, breaks = segment_numbers(t, 1.0 / hz, gap_factor)
        segment_id = numbers + next_segment
        next_segment = int(segment_id.max()) + 1
        start = pd.Series(t).groupby(segment_id).transform("first").to_numpy()

        label = df["Label"].astype("string").str.strip()
        part = pd.DataFrame({
            "individual_id": path.stem,
            "segment_id": segment_id,
            "time_s": t - start,
            "x": df["AccX"].astype("float32"),
            "y": df["AccY"].astype("float32"),
            "z": df["AccZ"].astype("float32"),
            "label": label.where(label != "", None),
            "timestamp": pd.to_datetime(df["TimeStamp_UNIX"], unit="ms", utc=True),
        })
        parts.append(part)
        sources.update({int(s): f"{DATA_DIR}/{path.name}" for s in np.unique(segment_id)})
        notes.append(
            f"{path.name}: {n_read:,} rows, {n_read - len(df):,} without acceleration or time dropped, "
            f"{int(numbers.max()) + 1} segments (breaks: " + ", ".join(f"{k} {v}" for k, v in breaks.items()) + ")"
        )

    samples = pd.concat(parts, ignore_index=True)
    segments = segments_table(samples, hz, sources)
    return samples, segments, notes
