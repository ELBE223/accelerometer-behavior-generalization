# bison_dataset_1.py
#
# Loader for Bison_dataset_1 (Saenger MSc thesis); reading rules in loaders/saenger_sheets.py.
# - Input: data/raw/Bison_dataset_1/Data_Bison_Raw/Wisent_Daten_gesamt.xlsx

from __future__ import annotations

from pathlib import Path

import pandas as pd

from loaders.saenger_sheets import load_saenger

DATASET = "Bison_dataset_1"
XLSX = "Data_Bison_Raw/Wisent_Daten_gesamt.xlsx"


def load(raw_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, list[str]]:
    return load_saenger(DATASET, raw_dir / XLSX)
