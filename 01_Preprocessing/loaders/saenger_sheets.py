# saenger_sheets.py
#
# Shared reader for Bison_dataset_1 and Horse_dataset_1 (Saenger MSc thesis: one Excel
# file, one sheet per animal; e-obs collars, 82-sample bursts at 33.33 Hz).
# - Sheets per animal are named "<name> <tag id>[ <note>]" (e.g. "Flake 4931",
#   "Jedi 4935 nach 21.10.16"); summary sheets (GESAMT, GESAMT FERTIG, ANZAHL, ...) and
#   sheets marked "NICHT IN GESAMT" by the author are not read.
# - Columns used: Datum, Zeit (burst start), Nr (sample number in the burst, 1-82),
#   X, Y, Z (raw counts, converted to g), Code (behavior code = original label).
# - A segment (burst) ends where Datum or Zeit change or Nr does not count on by one.
# - The animal is identified by its name; sheets of the same animal (same tag id) are one
#   individual.

from __future__ import annotations

import datetime as dt
import re
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd

from loaders.common import native_hz, raw_counts_to_g, segments_table

ANIMAL_SHEET = re.compile(r"^(?P<name>[^\W\d_]+) (?P<tag>\d{4})(?: .*)?$")
EXCLUDED_MARK = "NICHT IN GESAMT"
COLUMNS = ["Datum", "Zeit", "Nr", "X", "Y", "Z", "Code"]


def read_excel(path: Path, sheets: list[str]) -> dict[str, pd.DataFrame]:
    try:
        return pd.read_excel(path, sheet_name=sheets, engine="calamine")
    except ImportError:
        return pd.read_excel(path, sheet_name=sheets)


def time_of_day(value) -> dt.time | None:
    if isinstance(value, dt.datetime):
        return value.time()
    if isinstance(value, dt.time):
        return value
    if isinstance(value, str):
        try:
            return dt.time.fromisoformat(value.strip().replace(",", "."))
        except ValueError:
            return None
    return None


def load_saenger(dataset: str, xlsx: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    hz = native_hz(dataset)
    all_sheets = pd.ExcelFile(xlsx, engine="calamine").sheet_names
    animal = {s: ANIMAL_SHEET.match(s) for s in all_sheets if EXCLUDED_MARK not in s}
    animal = {s: m for s, m in animal.items() if m}
    notes = [f"Sheets read: {', '.join(animal)}",
             f"Sheets not read: {', '.join(s for s in all_sheets if s not in animal)}"]

    frames = read_excel(xlsx, list(animal))
    names_by_tag: dict[str, str] = {}
    parts: list[pd.DataFrame] = []
    sources: dict[int, str] = {}
    next_segment = 0

    for sheet, m in animal.items():
        name, tag = m.group("name"), m.group("tag")
        if names_by_tag.setdefault(tag, name) != name:
            raise ValueError(f"Tag {tag} has two names: {names_by_tag[tag]}, {name}")
        df = frames[sheet]
        missing = [c for c in COLUMNS if c not in df.columns]
        if missing:
            raise ValueError(f"Sheet {sheet}: missing columns {missing}")
        n_read = len(df)
        df = df.dropna(subset=["Datum", "Zeit", "Nr", "X", "Y", "Z"]).reset_index(drop=True)

        clock = df["Zeit"].map(time_of_day)
        bad_time = clock.isna()
        df, clock = df[~bad_time].reset_index(drop=True), clock[~bad_time].reset_index(drop=True)
        start = pd.to_datetime(df["Datum"]).dt.normalize() + pd.to_timedelta(
            clock.map(lambda t: t.hour * 3600 + t.minute * 60 + t.second + t.microsecond / 1e6), unit="s")

        nr = df["Nr"].to_numpy(dtype="int64")
        new_burst = np.ones(len(df), dtype=bool)
        new_burst[1:] = (start.to_numpy()[1:] != start.to_numpy()[:-1]) | (nr[1:] != nr[:-1] + 1)
        segment_id = np.cumsum(new_burst) - 1 + next_segment
        next_segment = int(segment_id.max()) + 1 if len(df) else next_segment
        position = pd.Series(np.ones(len(df))).groupby(segment_id).cumsum().to_numpy() - 1

        code = df["Code"].astype("string").str.strip()
        lengths = Counter(pd.Series(segment_id).value_counts().to_numpy().tolist())
        parts.append(pd.DataFrame({
            "individual_id": name,
            "segment_id": segment_id,
            "time_s": position / hz,
            "x": raw_counts_to_g(df["X"]).astype("float32"),
            "y": raw_counts_to_g(df["Y"]).astype("float32"),
            "z": raw_counts_to_g(df["Z"]).astype("float32"),
            "label": code.where(code != "", None).to_numpy(),
            "timestamp": start.dt.tz_localize("UTC").to_numpy(),
        }))
        sources.update({int(s): f"{xlsx.name} [{sheet}]" for s in np.unique(segment_id)})
        top = ", ".join(f"{k} samples: {v:,}" for k, v in lengths.most_common(4))
        notes.append(f"[{sheet}] {n_read:,} rows, {n_read - len(df):,} without time or acceleration dropped "
                     f"({int(bad_time.sum()):,} with unreadable Zeit), {len(np.unique(segment_id)):,} bursts; "
                     f"burst lengths: {top}")

    samples = pd.concat(parts, ignore_index=True)
    samples["timestamp"] = pd.to_datetime(samples["timestamp"], utc=True)
    segments = segments_table(samples, hz, sources)
    return samples, segments, notes
