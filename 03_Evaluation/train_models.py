# train_models.py
#
# Purpose:
# - Trains and evaluates the classifiers of 02_Models/models.py (Random Forest and LightGBM on
#   the window features, D21-D22; CNN, ResNet, HYDRA and MultiRocket on the window
#   signals, D25) with the classes of data/windows/<dataset>/classes.parquet (D10), in the
#   evaluation modes of D23 and with the seeds of D24. All models get the same training
#   and test windows:
#   within    leave-one-individual-out per dataset; test individuals need all classes with
#             at least 10 evaluation windows (D12); predictions of all folds pooled
#   cross     train on all other datasets, test on one
#   pairwise  train on dataset A, test on dataset B (all ordered pairs; same-species pairs
#             flagged)
# - Training: windows with overlap (D08), at least 30 per class, at most 250 per class
#   (per dataset and class when several datasets are pooled), spread over segments
#   (D09). Test: all non-overlapping windows with a class.
# - Metrics: accuracy and macro precision, recall and F1 over the classes
#   of the analysis (a class without test windows counts 0), and per class.
# - Scenarios (D11): primary; A (training without overlap); majority (class of >= 80 % of
#   the samples instead of pure windows); four_classes (with Other); E (ridden gaits as
#   Locomotion); F (only individuals that meet the test-unit rule, in all modes); C (2.4 s
#   windows without overlap: data/windows_C/ and data/features_C/ of make_windows.py,
#   assign_classes.py and features.py --variant C).
# - Output: 03_Evaluation/results/<scenario>/<model>/metrics.csv, confusion.csv, within_folds.csv,
#   training_sets.csv, importance.csv (rf, lgbm), skipped.csv; 03_Evaluation/results/<scenario>/
#   summary.txt over all models with results. A run replaces the folders of its models
#   only; with --add it keeps their results of other seeds and adds its seeds (a long run
#   can be split into one run per seed).
#
# Usage (from the project folder, venv active):
#   python 03_Evaluation/train_models.py                                   # rf + lgbm, primary, seeds 42-46
#   python 03_Evaluation/train_models.py --models cnn resnet hydra multirocket
#   python 03_Evaluation/train_models.py --models rf --modes within --seeds 42 --scenario A
#   python 03_Evaluation/train_models.py --models cnn resnet hydra multirocket --seeds 43 44 --add   # add seeds

from __future__ import annotations

import argparse
import csv
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
import pyarrow.parquet as pq

# The window features (01_Preprocessing/features.py) and the classifiers
# (02_Models/models.py) are imported from their own folders.
sys.path[:0] = [str(Path(__file__).resolve().parents[1] / folder) for folder in ("01_Preprocessing", "02_Models")]

from features import FEATURE_COLS, KEYS  # noqa: E402
from models import INPUT, MODEL_NAMES, make_model, predict_in_chunks  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
WINDOW_DIR = ROOT / "data" / "windows"
FEATURE_DIR = ROOT / "data" / "features"
RESULT_DIR = ROOT / "03_Evaluation" / "results"
DATASETS_CSV = ROOT / "00_Documentation" / "datasets.csv"

MAIN_CLASSES = ["Foraging", "Locomotion", "Resting"]
SCENARIOS = {
    "primary": dict(label="class", classes=MAIN_CLASSES, train_overlap=True, eligible_only=False),
    "A": dict(label="class", classes=MAIN_CLASSES, train_overlap=False, eligible_only=False),
    "majority": dict(label="majority", classes=MAIN_CLASSES, train_overlap=True, eligible_only=False),
    "four_classes": dict(label="class", classes=MAIN_CLASSES + ["Other"], train_overlap=True, eligible_only=False),
    "E": dict(label="class_sensitivity", classes=MAIN_CLASSES, train_overlap=True, eligible_only=False),
    "F": dict(label="class", classes=MAIN_CLASSES, train_overlap=True, eligible_only=True),
    "C": dict(label="class", classes=MAIN_CLASSES, train_overlap=False, eligible_only=False, variant="C"),
}
MAJORITY_SHARE = 0.8         # D11
MIN_TRAIN_PER_CLASS = 30     # training windows per class at least
MIN_TEST_PER_CLASS = 5       # cross, pairwise: at least two classes with this many test windows
MIN_TEST_CLASSES = 2
MIN_INDIVIDUAL_WINDOWS = 10  # test-unit rule for within-dataset test individuals (D12)
CAP_PER_CLASS = 250          # training windows per dataset and class at most (D09)
MODES = ["within", "cross", "pairwise"]
SIGNALS: np.ndarray | None = None  # window signals (n x 3 x samples), rows as in the data table


def log(msg: str) -> None:
    print(msg, flush=True)


# =========================================================
# Data
# =========================================================
def read_species() -> dict[str, str]:
    with DATASETS_CSV.open(newline="", encoding="utf-8") as fh:
        return {r["dataset_id"]: r["species"] for r in csv.DictReader(fh)}


def read_signals(window_dir: Path, dataset: str, keep: np.ndarray) -> np.ndarray:
    # Signal columns x_000 ... z_nnn of the windows with a class, as n x 3 x samples.
    pf = pq.ParquetFile(window_dir / dataset / "windows.parquet")
    names = pf.schema_arrow.names
    axes = [sorted(c for c in names if re.fullmatch(rf"{a}_\d{{3}}", c)) for a in "xyz"]
    table = pf.read(columns=axes[0] + axes[1] + axes[2]).to_pandas()
    arr = np.stack([table[cols].to_numpy(dtype=np.float32) for cols in axes], axis=1)
    return arr[keep]


def load_data(scenario: dict, with_signals: bool) -> tuple[pd.DataFrame, np.ndarray | None]:
    parts, signal_parts = [], []
    suffix = f"_{scenario['variant']}" if scenario.get("variant") else ""
    window_dir, feature_dir = WINDOW_DIR.parent / f"{WINDOW_DIR.name}{suffix}", FEATURE_DIR.parent / f"{FEATURE_DIR.name}{suffix}"
    for path in sorted(feature_dir.glob("*/features.parquet")):
        dataset = path.parent.name
        classes_path = window_dir / dataset / "classes.parquet"
        if not classes_path.exists():
            log(f"[WARN] {dataset}: features but no classes.parquet (run 01_Preprocessing/assign_classes.py); left out")
            continue
        feats = pd.read_parquet(path)
        classes = pd.read_parquet(classes_path)
        if len(feats) != len(classes) or not feats[KEYS].reset_index(drop=True).equals(classes[KEYS].reset_index(drop=True)):
            raise ValueError(f"{dataset}: features and classes do not belong to the same windows; "
                             "run 01_Preprocessing/features.py and 01_Preprocessing/assign_classes.py again")
        if scenario["label"] == "majority":
            label = classes["class_majority"].where(classes["class_share"] >= MAJORITY_SHARE)
        else:
            label = classes[scenario["label"]]
        df = feats.copy()
        df["label"] = label.to_numpy()
        keep = df["label"].isin(scenario["classes"]).to_numpy()
        parts.append(df[keep])
        if with_signals:
            signal_parts.append(read_signals(window_dir, dataset, keep))
    if not parts:
        raise FileNotFoundError(f"No datasets with features and classes in {feature_dir.name}/ (run 01_Preprocessing/features.py"
                                + (f" --variant {scenario['variant']})" if suffix else ")"))
    # The row index of the table is the row of the signal array.
    data = pd.concat(parts, ignore_index=True)
    data["label"] = data["label"].astype(str)
    data["individual_key"] = data["dataset_id"] + "__" + data["individual_id"].astype(str)
    signals = np.concatenate(signal_parts) if with_signals else None
    if signals is not None and len(signals) != len(data):
        raise ValueError("signals and windows do not match")
    return data, signals


def test_unit_rule(data: pd.DataFrame, classes: list[str]) -> set[str]:
    # Individuals with all classes and at least MIN_INDIVIDUAL_WINDOWS evaluation windows each.
    test = data[data["non_overlapping"]]
    counts = pd.crosstab(test["individual_key"], test["label"]).reindex(columns=classes, fill_value=0)
    return set(counts.index[(counts >= MIN_INDIVIDUAL_WINDOWS).all(axis=1)])


# =========================================================
# Training sets, models, metrics
# =========================================================
def training_windows(df: pd.DataFrame, overlap: bool) -> pd.DataFrame:
    return df if overlap else df[df["non_overlapping"]]


def spread_cap(df: pd.DataFrame, group_cols: list[str], n_cap: int, rng: np.random.Generator) -> pd.DataFrame:
    # D09: at most one window per segment first (random), then a second, and so on.
    tmp = df.assign(_r=rng.random(len(df))).sort_values("_r")
    tmp["_round"] = tmp.groupby(group_cols + ["dataset_id", "segment_id"]).cumcount()
    tmp = tmp.sort_values(group_cols + ["_round", "_r"])
    return tmp.groupby(group_cols, sort=False).head(n_cap).drop(columns=["_r", "_round"])


def enough_training(df: pd.DataFrame, classes: list[str]) -> tuple[bool, str]:
    counts = df["label"].value_counts()
    low = [f"{c} {int(counts.get(c, 0))}" for c in classes if counts.get(c, 0) < MIN_TRAIN_PER_CLASS]
    return (not low), ("training windows below 30: " + ", ".join(low)) if low else ""


def enough_test(df: pd.DataFrame, classes: list[str]) -> tuple[bool, str]:
    counts = df["label"].value_counts()
    n_ok = sum(counts.get(c, 0) >= MIN_TEST_PER_CLASS for c in classes)
    return n_ok >= MIN_TEST_CLASSES, f"only {n_ok} classes with at least {MIN_TEST_PER_CLASS} test windows"


def metrics(truth: np.ndarray, pred: np.ndarray, classes: list[str]) -> dict:
    out = {"n_test": len(truth), "accuracy": float((truth == pred).mean()) if len(truth) else np.nan}
    f1s, recalls, precisions = [], [], []
    for c in classes:
        tp = int(((truth == c) & (pred == c)).sum())
        support, predicted = int((truth == c).sum()), int((pred == c).sum())
        recall = tp / support if support else 0.0
        precision = tp / predicted if predicted else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        out.update({f"support_{c}": support, f"recall_{c}": recall, f"precision_{c}": precision, f"f1_{c}": f1})
        f1s.append(f1), recalls.append(recall), precisions.append(precision)
    out.update(macro_precision=float(np.mean(precisions)), macro_recall=float(np.mean(recalls)), macro_f1=float(np.mean(f1s)))
    return out


class Results:
    def __init__(self, classes: list[str]):
        self.classes = classes
        self.metrics: list[dict] = []
        self.confusion: list[dict] = []
        self.folds: list[dict] = []
        self.training: list[dict] = []
        self.skipped: list[dict] = []
        self.importance: dict[tuple, list[np.ndarray]] = defaultdict(list)

    def add(self, info: dict, truth: np.ndarray, pred: np.ndarray, extra: dict | None = None) -> None:
        self.metrics.append({**info, **(extra or {}), **metrics(truth, pred, self.classes)})
        cm = pd.crosstab(pd.Series(truth, name="truth"), pd.Series(pred, name="pred"))
        for t in self.classes:
            for p in self.classes:
                n = int(cm.loc[t, p]) if t in cm.index and p in cm.columns else 0
                self.confusion.append({**info, "truth": t, "pred": p, "n": n})

    def add_training(self, info: dict, train: pd.DataFrame) -> None:
        for cls, g in train.groupby("label"):
            self.training.append({**info, "class": cls, "windows": len(g),
                                  "segments": g[["dataset_id", "segment_id"]].drop_duplicates().shape[0],
                                  "individuals": g["individual_key"].nunique(), "datasets": g["dataset_id"].nunique()})

    def add_importance(self, model_name: str, mode: str, model) -> None:
        if not hasattr(model, "feature_importances_"):
            return
        imp = np.asarray(model.feature_importances_, dtype=float)
        if imp.sum() > 0:
            self.importance[(model_name, mode)].append(imp / imp.sum())

    def skip(self, info: dict, reason: str) -> None:
        self.skipped.append({**info, "reason": reason})


def model_input(model_name: str, rows: pd.DataFrame) -> np.ndarray:
    if INPUT[model_name] == "features":
        return rows[FEATURE_COLS].to_numpy()
    return SIGNALS[rows.index.to_numpy()]


def fit_predict(model_name: str, seed: int, train: pd.DataFrame, tests: list[pd.DataFrame], classes: list[str]):
    start = time.time()
    model = make_model(model_name, seed, classes)
    model.fit(model_input(model_name, train), train["label"].to_numpy())
    preds = [predict_in_chunks(model, model_input(model_name, t)) for t in tests]
    if INPUT[model_name] == "signals":
        log(f"    {model_name}: {len(train):,} training, {sum(len(t) for t in tests):,} test windows "
            f"({time.time() - start:.0f} s)")
    return model, preds


# =========================================================
# Modes
# =========================================================
def run_within(data, models, seed, sc, res: Results, rule: set[str]) -> None:
    classes = sc["classes"]
    for dataset, ds in data.groupby("dataset_id"):
        individuals = sorted(ds["individual_key"].unique())
        eligible = [i for i in individuals if i in rule]
        pooled = {m: ([], []) for m in models}
        n_folds = 0
        for ind in eligible:
            info = {"seed": seed, "mode": "within", "train": dataset, "test": dataset, "test_individual": ind}
            train_all = training_windows(ds[ds["individual_key"] != ind], sc["train_overlap"])
            ok, reason = enough_training(train_all, classes)
            if not ok:
                res.skip(info, reason)
                continue
            rng = np.random.default_rng([seed, n_folds])
            train = spread_cap(train_all, ["label"], CAP_PER_CLASS, rng)
            test = ds[(ds["individual_key"] == ind) & ds["non_overlapping"]]
            res.add_training(info, train)
            n_folds += 1
            for m in models:
                model, (pred,) = fit_predict(m, seed, train, [test], classes)
                res.add_importance(m, "within", model)
                truth = test["label"].to_numpy()
                pooled[m][0].append(truth)
                pooled[m][1].append(pred)
                res.folds.append({"model": m, **info, **metrics(truth, pred, classes)})
        info = {"seed": seed, "mode": "within", "train": dataset, "test": dataset}
        extra = {"individuals": len(individuals), "eligible_individuals": len(eligible), "folds": n_folds,
                 "complete": n_folds == len(individuals)}
        if not n_folds:
            res.skip(info, f"no valid fold ({len(eligible)} of {len(individuals)} individuals meet the rule)")
            continue
        for m in models:
            res.add({"model": m, **info}, np.concatenate(pooled[m][0]), np.concatenate(pooled[m][1]), extra)


def run_cross(data, models, seed, sc, res: Results, species: dict) -> None:
    classes = sc["classes"]
    for k, test_ds in enumerate(sorted(data["dataset_id"].unique())):
        info = {"seed": seed, "mode": "cross", "train": f"all except {test_ds}", "test": test_ds}
        train_all = training_windows(data[data["dataset_id"] != test_ds], sc["train_overlap"])
        test = data[(data["dataset_id"] == test_ds) & data["non_overlapping"]]
        for ok, reason in [enough_training(train_all, classes), enough_test(test, classes)]:
            if not ok:
                res.skip(info, reason)
                break
        else:
            train = spread_cap(train_all, ["dataset_id", "label"], CAP_PER_CLASS, np.random.default_rng([seed, k]))
            res.add_training(info, train)
            for m in models:
                model, (pred,) = fit_predict(m, seed, train, [test], classes)
                res.add_importance(m, "cross", model)
                res.add({"model": m, **info}, test["label"].to_numpy(), pred)


def run_pairwise(data, models, seed, sc, res: Results, species: dict) -> None:
    # One model per source dataset, tested on every other dataset (the training set of a
    # source does not depend on the target).
    classes = sc["classes"]
    datasets = sorted(data["dataset_id"].unique())
    tests = {d: data[(data["dataset_id"] == d) & data["non_overlapping"]] for d in datasets}
    for k, source in enumerate(datasets):
        targets = [t for t in datasets if t != source]
        info = {"seed": seed, "mode": "pairwise", "train": source}
        train_all = training_windows(data[data["dataset_id"] == source], sc["train_overlap"])
        ok, reason = enough_training(train_all, classes)
        if not ok:
            for t in targets:
                res.skip({**info, "test": t}, reason)
            continue
        valid = []
        for t in targets:
            ok, reason = enough_test(tests[t], classes)
            if ok:
                valid.append(t)
            else:
                res.skip({**info, "test": t}, reason)
        train = spread_cap(train_all, ["label"], CAP_PER_CLASS, np.random.default_rng([seed, k]))
        res.add_training({**info, "test": "(each other dataset)"}, train)
        for m in models:
            model, preds = fit_predict(m, seed, train, [tests[t] for t in valid], classes)
            res.add_importance(m, "pairwise", model)
            for t, pred in zip(valid, preds):
                res.add({"model": m, **info, "test": t}, tests[t]["label"].to_numpy(), pred,
                        {"same_species": species.get(source) == species.get(t)})



# =========================================================
# Output
# =========================================================
TABLES = ["metrics.csv", "confusion.csv", "within_folds.csv", "importance.csv", "training_sets.csv", "skipped.csv"]

def save_table(df: pd.DataFrame, path: Path) -> None:
    df = df.copy()
    for col in ["individuals", "eligible_individuals", "folds"]:
        if col in df.columns:
            df[col] = df[col].astype("Int64")
    for col in df.select_dtypes("float").columns:
        df[col] = df[col].round(5)
    df.to_csv(path, index=False)


def clear_folder(folder: Path) -> None:
    # Not shutil.rmtree: on exFAT drives macOS deletes the "._" file of a file together
    # with the file, and rmtree (Python < 3.13) then stops at the "._" file it listed.
    for p in folder.iterdir():
        p.unlink(missing_ok=True)


def split_flat_results(scenario_dir: Path) -> None:
    # Results of the first run (all models in one folder) into one folder per model.
    flat = scenario_dir / "metrics.csv"
    if not flat.exists():
        return
    tables = {name: pd.read_csv(scenario_dir / name) for name in TABLES if (scenario_dir / name).exists()}
    for model in tables["metrics.csv"]["model"].unique():
        out = scenario_dir / model
        out.mkdir(parents=True, exist_ok=True)
        for name, df in tables.items():
            save_table(df[df["model"] == model] if "model" in df.columns else df, out / name)
    for name in tables:
        (scenario_dir / name).unlink()


def data_info(data: pd.DataFrame, rule: set[str]) -> str:
    return (f"Windows: {len(data):,} ({int(data['non_overlapping'].sum()):,} evaluation windows); "
            f"individuals meeting the test-unit rule: {len(rule)} of {data['individual_key'].nunique()}")


def read_table(path: Path) -> pd.DataFrame:
    try:
        return pd.read_csv(path)
    except pd.errors.EmptyDataError:  # table without rows, e.g. importance.csv of the signal models
        return pd.DataFrame()


def read_previous(scenario_dir: Path, args, data_line: str) -> dict[str, dict]:
    # --add: the results of earlier runs stay and this run adds its seeds. Checked before
    # the training: no seed twice, the same modes and the same windows.
    split_flat_results(scenario_dir)
    previous = {}
    for model in args.models:
        out = scenario_dir / model
        if not (out / "metrics.csv").exists():
            continue
        where = out.relative_to(ROOT)
        tables = {name: read_table(out / name) for name in TABLES if (out / name).exists()}
        seeds = sorted(int(s) for s in tables["metrics.csv"]["seed"].unique())
        twice = sorted(set(seeds) & set(args.seeds))
        if twice:
            raise SystemExit(f"[ERROR] --add: seed(s) {', '.join(map(str, twice))} already in {where}/; "
                             "leave them out of --seeds")
        skipped = tables.get("skipped.csv", pd.DataFrame())
        modes = set(tables["metrics.csv"]["mode"]) | (set(skipped["mode"]) if "mode" in skipped.columns else set())
        if modes != set(args.modes):
            raise SystemExit(f"[ERROR] --add: {where}/ has the modes {', '.join(sorted(modes))}; "
                             f"use --modes {' '.join(m for m in MODES if m in modes)}")
        run = (out / "run.txt").read_text(encoding="utf-8").splitlines() if (out / "run.txt").exists() else []
        old_data = next((ln.split("; skipped runs")[0] for ln in run if ln.startswith("Windows:")), None)
        if old_data is None:
            log(f"[WARN] --add: {where}/ has no run.txt; not checked whether the windows are the same")
        elif old_data != data_line:
            raise SystemExit(f"[ERROR] --add: the windows changed since the run in {where}/ "
                             f"(then: {old_data}; now: {data_line}); run all seeds without --add")
        previous[model] = {"tables": tables, "seeds": seeds, "run": run}
    return previous


def merge_previous(old: dict[str, pd.DataFrame], new: dict[str, pd.DataFrame]) -> dict[str, pd.DataFrame]:
    merged = {}
    for name, df in new.items():
        parts = [d for d in (old.get(name, pd.DataFrame()), df) if not d.empty]
        both = pd.concat(parts, ignore_index=True) if parts else df
        if name == "importance.csv" and not both.empty:
            # Mean over all runs: the means of both parts weighted by their runs.
            both = both.assign(w=both["importance"] * both["runs"])
            both = both.groupby(["model", "mode", "feature"], sort=False)[["w", "runs"]].sum().reset_index()
            both = both.assign(importance=both["w"] / both["runs"])[["model", "mode", "feature", "importance", "runs"]]
        merged[name] = both
    return merged


def write_results(scenario_dir: Path, res: Results, args, data_line: str, seconds: float, seeds_done: list[int],
                  previous: dict[str, dict]) -> None:
    split_flat_results(scenario_dir)
    imp_rows = [{"model": m, "mode": mode, "feature": f, "importance": v, "runs": len(runs)}
                for (m, mode), runs in res.importance.items() for f, v in zip(FEATURE_COLS, np.mean(runs, axis=0))]
    per_model = {"metrics.csv": pd.DataFrame(res.metrics), "confusion.csv": pd.DataFrame(res.confusion),
                 "within_folds.csv": pd.DataFrame(res.folds), "importance.csv": pd.DataFrame(imp_rows)}
    shared = {"training_sets.csv": pd.DataFrame(res.training),
              "skipped.csv": pd.DataFrame(res.skipped, columns=["seed", "mode", "train", "test", "test_individual", "reason"])}
    for model in args.models:
        tables = {name: df[df["model"] == model] if "model" in df.columns else df for name, df in per_model.items()}
        tables.update(shared)
        prev = previous.get(model)
        if prev:
            tables = merge_previous(prev["tables"], tables)
        old_seeds = prev["seeds"] if prev else []
        seeds, planned = sorted(old_seeds + seeds_done), sorted(old_seeds + args.seeds)
        run_info = [f"Created: {time.strftime('%Y-%m-%d %H:%M:%S')} with 03_Evaluation/train_models.py "
                    f"({', '.join(args.models)}; {seconds / 60:.1f} min)",
                    f"Seeds: {', '.join(map(str, seeds))}"
                    + ("" if seeds == planned else f" (of {', '.join(map(str, planned))}; run not finished)")
                    + f"; modes: {', '.join(args.modes)}",
                    f"{data_line}; skipped runs: {len(tables['skipped.csv'])}"]
        if prev:
            created = next((ln for ln in prev["run"] if ln.startswith("Created:")), "(no run.txt)")
            run_info.append(f"Earlier results kept (--add): seeds {', '.join(map(str, old_seeds))} | {created}")
            run_info += [ln for ln in prev["run"] if ln.startswith("Earlier results kept")]
        out = scenario_dir / model
        out.mkdir(parents=True, exist_ok=True)
        clear_folder(out)
        for name, df in tables.items():
            save_table(df, out / name)
        (out / "run.txt").write_text("\n".join(run_info) + "\n", encoding="utf-8")
    write_summary(scenario_dir, args.scenario)


def write_summary(scenario_dir: Path, scenario: str) -> None:
    folders = sorted(p.parent for p in scenario_dir.glob("*/metrics.csv"))
    frames = [pd.read_csv(f / "metrics.csv") for f in folders]
    m = pd.concat([f for f in frames if not f.empty], ignore_index=True) if any(not f.empty for f in frames) else pd.DataFrame()
    lines = [f"MODEL RESULTS: scenario {scenario}",
             f"Updated: {time.strftime('%Y-%m-%d %H:%M:%S')} with 03_Evaluation/train_models.py",
             "Values: Macro-F1, mean ± SD over the seeds. Runs:"]
    for f in folders:
        info = (f / "run.txt").read_text(encoding="utf-8").splitlines() if (f / "run.txt").exists() else ["(first run)"]
        lines.append(f"  {f.name}: " + "; ".join(info))
    lines += summary(m)
    (scenario_dir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def mean_sd(values: pd.Series) -> str:
    return f"{values.mean():.3f} ± {values.std(ddof=1):.3f}" if len(values) > 1 else f"{values.mean():.3f}"


def summary(m: pd.DataFrame) -> list[str]:
    lines: list[str] = []
    if m.empty:
        return lines + ["", "(no results)"]
    if "within" in set(m["mode"]) or "cross" in set(m["mode"]):
        sub = m[m["mode"].isin(["within", "cross"])]
        table = sub.groupby(["test", "mode", "model"])["macro_f1"].apply(mean_sd).unstack(["mode", "model"])
        lines += ["", "WITHIN (leave one individual out) AND CROSS (train on all other datasets) PER DATASET", ""]
        lines += ["  " + ln for ln in table.to_string().splitlines()]
        w = m[m["mode"] == "within"].drop_duplicates(["test"])
        if not w.empty:
            lines += ["", "  Within: individuals / meeting the rule / folds: "
                      + "; ".join(f"{r.test} {int(r.individuals)}/{int(r.eligible_individuals)}/{int(r.folds)}"
                                  for r in w.itertuples())]
    if "pairwise" in set(m["mode"]):
        p = m[m["mode"] == "pairwise"]
        lines += ["", "PAIRWISE (rows: training dataset, columns: test dataset), Macro-F1 mean over seeds"]
        for model, g in p.groupby("model"):
            mat = g.groupby(["train", "test"])["macro_f1"].mean().unstack("test")
            lines += ["", f"  {model}", ""] + ["  " + ln for ln in mat.round(2).to_string().splitlines()]
        same = p.groupby(["model", "same_species"])["macro_f1"].mean().unstack("same_species")
        lines += ["", "  Mean over pairs: same species vs. different species", ""]
        lines += ["  " + ln for ln in same.round(3).to_string().splitlines()]
    return lines


def main() -> int:
    global SIGNALS
    parser = argparse.ArgumentParser(description="Train and evaluate the classifiers (D22-D25).")
    parser.add_argument("--models", nargs="+", default=["rf", "lgbm"], choices=MODEL_NAMES + ["all"])
    parser.add_argument("--modes", nargs="+", default=MODES, choices=MODES)
    parser.add_argument("--seeds", nargs="+", type=int, default=[42, 43, 44, 45, 46])
    parser.add_argument("--scenario", default="primary", choices=list(SCENARIOS))
    parser.add_argument("--add", action="store_true",
                        help="keep the results of other seeds and add these seeds (same windows and modes)")
    args = parser.parse_args()
    if "all" in args.models:
        args.models = MODEL_NAMES
    sc = SCENARIOS[args.scenario]
    start = time.time()

    data, SIGNALS = load_data(sc, with_signals=any(INPUT[m] == "signals" for m in args.models))
    species = read_species()
    rule = test_unit_rule(data, sc["classes"])
    if sc["eligible_only"]:
        data = data[data["individual_key"].isin(rule)]
    data_line = data_info(data, rule)
    previous = read_previous(RESULT_DIR / args.scenario, args, data_line) if args.add else {}
    for m in args.models:
        make_model(m, 0, sc["classes"])  # fails early if a library is missing
    log(f"[INFO] {len(data):,} windows of {data['dataset_id'].nunique()} datasets; scenario {args.scenario}; "
        f"{len(rule)} individuals meet the test-unit rule")

    res = Results(sc["classes"])
    runners = {"within": lambda s: run_within(data, args.models, s, sc, res, rule),
               "cross": lambda s: run_cross(data, args.models, s, sc, res, species),
               "pairwise": lambda s: run_pairwise(data, args.models, s, sc, res, species)}
    for i, seed in enumerate(args.seeds):
        for mode in args.modes:
            t0 = time.time()
            runners[mode](seed)
            log(f"[OK] seed {seed}, {mode} ({time.time() - t0:.0f} s)")
        # Saved after every seed, so a long run that stops keeps its finished seeds.
        write_results(RESULT_DIR / args.scenario, res, args, data_line, time.time() - start, args.seeds[:i + 1],
                      previous)
    log(f"[OK] Results in {(RESULT_DIR / args.scenario).relative_to(ROOT)}/ ({(time.time() - start) / 60:.1f} min)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
