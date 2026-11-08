# make_windows.py
#
# Purpose:
# - Builds the model windows from the harmonized samples (data/processed/<dataset>/),
#   following decisions D04-D07 and the settings in config/pipeline_settings.json:
#   each segment is resampled to target_hz with a polyphase filter (anti-aliasing,
#   time axis kept), windows of window_s are placed every step_s from the segment start,
#   and labels are assigned afterwards.
# - Every window is kept with its label information (pure, majority label and share,
#   unlabeled samples, samples per original label), so the primary analysis (pure
#   windows) and the sensitivity analysis with majority labels use the same file.
#   non_overlapping marks the windows on the window_s grid (evaluation windows, D08).
# - Output: data/windows/<dataset>/windows.parquet
#   Report: 01_Preprocessing/reports/pipeline_reports/<dataset>_windows.txt
#   Summary: 01_Preprocessing/reports/pipeline_reports/window_summary.csv (one row per dataset
#            and original label; rows of the processed datasets are replaced)
# - --variant C: the window settings of the variant in pipeline_settings.json (D11
#   sensitivity C, 2.4 s windows without overlap) into data/windows_C/, reports with "_C".
# - A dataset that is not harmonized or fails is reported (error in its report), the
#   others are still processed.
#
# Usage (from the project folder, venv active):
#   python 01_Preprocessing/make_windows.py Cattle_dataset_1     # one or more datasets
#   python 01_Preprocessing/make_windows.py                      # all harmonized datasets
#   python 01_Preprocessing/make_windows.py --variant C          # sensitivity windows (D11)

from __future__ import annotations

import argparse
import json
import time
import traceback
from collections import Counter
from fractions import Fraction
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[1]
PROCESSED_DIR = ROOT / "data" / "processed"
WINDOW_DIR = ROOT / "data" / "windows"
REPORT_DIR = ROOT / "01_Preprocessing" / "reports" / "pipeline_reports"
SUMMARY_CSV = REPORT_DIR / "window_summary.csv"
SETTINGS = ROOT / "config" / "pipeline_settings.json"
UNLABELED = -1
UNLABELED_TEXT = "(unlabeled)"
WIDTH = 100


def log(msg: str) -> None:
    print(msg, flush=True)


def section(title: str) -> list[str]:
    return ["", "=" * WIDTH, title, "=" * WIDTH]


# =========================================================
# Resampling and windows
# =========================================================
def resample_ratio(native_hz: float, target_hz: float, max_denominator: int) -> tuple[int, int]:
    ratio = Fraction(target_hz / native_hz).limit_denominator(max_denominator)
    return ratio.numerator, ratio.denominator


def resample_segment(xyz: np.ndarray, codes: np.ndarray, up: int, down: int, padtype: str) -> tuple[np.ndarray, np.ndarray]:
    if up == down:
        return xyz, codes
    out = resample_poly(xyz, up, down, axis=0, padtype=padtype)
    # Label of the original sample nearest in time to each new sample.
    idx = np.clip(np.rint(np.arange(len(out)) * down / up).astype(int), 0, len(codes) - 1)
    return out, codes[idx]


def window_segment(xyz: np.ndarray, codes: np.ndarray, length: int, step: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    # Returns window starts (samples), signal windows (n, length, 3) and label windows (n, length).
    if len(xyz) < length:
        return np.empty(0, dtype=int), np.empty((0, length, 3)), np.empty((0, length), dtype=int)
    starts = np.arange(0, len(xyz) - length + 1, step)
    sig = np.lib.stride_tricks.sliding_window_view(xyz, length, axis=0)[starts]  # (n, 3, length)
    lab = np.lib.stride_tricks.sliding_window_view(codes, length)[starts]
    return starts, np.transpose(sig, (0, 2, 1)), lab


def label_info(lab: np.ndarray, names: list[str]) -> pd.DataFrame:
    first = lab[:, 0]
    pure = (lab == first[:, None]).all(axis=1) & (first != UNLABELED)
    has_unlabeled = (lab == UNLABELED).any(axis=1)
    majority = np.where(pure, first, UNLABELED)
    share = np.where(pure, 1.0, 0.0)
    to_name = lambda c: names[c] if c != UNLABELED else None
    # Samples per original label ("GEH=30;REN=20"), so classes can be assigned later
    # (01_Preprocessing/assign_classes.py) without building the windows again.
    counts = [f"{names[c]}={lab.shape[1]}" if p else "" for c, p in zip(first, pure)]
    for i in np.flatnonzero(~pure):
        per_label = Counter(lab[i]).most_common()
        majority[i], share[i] = per_label[0][0], per_label[0][1] / lab.shape[1]
        counts[i] = ";".join(f"{to_name(c) or UNLABELED_TEXT}={n}" for c, n in per_label)
    return pd.DataFrame({
        "pure": pure,
        "label": [to_name(c) if p else None for c, p in zip(first, pure)],
        "label_majority": [to_name(c) for c in majority],
        "majority_share": share.astype("float32"),
        "has_unlabeled": has_unlabeled,
        "label_counts": counts,
    })


def make_windows(dataset: str, settings: dict) -> tuple[pd.DataFrame, dict]:
    samples = pd.read_parquet(PROCESSED_DIR / dataset / "samples.parquet")
    segments = pd.read_parquet(PROCESSED_DIR / dataset / "segments.parquet").set_index("segment_id")

    target = settings["target_hz"]
    length = int(round(settings["window_s"] * target))
    step = int(round(settings["step_s"] * target))
    names = sorted(samples["label"].dropna().unique().tolist())
    code_of = {n: i for i, n in enumerate(names)}
    codes_all = samples["label"].map(code_of).fillna(UNLABELED).astype(int).to_numpy()
    xyz_all = samples[["x", "y", "z"]].to_numpy(dtype="float64")
    bounds = np.flatnonzero(np.diff(samples["segment_id"].to_numpy())) + 1
    seg_ids = samples["segment_id"].to_numpy()[np.concatenate([[0], bounds])]

    parts = []
    stats = Counter()
    ratios = Counter()
    for seg_id, xyz, codes in zip(seg_ids, np.split(xyz_all, bounds), np.split(codes_all, bounds)):
        seg = segments.loc[seg_id]
        up, down = resample_ratio(seg["native_hz"], target, settings["resample_max_denominator"])
        ratios[(seg["native_hz"], up, down)] += 1
        xyz_r, codes_r = resample_segment(xyz, codes, up, down, settings["resample_padtype"])
        starts, sig, lab = window_segment(xyz_r, codes_r, length, step)
        stats["segments"] += 1
        stats["samples"] += len(codes)
        stats["labeled_samples"] += int((codes != UNLABELED).sum())
        if len(starts) == 0:
            stats["segments_too_short"] += 1
            stats["samples_too_short"] += len(codes)
            stats["labeled_samples_too_short"] += int((codes != UNLABELED).sum())
            continue
        info = label_info(lab, names)
        info.insert(0, "dataset_id", dataset)
        info.insert(1, "individual_id", seg["individual_id"])
        info.insert(2, "segment_id", int(seg_id))
        info.insert(3, "window_in_segment", np.arange(len(starts), dtype="int32"))
        info.insert(4, "start_s", (starts / target).astype("float32"))
        info.insert(5, "non_overlapping", (starts % length) == 0)
        flat = sig.astype("float32").transpose(0, 2, 1).reshape(len(starts), 3 * length)
        cols = [f"{a}_{i:03d}" for a in "xyz" for i in range(length)]
        parts.append(pd.concat([info, pd.DataFrame(flat, columns=cols)], axis=1))

    windows = pd.concat(parts, ignore_index=True) if parts else pd.DataFrame()
    stats["length"], stats["step"] = length, step
    stats["ratios"] = ratios
    stats["segment_duration"] = segments["duration_s"].describe()
    return windows, stats


# =========================================================
# Report and summary
# =========================================================
def report(dataset: str, windows: pd.DataFrame, stats: dict, settings: dict, seconds: float, variant: str | None) -> list[str]:
    target = settings["target_hz"]
    lines = [
        f"WINDOW REPORT: {dataset}" + (f" (variant {variant})" if variant else ""),
        f"Created: {time.strftime('%Y-%m-%d %H:%M:%S')} with 01_Preprocessing/make_windows.py ({seconds:.0f} s)",
        f"Settings: {target} Hz, window {settings['window_s']} s ({stats['length']} samples), "
        f"step {settings['step_s']} s ({stats['step']} samples), padtype {settings['resample_padtype']}",
    ]
    lines += section("1. SEGMENTS")
    d = stats["segment_duration"]
    lines += [
        f"  Segments: {stats['segments']:,}; duration min {d['min']:.2f} s, median {d['50%']:.2f} s, max {d['max']:.2f} s",
        f"  Segments shorter than one window (no window): {stats['segments_too_short']:,}, holding "
        f"{stats['samples_too_short']:,} of {stats['samples']:,} samples ({stats['samples_too_short'] / max(stats['samples'], 1):.1%}) and "
        f"{stats['labeled_samples_too_short']:,} of {stats['labeled_samples']:,} labeled samples "
        f"({stats['labeled_samples_too_short'] / max(stats['labeled_samples'], 1):.1%})",
        "  Resampling: " + "; ".join(f"{hz:g} Hz x {u}/{dn} ({n:,} segments)" for (hz, u, dn), n in stats["ratios"].items()),
    ]
    lines += section("2. WINDOWS")
    if windows.empty:
        return lines + ["  (no windows)"]
    nov = windows["non_overlapping"]
    for title, sub in [("all windows (training)", windows), ("non-overlapping (evaluation)", windows[nov])]:
        mixed = (~sub["pure"]) & (~sub["has_unlabeled"])
        lines += [
            f"  {title}: {len(sub):,}",
            f"    pure: {int(sub['pure'].sum()):,}; mixed labels: {int(mixed.sum()):,}; "
            f"with unlabeled samples: {int(sub['has_unlabeled'].sum()):,}",
        ]
    lines += section("3. PURE WINDOWS PER ORIGINAL LABEL")
    pure = windows[windows["pure"]]
    table = pure.groupby("label").agg(
        windows=("segment_id", "size"),
        non_overlapping=("non_overlapping", "sum"),
        segments=("segment_id", "nunique"),
        individuals=("individual_id", "nunique"),
    ).sort_values("windows", ascending=False)
    lines += ["  " + ln for ln in table.to_string().splitlines()]
    lines += section("4. EXCLUDED WINDOWS PER MAJORITY LABEL (mixed or unlabeled)")
    excl = windows[~windows["pure"]]
    if excl.empty:
        lines.append("  (none)")
    else:
        t2 = excl.groupby(excl["label_majority"].fillna("(unlabeled)")).agg(
            windows=("segment_id", "size"), median_share=("majority_share", "median")).sort_values("windows", ascending=False)
        lines += ["  " + ln for ln in t2.to_string().splitlines()]
    lines += section("5. PURE WINDOWS PER INDIVIDUAL AND LABEL")
    cross = pd.crosstab(pure["individual_id"], pure["label"])
    lines += ["  " + ln for ln in cross.to_string().splitlines()]
    return lines


def update_summary(dataset: str, windows: pd.DataFrame, stats: dict) -> None:
    cols = ["dataset_id", "label", "pure_windows", "pure_non_overlapping", "segments", "individuals",
            "segments_total", "segments_too_short", "windows_total", "windows_excluded"]
    rows = []
    if not windows.empty:
        pure = windows[windows["pure"]]
        for label, sub in pure.groupby("label"):
            rows.append([dataset, label, len(sub), int(sub["non_overlapping"].sum()), sub["segment_id"].nunique(),
                         sub["individual_id"].nunique(), stats["segments"], stats["segments_too_short"],
                         len(windows), int((~windows["pure"]).sum())])
    new = pd.DataFrame(rows, columns=cols)
    if SUMMARY_CSV.exists():
        old = pd.read_csv(SUMMARY_CSV)
        new = pd.concat([old[old["dataset_id"] != dataset], new], ignore_index=True)
    new.sort_values(["dataset_id", "label"]).to_csv(SUMMARY_CSV, index=False)


def main() -> int:
    global WINDOW_DIR, SUMMARY_CSV
    settings = json.loads(SETTINGS.read_text(encoding="utf-8"))
    parser = argparse.ArgumentParser(description="Build model windows from the harmonized samples.")
    parser.add_argument("datasets", nargs="*", help="Dataset IDs (default: all harmonized datasets)")
    parser.add_argument("--variant", choices=sorted(settings.get("variants", {})),
                        help="window variant of pipeline_settings.json (D11), with its own folder and reports")
    args = parser.parse_args()
    suffix = f"_{args.variant}" if args.variant else ""
    if args.variant:
        settings = {**settings, **settings["variants"][args.variant]}
        WINDOW_DIR, SUMMARY_CSV = ROOT / "data" / f"windows{suffix}", REPORT_DIR / f"window_summary{suffix}.csv"
    available = sorted(p.parent.name for p in PROCESSED_DIR.glob("*/samples.parquet"))
    datasets = args.datasets or available
    missing = [d for d in datasets if d not in available]
    if missing:
        log(f"[ERROR] Not harmonized (see the harmonization reports): {', '.join(missing)}")

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    failed = list(missing)
    for dataset in [d for d in datasets if d not in missing]:
        start = time.time()
        log(f"[INFO] {dataset}: building windows")
        report_file = REPORT_DIR / f"{dataset}_windows{suffix}.txt"
        try:
            windows, stats = make_windows(dataset, settings)
        except Exception as exc:
            failed.append(dataset)
            report_file.write_text(f"WINDOW REPORT: {dataset}\nCreated: {time.strftime('%Y-%m-%d %H:%M:%S')} "
                                   f"with 01_Preprocessing/make_windows.py\n\nFAILED\n\n{traceback.format_exc()}", encoding="utf-8")
            log(f"[ERROR] {dataset}: {type(exc).__name__}: {exc} (details in {report_file.relative_to(ROOT)})")
            continue
        out_dir = WINDOW_DIR / dataset
        out_dir.mkdir(parents=True, exist_ok=True)
        windows.to_parquet(out_dir / "windows.parquet", index=False)
        lines = report(dataset, windows, stats, settings, time.time() - start, args.variant)
        report_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        update_summary(dataset, windows, stats)
        log(f"[OK] {dataset}: {len(windows):,} windows ({time.time() - start:.0f} s)")
    if failed:
        log(f"[ERROR] Windowing failed for: {', '.join(failed)}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
