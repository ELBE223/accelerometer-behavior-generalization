# dataset_report.py
#
# Purpose:
# - Writes one text report per dataset that describes what the raw data contain:
#   files, formats, columns, rows, time stamps and sampling rate, value ranges of
#   the acceleration axes, labels and individuals, and the text of the
#   documentation files (mapping tables, settings, READMEs).
# - Read only: nothing in data/raw/ is changed.
# - Column roles (time, axis, label, individual) are guessed from column names and
#   marked as candidates; they are a starting point for the manual review.
#
# Usage (from the project folder, venv active):
#   python 01_Preprocessing/dataset_report.py Cattle_dataset_1     # one or more datasets
#   python 01_Preprocessing/dataset_report.py                      # all datasets
#
# Output: 01_Preprocessing/reports/dataset_reports/<dataset>.txt
# The reports contain a few example values per column; check this before the
# repository is made public.

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import itertools
import re
import time
import warnings
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
REPORT_DIR = ROOT / "01_Preprocessing" / "reports" / "dataset_reports"
DATASET_REGISTRY = ROOT / "00_Documentation" / "datasets.csv"

# =========================================================
# Settings
# =========================================================
DATA_EXTENSIONS = {".csv", ".tsv", ".xlsx", ".xls", ".parquet"}
TEXT_DOC_EXTENSIONS = {".rtf", ".md", ".txt", ".pdf"}
CODE_EXTENSIONS = {".r", ".rmd", ".py", ".m"}
EXCEL_EXTENSIONS = {".xlsx", ".xls"}
IGNORED_NAMES = {".DS_Store", ".Rhistory"}

DELIMITERS = [",", ";", "\t", "|"]
SNIFF_BYTES = 500_000
SNIFF_LINES = 50
MIN_TABLE_LINES = 5

MAX_LEVELS = 100        # value counts for columns with at most this many distinct values
N_FIRST_VALUES = 3
GAP_FACTOR = 5          # a time step above GAP_FACTOR x median step counts as a gap
MAX_DOC_LINES = 300
MAX_HINT_PLACES = 5
MAX_COMBINED_PARTS = 4  # a table may be the sum of up to this many other tables
MAX_COMBINED_TABLES = 20  # above this, the combined-table check is skipped (too many combinations)
ROW_NUMBER_NAMES = {"", "X", "...1", "(row names)"}
NAME_WIDTH = 40
WIDTH = 100

EOBS_RAW = "eobs:accelerations-raw"
EOBS_AXES = "eobs:acceleration-axes"
EOBS_FREQ = "eobs:acceleration-sampling-frequency-per-axis"

TIME_PATTERN = re.compile(r"time|date|zeit|datum|uhr|^t$|^sec|^ms$|millis", re.I)
TIME_WORDS = {"start", "end", "begin", "beginn", "ende", "stop", "onset", "offset"}
LABEL_PATTERN = re.compile(r"behav|verhalten|label|activ|aktiv|class|klasse|ethog|state|code|annot|^bev|^beh", re.I)
ID_PATTERN = re.compile(r"individ|animal|tier|subject|name|^id$|_id$|^id_|identifier|collar|halsband|logger|device", re.I)
AXIS_WORDS = {"a", "acc", "accel", "acceleration", "accelerometer", "achse", "axis"}
DATE_ONLY = "date only (no time of day)"
TIME_OF_DAY = re.compile(r"\d{1,2}:\d{2}:\d{2}([.,]\d+)?")


# =========================================================
# Helpers
# =========================================================
def log(msg: str) -> None:
    print(msg, flush=True)


def is_ignored(path: Path) -> bool:
    # "._*" files are macOS metadata on external drives, not data.
    return path.name.startswith("._") or path.name in IGNORED_NAMES


def fmt_size(n_bytes: float) -> str:
    for unit in ["B", "KB", "MB"]:
        if n_bytes < 1024:
            return f"{n_bytes:.0f} {unit}" if unit == "B" else f"{n_bytes:.1f} {unit}"
        n_bytes /= 1024
    return f"{n_bytes:.1f} GB"


def fmt_count(n: int) -> str:
    return f"{n:,}".replace(",", " ")


def fmt_num(value) -> str:
    if value is None or (isinstance(value, (float, np.floating)) and np.isnan(value)):
        return "NA"
    if isinstance(value, (float, np.floating)):
        return f"{value:.6g}"
    return str(value)


def fmt_duration(seconds: float) -> str:
    if seconds is None or np.isnan(seconds):
        return "NA"
    return str(dt.timedelta(seconds=round(float(seconds), 3)))


def short(value, width: int = 24) -> str:
    text = str(value).replace("\n", " ").replace("\r", " ")
    return text if len(text) <= width else text[: width - 1] + "…"


def section(title: str) -> list[str]:
    return ["", "=" * WIDTH, title, "=" * WIDTH]


def subsection(title: str) -> list[str]:
    return ["", title, "-" * min(len(title), WIDTH)]


def text_table(header: list[str], rows: list[list[str]], indent: str = "  ") -> list[str]:
    rows = [[str(c) for c in r] for r in rows]
    widths = [max([len(header[i])] + [len(r[i]) for r in rows]) for i in range(len(header))]
    line = lambda cells: indent + "  ".join(c.ljust(w) for c, w in zip(cells, widths)).rstrip()
    return [line(header), line(["-" * w for w in widths])] + [line(r) for r in rows]


def read_datasets() -> list[str]:
    with DATASET_REGISTRY.open(newline="", encoding="utf-8") as fh:
        return [row["dataset_id"].strip() for row in csv.DictReader(fh) if row["dataset_id"].strip()]


class Hints:
    # Collects (place, message) pairs and prints each message once with its places.
    def __init__(self) -> None:
        self.items: list[tuple[str, str]] = []

    def add(self, place: str, message: str) -> None:
        if (place, message) not in self.items:
            self.items.append((place, message))

    def lines(self, all_places: list[str]) -> list[str]:
        grouped: dict[str, list[str]] = {}
        for place, message in self.items:
            grouped.setdefault(message, []).append(place)
        out = []
        for message, places in grouped.items():
            places = [p for p in places if p]
            if not places:
                out.append(f"  - {message}")
            elif len(places) > 1 and set(places) == set(all_places):
                out.append(f"  - {message} (all {len(places)} data tables)")
            else:
                shown = ", ".join(places[:MAX_HINT_PLACES])
                more = f" and {len(places) - MAX_HINT_PLACES} more" if len(places) > MAX_HINT_PLACES else ""
                out.append(f"  - {message}: {shown}{more}")
        return out or ["  - none"]


# =========================================================
# Reading
# =========================================================
def sniff_text(path: Path) -> dict:
    raw = path.read_bytes()[:SNIFF_BYTES]
    if path.stat().st_size > SNIFF_BYTES:
        # Cut at the last complete line, so no character is split.
        raw = raw[: raw.rfind(b"\n") + 1]
    encoding = "utf-8-sig"
    try:
        sample = raw.decode(encoding)
    except UnicodeDecodeError:
        encoding = "cp1252"
        sample = raw.decode(encoding, errors="replace")

    lines = sample.splitlines()[: SNIFF_LINES * 4]
    nonblank = [(i, ln) for i, ln in enumerate(lines) if ln.strip()][:SNIFF_LINES]

    best = {"sep": None, "score": 0, "mode": 0}
    for sep in DELIMITERS:
        counts = [ln.count(sep) for _, ln in nonblank]
        mode, n_mode = Counter(counts).most_common(1)[0] if counts else (0, 0)
        if mode > 0 and n_mode > best["score"]:
            best = {"sep": sep, "score": n_mode, "mode": mode}

    if best["sep"] is None:
        counts = [len(ln.split()) - 1 for _, ln in nonblank]
        mode, n_mode = Counter(counts).most_common(1)[0] if counts else (0, 0)
        if mode > 0:
            best = {"sep": r"\s+", "score": n_mode, "mode": mode}

    sep, mode = best["sep"], best["mode"]
    count = (lambda ln: len(ln.split()) - 1) if sep == r"\s+" else (lambda ln: ln.count(sep))

    # Lines before the first line with the typical number of fields are metadata.
    skiprows = 0
    row_names = False
    if sep is not None:
        first = next((k for k, (_, ln) in enumerate(nonblank) if count(ln) == mode), 0)
        skiprows = nonblank[first][0] if nonblank else 0
        # write.table(row.names = TRUE) in R writes a header with one field less than the data.
        if first > 0 and count(nonblank[first - 1][1]) == mode - 1:
            skiprows = nonblank[first - 1][0]
            row_names = True

    decimal = "."
    if sep is not None and sep != ",":
        data_lines = [ln for i, ln in nonblank if i > skiprows]
        fields = [f.strip() for ln in data_lines for f in re.split(sep if sep == r"\s+" else re.escape(sep), ln)]
        n_comma = sum(bool(re.fullmatch(r"-?\d+,\d+", f)) for f in fields)
        n_dot = sum(bool(re.fullmatch(r"-?\d+\.\d+", f)) for f in fields)
        decimal = "," if n_comma > n_dot else "."

    return {
        "encoding": encoding,
        "sep": sep,
        "decimal": decimal,
        "skiprows": skiprows,
        "metadata_lines": lines[:skiprows],
        "row_names": row_names,
        "is_table": sep is not None and best["score"] >= MIN_TABLE_LINES,
    }


def read_text_table(path: Path, info: dict) -> pd.DataFrame:
    kwargs = {"engine": "python"} if info["sep"] == r"\s+" else {"low_memory": False}
    df = pd.read_csv(
        path,
        sep=info["sep"],
        decimal=info["decimal"],
        encoding=info["encoding"],
        skiprows=info["skiprows"],
        **kwargs,
    )
    if info["row_names"]:
        # pandas puts the column without a header into the index.
        df = df.reset_index().rename(columns={"index": "(row names)"})
    return df


def read_excel_sheets(path: Path) -> dict[str, pd.DataFrame]:
    try:
        return pd.read_excel(path, sheet_name=None, engine="calamine")
    except ImportError:
        return pd.read_excel(path, sheet_name=None)


def read_doc_text(path: Path) -> str:
    if path.suffix.lower() == ".rtf":
        from striprtf.striprtf import rtf_to_text

        raw = path.read_bytes().decode("cp1252", errors="replace")
        return rtf_to_text(raw, errors="ignore")
    for encoding in ["utf-8-sig", "cp1252"]:
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="utf-8", errors="replace")


# =========================================================
# Column analysis
# =========================================================
def name_tokens(name: str) -> list[str]:
    return re.findall(r"[a-z]+|\d+", str(name).lower())


def axis_of(name: str) -> str | None:
    tokens = name_tokens(name)
    for tok in tokens:
        m = re.fullmatch(r"(?:acc|accel|a)?([xyz])(?:axis|achse|acc)?", tok)
        if m and (len(tok) > 1 or len(tokens) == 1 or set(tokens) & AXIS_WORDS):
            return m.group(1)
    return None


def is_time_name(name: str) -> bool:
    return bool(TIME_PATTERN.search(name) or set(name_tokens(name)) & TIME_WORDS)


def is_row_number(name: str, series: pd.Series) -> bool:
    # Row numbers written by R (write.csv) or Excel exports, not data.
    if name == "(row names)":
        return True
    if not (name in ROW_NUMBER_NAMES or name.startswith("Unnamed: 0")):
        return False
    values = pd.to_numeric(series, errors="coerce")
    if values.isna().any() or len(values) < 2:
        return False
    return float(np.mean(np.diff(values.to_numpy()) == 1)) >= 0.95


def as_numeric(series: pd.Series) -> pd.Series | None:
    if pd.api.types.is_bool_dtype(series):
        return None
    if pd.api.types.is_numeric_dtype(series):
        return series
    values = series.dropna()
    if values.empty or not all(isinstance(v, (str, int, float, np.number)) for v in values.head(1000)):
        return None
    converted = pd.to_numeric(series, errors="coerce")
    if converted.notna().sum() >= 0.95 * series.notna().sum():
        return converted
    return None


def epoch_seconds(stamps: pd.Series) -> pd.Series:
    # Independent of the datetime resolution (ns, us, s) and of time zones.
    if getattr(stamps.dt, "tz", None) is not None:
        stamps = stamps.dt.tz_convert(None)
    return (stamps - pd.Timestamp("1970-01-01")).dt.total_seconds()


def time_of_day_seconds(value) -> float:
    # Seconds since midnight from time, date-time or "hh:mm:ss" text values.
    if isinstance(value, dt.datetime):
        value = value.time()
    if isinstance(value, dt.time):
        return value.hour * 3600 + value.minute * 60 + value.second + value.microsecond / 1e6
    if isinstance(value, str) and TIME_OF_DAY.fullmatch(value.strip()):
        h, m, s = value.strip().replace(",", ".").split(":")
        return int(h) * 3600 + int(m) * 60 + float(s)
    return np.nan


def date_kind(stamps: pd.Series, kind: str) -> str:
    # Columns that hold only the date (time of day always 00:00:00).
    return DATE_ONLY if (stamps.dt.normalize() == stamps).all() else kind


def to_seconds(series: pd.Series) -> tuple[pd.Series | None, str, pd.Series | None]:
    # Returns (time in seconds, kind, datetime values for display). For numbers
    # whose unit is unknown, the values are returned unchanged.
    s = series.dropna()
    if s.empty:
        return None, "empty", None

    if pd.api.types.is_datetime64_any_dtype(s):
        stamps = pd.to_datetime(s)
        return epoch_seconds(stamps), date_kind(stamps, "date-time"), stamps

    if isinstance(s.iloc[0], dt.time):
        secs = s.map(time_of_day_seconds).astype(float)
        share = secs.notna().mean()
        kind = "time of day (no date)" + (f", {share:.1%} parsed" if share < 1 else "")
        return secs.dropna(), kind, None

    numeric = as_numeric(s)
    if numeric is not None:
        values = numeric.astype(float)
        median = float(np.median(np.abs(values)))
        if 1e12 <= median < 2.5e12:
            return values / 1000, "number, looks like Unix time in milliseconds", pd.to_datetime(values, unit="ms")
        if 1e9 <= median < 2.5e9:
            return values, "number, looks like Unix time in seconds", pd.to_datetime(values, unit="s")
        return values, "number (unit unknown)", None

    text = s.astype(str).str.strip()
    if text.head(1000).str.fullmatch(TIME_OF_DAY).all():
        secs = pd.to_timedelta(text.str.replace(",", ".", regex=False), errors="coerce").dt.total_seconds()
        return secs, "time of day (no date)", None

    # Dates with dots (7.11.2018) are day first; otherwise month first is tried first.
    dotted = bool(text.head(1000).str.match(r"\d{1,2}\.\d{1,2}\.\d{2,4}").all())
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        stamps = pd.to_datetime(text, errors="coerce", dayfirst=dotted)
        if stamps.notna().mean() < 0.9:
            stamps = pd.to_datetime(text, errors="coerce", dayfirst=not dotted)
    if stamps.notna().mean() < 0.5:
        return None, "text, not parseable as time", None
    share = stamps.notna().mean()
    stamps = stamps.dropna()
    return epoch_seconds(stamps), date_kind(stamps, f"text parsed as date-time ({share:.0%} parsed)"), stamps


def time_summary(series: pd.Series, hints: Hints, place: str) -> list[str]:
    secs, kind, stamps = to_seconds(series)
    if secs is not None:
        secs = secs.dropna()
    lines = [f"    Kind: {kind}"]
    in_seconds = kind != "number (unit unknown)"
    if kind.startswith("time of day"):
        hints.add(place, "time stamps without date")
    if secs is None or secs.size < 2:
        return lines
    if kind == DATE_ONLY:
        dates = stamps.dt.date
        lines.append(f"    First: {dates.iloc[0]}   Last: {dates.iloc[-1]}   Distinct dates: {dates.nunique()}")
        return lines

    if stamps is not None:
        lines.append(f"    First: {stamps.iloc[0]}   Last: {stamps.iloc[-1]}   Span: {fmt_duration(secs.max() - secs.min())}")
    elif kind.startswith("time of day"):
        lines.append(f"    First: {fmt_duration(secs.iloc[0])}   Last: {fmt_duration(secs.iloc[-1])}   Earliest: {fmt_duration(secs.min())}   Latest: {fmt_duration(secs.max())}")
    else:
        lines.append(f"    First: {fmt_num(secs.iloc[0])}   Last: {fmt_num(secs.iloc[-1])}   Min: {fmt_num(secs.min())}   Max: {fmt_num(secs.max())}")

    steps = np.diff(secs.to_numpy())
    positive = steps[steps > 0]
    n_zero = int((steps == 0).sum())
    n_negative = int((steps < 0).sum())

    median_step = float(np.median(positive)) if positive.size else np.nan
    if positive.size:
        if in_seconds:
            lines.append(f"    Median step: {median_step:.4g} s -> {1 / median_step:.4g} Hz")
        else:
            lines.append(f"    Median step: {median_step:.4g} (unit unknown; {1 / median_step:.4g} Hz if seconds, {1000 / median_step:.4g} Hz if ms)")
        gaps = positive[positive > GAP_FACTOR * median_step]
        if gaps.size:
            largest = fmt_duration(gaps.max()) if in_seconds else f"{gaps.max():.4g}"
            lines.append(f"    Gaps (> {GAP_FACTOR} x median step): {fmt_count(gaps.size)}, largest {largest}")

    if n_zero:
        per_stamp = series.dropna().groupby(series.dropna()).size()
        rows_per_stamp = float(per_stamp.median())
        line = f"    Repeated time stamps: {n_zero / steps.size:.1%} of steps; rows per time stamp: median {fmt_num(rows_per_stamp)}, max {fmt_count(int(per_stamp.max()))}"
        if n_zero / steps.size > 0.5 and in_seconds and positive.size:
            if median_step <= 2:
                line += f" -> about {rows_per_stamp / median_step:.4g} Hz"
                hints.add(place, "time stamps repeat (resolution coarser than the sampling interval); sampling rate from rows per time stamp")
            else:
                line += f" -> looks like bursts of about {rows_per_stamp:.0f} samples every {median_step:.4g} s"
                hints.add(place, "data in bursts (one time stamp per burst); take the sampling rate from the documentation")
        lines.append(line)
    if n_negative:
        lines.append(f"    Time goes backwards {fmt_count(n_negative)} times (several recordings or individuals in one table?)")
        hints.add(place, "time goes backwards; split by recording or individual before windowing")
    return lines


def unit_lines(df: pd.DataFrame, axes: dict[str, str], hints: Hints, place: str) -> list[str]:
    values = df[list(axes)].apply(pd.to_numeric, errors="coerce").dropna()
    if values.empty:
        return []
    lines = []
    sample = values.head(100_000).to_numpy()
    raw_counts = bool(np.all(np.mod(sample, 1) == 0) and sample.min() >= 0 and sample.max() <= 65535)
    if raw_counts:
        lines.append("    All axis values are non-negative integers: probably raw sensor counts")
        hints.add(place, "axis values look like raw sensor counts; conversion to g needed")
    if sorted(axes.values()) == ["x", "y", "z"]:
        median = float(np.median(np.sqrt((values.to_numpy() ** 2).sum(axis=1))))
        if 0.7 <= median <= 1.3:
            unit = "about 1: values are probably in g"
        elif 7 <= median <= 12.5:
            unit = "about 9.81: values are probably in m/s^2"
            hints.add(place, "axis values probably in m/s^2; divide by 9.81 for g")
        else:
            unit = "neither 1 (g) nor 9.81 (m/s^2): unit or offset to be checked"
            if not raw_counts:
                hints.add(place, "unit of the axis values unclear")
        lines.append(f"    Median vector magnitude sqrt(x^2+y^2+z^2) = {median:.3f}, {unit}")
    return lines


def eobs_lines(df: pd.DataFrame, hints: Hints, place: str) -> list[str]:
    hints.add(place, "acceleration stored as e-obs bursts in one text column; split bursts and convert raw counts to g")
    lines = ["    Movebank e-obs format: one row per burst, samples in one text column"]
    raw = df[EOBS_RAW].dropna().astype(str).str.strip()
    lengths = raw.str.count(r"\s+") + 1
    lines.append(f"    Bursts: {fmt_count(raw.size)}; values per burst: " + ", ".join(f"{k} ({fmt_count(v)}x)" for k, v in lengths.value_counts().head(5).items()))
    sample = np.concatenate([np.array(b.split(), dtype=float) for b in raw.head(2000)]) if raw.size else np.array([])
    if sample.size:
        lines.append(f"    Raw values (first 2000 bursts): min {fmt_num(sample.min())}, max {fmt_num(sample.max())}, median {fmt_num(float(np.median(sample)))}")
    for col in [EOBS_AXES, EOBS_FREQ]:
        if col in df.columns:
            counts = df[col].value_counts(dropna=False).head(5)
            lines.append(f"    {col}: " + ", ".join(f"{k} ({fmt_count(v)}x)" for k, v in counts.items()))
    return lines


def analyze_table(df: pd.DataFrame, place: str, hints: Hints) -> tuple[list[str], dict]:
    lines = [f"  Rows: {fmt_count(len(df))}   Columns: {df.shape[1]}"]
    roles: dict[str, list[str]] = {"time": [], "axis": [], "label": [], "individual": []}
    axes: dict[str, str] = {}
    numeric_cols: dict[str, pd.Series] = {}
    summary_rows = []

    row_number_cols = [c for c in df.columns if is_row_number(str(c), df[c])]
    empty_cols = [c for c in df.columns if c not in row_number_cols and df[c].isna().all()]
    if row_number_cols:
        lines.append(f"  Row-number column (ignored): {', '.join(map(str, row_number_cols))}")
        if "(row names)" in row_number_cols:
            lines.append("  The header has one field less than the data rows (R row names); the first column is the row name.")
    if empty_cols:
        lines.append(f"  Empty columns (ignored): {', '.join(map(str, empty_cols))}")
    df = df.drop(columns=row_number_cols + empty_cols)

    if any(str(c).startswith("Unnamed") for c in df.columns):
        hints.add(place, "unnamed columns with values; the header may not be in the first row")

    # Rows with at most one value, e.g. a name filled down to the last Excel row.
    empty = df.notna().sum(axis=1) <= (1 if df.shape[1] >= 3 else 0)
    empty_rows = int(empty.sum())
    if empty_rows:
        lines.append(f"  Empty rows (at most one value): {fmt_count(empty_rows)}")
        hints.add(place, "empty rows (e.g. a sheet filled down to the last Excel row); drop them")
    row_hashes = pd.util.hash_pandas_object(df, index=False).to_numpy() if df.shape[1] else np.array([], dtype="uint64")
    n_duplicate = int(pd.Series(row_hashes[~empty.to_numpy()]).duplicated().sum())
    if n_duplicate > 0:
        lines.append(f"  Rows that repeat an earlier row exactly: {fmt_count(n_duplicate)} ({n_duplicate / len(df):.1%})")
        # Identical rows are normal for resting animals with coarse time stamps; only many are suspicious.
        if n_duplicate / len(df) > 0.25:
            hints.add(place, "more than 25 % of the rows repeat an earlier row exactly; check for copied data")

    for col in df.columns:
        series = df[col]
        name = str(col)
        numeric = as_numeric(series)
        if numeric is not None:
            numeric_cols[col] = numeric

        axis = axis_of(name) if numeric is not None else None
        if axis:
            roles["axis"].append(name)
            axes[col] = axis
        elif is_time_name(name) or pd.api.types.is_datetime64_any_dtype(series):
            roles["time"].append(name)
        elif LABEL_PATTERN.search(name):
            roles["label"].append(name)
        elif ID_PATTERN.search(name):
            roles["individual"].append(name)

        low = fmt_num(numeric.min()) if numeric is not None else ""
        high = fmt_num(numeric.max()) if numeric is not None else ""
        first_values = ", ".join(short(v, 20) for v in series.dropna().head(N_FIRST_VALUES))
        summary_rows.append([short(name, NAME_WIDTH), str(series.dtype), fmt_count(int(series.isna().sum())),
                             fmt_count(int(series.nunique(dropna=True))), low, high, first_values])

    lines += [""] + text_table(["column", "dtype", "missing", "distinct", "min", "max", "first values"], summary_rows)

    # Text columns with one value often hold metadata (study name, sensor); shown in full.
    constant = [c for c in df.columns if df[c].nunique(dropna=True) == 1 and c not in numeric_cols]
    if constant:
        lines += ["", "  Columns with a single value:"]
        lines += [f"    {short(c, NAME_WIDTH)}: {short(df[c].dropna().iloc[0], 200)}" for c in constant]
    lines += ["", "  Candidate roles (from column names):"]
    lines += [f"    {role:<11} {', '.join(cols) if cols else '-'}" for role, cols in roles.items()]

    if roles["label"] and len(roles["time"]) >= 2 and not axes and EOBS_RAW not in df.columns:
        hints.add(place, "labels given as time intervals; match them to the acceleration time stamps")
    if roles["label"] and roles["time"] and not axes and EOBS_RAW not in df.columns:
        hints.add(place, "labels without acceleration values; join them to the acceleration table by time")
    if axes and not roles["time"]:
        hints.add(place, "no time column found; sample order and segment columns define the time series")

    if EOBS_RAW in df.columns:
        lines += ["", "  Acceleration bursts:"] + eobs_lines(df, hints, place)

    for col in roles["time"]:
        lines += ["", f"  Time column '{col}':"] + time_summary(df[col], hints, place)

    if axes:
        rows = []
        for col, axis in axes.items():
            v = numeric_cols[col].dropna()
            q = v.quantile([0.01, 0.5, 0.99]) if not v.empty else pd.Series([np.nan] * 3)
            rows.append([axis, short(col, NAME_WIDTH), fmt_num(v.min()), fmt_num(q.iloc[0]), fmt_num(q.iloc[1]),
                         fmt_num(q.iloc[2]), fmt_num(v.max()), fmt_num(v.mean()), fmt_num(v.std())])
        lines += ["", "  Acceleration axes:"]
        lines += text_table(["axis", "column", "min", "p1", "median", "p99", "max", "mean", "sd"], rows, indent="    ")
        lines += unit_lines(df, axes, hints, place)

    # Value counts for columns with repeated values: text columns and label or individual candidates.
    count_cols = []
    for col in df.columns:
        name = str(col)
        if name in roles["time"] or name in roles["axis"]:
            continue
        n_distinct = df[col].nunique(dropna=True)
        repeated = n_distinct < df[col].notna().sum()
        if 0 < n_distinct <= MAX_LEVELS and repeated and (col not in numeric_cols or name in roles["label"] + roles["individual"]):
            count_cols.append(col)

    for col in count_cols:
        counts = df[col].value_counts(dropna=False)
        rows = [[short(k, 40), fmt_count(int(v)), f"{v / len(df):.1%}"] for k, v in counts.items()]
        lines += ["", f"  Values of '{col}' ({len(counts)} distinct):"] + text_table(["value", "rows", "share"], rows, indent="    ")

    labels = [c for c in roles["label"] if c in count_cols]
    individuals = [c for c in roles["individual"] if c in count_cols and df[c].nunique() > 1]
    if labels and individuals:
        lab, ind = labels[0], individuals[0]
        # object dtype, so numeric label codes can take the "NA" fill value.
        cross = pd.crosstab(df[lab].astype(object).fillna("NA"), df[ind].astype(object).fillna("NA"))
        lines += ["", f"  Rows per '{lab}' (rows) and '{ind}' (columns):", ""]
        lines += ["    " + ln for ln in cross.to_string().splitlines()]

    info = {
        "columns": [str(c) for c in df.columns],
        "rows": len(df),
        "label_counts": {str(c): df[c].value_counts(dropna=False) for c in labels},
        "row_hashes": row_hashes,
        "axis_signature": axis_signature(df, list(axes)) if axes else None,
    }
    return lines, info


# =========================================================
# Report
# =========================================================
def axis_signature(df: pd.DataFrame, cols: list) -> str:
    # Same signature = the same acceleration values in the same order.
    values = df[cols].apply(pd.to_numeric, errors="coerce").to_numpy(dtype="float64")
    return hashlib.sha1(np.ascontiguousarray(values).tobytes()).hexdigest()


def identical_axes(tables: dict[str, dict]) -> list[str]:
    groups: dict[str, list[str]] = {}
    for place, info in tables.items():
        if info.get("axis_signature"):
            groups.setdefault(info["axis_signature"], []).append(place)
    return [f"identical acceleration values in {', '.join(places)} (copies of one recording?)"
            for places in groups.values() if len(places) > 1]


def classify(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in DATA_EXTENSIONS:
        return "data"
    if ext == ".txt":
        return "data" if sniff_text(path)["is_table"] else "documentation"
    if ext in TEXT_DOC_EXTENSIONS:
        return "documentation"
    if ext in CODE_EXTENSIONS:
        return "code"
    # Files without (or with an unknown) extension can still be text tables (Dog_dataset_2).
    if is_text_file(path) and sniff_text(path)["is_table"]:
        return "data"
    return "other"


def is_text_file(path: Path) -> bool:
    with path.open("rb") as fh:
        head = fh.read(4096)
    return bool(head) and b"\x00" not in head


def read_tables(path: Path, place: str, hints: Hints) -> tuple[dict[str, pd.DataFrame], list[str]]:
    # Returns the tables of one file and lines describing how it was read.
    ext = path.suffix.lower()
    if ext in EXCEL_EXTENSIONS:
        sheets = read_excel_sheets(path)
        return {f"{place} [sheet {name}]": df for name, df in sheets.items()}, [f"  Excel, {len(sheets)} sheet(s)"]
    if ext == ".parquet":
        return {place: pd.read_parquet(path)}, ["  Parquet"]

    info = sniff_text(path)
    sep_name = {"\t": "tab", r"\s+": "whitespace"}.get(info["sep"], info["sep"])
    read_lines = [f"  Text: delimiter '{sep_name}', decimal '{info['decimal']}', encoding {info['encoding']}, lines skipped before the header: {info['skiprows']}"]
    if info["metadata_lines"]:
        read_lines += ["  Lines before the header:"] + ["    " + short(ln, 90) for ln in info["metadata_lines"][:20]]
        hints.add(place, "lines before the header (logger settings?); see the file section")
    if info["decimal"] == ",":
        hints.add(place, "decimal comma")
    if info["encoding"] == "cp1252":
        hints.add(place, "text encoding is not UTF-8 (read as cp1252)")
    return {place: read_text_table(path, info)}, read_lines


def combined_tables(tables: dict[str, dict]) -> list[str]:
    # A table with the same columns whose rows are exactly those of 2 or more other
    # tables is probably a combined copy (e.g. a GESAMT sheet).
    found = []
    for place, info in tables.items():
        parts = [p for p, other in tables.items()
                 if p != place and other["columns"] == info["columns"] and 0 < other["rows"] < info["rows"]]
        rows = None  # built only when the row counts add up
        for combo in (c for k in range(2, min(len(parts), MAX_COMBINED_PARTS) + 1) for c in itertools.combinations(parts, k)):
            if sum(tables[p]["rows"] for p in combo) != info["rows"]:
                continue
            if rows is None:
                rows = set(info["row_hashes"].tolist())
            if all(set(tables[p]["row_hashes"][:1000].tolist()) <= rows for p in combo):
                found.append(f"{place} contains the rows of {' + '.join(combo)}; use either the parts or the combined table")
                break
    return found


def equal_sheets(tables: dict[str, dict]) -> list[str]:
    # Sheets of the same Excel file with the same number of rows may hold the same data.
    found = []
    by_file: dict[str, list[str]] = {}
    for place in tables:
        if " [sheet " in place:
            by_file.setdefault(place.split(" [sheet ")[0], []).append(place)
    for places in by_file.values():
        for a, b in itertools.combinations(places, 2):
            if tables[a]["rows"] == tables[b]["rows"] >= 1000:
                found.append(f"{a} and {b} have the same number of rows ({fmt_count(tables[a]['rows'])}); possibly the same data")
    return found


def dataset_report(dataset: str) -> list[str]:
    folder = RAW_DIR / dataset
    files = sorted(
        p for p in folder.rglob("*")
        if p.is_file() and not is_ignored(p) and not any(is_ignored(x) for x in p.relative_to(folder).parents)
    )
    rel = lambda p: str(p.relative_to(folder))
    categories = {p: classify(p) for p in files}
    hints = Hints()

    header = [
        f"DATASET REPORT: {dataset}",
        f"Created: {time.strftime('%Y-%m-%d %H:%M:%S')} with 01_Preprocessing/dataset_report.py (pandas {pd.__version__})",
        f"Folder: data/raw/{dataset}",
        "Generated automatically from the raw data; column roles are guesses from column names.",
    ]

    body = section("1. FILES")
    if not files:
        return header + body + ["  (no files)"]
    body += text_table(["file", "category", "type", "size"],
                       [[rel(p), categories[p], p.suffix.lower() or "-", fmt_size(p.stat().st_size)] for p in files])

    body += section("2. DOCUMENTATION")
    docs = [p for p in files if categories[p] == "documentation"]
    for p in docs:
        body += subsection(rel(p))
        if p.suffix.lower() == ".pdf":
            body.append("  PDF, not read by this script.")
            continue
        try:
            text = read_doc_text(p).splitlines()
            body += ["  " + ln.rstrip() for ln in text[:MAX_DOC_LINES]]
            if len(text) > MAX_DOC_LINES:
                body.append(f"  ... ({len(text) - MAX_DOC_LINES} more lines)")
        except Exception as exc:
            body.append(f"  Could not read: {exc}")
    if not docs:
        body.append("  (no documentation files)")

    body += section("3. DATA FILES")
    overview_rows = []
    places: list[str] = []
    table_infos: dict[str, dict] = {}
    label_tables: dict[str, dict[str, pd.Series]] = {}
    column_sets: Counter = Counter()

    data_files = [p for p in files if categories[p] == "data"]
    check_combined = len(data_files) <= MAX_COMBINED_TABLES
    for p in data_files:
        log(f"[INFO] {dataset} | reading {rel(p)}")
        try:
            tables, read_lines = read_tables(p, rel(p), hints)
        except Exception as exc:
            body += subsection(rel(p)) + [f"  Could not read: {type(exc).__name__}: {exc}"]
            hints.add(rel(p), "file could not be read automatically")
            overview_rows.append([rel(p), "error", "", ""])
            continue

        for place, df in tables.items():
            places.append(place)
            body += subsection(place) + read_lines
            try:
                table_lines, table_info = analyze_table(df, place, hints)
            except Exception as exc:
                body.append(f"  Analysis failed: {type(exc).__name__}: {exc}")
                hints.add(place, "analysis failed")
                continue
            body += table_lines
            overview_rows.append([place, fmt_count(table_info["rows"]), str(len(table_info["columns"])), short(", ".join(table_info["columns"]), 60)])
            column_sets[tuple(table_info["columns"])] += 1
            if not check_combined:
                table_info["row_hashes"] = None  # not needed; saves memory with many tables
            table_infos[place] = table_info
            for col, counts in table_info["label_counts"].items():
                label_tables.setdefault(col, {})[place] = counts

    overview = section("0. OVERVIEW")
    overview.append(f"  Files: {len(files)} (" + ", ".join(f"{k} {v}" for k, v in Counter(categories.values()).items()) + ")")
    overview += ([""] + text_table(["table", "rows", "cols", "columns"], overview_rows)) if overview_rows else ["  (no data tables)"]
    if len(column_sets) > 1:
        overview += ["", f"  The data tables have {len(column_sets)} different column sets."]

    for col, per_table in label_tables.items():
        if len(per_table) > 1:
            matrix = pd.DataFrame(per_table).fillna(0).astype(int).T
            matrix.index = [short(i, 45) for i in matrix.index]
            overview += ["", f"  Rows per value of '{col}' and table:", ""]
            overview += ["    " + ln for ln in matrix.to_string().splitlines()]

    combined = combined_tables(table_infos) if check_combined else []
    if not check_combined:
        overview += ["", f"  Check for tables that combine other tables skipped ({len(data_files)} data files)."]
    for message in combined + equal_sheets(table_infos) + identical_axes(table_infos):
        hints.add("", message)

    code_files = [rel(p) for p in files if categories[p] == "code"]
    if code_files:
        hints.add("", f"code files in the raw data folder: {', '.join(code_files)}")
    overview += ["", "  Automatic hints:"] + hints.lines(places)

    return header + overview + body


# =========================================================
# Main
# =========================================================
def main() -> int:
    parser = argparse.ArgumentParser(description="Write one text report per raw dataset.")
    parser.add_argument("datasets", nargs="*", help="Dataset IDs (default: all in datasets.csv)")
    args = parser.parse_args()

    known = read_datasets()
    datasets = args.datasets or known
    unknown = [ds for ds in datasets if ds not in known]
    if unknown:
        log(f"[ERROR] Unknown dataset(s): {', '.join(unknown)}. Known: {', '.join(known)}")
        return 1

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    for ds in datasets:
        if not (RAW_DIR / ds).is_dir():
            log(f"[WARN] {ds}: folder data/raw/{ds} not found, skipped")
            continue
        start = time.time()
        report = dataset_report(ds)
        out_file = REPORT_DIR / f"{ds}.txt"
        out_file.write_text("\n".join(report) + "\n", encoding="utf-8")
        log(f"[OK] {ds}: {out_file.relative_to(ROOT)} ({time.time() - start:.0f} s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
