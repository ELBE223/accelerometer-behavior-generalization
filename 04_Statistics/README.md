# 04_Statistics

Tests of H1–H3 (Methods 2.5) for every scenario in `03_Evaluation/results/`. Values are
first averaged over the five seeds.

| Script | Analysis | Output in `results/<scenario>/` |
|---|---|---|
| `stats_h1_h2.py` | Seed means and SD; H1: paired Wilcoxon tests (within vs. cross Macro-F1, accuracy); H2: Friedman tests, Kendall's W, Holm-corrected pairwise Wilcoxon tests (cross F1, transfer loss); input of H3 | `seed_means.csv`, `seed_variability.csv`, `h1_values.csv`, `h1_tests.csv`, `h2_values.csv`, `h2_descriptives.csv`, `h2_friedman.csv`, `h2_posthoc.csv`, `h3_input.csv`, `h3_input_by_seed.csv`, `statistics_h1_h2.txt` |
| `stats_h3.R` | Trait distances (Gower, five core traits), alternative distances (EltonTraits, body mass, TimeTree), dyadic mixed model with likelihood-ratio test, per-classifier slopes and Spearman correlations, robustness (random effects, trait sensitivity, leave one species out, per seed) | `h3_distances.csv`, `h3_data.csv`, `h3_models.csv`, `h3_fixed_effects.csv`, `h3_random_effects.csv`, `h3_prediction.csv`, `h3_slopes.csv`, `h3_spearman.csv`, `h3_loso.csv`, `h3_seeds.csv`, `h3_elton_traits.csv`, `h3_gawdis_weights.csv`, `statistics_h3.txt` |

Which result feeds which table or figure: `05_Paper_Outputs/output_manifest.csv`
(columns `sources` and `produced_by`).

Run from the project folder:

```
python 04_Statistics/stats_h1_h2.py            # all scenarios (or --scenario primary)
Rscript 04_Statistics/stats_h3.R               # all scenarios with an h3_input.csv
```

H3 needs the R packages lme4, lmerTest and cluster (optional: gawdis for the weighted trait
distance, performance for VIF) and, for the EltonTraits distance,
`data/raw/EltonTraits/MamFuncDat.txt`. Decisions: D26–D39, D43.
