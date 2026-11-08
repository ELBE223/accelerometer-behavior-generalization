# common.py
#
# Purpose:
# - Shared helpers for the dataset loaders in 01_Preprocessing/loaders/<dataset_id lower case>.py.
# - Defines the harmonized format that every loader returns:
#   samples: one row per sample, in time order within each segment
#   segments: one row per segment (a stretch of samples without interruption: one
#             burst, or a gap-free part of a continuous recording; D04)
#
# A loader module provides
#   DATASET = "<dataset_id>"
#   def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]
# returning samples, segments and notes for the harmonization report.

from __future__ import annotations

import csv
import json
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
SENSOR_SETTINGS = ROOT / "00_Documentation" / "sensor_settings.csv"
PIPELINE_SETTINGS = ROOT / "config" / "pipeline_settings.json"

# x, y, z in g; label is the original label (None = unlabeled); time_s counts from the
# first sample of the segment; timestamp is the absolute time where the data have it.
SAMPLE_COLUMNS = ["individual_id", "segment_id", "time_s", "x", "y", "z", "label", "timestamp"]
SEGMENT_COLUMNS = ["segment_id", "individual_id", "native_hz", "n_samples", "duration_s",
                   "start_timestamp", "source_file", "setting"]

GRAVITY = 9.80665


def pipeline_settings() -> dict:
    return json.loads(PIPELINE_SETTINGS.read_text(encoding="utf-8"))


def sensor_settings(dataset: str) -> list[dict]:
    with SENSOR_SETTINGS.open(newline="", encoding="utf-8") as fh:
        rows = [r for r in csv.DictReader(fh) if r["dataset_id"] == dataset]
    if not rows:
        raise ValueError(f"No entry for {dataset} in {SENSOR_SETTINGS.name}")
    return rows


def native_hz(dataset: str, setting: str = "1") -> float:
    for row in sensor_settings(dataset):
        if row["setting"] == str(setting):
            return float(row["native_hz"])
    raise ValueError(f"No setting {setting} for {dataset} in {SENSOR_SETTINGS.name}")


def raw_counts_to_g(values) -> np.ndarray:
    # 12-bit e-obs counts, +/-4 g (D03).
    return (np.asarray(values, dtype="float64") - 2048.0) / 512.0


def segment_numbers(time_s: np.ndarray, interval_s: float, gap_factor: float) -> tuple[np.ndarray, dict]:
    # Segment number per sample (0, 1, ...) for one continuous recording in file order:
    # a new segment starts after a gap, where time goes backwards, or at a repeated time.
    step = np.diff(np.asarray(time_s, dtype="float64"))
    gap = step > gap_factor * interval_s
    backwards = step < 0
    repeated = step == 0
    breaks = gap | backwards | repeated
    numbers = np.concatenate([[0], np.cumsum(breaks)])
    counts = {"gaps": int(gap.sum()), "time backwards": int(backwards.sum()), "repeated time": int(repeated.sum())}
    # Gap sizes in sampling intervals, to judge how much the gap rule splits.
    size = step[gap] / interval_s
    counts["gaps of 2 intervals (1 missing sample)"] = int((size <= 2.5).sum())
    counts["gaps of 3-5 intervals"] = int(((size > 2.5) & (size <= 5.5)).sum())
    counts["gaps of 6-25 intervals"] = int(((size > 5.5) & (size <= 25.5)).sum())
    counts["gaps of more than 25 intervals"] = int((size > 25.5).sum())
    return numbers, counts


def segments_table(samples: pd.DataFrame, hz_by_segment: dict | float, source_by_segment: dict,
                   setting_by_segment: dict | str = "1") -> pd.DataFrame:
    grouped = samples.groupby("segment_id", sort=True)
    seg = grouped.agg(individual_id=("individual_id", "first"), n_samples=("x", "size"),
                      start_timestamp=("timestamp", "first")).reset_index()
    seg["native_hz"] = seg["segment_id"].map(hz_by_segment) if isinstance(hz_by_segment, dict) else float(hz_by_segment)
    seg["duration_s"] = seg["n_samples"] / seg["native_hz"]
    seg["source_file"] = seg["segment_id"].map(source_by_segment)
    seg["setting"] = seg["segment_id"].map(setting_by_segment) if isinstance(setting_by_segment, dict) else str(setting_by_segment)
    return seg[SEGMENT_COLUMNS]


def check_format(samples: pd.DataFrame, segments: pd.DataFrame) -> None:
    missing = [c for c in SAMPLE_COLUMNS if c not in samples.columns]
    if missing:
        raise ValueError(f"samples lack columns: {missing}")
    missing = [c for c in SEGMENT_COLUMNS if c not in segments.columns]
    if missing:
        raise ValueError(f"segments lack columns: {missing}")
    if samples[["x", "y", "z"]].isna().any().any():
        raise ValueError("samples contain missing acceleration values")
    if not samples["segment_id"].is_monotonic_increasing:
        raise ValueError("samples are not ordered by segment")
    if set(samples["segment_id"].unique()) != set(segments["segment_id"]):
        raise ValueError("segments do not match the samples")
    per_segment = samples.groupby("segment_id")["individual_id"].nunique()
    if (per_segment > 1).any():
        raise ValueError("a segment holds more than one individual")
