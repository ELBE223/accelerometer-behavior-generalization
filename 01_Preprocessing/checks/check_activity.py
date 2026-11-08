# check_activity.py
#
# Purpose:
# - Plausibility check of the labels: movement intensity (median VeDBA of the evaluation
#   windows, in g) per dataset, individual and original label or class. Locomotion should
#   be clearly more intense than Resting in every individual; where it is not, the labels
#   may not fit the data.
# - Input: data/features/<dataset>/features.parquet, data/windows/<dataset>/windows.parquet
#   (original label of pure windows) and classes.parquet.
# - Output: 01_Preprocessing/reports/pipeline_reports/activity_check.txt and activity_levels.csv
#
# Usage (from the project folder, venv active):
#   python 01_Preprocessing/checks/check_activity.py

from __future__ import annotations

import time
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
WINDOW_DIR = ROOT / "data" / "windows"
FEATURE_DIR = ROOT / "data" / "features"
REPORT_DIR = ROOT / "01_Preprocessing" / "reports" / "pipeline_reports"
CLASSES = ["Foraging", "Locomotion", "Resting", "Other"]
MIN_WINDOWS = 5   # fewer windows of an individual and class: no median shown
RATIO_FLAG = 2.0  # Locomotion should be at least this many times as intense as Resting
WIDTH = 100


def log(msg: str) -> None:
    print(msg, flush=True)


def load(dataset: str) -> pd.DataFrame:
    feats = pd.read_parquet(FEATURE_DIR / dataset / "features.parquet",
                            columns=["individual_id", "non_overlapping", "vedba_mean"])
    labels = pd.read_parquet(WINDOW_DIR / dataset / "windows.parquet", columns=["label"])
    classes = pd.read_parquet(WINDOW_DIR / dataset / "classes.parquet", columns=["class"])
    if not (len(feats) == len(labels) == len(classes)):
        raise ValueError(f"{dataset}: features, windows and classes differ in length; run the pipeline again")
    df = feats.assign(label=labels["label"].to_numpy(), cls=classes["class"].to_numpy())
    return df[df["non_overlapping"]]


def medians(df: pd.DataFrame, column: str) -> pd.DataFrame:
    g = df[df[column].notna()].groupby(["individual_id", column])["vedba_mean"]
    table = g.median().where(g.size() >= MIN_WINDOWS).unstack(column)
    return table


def dataset_section(dataset: str, df: pd.DataFrame, rows: list[dict]) -> list[str]:
    lines = ["", "=" * WIDTH, dataset, "=" * WIDTH]
    for (ind, label), g in df[df["label"].notna()].groupby(["individual_id", "label"]):
        cls = g["cls"].dropna()
        rows.append({"dataset_id": dataset, "individual_id": ind, "label": label,
                     "class": cls.iloc[0] if len(cls) else "", "windows": len(g),
                     "vedba_median": g["vedba_mean"].median(), "vedba_p25": g["vedba_mean"].quantile(0.25),
                     "vedba_p75": g["vedba_mean"].quantile(0.75)})

    by_class = medians(df, "cls").reindex(columns=[c for c in CLASSES if c in set(df["cls"].dropna())])
    lines += ["", "  Median VeDBA (g) per individual and class (evaluation windows; empty: fewer than 5):", ""]
    lines += ["  " + ln for ln in by_class.round(3).to_string().splitlines()]

    by_label = medians(df, "label")
    order = df[df["label"].notna()].groupby("label")["vedba_mean"].median().sort_values().index
    by_label = by_label.reindex(columns=order)
    lines += ["", "  Median VeDBA (g) per individual and original label (labels ordered by intensity):", ""]
    lines += ["  " + ln for ln in by_label.round(3).to_string().splitlines()]

    if {"Locomotion", "Resting"} <= set(by_class.columns):
        ratio = by_class["Locomotion"] / by_class["Resting"]
        flagged = ratio[ratio < RATIO_FLAG].dropna()
        lines += ["", "  Locomotion / Resting intensity per individual: "
                      + ", ".join(f"{i} {r:.1f}" for i, r in ratio.dropna().items())]
        lines.append(f"  Individuals with Locomotion less than {RATIO_FLAG:g} times as intense as Resting: "
                     + (", ".join(flagged.index) if len(flagged) else "none"))
    return lines


def main() -> int:
    datasets = sorted(p.parent.name for p in FEATURE_DIR.glob("*/features.parquet")
                      if (WINDOW_DIR / p.parent.name / "classes.parquet").exists())
    if not datasets:
        log("[ERROR] No datasets with features and classes")
        return 1
    lines = ["ACTIVITY CHECK",
             f"Created: {time.strftime('%Y-%m-%d %H:%M:%S')} with 01_Preprocessing/checks/check_activity.py",
             "Movement intensity: median of the window mean of VeDBA (g), evaluation windows only."]
    rows: list[dict] = []
    for dataset in datasets:
        try:
            lines += dataset_section(dataset, load(dataset), rows)
        except Exception as exc:
            lines += ["", f"{dataset}: FAILED {type(exc).__name__}: {exc}"]
            log(f"[ERROR] {dataset}: {exc}")
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    (REPORT_DIR / "activity_check.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    out = pd.DataFrame(rows)
    for col in ["vedba_median", "vedba_p25", "vedba_p75"]:
        out[col] = out[col].astype(float).round(4)
    out.to_csv(REPORT_DIR / "activity_levels.csv", index=False)
    log(f"[OK] activity_check.txt for {len(datasets)} datasets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
