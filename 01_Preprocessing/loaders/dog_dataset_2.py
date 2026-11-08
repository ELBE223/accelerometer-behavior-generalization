# dog_dataset_2.py
#
# Loader for Dog_dataset_2 (Groth MSc thesis); burst rules in loaders/bursts.py.
# - Input: data/raw/Dog_dataset_2/Data_Dog_Raw/<name>_6568 (text files without
#   extension). All files come from sensor 6568 (setting 4 of Settings.rtf, 20 Hz).
# - Columns used: Date and Time (burst start), x, y, z (raw counts), Behaviour (original
#   label). Number is one value per recording (listed in the notes), not a burst key: two
#   files also contain 302, apparently a typo of 4302.
# - Several files hold the same recording under different dog names (identical acceleration
#   values). Which dog was recorded is unknown, so each recording is one unit (D15), named
#   after all its files (e.g. "Ami+Winston"); only one copy is read.
# - The files have 124 samples per burst (6.2 s), not the 130 of Settings.rtf.

from __future__ import annotations

import hashlib
from pathlib import Path

import pandas as pd

from loaders.bursts import burst_samples, date_time
from loaders.common import native_hz

DATASET = "Dog_dataset_2"
DATA_DIR = "Data_Dog_Raw"
SETTING = "4"
SUFFIX = "_6568"
BURST_SAMPLES = 124


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    files = sorted(p for p in (raw_dir / DATA_DIR).glob(f"*{SUFFIX}") if not p.name.startswith("._"))
    if not files:
        raise FileNotFoundError(f"No '*{SUFFIX}' files in {raw_dir / DATA_DIR}")

    # Group the files by their acceleration values.
    recordings: dict[bytes, list[tuple[str, pd.DataFrame]]] = {}
    for path in files:
        df = pd.read_csv(path, encoding="utf-8-sig")
        key = hashlib.sha1(df[["x", "y", "z"]].to_numpy(dtype="int64").tobytes()).digest()
        recordings.setdefault(key, []).append((path.name.removesuffix(SUFFIX), df))

    parts, notes = [], [f"{len(files)} files hold {len(recordings)} different recordings"]
    for copies in recordings.values():
        unit = "+".join(name for name, _ in copies)
        df = copies[0][1]
        same_labels = all(c["Behaviour"].astype(str).equals(df["Behaviour"].astype(str)) for _, c in copies[1:])
        same_meta = all(c[["Date", "Time"]].astype(str).equals(df[["Date", "Time"]].astype(str)) for _, c in copies[1:])
        numbers = df["Number"].value_counts()
        notes.append(f"{unit}: {len(df):,} rows, Number " + ", ".join(f"{k} ({v:,} rows)" for k, v in numbers.items())
                     + f"; labels {'identical' if same_labels else 'DIFFER'} in all copies, "
                     f"date and time {'identical' if same_meta else 'differ'} "
                     f"(dates: {', '.join(sorted({str(d) for _, c in copies for d in c['Date'].unique()}))})")
        if not same_labels:
            raise ValueError(f"{unit}: copies of one recording have different labels; decide which to use")
        parts.append(pd.DataFrame({
            "individual_id": unit,
            "time": date_time(df["Date"], df["Time"]),
            "x_raw": df["x"], "y_raw": df["y"], "z_raw": df["z"],
            "label": df["Behaviour"],
            "source_file": f"{DATA_DIR}/{copies[0][0]}{SUFFIX}",
        }))

    samples, segments, burst_notes = burst_samples(pd.concat(parts, ignore_index=True),
                                                   native_hz(DATASET, SETTING), BURST_SAMPLES, SETTING)
    return samples, segments, burst_notes + notes
