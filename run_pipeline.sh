#!/usr/bin/env bash
# run_pipeline.sh
#
# Runs the analysis steps from the project folder (after python3.11 setup_project.py).
#
#   bash run_pipeline.sh pipeline [datasets]     raw data -> windows, classes, features
#   bash run_pipeline.sh models [models] [opts]  RF and LightGBM (default), or the named models
#                                                ("all" for all six); options go to train_models.py
#   bash run_pipeline.sh sensitivity             sensitivity scenarios with RF and LightGBM
#   bash run_pipeline.sh stats                   H1-H3 statistics, tables and figures, check
#
# A dataset that fails in the pipeline is skipped (the error is in its report in
# 01_Preprocessing/reports/pipeline_reports/); the script ends with an error message then.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$ROOT/.venv/bin/python"
cd "$ROOT"

if [ ! -x "$PY" ]; then
  echo "[ERROR] No venv found. Run first: python3.11 setup_project.py"
  exit 1
fi
# macOS writes "._" files on external drives; they break pip, Python and git.
find .venv config 00_Documentation 01_Preprocessing 02_Models 03_Evaluation 04_Statistics 05_Paper_Outputs tests \
  -name '._*' -delete 2>/dev/null || true

mode="${1:-}"
args=("${@:2}")
failed=""

run_stats() {
  "$PY" 04_Statistics/stats_h1_h2.py
  Rscript 04_Statistics/stats_h3.R
  Rscript 05_Paper_Outputs/paper_figures.R
  "$PY" tests/check_paper_outputs.py
}

case "$mode" in
  pipeline)
    "$PY" 01_Preprocessing/prepare_raw_data.py
    "$PY" 01_Preprocessing/harmonize.py ${args[@]+"${args[@]}"} || failed="harmonize.py"
    "$PY" 01_Preprocessing/make_windows.py ${args[@]+"${args[@]}"} || failed="$failed make_windows.py"
    "$PY" 01_Preprocessing/assign_classes.py || failed="$failed assign_classes.py"
    "$PY" 01_Preprocessing/features.py ${args[@]+"${args[@]}"} || failed="$failed features.py"
    "$PY" 01_Preprocessing/checks/check_activity.py || failed="$failed check_activity.py"
    ;;
  models)
    # Model names first, then options of train_models.py (e.g. --seeds 43 --add).
    names=(); opts=()
    for a in ${args[@]+"${args[@]}"}; do
      if [ "${#opts[@]}" -gt 0 ] || [[ "$a" == --* ]]; then opts+=("$a"); else names+=("$a"); fi
    done
    model_args=()
    if [ "${#names[@]}" -gt 0 ]; then model_args=(--models "${names[@]}"); fi
    "$PY" 03_Evaluation/train_models.py ${model_args[@]+"${model_args[@]}"} ${opts[@]+"${opts[@]}"}
    ;;
  sensitivity)
    # Scenario C uses its own windows (2.4 s without overlap).
    "$PY" 01_Preprocessing/make_windows.py --variant C
    "$PY" 01_Preprocessing/assign_classes.py --variant C
    "$PY" 01_Preprocessing/features.py --variant C
    for scenario in A C majority four_classes E F; do
      "$PY" 03_Evaluation/train_models.py --models rf lgbm --scenario "$scenario" || failed="$failed $scenario"
    done
    ;;
  stats)
    run_stats
    ;;
  *)
    echo "Usage: bash run_pipeline.sh pipeline|models|sensitivity|stats [arguments]"
    exit 1
    ;;
esac

if [ -n "$failed" ]; then
  echo "DONE WITH ERRORS in:$failed"
  exit 1
fi
echo "DONE"
