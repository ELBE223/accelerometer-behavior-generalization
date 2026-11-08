# stats_h1_h2.py
#
# Purpose:
# - Statistics of H1 and H2 (D26) from 03_Evaluation/results/<scenario>/<model>/metrics.csv:
#   seeds     the mean over the seeds is the value of a model and dataset (or dataset
#             pair) in the tests; the SD over the seeds is reported descriptively
#   H1        within vs. cross Macro-F1 (and accuracy) per dataset: paired Wilcoxon
#             signed-rank test per model, rank-biserial correlation, gaps
#   H2        cross F1 per class: Friedman test per model (blocks: test datasets with all
#             classes), Kendall's W, pairwise Wilcoxon tests between the classes with Holm
#             correction per model (interpreted only after a significant Friedman test);
#             the same for the transfer loss (within F1 - cross F1 per class)
#   H3 input  pairwise Macro-F1 per model and dataset pair (mean and SD over the seeds) with
#             the scientific species names and the within Macro-F1 of both datasets, for
#             04_Statistics/stats_h3.R
# - Wilcoxon tests: exact two-sided p-values; the normal approximation with continuity
#   correction only with ties or zero differences (column test_method), as wilcox.test in R.
# - Output: 04_Statistics/results/<scenario>/seed_means.csv, seed_variability.csv, h1_values.csv,
#   h1_tests.csv, h2_values.csv, h2_descriptives.csv, h2_friedman.csv, h2_posthoc.csv,
#   h3_input.csv, h3_input_by_seed.csv, statistics_h1_h2.txt
#
# Usage (from the project folder, venv active):
#   python 04_Statistics/stats_h1_h2.py                 # every scenario with results in 03_Evaluation/results
#   python 04_Statistics/stats_h1_h2.py --scenario primary

from __future__ import annotations

import argparse
import math
import sys
from itertools import combinations
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import chi2, norm, rankdata

# Classifier names (02_Models/models.py) and result paths (03_Evaluation/train_models.py)
# are imported from their own folders.
sys.path[:0] = [str(Path(__file__).resolve().parents[1] / folder) for folder in ("02_Models", "03_Evaluation")]

from models import MODEL_NAMES  # noqa: E402
from train_models import DATASETS_CSV, MIN_TEST_PER_CLASS, RESULT_DIR, ROOT  # noqa: E402

STATS_DIR = ROOT / "04_Statistics" / "results"
DISPLAY = {"cnn": "CNN", "resnet": "ResNet", "hydra": "HYDRA", "multirocket": "MultiRocket",
           "rf": "RF", "lgbm": "LGBM"}
MODEL_ORDER = list(DISPLAY)  # order in all tables
ALPHA = 0.05
SEP_KEYS = ["model", "mode", "train", "test"]
WIDTH = 100


def log(msg: str) -> None:
    print(msg, flush=True)


# --- tests ----------------------------------------------------------------------------

def signed_rank_counts(n: int) -> np.ndarray:
    # Number of subsets of 1..n per rank sum (null distribution of V without ties).
    counts = np.zeros(n * (n + 1) // 2 + 1)
    counts[0] = 1
    for k in range(1, n + 1):
        counts[k:] = counts[k:] + counts[:-k].copy()
    return counts


def wilcoxon(x, y) -> dict:
    # Paired two-sided Wilcoxon signed-rank test of x - y, as wilcox.test(x, y, paired = TRUE)
    # in R: zero differences dropped, V = sum of the ranks of the positive differences.
    d = np.round(np.asarray(x, float) - np.asarray(y, float), 12)
    d = d[np.isfinite(d)]
    zeros = int((d == 0).sum())
    d = d[d != 0]
    n = len(d)
    out = {"n_pairs": n + zeros, "n_zero": zeros, "V": np.nan, "p_value": np.nan,
           "test_method": "no non-zero differences", "rank_biserial": np.nan}
    if n == 0:
        return out
    ranks = rankdata(np.abs(d))
    v, v_neg = ranks[d > 0].sum(), ranks[d < 0].sum()
    out.update(V=v, rank_biserial=(v - v_neg) / (v + v_neg))
    ties = len(np.unique(np.abs(d))) < n
    if not ties and not zeros and n < 50:
        counts = signed_rank_counts(n)
        cdf = np.cumsum(counts) / counts.sum()
        k = round(v)
        p = 1 - cdf[k - 1] if v > n * (n + 1) / 4 else cdf[k]
        out.update(p_value=min(2 * p, 1.0), test_method="exact")
    else:
        _, t = np.unique(ranks, return_counts=True)
        sigma = math.sqrt(n * (n + 1) * (2 * n + 1) / 24 - (t ** 3 - t).sum() / 48)
        z = v - n * (n + 1) / 4
        z = (z - np.sign(z) * 0.5) / sigma
        out.update(p_value=float(2 * min(norm.cdf(z), norm.sf(z))),
                   test_method="normal approximation, continuity correction (ties or zero differences)")
    return out


def friedman(table: pd.DataFrame) -> dict:
    # friedman.test in R: rows are blocks, columns groups; ranks within blocks, tie correction.
    y = table.to_numpy(float)
    n, k = y.shape
    if n < 2 or k < 2:
        return {"n_blocks": n, "chi_sq": np.nan, "df": k - 1, "p_value": np.nan, "kendalls_w": np.nan}
    r = np.apply_along_axis(rankdata, 1, y)
    ties = sum(((c := np.unique(row, return_counts=True)[1]) ** 3 - c).sum() for row in r)
    stat = 12 * ((r.sum(0) - n * (k + 1) / 2) ** 2).sum() / (n * k * (k + 1) - ties / (k - 1))
    return {"n_blocks": n, "chi_sq": stat, "df": k - 1, "p_value": float(chi2.sf(stat, k - 1)),
            "kendalls_w": stat / (n * (k - 1))}


def holm(p) -> np.ndarray:
    # p.adjust(p, "holm") in R.
    p = np.asarray(p, float)
    out = np.full(len(p), np.nan)
    ok = np.flatnonzero(np.isfinite(p))
    running = 0.0
    for i, idx in enumerate(ok[np.argsort(p[ok])]):
        running = max(running, min(1.0, (len(ok) - i) * p[idx]))
        out[idx] = running
    return out


def describe(values: pd.Series, prefix: str) -> dict:
    v = values.dropna()
    return {f"{prefix}_mean": v.mean(), f"{prefix}_sd": v.std(ddof=1), f"{prefix}_median": v.median(),
            f"{prefix}_q1": v.quantile(0.25), f"{prefix}_q3": v.quantile(0.75)}


# --- data -----------------------------------------------------------------------------

def load_metrics(scenario: str) -> pd.DataFrame:
    files = sorted((RESULT_DIR / scenario).glob("*/metrics.csv"))
    if not files:
        return pd.DataFrame()
    m = pd.concat([pd.read_csv(f) for f in files], ignore_index=True)
    return m[m["model"].isin(MODEL_NAMES)]


def class_names(m: pd.DataFrame) -> list[str]:
    return [c[3:] for c in m.columns if c.startswith("f1_")]


def seed_means(m: pd.DataFrame, classes: list[str]) -> pd.DataFrame:
    # One row per model, mode, training and test set: mean and SD over the seeds.
    values = ["macro_f1", "accuracy"] + [f"f1_{c}" for c in classes]
    supports = [f"support_{c}" for c in classes]
    g = m.groupby(SEP_KEYS, sort=False)
    out = g[values].mean()
    out = out.join(g[values].std(ddof=1).add_suffix("_sd"))
    out = out.join(g[supports + ["n_test"]].mean())
    out = out.join(g["seed"].agg(n_seeds="nunique", seeds=lambda s: " ".join(map(str, sorted(s.unique())))))
    first = g[["individuals", "eligible_individuals", "folds"]].first()
    out = out.join(first).reset_index()
    out["model"] = pd.Categorical(out["model"], [x for x in MODEL_ORDER if x in set(out["model"])], ordered=True)
    return out.sort_values(["model", "mode", "train", "test"]).reset_index(drop=True)


def seed_variability(sm: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for (model, mode), g in sm.groupby(["model", "mode"], observed=True):
        top = g.loc[g["macro_f1_sd"].idxmax()] if g["macro_f1_sd"].notna().any() else None
        rows.append({"model": model, "mode": mode, "rows": len(g), "n_seeds_min": g["n_seeds"].min(),
                     "n_seeds_max": g["n_seeds"].max(), "sd_macro_f1_median": g["macro_f1_sd"].median(),
                     "sd_macro_f1_max": g["macro_f1_sd"].max(),
                     "max_at": "" if top is None else f"{top['train']} -> {top['test']}"})
    return pd.DataFrame(rows)


# --- H1 -------------------------------------------------------------------------------

def h1(sm: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    keep = ["model", "test", "macro_f1", "macro_f1_sd", "accuracy", "accuracy_sd", "n_test", "n_seeds"]
    w = sm[sm["mode"] == "within"][keep + ["individuals", "eligible_individuals", "folds"]]
    c = sm[sm["mode"] == "cross"][keep]
    v = w.merge(c, on=["model", "test"], suffixes=("_within", "_cross")).rename(columns={"test": "dataset"})
    v = v.rename(columns={"individuals_within": "individuals", "eligible_individuals_within": "eligible_individuals",
                          "folds_within": "folds"})
    for metric in ["macro_f1", "accuracy"]:
        v[f"gap_{metric}"] = v[f"{metric}_within"] - v[f"{metric}_cross"]
    # Within and cross test the same windows only if every individual is a test unit (D12).
    v["same_test_windows"] = v["folds"] == v["individuals"]
    tests = []
    for dataset_set, sub in [("all", v), ("same_test_windows", v[v["same_test_windows"]])]:
        for model, g in sub.groupby("model", observed=True):
            for metric in ["macro_f1", "accuracy"]:
                res = wilcoxon(g[f"{metric}_within"], g[f"{metric}_cross"])
                tests.append({"model": model, "datasets": dataset_set, "metric": metric, **res,
                              "n_within_higher": int((g[f"gap_{metric}"] > 0).sum()),
                              **describe(g[f"gap_{metric}"], "gap"), **describe(g[f"{metric}_within"], "within"),
                              **describe(g[f"{metric}_cross"], "cross")})
    return v, pd.DataFrame(tests)


# --- H2 -------------------------------------------------------------------------------

def h2_values(sm: pd.DataFrame, classes: list[str]) -> pd.DataFrame:
    rows = []
    for mode in ["cross", "within"]:
        sub = sm[sm["mode"] == mode]
        for c in classes:
            part = sub[["model", "test", f"f1_{c}", f"f1_{c}_sd", f"support_{c}"]].copy()
            part.columns = ["model", "dataset", "f1", "f1_sd", "support"]
            rows.append(part.assign(mode=mode, behavior=c))
    long = pd.concat(rows, ignore_index=True)
    # A class enters H2 only with enough test windows (D23: at least 5).
    long.loc[long["support"] < MIN_TEST_PER_CLASS, ["f1", "f1_sd"]] = np.nan
    v = long.pivot_table(index=["model", "dataset", "behavior"], columns="mode",
                         values=["f1", "f1_sd", "support"], observed=True)
    v.columns = [f"{mode}_{name}" for name, mode in v.columns]
    v = v.reset_index()
    for col in ["within_f1", "within_f1_sd", "within_support"]:
        if col not in v:
            v[col] = np.nan
    v["transfer_loss_f1"] = v["within_f1"] - v["cross_f1"]
    return v[["model", "dataset", "behavior", "cross_f1", "cross_f1_sd", "cross_support", "within_f1",
              "within_f1_sd", "within_support", "transfer_loss_f1"]]


def h2_tests(v: pd.DataFrame, classes: list[str]) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    fried, post, desc = [], [], []
    for response in ["cross_f1", "transfer_loss_f1"]:
        for model, g in v.groupby("model", observed=True):
            for c in classes:
                desc.append({"model": model, "response": response, "behavior": c,
                             "n": int(g.loc[g["behavior"] == c, response].notna().sum()),
                             **describe(g.loc[g["behavior"] == c, response], "value")})
            table = g.pivot(index="dataset", columns="behavior", values=response).reindex(columns=classes)
            table = table.dropna()  # complete blocks only
            res = friedman(table)
            fried.append({"model": model, "response": response, "groups": len(classes), **res,
                          "blocks": " ".join(table.index)})
            pairs = []
            for a, b in combinations(classes, 2):
                diff = table[a] - table[b]
                pairs.append({"model": model, "response": response, "behavior_1": a, "behavior_2": b,
                              **wilcoxon(table[a], table[b]), **describe(diff, "diff")})
            adj = holm([p["p_value"] for p in pairs])
            for p, a in zip(pairs, adj):
                p.update(p_holm=a, friedman_significant=bool(res["p_value"] < ALPHA))
            post += pairs
    return pd.DataFrame(fried), pd.DataFrame(post), pd.DataFrame(desc)


# --- H3 input -------------------------------------------------------------------------

def h3_input(sm: pd.DataFrame, m: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    # Dataset pairs with the mean over the seeds, and the same per seed (for the seed check of H3).
    species = pd.read_csv(DATASETS_CSV).set_index("dataset_id")["scientific_name"]
    within = sm[sm["mode"] == "within"].set_index(["model", "test"])["macro_f1"]

    def add_species(df: pd.DataFrame) -> pd.DataFrame:
        df["train_species"] = df["train"].map(species)
        df["test_species"] = df["test"].map(species)
        df["same_species"] = df["train_species"] == df["test_species"]
        df["source_within_macro_f1"] = [within.get((x, d), np.nan) for x, d in zip(df["model"], df["train"])]
        df["target_within_macro_f1"] = [within.get((x, d), np.nan) for x, d in zip(df["model"], df["test"])]
        df["model"] = df["model"].map(DISPLAY)
        return df

    cols = ["model", "train", "test", "macro_f1"]
    mean = add_species(sm[sm["mode"] == "pairwise"][cols + ["macro_f1_sd", "n_seeds"]].copy())
    by_seed = m[m["mode"] == "pairwise"][cols[:3] + ["seed", "macro_f1"]].copy()
    by_seed = add_species(by_seed.sort_values(["model", "seed", "train", "test"]))
    return mean, by_seed


# --- report ---------------------------------------------------------------------------

def fmt_p(p: float) -> str:
    return "NA" if not np.isfinite(p) else ("< 0.001" if p < 0.001 else f"{p:.3f}")


def report(scenario: str, sm, var, h1v, h1t, h2f, h2p, h2d, h3, classes) -> list[str]:
    lines = [f"STATISTICS H1 AND H2 – scenario {scenario}", "=" * WIDTH, "",
             "Values: mean over the seeds per model and dataset (or dataset pair); SD = SD over the seeds.",
             "Wilcoxon: exact two-sided p unless ties or zero differences (test_method in the csv files).", ""]
    lines += ["SEED VARIABILITY (SD of Macro-F1 over the seeds, per model and mode)", ""]
    shown = var.assign(model=var["model"].map(DISPLAY))
    lines += ["  " + ln for ln in shown.round(3).to_string(index=False).splitlines()]

    lines += ["", "", "H1: WITHIN VS. CROSS (Macro-F1 per dataset, mean ± SD over the seeds)", ""]
    for model, g in h1v.groupby("model", observed=True):
        lines.append(f"  {DISPLAY[model]}")
        for r in g.itertuples():
            note = "" if r.same_test_windows else f"  (test units {int(r.folds)} of {int(r.individuals)} individuals)"
            lines.append(f"    {r.dataset:<20} within {r.macro_f1_within:.3f} ± {r.macro_f1_sd_within:.3f}   "
                         f"cross {r.macro_f1_cross:.3f} ± {r.macro_f1_sd_cross:.3f}   gap {r.gap_macro_f1:+.3f}{note}")
    lines += ["", "  Paired Wilcoxon tests (datasets 'all': every dataset with a within value; 'same_test_windows':",
              "  only datasets in which every individual is a test unit, so within and cross test the same windows)", ""]
    for r in h1t.itertuples():
        lines.append(f"  {DISPLAY[r.model]:<12} {r.datasets:<18} {r.metric:<9} n {r.n_pairs:>2}  within higher "
                     f"{r.n_within_higher:>2}  gap median {r.gap_median:.3f} [{r.gap_q1:.3f}, {r.gap_q3:.3f}]  "
                     f"V {r.V:g}  p {fmt_p(r.p_value)}  r_rb {r.rank_biserial:.2f}  ({r.test_method.split(',')[0]})")

    lines += ["", "", f"H2: DIFFERENCES BETWEEN THE CLASSES ({', '.join(classes)})", ""]
    for response, title in [("cross_f1", "Cross F1 per class"), ("transfer_loss_f1", "Transfer loss (within F1 - cross F1)")]:
        lines += [f"  {title}", ""]
        d = h2d[h2d["response"] == response].pivot(index="model", columns="behavior", values="value_median")
        d = d.reindex(index=[x for x in MODEL_ORDER if x in d.index], columns=classes).rename(index=DISPLAY)
        lines += ["    Median over the datasets:"] + ["    " + ln for ln in d.round(3).to_string().splitlines()]
        lines.append("")
        for r in h2f[h2f["response"] == response].itertuples():
            lines.append(f"    {DISPLAY[r.model]:<12} Friedman chi² {r.chi_sq:.2f}, df {r.df}, n {r.n_blocks}, "
                         f"p {fmt_p(r.p_value)}, Kendall's W {r.kendalls_w:.2f}")
            sub = h2p[(h2p["response"] == response) & (h2p["model"] == r.model)]
            for q in sub.itertuples():
                flag = "" if q.friedman_significant else "  (not interpreted: Friedman not significant)"
                lines.append(f"      {q.behavior_1} - {q.behavior_2}: median diff {q.diff_median:+.3f}, "
                             f"V {q.V:g}, p {fmt_p(q.p_value)}, Holm {fmt_p(q.p_holm)}{flag}")
        lines.append("")

    lines += ["", "H3 INPUT (h3_input.csv, for 04_Statistics/stats_h3.R)", ""]
    n_pairs = h3.groupby("model")["train"].size()
    lines.append("  Dataset pairs per model: " + ", ".join(f"{m} {n}" for m, n in n_pairs.items()))
    lines.append(f"  Pairs of the same species (scientific name; left out in H3): "
                 f"{int(h3.drop_duplicates(['train', 'test'])['same_species'].sum())}")
    return lines


def run(scenario: str) -> bool:
    m = load_metrics(scenario)
    if m.empty:
        log(f"{scenario}: no results in {RESULT_DIR / scenario}")
        return False
    classes = class_names(m)
    sm = seed_means(m, classes)
    var = seed_variability(sm)
    h1v, h1t = h1(sm)
    h2v = h2_values(sm, classes)
    h2f, h2p, h2d = h2_tests(h2v, classes)
    h3, h3_seeds = h3_input(sm, m)
    out = STATS_DIR / scenario
    out.mkdir(parents=True, exist_ok=True)
    tables = {"seed_means": sm, "seed_variability": var, "h1_values": h1v, "h1_tests": h1t, "h2_values": h2v,
              "h2_descriptives": h2d, "h2_friedman": h2f, "h2_posthoc": h2p, "h3_input": h3,
              "h3_input_by_seed": h3_seeds}
    for name, df in tables.items():
        df.to_csv(out / f"{name}.csv", index=False, float_format="%.6g")
    text = report(scenario, sm, var, h1v, h1t, h2f, h2p, h2d, h3, classes)
    (out / "statistics_h1_h2.txt").write_text("\n".join(text) + "\n", encoding="utf-8")
    log(f"{scenario}: {len(m)} result rows, models {', '.join(sorted(set(m['model'])))} -> {out}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Statistics of H1 and H2 and the H3 input (D26).")
    parser.add_argument("--scenario", nargs="+", help="default: every scenario with results")
    args = parser.parse_args()
    scenarios = args.scenario
    if not scenarios and RESULT_DIR.exists():
        scenarios = sorted(p.name for p in RESULT_DIR.iterdir() if p.is_dir())
    if not scenarios:
        log("No results found in 03_Evaluation/results")
        return 1
    ok = [run(s) for s in scenarios]
    return 0 if all(ok) else 1


if __name__ == "__main__":
    raise SystemExit(main())
