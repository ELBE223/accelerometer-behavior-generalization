# 04_Statistics

Tests of H1–H3 (Methods 2.5) for each scenario; results in `results/<scenario>/`.

| Script | Analysis |
|---|---|
| `stats_h1_h2.py` | H1: paired Wilcoxon tests; H2: Friedman and post-hoc tests; input of H3 |
| `stats_h3.R` | Trait and other distances; dyadic mixed models; robustness analyses |

Which result feeds which table: `05_Paper_Outputs/output_manifest.csv`. H3 needs the R
packages lme4, lmerTest and cluster (optional: gawdis, performance) and, for the EltonTraits
distance, `data/raw/EltonTraits/MamFuncDat.txt`. Run: `bash run_pipeline.sh stats`.
