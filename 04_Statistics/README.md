# 04_Statistics

Tests of H1–H3 (Methods 2.5) for each scenario, from the stored model results in
`03_Evaluation/results/`; results in `results/<scenario>/`.

| Script | Analysis |
|---|---|
| `stats_h1_h2.py` | H1: paired Wilcoxon tests, Holm-adjusted over the six classifiers separately for the ten and the seven datasets (D51); H2: Friedman and post-hoc tests; cross-dataset confusion matrices (Figure S3); input of H3 |
| `stats_h3.R` | Core trait distance and the alternative distances; dyadic mixed models; robustness analyses (Tables 3, S12–S17) |

Unadjusted p-values stay in every result file (column `p_value`); the Holm-adjusted ones
are in `p_holm`. The sensitivity scenarios are reported unadjusted (Table S17).

The EltonTraits distances (Table 3, Table S13, Text S2) use
`data/raw/EltonTraits/MamFuncDat.txt` (Wilman et al. 2014) when it is present; each such run
writes the rows of the nine study species to
`00_Documentation/traits/eltontraits_study_species.txt`, which is used when the raw file is
missing.

`archive/h3_exploratory/`: the weighted trait distance (gawdis) and the add-backs of trunk
motion amplitude and directional change tendency, removed from the standard run (D51), with
their code, inputs and last results.

Which result feeds which table: `05_Paper_Outputs/output_manifest.csv`. H3 needs the R
packages lme4, lmerTest and cluster (optional: performance). Run: `bash run_pipeline.sh stats`.
