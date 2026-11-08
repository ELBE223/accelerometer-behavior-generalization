# 01_Preprocessing

From the raw data to labeled windows and features (Methods 2.1–2.2). Settings:
`config/pipeline_settings.json` (25 Hz; 2.0-s windows every 1.0 s; variant C: 2.4-s
windows without overlap).

| Script | Output |
|---|---|
| `prepare_raw_data.py` | Downloads Horse 2 (public dataset) into `data/raw/` and moves converted copies out of the raw folders |
| `harmonize.py` + `loaders/` | `data/processed/<dataset>/`: samples in g with labels, individuals and segments (one loader per dataset) |
| `make_windows.py` | `data/windows/<dataset>/windows.parquet`: resampled to 25 Hz, windows within segments |
| `assign_classes.py` | `data/windows/<dataset>/classes.parquet`; `reports/pipeline_reports/class_summary.csv` (Table S1, Figure S1) |
| `features.py` | `data/features/<dataset>/features.parquet`: 26 features (Table S4) |
| `checks/check_activity.py` | `reports/pipeline_reports/activity_levels.csv`: movement intensity per class and individual (check of the labels) |

`make_windows.py`, `assign_classes.py` and `features.py` take `--variant C` for the
2.4-s windows. Run all steps with `bash run_pipeline.sh pipeline`.
