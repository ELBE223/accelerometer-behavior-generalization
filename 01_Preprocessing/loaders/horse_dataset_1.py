# horse_dataset_1.py
#
# Loader for Horse_dataset_1 (Saenger MSc thesis); reading rules in loaders/saenger_sheets.py.
# - Input: data/raw/Horse_dataset_1/Data_Horse_Raw/Horse.xlsx
# - The sheet "Pernot_Sultan NICHT IN GESAMT" is not read (excluded by the author);
#   "Jedi 4935" and "Jedi 4935 nach 21.10.16" are one horse.

from __future__ import annotations

from pathlib import Path

import pandas as pd

from loaders.saenger_sheets import load_saenger

DATASET = "Horse_dataset_1"
XLSX = "Data_Horse_Raw/Horse.xlsx"


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    return load_saenger(DATASET, raw_dir / XLSX)
