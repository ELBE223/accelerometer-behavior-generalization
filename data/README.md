# data/

Local data folder. Everything here except this file is ignored by git: nine of the eleven
datasets are not public, and all other folders are recreated by the code.

| Folder | Content | Written by |
|---|---|---|
| `raw/<dataset>/` | Raw data as received (read only, never changed) | you; `01_Preprocessing/prepare_raw_data.py` downloads and unpacks Horse_dataset_2 |
| `raw/EltonTraits/MamFuncDat.txt` | EltonTraits (Wilman et al. 2014), for the alternative distance in H3 | you |
| `processed/<dataset>/` | Harmonized samples and segments (`samples.parquet`, `segments.parquet`) | `01_Preprocessing/harmonize.py` |
| `windows/<dataset>/` | Model windows (25 Hz, 2 s) and their classes | `make_windows.py`, `assign_classes.py` |
| `features/<dataset>/` | 26 window features for RF and LightGBM | `01_Preprocessing/features.py` |
| `windows_C/`, `features_C/` | The same for sensitivity scenario C (2.4-s windows) | `--variant C` of the scripts above |

`python3.11 setup_project.py` creates `raw/<dataset>/` and `processed/<dataset>/` for every
dataset in `00_Documentation/datasets.csv`.

Moving from the old layout (`paper-izw-cross-species-transfer`): move the local folders into this folder.

```
mv 01_raw_data        data/raw
mv 02_processed_data  data/processed
mv 03_windows         data/windows
mv 04_features        data/features
mv 03_windows_C       data/windows_C
mv 04_features_C      data/features_C
```
