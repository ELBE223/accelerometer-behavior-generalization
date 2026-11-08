# data/

Local data, not in git (nine of the eleven datasets are not public).

| Folder | Content |
|---|---|
| `raw/<dataset>/` | Raw data as received (read only) |
| `raw/EltonTraits/MamFuncDat.txt` | EltonTraits (Wilman et al. 2014), for the EltonTraits distance |
| `processed/`, `windows/`, `features/` | Written by `01_Preprocessing/` (`windows_C/`, `features_C/`: 2.4-s windows) |

`python3.11 setup_project.py` creates `raw/<dataset>/` and `processed/<dataset>/`.
