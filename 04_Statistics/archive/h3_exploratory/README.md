# Archived H3 analyses (D51)

Three exploratory H3 analyses were part of the standard run of `04_Statistics/stats_h3.R`
and of the robustness table up to commit `170d85c` (2026-11-08). They are not reported in
the manuscript or the supplement and were removed from the standard run and the final
export (decision D51, `00_Documentation/decisions.md`). This folder keeps them traceable.

| Analysis (label in `h3_models.csv`) | Distance |
|---|---|
| `S3 gawdis distance` | Gower distance of the five core traits with trait weights from `gawdis` (`w.type = "optimized"`, seed 42) |
| `exploratory core + C4 (D36)` | Five core traits plus trunk motion amplitude (ordinal low < moderate < high < very high), equal weights |
| `exploratory core + C5 (D37)` | Five core traits plus directional change tendency (ordinal, as above), equal weights |

Each distance replaced the core trait distance in the primary mixed model (z-scored; same
fixed and random effects).

## Contents

| File | Content |
|---|---|
| `species_traits_exploratory.csv` | Trunk motion amplitude and directional change tendency per species (moved from `00_Documentation/traits/`) |
| `stats_h3_until_D51.R` | `stats_h3.R` of commit `170d85c` with a header; unchanged otherwise |
| `results/h3_exploratory_models.csv` | The three analyses from `h3_models.csv` of the last run, all seven scenarios |
| `results/h3_exploratory_fixed_effects.csv` | Their fixed effects (REML fits) |
| `results/h3_gawdis_weights.csv` | gawdis trait weights (equal, analytic, optimized) and trait correlations, all scenarios |
| `results/h3_exploratory_distances.csv` | Pairwise species distances: core (Gower), gawdis, core + C4, core + C5 |

## Last values (primary scenario, 432 records)

| Analysis | β per SD [95% CI] | LR χ² (df = 1) | p | R² marginal / conditional | Singular fit |
|---|---|---|---|---|---|
| Weighted trait distance (gawdis) | −0.037 [−0.074, −0.0005] | 4.21 | 0.040 | 0.41 / 0.82 | Yes |
| Core traits + trunk motion amplitude | −0.036 [−0.073, 0.001] | 3.94 | 0.047 | 0.41 / 0.82 | Yes |
| Core traits + directional change tendency | −0.020 [−0.055, 0.014] | 2.18 | 0.140 | 0.38 / 0.82 | No |

## Reproduce

The code and inputs are those of commit `170d85c`; run them in a separate checkout so the
current results are not overwritten (R packages: lme4, lmerTest, cluster, gawdis):

```bash
git worktree add ../h3-archive 170d85c
```

```bash
cd ../h3-archive && Rscript 04_Statistics/stats_h3.R primary
```
