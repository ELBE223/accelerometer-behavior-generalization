# 01_Preprocessing

From the raw data to labeled windows and window features (Methods 2.1–2.2).
Settings: `config/pipeline_settings.json` (25 Hz, 2.0-s windows every 1.0 s; variant C:
2.4-s windows every 2.4 s). Decisions: D02–D21 in `00_Documentation/decisions.md`.

| Step | Script | Input | Output |
|---|---|---|---|
| 0 | `prepare_raw_data.py` | — | downloads Horse_dataset_2 (4TU), sorts converted thesis files out of the raw folders |
| 1 | `harmonize.py` + `loaders/` | `data/raw/<dataset>/` | `data/processed/<dataset>/samples.parquet`, `segments.parquet` (x/y/z in g, labels, individuals, segments) |
| 2 | `make_windows.py` | `data/processed/` | `data/windows/<dataset>/windows.parquet` (resampled to 25 Hz, windows within segments) |
| 3 | `assign_classes.py` | windows, `00_Documentation/behavior_mapping.csv` | `data/windows/<dataset>/classes.parquet`; `reports/pipeline_reports/class_summary.csv` |
| 4 | `features.py` | windows | `data/features/<dataset>/features.parquet` (26 features, Table S4) |
| check | `checks/check_activity.py` | windows, features, classes | `reports/pipeline_reports/activity_levels.csv`: movement intensity per class and individual (Locomotion should exceed Resting) |

`loaders/` has one loader per dataset (`<dataset_id lower case>.py`) that reads its raw
format into the common format; `common.py`, `bursts.py` and `saenger_sheets.py` are
shared helpers. `make_windows.py`, `assign_classes.py` and `features.py` take
`--variant C` for sensitivity scenario C (into `data/windows_C/`, `data/features_C/`).

`reports/pipeline_reports/` is generated. In git are only the summaries:
`class_summary.csv` (windows per dataset, individual and class; Table S1, Figure S1),
`window_summary.csv` (windows per original label) and `activity_levels.csv`, each also for
variant C. The text reports per dataset and step (`<dataset>_harmonized.txt`,
`<dataset>_windows.txt`, `class_report.txt`, `activity_check.txt`) stay local; they hold
the details and any error messages of a run.

Run all steps: `bash update_local.sh` (pipeline) or each script from the project folder,
e.g. `python 01_Preprocessing/harmonize.py Cattle_dataset_1`.
