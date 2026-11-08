# features.py
#
# Purpose:
# - Computes the 26 window features of the thesis (06_feature_extraction.R; D21) from the
#   model windows in data/windows/<dataset>/windows.parquet (25 Hz, x/y/z in g).
# - All features use the dynamic acceleration (axis minus its window mean), as in the
#   thesis; posture (the static part) is not a feature.
#   vedba = sqrt(dx^2 + dy^2 + dz^2), odba = |dx| + |dy| + |dz| per sample;
#   vedba_mean/sd/max, odba_mean/sd; per axis sd, rms, iqr, skewness, excess kurtosis,
#   zero crossings; dominant frequency, spectral centroid and normalized spectral entropy
#   of the vedba series (mean removed, FFT without the 0-Hz bin).
#   sd uses n - 1 (R var), rms and the moments of skewness and kurtosis use n, iqr the
#   default quantiles of R (type 7), as in the thesis script.
# - Output: data/features/<dataset>/features.parquet, one row per window in the order of
#   windows.parquet (window keys and features).
# - --variant C: the windows of make_windows.py --variant C (data/windows_C/ -> data/features_C/).
#
# Usage (from the project folder, venv active):
#   python 01_Preprocessing/features.py Cattle_dataset_1   # one or more datasets
#   python 01_Preprocessing/features.py                    # all windowed datasets
#   python 01_Preprocessing/features.py --variant C        # sensitivity windows (D11)

from __future__ import annotations

import argparse
import json
import re
import time
from pathlib import Path

import numpy as np
import pandas as pd
import pyarrow.parquet as pq

ROOT = Path(__file__).resolve().parents[1]
WINDOW_DIR = ROOT / "data" / "windows"
FEATURE_DIR = ROOT / "data" / "features"
SETTINGS = ROOT / "config" / "pipeline_settings.json"

KEYS = ["dataset_id", "individual_id", "segment_id", "window_in_segment", "non_overlapping"]
FEATURE_COLS = [
    "vedba_mean", "vedba_sd", "vedba_max",
    "odba_mean", "odba_sd",
    "sd_x", "sd_y", "sd_z",
    "rms_x", "rms_y", "rms_z",
    "iqr_x", "iqr_y", "iqr_z",
    "skew_x", "skew_y", "skew_z",
    "kurt_x", "kurt_y", "kurt_z",
    "zero_cross_x", "zero_cross_y", "zero_cross_z",
    "spec_dom_freq_mag", "spec_centroid_mag", "spec_entropy_mag",
]
BATCH_ROWS = 50_000


def log(msg: str) -> None:
    print(msg, flush=True)


def signal_columns(names: list[str]) -> dict[str, list[str]]:
    return {axis: sorted(c for c in names if re.fullmatch(rf"{axis}_\d{{3}}", c)) for axis in "xyz"}


def moments(dyn: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    # Skewness and excess kurtosis with the sd of n - 1, 0 where the sd is 0.
    sd = dyn.std(axis=1, ddof=1)
    centered = dyn - dyn.mean(axis=1, keepdims=True)
    with np.errstate(divide="ignore", invalid="ignore"):
        skew = np.where(sd > 0, (centered ** 3).mean(axis=1) / sd ** 3, 0.0)
        kurt = np.where(sd > 0, (centered ** 4).mean(axis=1) / sd ** 4 - 3.0, 0.0)
    return np.nan_to_num(skew, nan=0.0, posinf=0.0, neginf=0.0), np.nan_to_num(kurt, nan=0.0, posinf=0.0, neginf=0.0)


def spectral(series: np.ndarray, hz: float) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n = series.shape[1]
    centered = series - series.mean(axis=1, keepdims=True)
    power = np.abs(np.fft.fft(centered, axis=1)) ** 2
    keep = np.arange(1, n // 2 + 1)
    power = power[:, keep]
    freqs = keep * hz / n
    total = power.sum(axis=1)
    dom = freqs[np.argmax(power, axis=1)]
    with np.errstate(divide="ignore", invalid="ignore"):
        centroid = (power * freqs).sum(axis=1) / total
        p = power / total[:, None]
        entropy = -(p * np.log(np.maximum(p, np.finfo(float).eps))).sum(axis=1) / np.log(len(freqs))
    flat = ~(total > 0)
    dom[flat], centroid[flat], entropy[flat] = 0.0, 0.0, 0.0
    return dom, np.nan_to_num(centroid), np.nan_to_num(entropy)


def window_features(x: np.ndarray, y: np.ndarray, z: np.ndarray, hz: float) -> pd.DataFrame:
    dyn = {a: v - v.mean(axis=1, keepdims=True) for a, v in zip("xyz", (x, y, z))}
    vedba = np.sqrt(dyn["x"] ** 2 + dyn["y"] ** 2 + dyn["z"] ** 2)
    odba = np.abs(dyn["x"]) + np.abs(dyn["y"]) + np.abs(dyn["z"])
    out = {
        "vedba_mean": vedba.mean(axis=1), "vedba_sd": vedba.std(axis=1, ddof=1), "vedba_max": vedba.max(axis=1),
        "odba_mean": odba.mean(axis=1), "odba_sd": odba.std(axis=1, ddof=1),
    }
    for a in "xyz":
        out[f"sd_{a}"] = dyn[a].std(axis=1, ddof=1)
    for a in "xyz":
        out[f"rms_{a}"] = np.sqrt((dyn[a] ** 2).mean(axis=1))
    for a in "xyz":
        q1, q3 = np.quantile(dyn[a], [0.25, 0.75], axis=1)
        out[f"iqr_{a}"] = q3 - q1
    skew_kurt = {a: moments(dyn[a]) for a in "xyz"}
    for a in "xyz":
        out[f"skew_{a}"] = skew_kurt[a][0]
    for a in "xyz":
        out[f"kurt_{a}"] = skew_kurt[a][1]
    for a in "xyz":
        s = np.sign(dyn[a])
        out[f"zero_cross_{a}"] = ((s[:, :-1] * s[:, 1:]) < 0).sum(axis=1).astype(float)
    out["spec_dom_freq_mag"], out["spec_centroid_mag"], out["spec_entropy_mag"] = spectral(vedba, hz)
    return pd.DataFrame(out)[FEATURE_COLS]


def dataset_features(dataset: str, hz: float) -> pd.DataFrame:
    path = WINDOW_DIR / dataset / "windows.parquet"
    pf = pq.ParquetFile(path)
    cols = signal_columns(pf.schema_arrow.names)
    if not all(cols.values()) or len({len(c) for c in cols.values()}) != 1:
        raise ValueError(f"{path.name}: signal columns x_000 ... z_nnn not found")
    parts = []
    for batch in pf.iter_batches(batch_size=BATCH_ROWS, columns=KEYS + cols["x"] + cols["y"] + cols["z"]):
        df = batch.to_pandas()
        arrays = [df[cols[a]].to_numpy(dtype="float64") for a in "xyz"]
        feats = window_features(*arrays, hz)
        parts.append(pd.concat([df[KEYS].reset_index(drop=True), feats.astype("float32")], axis=1))
    return pd.concat(parts, ignore_index=True)


def main() -> int:
    global WINDOW_DIR, FEATURE_DIR
    settings = json.loads(SETTINGS.read_text(encoding="utf-8"))
    parser = argparse.ArgumentParser(description="Compute the window features (D21).")
    parser.add_argument("datasets", nargs="*", help="Dataset IDs (default: all windowed datasets)")
    parser.add_argument("--variant", choices=sorted(settings.get("variants", {})),
                        help="window variant of pipeline_settings.json (D11)")
    args = parser.parse_args()
    hz = float(settings["target_hz"])
    if args.variant:
        WINDOW_DIR, FEATURE_DIR = ROOT / "data" / f"windows_{args.variant}", ROOT / "data" / f"features_{args.variant}"

    available = sorted(p.parent.name for p in WINDOW_DIR.glob("*/windows.parquet"))
    datasets = args.datasets or available
    failed = [d for d in datasets if d not in available]
    if failed:
        log(f"[ERROR] No windows (run 01_Preprocessing/make_windows.py): {', '.join(failed)}")
    for dataset in [d for d in datasets if d in available]:
        start = time.time()
        try:
            feats = dataset_features(dataset, hz)
        except Exception as exc:
            failed.append(dataset)
            log(f"[ERROR] {dataset}: {type(exc).__name__}: {exc}")
            continue
        bad = ~np.isfinite(feats[FEATURE_COLS].to_numpy()).all(axis=1)
        out_dir = FEATURE_DIR / dataset
        out_dir.mkdir(parents=True, exist_ok=True)
        feats.to_parquet(out_dir / "features.parquet", index=False)
        log(f"[OK] {dataset}: {len(feats):,} windows, {int(bad.sum()):,} with non-finite features "
            f"({time.time() - start:.0f} s)")
    if failed:
        log(f"[ERROR] Features missing for: {', '.join(failed)}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
