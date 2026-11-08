# 03_Evaluation

`train_models.py` trains and evaluates the classifiers (Methods 2.3) with five seeds
(42–46); all classifiers get the same training and test windows.

| Mode | Design |
|---|---|
| `within` | Leave one individual out per dataset |
| `cross` | Train on all other datasets, test on the held-out dataset |
| `pairwise` | Train on one dataset, test on another |

`results/<scenario>/<model>/metrics.csv` holds accuracy, precision, recall and F1 (macro and per class) per
mode, seed and test dataset; `skipped.csv` lists evaluations that were not possible.
Scenarios: `primary` (all six classifiers) and the sensitivity scenarios with RF and
LightGBM (Text S1).

Run: `bash run_pipeline.sh models` (RF and LightGBM) or `bash run_pipeline.sh models all`.
