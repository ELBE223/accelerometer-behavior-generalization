# giraffe_dataset_1.py
#
# Loader for Giraffe_dataset_1 (Brandes MSc thesis); burst rules in loaders/bursts.py.
# - Input: data/raw/Giraffe_dataset_1/Data_Giraffe_Raw/Giraffe.xlsx, first sheet
#   (e-obs_all_beh-values-adjusted).
# - Columns used: animal, tag_day (a change starts a new burst), date and time_s (burst
#   start), time_ss (time of each sample), x, y, z (raw counts), cat_code and beh_code.
# - Label: "<cat_code>/<beh_code>" (e.g. "STA/1St_Gu"). cat_code is the category of
#   beh_code, but two beh_codes occur under two categories, and the thesis mapped
#   cat_code and split STA by beh_code; both codes are kept for the behavior mapping.
# - 82-sample bursts; rate 33.33 Hz from the sample times (sensor_settings.csv).

from __future__ import annotations

from pathlib import Path

import pandas as pd

from loaders.bursts import burst_length, burst_samples, date_time, read_excel
from loaders.common import native_hz

DATASET = "Giraffe_dataset_1"
XLSX = "Data_Giraffe_Raw/Giraffe.xlsx"


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    df = read_excel(raw_dir / XLSX, 0)
    pairs = (df.groupby("beh_code")["cat_code"].agg(lambda s: "/".join(sorted(s.dropna().astype(str).unique())))
             .sort_index())
    notes = [f"{XLSX}: {len(df):,} rows",
             "beh_code -> cat_code: " + ", ".join(f"{b} {c}" for b, c in pairs.items())]
    several = pairs[pairs.str.contains("/")]
    if len(several):
        notes.append("beh_code with more than one cat_code: " + ", ".join(several.index))

    table = pd.DataFrame({
        "individual_id": df["animal"],
        "time": date_time(df["date"], df["time_s"]),
        "sample_time": date_time(df["date"], df["time_ss"]),
        "burst_key": df["tag_day"],
        "x_raw": df["x"], "y_raw": df["y"], "z_raw": df["z"],
        "label": df["cat_code"].astype("string").str.strip().str.cat(df["beh_code"].astype("string").str.strip(), sep="/"),
        "source_file": XLSX,
    })
    samples, segments, burst_notes = burst_samples(table, native_hz(DATASET), burst_length(DATASET))
    return samples, segments, notes + burst_notes
