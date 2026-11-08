# bursts.py
#
# Shared helper for burst data in table form (e-obs exports: one row per sample, in
# recording order; the time is the burst start or, in some files, the time of each sample).
# - Input table, one row per sample in file order, with the columns
#     individual_id, time (datetime), x_raw, y_raw, z_raw (raw counts), label (original
#     label, missing = unlabeled), source_file
#   and optionally burst_key (e.g. tag or recording file; a change starts a new burst),
#   sample_time (datetime of each sample, used as timestamp and to check the sampling
#   rate) and setting (sensor setting per row).
# - A segment (burst) starts where individual_id, source_file or burst_key change, where
#   the time goes backwards, or where it jumps by more than NEW_BURST_AFTER_S. The time
#   step inside a burst is 0 (burst start in every row) or one sample interval (time per
#   sample, also when rounded to whole seconds); between bursts it is several seconds.
# - A run longer than the burst length is split into pieces of that length (two bursts
#   with the same start time), so no window crosses two bursts.
# - Bursts with exactly the same acceleration values as an earlier burst are copies:
#   with the same labels only the first is kept, with different labels all copies are
#   dropped (the right label is unknown).
# - Raw counts are converted to g (D03); time_s counts samples at the native rate.

from __future__ import annotations

import datetime as dt
import hashlib
from collections import Counter

import numpy as np
import pandas as pd

from loaders.common import raw_counts_to_g, segments_table, sensor_settings

REQUIRED = ["individual_id", "time", "x_raw", "y_raw", "z_raw", "label", "source_file"]
NEW_BURST_AFTER_S = 1.0


def burst_samples(table: pd.DataFrame, hz: float, samples_per_burst: int | None,
                  setting: str = "1") -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    missing = [c for c in REQUIRED if c not in table.columns]
    if missing:
        raise ValueError(f"burst table lacks columns: {missing}")
    n_read = len(table)
    table = table.dropna(subset=["individual_id", "time", "x_raw", "y_raw", "z_raw"]).reset_index(drop=True)
    n = len(table)
    notes = [f"{n_read:,} rows; {n_read - n:,} without individual, time or acceleration dropped"]

    # Burst starts.
    new = np.zeros(n, dtype=bool)
    if n:
        new[0] = True
    for key in ["individual_id", "source_file"]:
        values = table[key].astype(str).to_numpy()
        new[1:] |= values[1:] != values[:-1]
    step = np.diff(table["time"].to_numpy().astype("datetime64[ns]").astype("int64")) / 1e9
    new[1:] |= (step < 0) | (step > NEW_BURST_AFTER_S)
    if "burst_key" in table.columns:
        values = table["burst_key"].astype(str).to_numpy()
        by_key = np.r_[False, values[1:] != values[:-1]] & ~new
        new |= by_key
        # A key change without a new time inside a burst would point to a wrong key value.
        notes.append(f"Burst starts from a change of the key column alone (same time): {int(by_key.sum()):,}")
    run = np.cumsum(new) - 1
    position = np.arange(n) - np.flatnonzero(new)[run] if n else np.zeros(0, dtype=int)

    run_length = np.bincount(run) if n else np.zeros(0, dtype=int)
    notes.append("Rows per burst before splitting (rows: bursts): " + top_counts(run_length))
    origin = table["source_file"].astype(str).to_numpy()
    if "burst_key" in table.columns:
        origin = origin + " " + table["burst_key"].astype(str).to_numpy()
    if samples_per_burst:
        long_runs = run_length > samples_per_burst
        uneven = long_runs & (run_length % samples_per_burst != 0)
        notes.append(f"Runs longer than {samples_per_burst} samples (bursts with the same time) split into "
                     f"{samples_per_burst}-sample pieces: {int(long_runs.sum()):,}; of these not a multiple of "
                     f"{samples_per_burst} (piece borders uncertain): {int(uneven.sum()):,}")
        notes += long_run_details(table, origin, run, np.flatnonzero(long_runs))
        piece = position // samples_per_burst
        new = np.zeros(n, dtype=bool)
        if n:
            new[0] = True
            new[1:] = (run[1:] != run[:-1]) | (piece[1:] != piece[:-1])
        run = np.cumsum(new) - 1
        position = position % samples_per_burst

    if "sample_time" in table.columns:
        notes.append(sampling_rate_note(table["sample_time"], run))

    raw = table[["x_raw", "y_raw", "z_raw"]].to_numpy(dtype="float64")
    label = clean_labels(table["label"])
    keep, dup_notes = drop_copies(raw, label, table["individual_id"].astype(str).to_numpy(), origin, run)
    notes += dup_notes

    table, raw, label, position = table[keep].reset_index(drop=True), raw[keep], label[keep], position[keep]
    _, segment_id = np.unique(run[keep], return_inverse=True)
    stamp = table["sample_time"] if "sample_time" in table.columns else table["time"]
    samples = pd.DataFrame({
        "individual_id": table["individual_id"].astype(str).to_numpy(),
        "segment_id": segment_id,
        "time_s": position / hz,
        "x": raw_counts_to_g(raw[:, 0]).astype("float32"),
        "y": raw_counts_to_g(raw[:, 1]).astype("float32"),
        "z": raw_counts_to_g(raw[:, 2]).astype("float32"),
        "label": label,
        "timestamp": pd.to_datetime(stamp).dt.tz_localize("UTC").to_numpy(),
    })
    samples["timestamp"] = pd.to_datetime(samples["timestamp"], utc=True)
    first = np.flatnonzero(np.r_[True, segment_id[1:] != segment_id[:-1]]) if len(segment_id) else np.zeros(0, dtype=int)
    sources = dict(zip(segment_id[first], table["source_file"].astype(str).to_numpy()[first]))
    settings = (dict(zip(segment_id[first], table["setting"].astype(str).to_numpy()[first]))
                if "setting" in table.columns else setting)
    segments = segments_table(samples, hz, sources, settings)
    if "burst_key" in table.columns:
        notes += same_key_and_time(table.iloc[first])
    lengths = segments["n_samples"].to_numpy()
    if len(lengths):
        notes.append(f"{len(segments):,} bursts at {hz:g} Hz; samples per burst min {lengths.min()}, median "
                     f"{np.median(lengths):g}, max {lengths.max()}; most common (samples: bursts): " + top_counts(lengths))
    return samples, segments, notes


def same_key_and_time(starts: pd.DataFrame) -> list[str]:
    # Bursts of different individuals with the same key and start time: animals recorded
    # at the same time (key = recording number), or one recording under two names if the
    # values are also the same (then counted as copies). If the key is a collar, a wrong
    # collar, time or individual.
    keyed = pd.DataFrame({"key": starts["burst_key"].astype(str).to_numpy(), "time": starts["time"].to_numpy(),
                          "individual": starts["individual_id"].astype(str).to_numpy()})
    per_slot = keyed.groupby(["key", "time"])["individual"].agg(lambda s: " + ".join(sorted(set(s))))
    clash = per_slot[per_slot.str.contains(" \\+ ")]
    notes = [f"Bursts of different individuals with the same key and start time (recorded at once): {len(clash):,}"]
    for pair, n in clash.value_counts().head(10).items():
        times = clash[clash == pair].index.get_level_values("time")
        keys = ", ".join(sorted(set(clash[clash == pair].index.get_level_values("key"))))
        notes.append(f"  {pair} (key {keys}): {n:,} bursts, {pd.Timestamp(times.min())} to {pd.Timestamp(times.max())}")
    return notes


def burst_length(dataset: str, setting: str | None = "1") -> int | None:
    # Burst length in samples from sensor_settings.csv; setting None: longest of all settings.
    values = [int(r["burst_samples_per_axis"]) for r in sensor_settings(dataset)
              if r["burst_samples_per_axis"] and (setting is None or r["setting"] == str(setting))]
    return max(values) if values else None


def top_counts(lengths: np.ndarray, k: int = 6) -> str:
    counts = Counter(np.asarray(lengths).tolist())
    return ", ".join(f"{length}: {count:,}" for length, count in counts.most_common(k)) or "-"


def clean_labels(values: pd.Series) -> np.ndarray:
    out = np.empty(len(values), dtype=object)
    for i, v in enumerate(values.to_numpy(dtype=object)):
        text = None if v is None or (not isinstance(v, str) and pd.isna(v)) else str(v).strip()
        out[i] = text or None
    return out


def sampling_rate_note(sample_time: pd.Series, run: np.ndarray) -> str:
    t = sample_time.to_numpy().astype("datetime64[ns]").astype("int64") / 1e9
    step = np.diff(t)[run[1:] == run[:-1]]
    step = step[step > 0]
    if not len(step):
        return "Time stamps per sample: none (one time per burst)"
    med = float(np.median(step))
    return (f"Time stamps per sample: median step {med:.5f} s ({1 / med:.2f} Hz), "
            f"5-95 % {np.percentile(step, 5):.5f}-{np.percentile(step, 95):.5f} s")


def long_run_details(table: pd.DataFrame, origin: np.ndarray, run: np.ndarray, runs: np.ndarray,
                     k: int = 10) -> list[str]:
    # Where the runs that were cut lie, and whether their times are per burst or per sample.
    lines = []
    time = table["time"].to_numpy()
    for r in runs[:k]:
        rows = np.flatnonzero(run == r)
        t = time[rows]
        distinct = len(np.unique(t))
        step = np.diff(np.unique(t)).astype("timedelta64[ms]").astype(float) / 1000
        lines.append(f"  {origin[rows[0]]} ({table['individual_id'].iloc[rows[0]]}): {len(rows):,} rows, "
                     f"{pd.Timestamp(t[0])} to {pd.Timestamp(t[-1])}, {distinct:,} different times "
                     f"({len(rows) / distinct:.0f} rows per time"
                     + (f", steps between times {step.min():g}-{step.max():g} s)" if len(step) else ")"))
    if len(runs) > k:
        lines.append(f"  ... and {len(runs) - k:,} more")
    return lines


def drop_copies(raw: np.ndarray, label: np.ndarray, individual: np.ndarray, origin: np.ndarray,
                run: np.ndarray) -> tuple[np.ndarray, list[str]]:
    starts = np.flatnonzero(np.r_[True, run[1:] != run[:-1]]) if len(run) else np.zeros(0, dtype=int)
    ends = np.r_[starts[1:], len(run)]
    groups: dict[bytes, list[int]] = {}
    for b, (s, e) in enumerate(zip(starts, ends)):
        groups.setdefault(hashlib.sha1(raw[s:e].tobytes()).digest(), []).append(b)

    drop: set[int] = set()
    n_groups = n_conflict = n_across = 0
    places: Counter = Counter()
    for members in groups.values():
        if len(members) < 2:
            continue
        n_groups += 1
        for b in members[1:]:
            places[(origin[starts[members[0]]], origin[starts[b]])] += 1
        labels = {tuple(label[starts[b]:ends[b]]) for b in members}
        if len({individual[starts[b]] for b in members}) > 1:
            n_across += 1
        if len(labels) > 1:
            n_conflict += 1
            drop.update(members)
        else:
            drop.update(members[1:])

    keep = np.ones(len(run), dtype=bool)
    for b in drop:
        keep[starts[b]:ends[b]] = False
    notes = [f"Bursts with identical acceleration values (copies): {n_groups:,} groups, "
             f"{len(drop):,} bursts dropped ({n_conflict:,} groups with different labels, all copies dropped; "
             f"{n_across:,} groups across individuals)"]
    if places:
        notes.append("  Where the copies are (first burst <- copy: bursts):")
        notes += [f"    {a} <- {b}: {count:,}" for (a, b), count in places.most_common(15)]
        if len(places) > 15:
            notes.append(f"    ... and {len(places) - 15:,} more pairs")
    return keep, notes


# =========================================================
# Date and time columns
# =========================================================
def by_value(values: pd.Series, convert) -> pd.Series:
    # Converts each distinct value once (time columns repeat within bursts).
    codes, uniques = pd.factorize(values, use_na_sentinel=True)
    converted = np.array([convert(u) for u in uniques] + [convert(None)], dtype=object)
    return pd.Series(converted[codes], index=values.index)


def to_date(values: pd.Series) -> pd.Series:
    # Dates as datetime, Excel day numbers or day-first text (12.4.2017).
    if pd.api.types.is_datetime64_any_dtype(values):
        return values.dt.normalize()
    if pd.api.types.is_numeric_dtype(values):
        return pd.to_datetime(values, unit="D", origin="1899-12-30").dt.normalize()

    def one(v):
        if isinstance(v, (dt.datetime, dt.date)):
            return pd.Timestamp(v).normalize()
        if isinstance(v, (int, float)) and not pd.isna(v):
            return pd.Timestamp("1899-12-30") + pd.Timedelta(days=int(v))
        if isinstance(v, str) and v.strip():
            return pd.to_datetime(v.strip(), dayfirst=True, errors="coerce")
        return pd.NaT

    return pd.to_datetime(by_value(values, one))


def to_seconds_of_day(values: pd.Series) -> pd.Series:
    # Time of day as time objects, datetimes, Excel day fractions or "hh:mm:ss[.fff]" text.
    if pd.api.types.is_string_dtype(values) and not pd.api.types.is_object_dtype(values):
        return pd.to_timedelta(values.str.strip().str.replace(",", ".", regex=False), errors="coerce").dt.total_seconds()

    def one(v):
        if isinstance(v, dt.datetime):
            v = v.time()
        if isinstance(v, dt.time):
            return v.hour * 3600 + v.minute * 60 + v.second + v.microsecond / 1e6
        if isinstance(v, pd.Timedelta):
            return v.total_seconds()
        if isinstance(v, (int, float)) and not pd.isna(v):
            return float(v) * 86400 if 0 <= v < 1 else np.nan
        if isinstance(v, str) and v.strip():
            t = pd.to_timedelta(v.strip().replace(",", "."), errors="coerce")
            return np.nan if pd.isna(t) else t.total_seconds()
        return np.nan

    return by_value(values, one).astype("float64")


def date_time(date: pd.Series, clock: pd.Series) -> pd.Series:
    return to_date(date) + pd.to_timedelta(to_seconds_of_day(clock), unit="s")


def read_excel(path, sheet: str | int = 0, **kwargs) -> pd.DataFrame:
    try:
        return pd.read_excel(path, sheet_name=sheet, engine="calamine", **kwargs)
    except ImportError:
        return pd.read_excel(path, sheet_name=sheet, **kwargs)
