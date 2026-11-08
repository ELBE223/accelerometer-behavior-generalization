# 03_Evaluation

Training and evaluation of the six classifiers (Methods 2.3) with `train_models.py`.
All classifiers get the same training and test windows for each of the five seeds
(42–46).

| Mode | Design | Used for |
|---|---|---|
| `within` | Leave one individual out per dataset; test individuals need all three classes with ≥ 10 evaluation windows | H1, H2 (within-dataset baseline) |
| `cross` | Train on all other datasets, test on the held-out dataset | H1, H2 |
| `pairwise` | Train on dataset A, test on dataset B (all ordered pairs) | H3 (pairs of different species), Table S15 |
| `global` | All datasets pooled, 25 % of the individuals held out | not in the manuscript |

Training: overlapping windows, at least 30 and at most 250 windows per dataset and class,
spread over segments. Test: all non-overlapping windows with a class. Decisions: D08–D12,
D21–D25.

## results/

`results/<scenario>/<model>/` for the primary analysis (`primary`, all six classifiers) and
the sensitivity scenarios with RF and LightGBM (`A`, `C`, `majority`, `four_classes`, `E`,
`F`; Text S1, Table S20):

| File | Content | In git |
|---|---|---|
| `metrics.csv` | Accuracy, macro and per-class precision, recall and F1 per mode, seed and test dataset (pair); the only input of the statistics | yes |
| `skipped.csv` | Evaluations that were not possible, with the reason | yes |
| `../summary.txt` | Overview of the scenario | yes |
| `confusion.csv`, `within_folds.csv`, `training_sets.csv`, `importance.csv` | Confusion matrices, per held-out individual, training windows per class, feature importance | no (local only, D45) |

Run: `python 03_Evaluation/train_models.py --models rf lgbm` (see the script header for all
options), or `bash update_local.sh models`. The window features and classifiers are
imported from `01_Preprocessing/` and `02_Models/`.
