#!/usr/bin/env bash
# update_local.sh
#
# Purpose:
# - One command for the local update: removes macOS "._" files from .git, gets the
#   latest code (git pull), installs new packages (setup_project.py), prepares the raw
#   data (prepare_raw_data.py), runs the pipeline (harmonize.py, make_windows.py,
#   assign_classes.py, features.py), the models (train_models.py), the statistics
#   (stats_h1_h2.py, stats_h3.R), the paper figures and tables (paper_figures.R) and/or writes the dataset
#   reports, and commits and pushes the documentation and results.
# - Stops at the first error; nothing is pushed then. Exception: in the pipeline a dataset
#   that fails is skipped (the error is in its pipeline report), the others go on, and
#   the reports are pushed before the script ends with an error message.
# - Generated files (dataset reports, thesis checks, requirements-lock.txt) with local
#   changes are reset before the pull, because this script writes them again. Not the
#   model results: results of a model run that stopped before its push (hours of
#   computing; --add builds on them) are committed before the pull and pushed at the end.
#
# Usage:
#   bash update_local.sh            # pipeline for all datasets with a loader
#   bash update_local.sh reports    # dataset reports for all datasets
#   bash update_local.sh all        # both
#   bash update_local.sh pipeline Cattle_dataset_1   # selected datasets
#   bash update_local.sh classes    # only classes (after a mapping change)
#   bash update_local.sh models     # features, RF and LightGBM (03_Evaluation/results)
#   bash update_local.sh models cnn resnet hydra multirocket
#   bash update_local.sh models cnn resnet hydra multirocket --seeds 43 --add
#                                                        # options after the model names go to train_models.py
#   bash update_local.sh stats      # H1-H3, figures and tables (04_Statistics/results, 05_Paper_Outputs)
#   bash update_local.sh sensitivity  # D11 scenarios with RF and LightGBM (D27)
#
# If the git pull changes this script, the new version is started at once.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$ROOT/.venv/bin/python"
# Only generated folders (05_Paper_Outputs also holds paper_figures.R, which is never reset).
PAPER_OUTPUTS=(05_Paper_Outputs/main 05_Paper_Outputs/supplementary 05_Paper_Outputs/additional 05_Paper_Outputs/output_manifest.csv)
GENERATED=(01_Preprocessing/reports 03_Evaluation/results 04_Statistics/results "${PAPER_OUTPUTS[@]}" requirements-lock.txt)

step() { printf '\n=== %s\n' "$1"; }

# H1 and H2 in Python, H3 in R (D26), then the paper figures and their check; without R only
# H1 and H2.
# The figures and tables of the paper (05_Paper_Outputs) come from paper_figures.R after the H3
# statistics.
run_stats() {
  "$PY" 04_Statistics/stats_h1_h2.py || return 1
  if command -v Rscript >/dev/null 2>&1; then
    Rscript 04_Statistics/stats_h3.R || return 1
  else
    echo "[WARN] Rscript not found; H3 (04_Statistics/stats_h3.R) and the paper figures (05_Paper_Outputs/paper_figures.R) skipped"
  fi
  if command -v Rscript >/dev/null 2>&1; then
    Rscript 05_Paper_Outputs/paper_figures.R || return 1
    # Manifest, numbering and cross-references of 05_Paper_Outputs.
    "$PY" tests/check_paper_outputs.py || return 1
  fi
}

# Everything runs inside main, so bash has read the whole script before git pull
# can replace this file.
main() {
  cd "$ROOT"
  local mode="${1:-pipeline}"
  local datasets=("${@:2}")  # optional: only these datasets
  case "$mode" in
    pipeline|reports|all|classes|models|stats|sensitivity) ;;
    *) echo "[ERROR] Unknown option '$mode' (use: pipeline, reports, all, classes, models, stats, sensitivity)"; exit 1 ;;
  esac
  if [ ! -x "$PY" ]; then
    echo "[ERROR] No venv found. Run first: python3.11 setup_project.py"
    exit 1
  fi

  step "1/6 Remove macOS metadata files"
  # "._*" files confuse git (.git), pip (.venv) and Python (code); raw data stay untouched.
  find .git .venv config 00_Documentation 01_Preprocessing 02_Models 03_Evaluation 04_Statistics 05_Paper_Outputs tests \
    -name '._*' -delete 2>/dev/null || true

  step "2/6 Get the latest code"
  if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
    echo "[ERROR] An earlier git pull is unfinished. Run 'git rebase --abort' and start this script again."
    exit 1
  fi
  # On exFAT drives git can see unchanged files as modified until the index is refreshed.
  git update-index -q --refresh || true
  if [ -n "$(git status --porcelain -- 03_Evaluation/results)" ]; then
    git add 03_Evaluation/results
    git commit -q -m "Results of a stopped model run (kept by update_local.sh)"
    echo "[INFO] Results in 03_Evaluation/results that were not pushed yet are kept (committed, pushed at the end)"
  fi
  for path in "${GENERATED[@]}"; do
    git checkout -- "$path" 2>/dev/null || true
  done
  git update-index -q --refresh || true
  local self_hash
  self_hash="$(git hash-object update_local.sh)"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "[ERROR] Uncommitted changes in these files; commit or discard them first:"
    git status --short --untracked-files=no
    exit 1
  fi
  git pull --rebase
  if [ -z "${UPDATE_LOCAL_RESTARTED:-}" ] && [ "$(git hash-object update_local.sh)" != "$self_hash" ]; then
    echo "[INFO] update_local.sh was updated by the pull; starting the new version"
    UPDATE_LOCAL_RESTARTED=1 exec bash "$ROOT/update_local.sh" "$@"
  fi

  step "3/6 Install new packages"
  "$PY" setup_project.py

  step "4/6 Prepare raw data"
  "$PY" 01_Preprocessing/prepare_raw_data.py

  if [ "$mode" = "reports" ] || [ "$mode" = "all" ]; then
    step "5/6 Dataset reports"
    "$PY" 01_Preprocessing/dataset_report.py ${datasets[@]+"${datasets[@]}"}
  fi
  local failed=""
  if [ "$mode" = "pipeline" ] || [ "$mode" = "all" ]; then
    step "5/6 Pipeline: harmonized samples and windows"
    "$PY" 01_Preprocessing/harmonize.py ${datasets[@]+"${datasets[@]}"} || failed="harmonize.py"
    "$PY" 01_Preprocessing/make_windows.py ${datasets[@]+"${datasets[@]}"} || failed="$failed make_windows.py"
    # Fast; always for all windowed datasets, so the class report stays complete.
    "$PY" 01_Preprocessing/assign_classes.py || failed="$failed assign_classes.py"
    "$PY" 01_Preprocessing/features.py ${datasets[@]+"${datasets[@]}"} || failed="$failed features.py"
    "$PY" 01_Preprocessing/checks/check_activity.py || failed="$failed check_activity.py"
  fi
  if [ "$mode" = "classes" ]; then
    step "5/6 Classes of the windows and activity check"
    "$PY" 01_Preprocessing/assign_classes.py || failed="assign_classes.py"
    if ls data/features/*/features.parquet >/dev/null 2>&1; then
      "$PY" 01_Preprocessing/checks/check_activity.py || failed="$failed check_activity.py"
    fi
  fi
  if [ "$mode" = "models" ]; then
    step "5/6 Features and models"
    "$PY" 01_Preprocessing/assign_classes.py || failed="assign_classes.py"
    "$PY" 01_Preprocessing/features.py || failed="$failed features.py"
    "$PY" 01_Preprocessing/checks/check_activity.py || failed="$failed check_activity.py"
    # Optional: model names after "models" (default: rf lgbm; "all" for all six), then
    # options of train_models.py (e.g. --seeds 43 --add).
    local model_args=() names=() opts=()
    local arg
    for arg in ${datasets[@]+"${datasets[@]}"}; do
      if [ "${#opts[@]}" -gt 0 ] || [[ "$arg" == --* ]]; then opts+=("$arg"); else names+=("$arg"); fi
    done
    if [ "${#names[@]}" -gt 0 ]; then model_args=(--models "${names[@]}"); fi
    model_args+=(${opts[@]+"${opts[@]}"})
    "$PY" 03_Evaluation/train_models.py ${model_args[@]+"${model_args[@]}"} || failed="$failed train_models.py"
    run_stats || failed="$failed statistics"
  fi
  if [ "$mode" = "stats" ]; then
    step "5/6 Statistics H1-H3"
    run_stats || failed="statistics"
  fi
  if [ "$mode" = "sensitivity" ]; then
    step "5/6 Sensitivity analyses (D11, D27): windows of C, RF and LightGBM for every scenario"
    "$PY" 01_Preprocessing/assign_classes.py || failed="assign_classes.py"
    "$PY" 01_Preprocessing/features.py || failed="$failed features.py"
    # C: 2.4 s windows without overlap, in data/windows_C/ and data/features_C/.
    "$PY" 01_Preprocessing/make_windows.py --variant C || failed="$failed make_windows.py-C"
    "$PY" 01_Preprocessing/assign_classes.py --variant C || failed="$failed assign_classes.py-C"
    "$PY" 01_Preprocessing/features.py --variant C || failed="$failed features.py-C"
    local scenario
    for scenario in A majority four_classes E F C; do
      "$PY" 03_Evaluation/train_models.py --models rf lgbm --scenario "$scenario" || failed="$failed train_models.py-$scenario"
    done
    run_stats || failed="$failed statistics"
  fi

  step "6/6 Commit and push the documentation"
  find .git -name '._*' -delete
  git update-index -q --refresh || true
  # The reports can take minutes; changes pushed in the meantime are pulled before the
  # commit (the new reports are set aside and put back), so no commit has to be replayed.
  git pull --rebase --autostash
  git add 00_Documentation 01_Preprocessing/reports requirements-lock.txt
  for path in 03_Evaluation/results 04_Statistics/results "${PAPER_OUTPUTS[@]}"; do
    if [ -e "$path" ]; then git add "$path"; fi
  done
  if git diff --cached --quiet; then
    echo "[INFO] Nothing new to commit"
  else
    git commit -m "Update reports (local update: $mode)"
  fi
  git push

  echo
  if [ -n "$failed" ]; then
    echo "FERTIG, ABER MIT FEHLERN in: $failed"
    echo "Die Berichte (mit den Fehlermeldungen) sind gepusht."
    exit 1
  fi
  echo "ALLES FERTIG"
}

main "$@"
