# horse_dataset_2.py
#
# Loader for Horse_dataset_2 (Horsing Around, Kamminga et al.; original download).
# - Input: data/raw/Horse_dataset_2/original_download/extracted/*/csv/
#   subject_<n>_<name>_part_<k>.csv; 100 Hz (settings.csv of the dataset), acceleration in
#   m/s^2 (Ax, Ay, Az), converted to g (D03).
# - No time stamps: the dataset's own `segment` column (stretches of at most 10 s) defines
#   the segments; runs of consecutive rows with the same segment value form one segment.
#   Whether consecutive segments are gap-free cannot be checked, so windows do not cross them.
# - Labels: column `label` as given ("unknown" kept as a label). Parts without a label
#   column and segments without any label are left out: they cannot give labeled windows
#   and hold most of the 28 GB.

from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd

from loaders.common import GRAVITY, native_hz, segments_table

DATASET = "Horse_dataset_2"
CSV_GLOB = "original_download/extracted/*/csv/subject_*_part_*.csv"
NAME_PATTERN = re.compile(r"subject_(\d+)_(.+)_part_(\d+)\.csv$")
COLUMNS = ["Ax", "Ay", "Az", "label", "segment"]


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    hz = native_hz(DATASET)
    files = sorted(p for p in raw_dir.glob(CSV_GLOB) if not p.name.startswith("._"))
    if not files:
        raise FileNotFoundError(f"No {CSV_GLOB} in {raw_dir} (run 01_Preprocessing/prepare_raw_data.py)")

    parts: list[pd.DataFrame] = []
    sources: dict[int, str] = {}
    notes: list[str] = []
    skipped_parts = []
    next_segment = 0
    n_mixed = 0

    for path in files:
        m = NAME_PATTERN.search(path.name)
        if not m:
            notes.append(f"{path.name}: name not recognized, skipped")
            continue
        header = pd.read_csv(path, nrows=0).columns
        if "label" not in header:
            skipped_parts.append(path.name)
            continue

        # label as text: in parts with long unlabeled stretches pandas otherwise guesses mixed types.
        df = pd.read_csv(path, usecols=COLUMNS, dtype={"label": "string"})
        n_read = len(df)
        df = df.dropna(subset=["Ax", "Ay", "Az", "segment"]).reset_index(drop=True)
        label = df["label"].astype("string").str.strip()
        label = label.where(label != "", None)

        # Runs of the same segment value, numbered within this file.
        run = np.concatenate([[0], np.cumsum(df["segment"].to_numpy()[1:] != df["segment"].to_numpy()[:-1])])
        labeled_runs = pd.Series(label.notna().to_numpy()).groupby(run).transform("any").to_numpy()
        keep = labeled_runs
        n_mixed += int(pd.Series(label.fillna("(none)").to_numpy()[keep]).groupby(run[keep]).nunique().gt(1).sum())

        run_kept = run[keep]
        _, segment_local = np.unique(run_kept, return_inverse=True)
        segment_id = segment_local + next_segment
        if len(segment_id):
            next_segment = int(segment_id.max()) + 1
        position = pd.Series(np.ones(len(run_kept))).groupby(segment_id).cumsum().to_numpy() - 1

        acc = df.loc[keep, ["Ax", "Ay", "Az"]].to_numpy(dtype="float64") / GRAVITY
        parts.append(pd.DataFrame({
            "individual_id": m.group(2),
            "segment_id": segment_id,
            "time_s": position / hz,
            "x": acc[:, 0].astype("float32"),
            "y": acc[:, 1].astype("float32"),
            "z": acc[:, 2].astype("float32"),
            "label": label[keep].to_numpy(),
            "timestamp": pd.NaT,
        }))
        sources.update({int(s): path.name for s in np.unique(segment_id)})
        notes.append(f"{path.name}: {n_read:,} rows, {int(keep.sum()):,} in segments with labels, "
                     f"{len(np.unique(run_kept)):,} of {len(np.unique(run)):,} segments kept")

    notes.insert(0, f"{len(skipped_parts)} parts without a label column left out")
    notes.insert(1, f"Segments with more than one label (incl. unlabeled rows): {n_mixed:,}")
    samples = pd.concat(parts, ignore_index=True)
    samples["timestamp"] = pd.to_datetime(samples["timestamp"], utc=True)
    segments = segments_table(samples, hz, sources)
    return samples, segments, notes
