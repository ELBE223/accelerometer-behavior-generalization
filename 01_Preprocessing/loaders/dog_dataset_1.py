# dog_dataset_1.py
#
# Loader for Dog_dataset_1 (Szangolies BSc thesis); burst rules in loaders/bursts.py.
# - Input: data/raw/Dog_dataset_1/Data_Dog_Raw/<name> Achsen.txt, one file per dog (R
#   export: the header has one field less than the rows, the first field is the row name).
# - Columns used: Burst or Nummer (recording number, shared by dogs recorded at the same
#   time; a change starts a new burst), Datum and Zeit (burst start), x, y, z (raw
#   counts), Verhalten (original label), Tier (dog code). The dog is named after the file.
# - Rows with another dog's code than the rest of the file (Emi's file holds rows coded
#   HEL) are left out (D20); the notes compare them with the file of that dog.
# - 110-sample bursts at 33.333 Hz (setting A of the thesis, pp. 7-8; sensor_settings.csv).
# - Some clock times in Lumpi's file are written HH.MM:SS (e.g. 10.38:45); they are read
#   as HH:MM:SS (D19). The repaired rows and examples are in the notes.

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from loaders.bursts import burst_length, burst_samples, to_date, to_seconds_of_day
from loaders.common import native_hz

DATASET = "Dog_dataset_1"
DATA_DIR = "Data_Dog_Raw"
SUFFIX = " Achsen"
DOTTED_HOUR = r"^\s*(\d{1,2})\.(\d{2}):(\d{2})\s*$"


def repair_clock(clock: pd.Series) -> tuple[pd.Series, list[str]]:
    text = clock.astype(str)
    dotted = text.str.match(DOTTED_HOUR)
    notes = []
    if dotted.any():
        examples = ", ".join(text[dotted].unique()[:3])
        notes.append(f"  clock times HH.MM:SS read as HH:MM:SS: {int(dotted.sum()):,} rows (e.g. {examples})")
    return text.str.replace(DOTTED_HOUR, r"\1:\2:\3", regex=True), notes


def read_file(path: Path) -> tuple[pd.DataFrame, list[str]]:
    df = pd.read_csv(path, encoding="utf-8-sig")
    tag = "Burst" if "Burst" in df.columns else "Nummer"
    clock, notes = repair_clock(df["Zeit"])
    out = pd.DataFrame({
        "individual_id": path.stem.removesuffix(SUFFIX),
        "code": df["Tier"].astype(str).str.strip(),
        "time": to_date(df["Datum"]) + pd.to_timedelta(to_seconds_of_day(clock), unit="s"),
        "burst_key": df[tag],
        "x_raw": df["x"], "y_raw": df["y"], "z_raw": df["z"],
        "label": df["Verhalten"],
        "source_file": f"{DATA_DIR}/{path.name}",
    })
    codes = out["code"].value_counts()
    notes.insert(0, f"{path.name}: {len(df):,} rows, Tier code " + ", ".join(f"{c} ({n:,} rows)" for c, n in codes.items())
                 + f", {tag} {', '.join(map(str, sorted(df[tag].dropna().unique())))}")
    return out, notes


def compare_bursts(rows: pd.DataFrame, other: pd.DataFrame) -> str:
    # Rows with another dog's code against that dog's own file, burst by burst (same time).
    other_bursts = dict(list(other.groupby("time")))
    n_bursts = matched = identical = same_label = 0
    differences = []
    for t, burst in rows.groupby("time"):
        n_bursts += 1
        match = other_bursts.get(t)
        if match is None:
            continue
        matched += 1
        n = min(len(burst), len(match))
        a = burst[["x_raw", "y_raw", "z_raw"]].to_numpy(dtype=float)[:n]
        b = match[["x_raw", "y_raw", "z_raw"]].to_numpy(dtype=float)[:n]
        identical += int(len(burst) == len(match) and np.array_equal(a, b))
        differences.append(np.abs(a - b).mean())
        same_label += int(set(burst["label"]) == set(match["label"]))
    text = f"{n_bursts:,} bursts, {matched:,} at a time that also occurs in {other['source_file'].iloc[0]}"
    if matched:
        text += (f"; of these {identical:,} with identical values, {same_label:,} with the same label, "
                 f"median mean |difference| {np.median(differences):.1f} counts")
    return text


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    files = sorted(p for p in (raw_dir / DATA_DIR).glob(f"*{SUFFIX}.txt") if not p.name.startswith("._"))
    if not files:
        raise FileNotFoundError(f"No '*{SUFFIX}.txt' files in {raw_dir / DATA_DIR}")

    tables, notes = [], []
    for path in files:
        table, file_notes = read_file(path)
        tables.append(table)
        notes += file_notes
    main_code = {t["individual_id"].iloc[0]: t["code"].value_counts().index[0] for t in tables}
    file_of_code = {code: name for name, code in main_code.items()}

    parts = []
    for table in tables:
        name = table["individual_id"].iloc[0]
        foreign = table["code"] != main_code[name]
        for code in table.loc[foreign, "code"].unique():
            rows = table[table["code"] == code]
            other = next((t for t in tables if t["individual_id"].iloc[0] == file_of_code.get(code)), None)
            where = compare_bursts(rows, other) if other is not None else "no file of that dog"
            labels = ", ".join(f"{k} ({v:,})" for k, v in rows["label"].value_counts().items())
            notes.append(f"Left out: {len(rows):,} rows coded {code} in the file of {name} "
                         f"({rows['time'].min()} to {rows['time'].max()}; labels {labels}); {where}")
        parts.append(table[~foreign].drop(columns="code"))

    samples, segments, burst_notes = burst_samples(pd.concat(parts, ignore_index=True),
                                                   native_hz(DATASET), burst_length(DATASET))
    return samples, segments, burst_notes + notes
