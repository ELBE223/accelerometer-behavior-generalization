# setup_project.py
#
# Purpose:
# - Creates the local folders that are not in git: one folder per dataset in
#   data/raw/ and data/processed/ (datasets from 00_Documentation/datasets.csv).
# - Creates a Python virtual environment (.venv) and installs the exact package versions
#   of requirements-lock.txt: the versions that produced the results (Table S5, D46). The
#   lock file is not changed, so every run gives the same environment.
# - --update installs the newest versions of requirements.txt instead and writes them to
#   requirements-lock.txt. Only for a deliberate change, with a decision entry: the results
#   and Table S5 refer to the locked versions.
# - Safe to run again: existing folders and files are never removed.
#
# Usage (from the project folder; the venv uses the Python that runs this script):
#   python3.11 setup_project.py
#   python3.11 setup_project.py --no-venv      # folders only
#   python3.11 setup_project.py --no-install   # venv without packages
#   python3.11 setup_project.py --update       # newest versions, rewrites the lock file
#
# Afterwards: source .venv/bin/activate

from __future__ import annotations

import argparse
import csv
import shutil
import subprocess
import sys
import venv
from pathlib import Path

ROOT = Path(__file__).resolve().parent

DOC_DIR = ROOT / "00_Documentation"
RAW_DIR = ROOT / "data" / "raw"
PROCESSED_DIR = ROOT / "data" / "processed"
VENV_DIR = ROOT / ".venv"

DATASET_REGISTRY = DOC_DIR / "datasets.csv"
REQUIREMENTS = ROOT / "requirements.txt"
REQUIREMENTS_LOCK = ROOT / "requirements-lock.txt"


# =========================================================
# Helpers
# =========================================================
def log(msg: str) -> None:
    print(msg, flush=True)


def read_datasets() -> list[str]:
    with DATASET_REGISTRY.open(newline="", encoding="utf-8") as fh:
        datasets = [row["dataset_id"].strip() for row in csv.DictReader(fh)]
    datasets = [ds for ds in datasets if ds]
    if len(datasets) != len(set(datasets)):
        raise ValueError(f"Duplicate dataset_id in {DATASET_REGISTRY}")
    return datasets


def venv_python() -> Path:
    if sys.platform == "win32":
        return VENV_DIR / "Scripts" / "python.exe"
    return VENV_DIR / "bin" / "python"


def create_venv() -> None:
    if (VENV_DIR / "pyvenv.cfg").exists():
        log(f"[SKIP] venv exists: {VENV_DIR}")
        return
    log(f"[INFO] Creating venv with Python {sys.version.split()[0]} ...")
    try:
        venv.EnvBuilder(with_pip=True, symlinks=sys.platform != "win32").create(VENV_DIR)
    except OSError as exc:
        # External drives formatted as exFAT do not support symlinks.
        log(f"[WARN] Symlinks not supported ({exc}); creating the venv with copies.")
        shutil.rmtree(VENV_DIR, ignore_errors=True)
        venv.EnvBuilder(with_pip=True, symlinks=False, clear=True).create(VENV_DIR)
    log(f"[OK] venv created: {VENV_DIR}")


def installed(python: str) -> list[str]:
    frozen = subprocess.run([python, "-m", "pip", "freeze"], check=True, capture_output=True, text=True).stdout
    return [line.strip() for line in frozen.splitlines() if line.strip()]


def install_requirements(update: bool) -> None:
    python = str(venv_python())
    subprocess.run([python, "-m", "pip", "install", "--upgrade", "pip"], check=True)
    if update:
        log(f"[INFO] Installing the newest versions of {REQUIREMENTS.name} ...")
        subprocess.run([python, "-m", "pip", "install", "--upgrade", "-r", str(REQUIREMENTS)], check=True)
        REQUIREMENTS_LOCK.write_text("\n".join(installed(python)) + "\n", encoding="utf-8")
        log(f"[WARN] {REQUIREMENTS_LOCK.name} now lists the new versions; record the change in "
            "00_Documentation/decisions.md (results and Table S5 refer to the locked versions)")
        return
    log(f"[INFO] Installing the package versions of {REQUIREMENTS_LOCK.name} ...")
    subprocess.run([python, "-m", "pip", "install", "-r", str(REQUIREMENTS_LOCK)], check=True)
    locked = {line.strip().lower() for line in REQUIREMENTS_LOCK.read_text(encoding="utf-8").splitlines()}
    other = [line for line in installed(python) if line.lower() not in locked]
    if other:
        log(f"[INFO] Also installed, not in {REQUIREMENTS_LOCK.name}: {', '.join(other)}")
    log(f"[OK] Package versions as in {REQUIREMENTS_LOCK.name}")


# =========================================================
# Main
# =========================================================
def main() -> int:
    parser = argparse.ArgumentParser(description="Create the local project folders and the venv.")
    parser.add_argument("--no-venv", action="store_true", help="Do not create a venv")
    parser.add_argument("--no-install", action="store_true", help="Create the venv without installing packages")
    parser.add_argument("--update", action="store_true",
                        help="Install the newest versions of requirements.txt and rewrite requirements-lock.txt")
    args = parser.parse_args()

    if sys.version_info[:2] != (3, 11):
        log(f"[WARN] Running Python {sys.version.split()[0]}; the thesis analyses used Python 3.11.")

    datasets = read_datasets()
    log(f"[INFO] Project folder: {ROOT}")

    folders = [RAW_DIR, PROCESSED_DIR]
    folders += [RAW_DIR / ds for ds in datasets] + [PROCESSED_DIR / ds for ds in datasets]
    for folder in folders:
        folder.mkdir(parents=True, exist_ok=True)
    log(f"[OK] Folders present for {len(datasets)} datasets")

    if not args.no_venv:
        create_venv()
        # Also on re-runs, so a failed or new installation is completed.
        if not args.no_install:
            install_requirements(args.update)

    log(f"\n[OK] Done. Next: copy each raw dataset into its folder in {RAW_DIR.relative_to(ROOT)}/")
    if not args.no_venv:
        log("     Activate the venv with: source .venv/bin/activate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
