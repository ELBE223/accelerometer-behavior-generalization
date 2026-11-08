# Beyond Training Data: How Well Do Accelerometer-Based Behavior Classifiers Generalize Across Datasets and Species?

**Lucas Beselerᵃ · Anne Bergerᵇ · Andreas Theisslerᶜ**

ᵃ Justus Liebig University Giessen, Giessen, Germany  
ᵇ Department of Evolutionary Ecology, Leibniz Institute for Zoo and Wildlife Research (Leibniz-IZW), Berlin, Germany  
ᶜ Institute of Computer Science, Justus Liebig University Giessen, Giessen, Germany

**Status:** Manuscript in preparation  
**Target journal:** *Ecological Informatics*  
**DOI:** To be added upon publication

---

## Overview

This repository accompanies the manuscript *Beyond Training Data*, which investigates the generalizability of accelerometer-based animal behavior classifiers across datasets and terrestrial mammal species.

The study integrates 11 accelerometer datasets covering 9 species and evaluates six machine-learning classifiers. Three research questions are addressed:

1. How does classification performance change when models are applied to unseen datasets?
2. How does transferability differ among behavioral classes?
3. Does functional-biomechanical similarity between species explain cross-species transfer performance?

<img width="250" height="250" alt="Terrestrial mammal species pictogram" src="https://github.com/user-attachments/assets/60189d8f-90ce-4210-9360-bf3efe61177d" />

## Repository structure

The repository is organized around six stages:

- **00_Documentation** — Datasets, behavioral harmonization, biological traits and the decision log (`decisions.md`)
- **01_Preprocessing** — Signal processing and feature extraction
- **02_Models** — Classifier implementations
- **03_Evaluation** — Training, within-dataset and transfer evaluations
- **04_Statistics** — Hypothesis testing and robustness analyses
- **05_Paper_Outputs** — Manuscript figures, tables, and supplementary materials

Each stage folder holds its code, its outputs and a README (inputs, outputs, manuscript sections). In addition:

- **config/** — Preprocessing settings (`pipeline_settings.json`)
- **data/** — Local data, not in git (see `data/README.md`)
- **tests/** — Consistency check of the paper outputs
- `setup_project.py` — Creates the local folders and the Python environment
- `update_local.sh` — Runs the pipeline steps and pushes the results (local workflow)

### From the data to the paper

```
data/raw ─▶ 01_Preprocessing ─▶ data/processed, data/windows, data/features
                                          │
                     02_Models ──────────▶ 03_Evaluation ─▶ 03_Evaluation/results/<scenario>/<model>/
                                                                     │
                                          04_Statistics ◀────────────┘
                                                │
                                                ▼
                         04_Statistics/results/<scenario>/ ─▶ 05_Paper_Outputs
```

Every table and figure of the manuscript is in `05_Paper_Outputs/`, named after its number (e.g. `supplementary/table_s16_h3_mixed_model.txt`). `05_Paper_Outputs/output_manifest.csv` lists each item with its title, file, source files, the script that made them and where the manuscript cites it.

| Manuscript | Content | Made by |
|---|---|---|
| Figure 1, Table 1; Tables S10–S11; Figure S2 | H1: within- vs. cross-dataset Macro-F1 and accuracy | `04_Statistics/stats_h1_h2.py` |
| Figure 2, Table 2; Tables S12–S14; Figure S3 | H2: cross-dataset F1 and transfer loss per class | `04_Statistics/stats_h1_h2.py` |
| Figure 3, Table 3; Tables S8–S9, S16–S19 | H3: distance and cross-species Macro-F1 | `04_Statistics/stats_h3.R` |
| Tables S1–S7, Figure S1 | Datasets, label mapping, preprocessing, features, classifiers, traits | `00_Documentation/`, `01_Preprocessing/`, `02_Models/` |
| Table S15 | Pairwise transfer between datasets | `04_Statistics/stats_h1_h2.py` |
| Table S20, Text S1 | Sensitivity scenarios with RF and LightGBM | `04_Statistics/` (all scenarios) |

All tables and figures are written by `05_Paper_Outputs/paper_figures.R`; the numbering is defined once at the top of that script and checked by `tests/check_paper_outputs.py`.

## Reproduce

### Paper outputs from the results in this repository (no raw data needed)

The model results (`03_Evaluation/results/`) and statistics (`04_Statistics/results/`) are in the repository. From the project folder:

```
python3.11 04_Statistics/stats_h1_h2.py     # H1, H2 and the input of H3
Rscript 04_Statistics/stats_h3.R            # H3 (lme4, lmerTest, cluster; optional gawdis, performance)
Rscript 05_Paper_Outputs/paper_figures.R    # all tables and figures (ggplot2, patchwork)
python3.11 tests/check_paper_outputs.py     # numbering, files and cross-references
```

Python 3.11 with the package versions that produced the results: `pip install -r requirements-lock.txt` (`setup_project.py` does this; direct dependencies in `requirements.txt`). R 4.5.2. The EltonTraits distance needs `data/raw/EltonTraits/MamFuncDat.txt` (Wilman et al. 2014) and the weighted trait distance needs the R package gawdis; without them, those rows of Tables 3 and S9 are left out.

### Full analysis (needs the raw data)

```
python3.11 setup_project.py && source .venv/bin/activate   # folders and environment
bash update_local.sh                       # pipeline: harmonize, windows, classes
bash update_local.sh models                # features, RF and LightGBM
bash update_local.sh models cnn resnet hydra multirocket   # signal models (hours)
bash update_local.sh sensitivity           # sensitivity scenarios (RF, LightGBM)
bash update_local.sh stats                 # H1–H3 statistics and paper outputs
```

`update_local.sh` also pulls the latest code and commits and pushes the reports and results; the single scripts can be run on their own (see the folder READMEs). Each script describes its input and output in its header.

## Data availability

Two datasets are publicly available:

- [Horsing Around – A Dataset Comprising Horse Movement](https://doi.org/10.4121/uuid:2e08745c-4178-4183-8551-f248c992cb14)
- [Japanese Black Beef Cow Behavior Classification Dataset](https://doi.org/10.5281/zenodo.5399258)

The remaining datasets are subject to access restrictions and cannot be redistributed. The repository holds no raw data values: only registry and mapping tables, summaries (window and class counts) and model results. Raw data are read only; every change is made in code and recorded in `00_Documentation/decisions.md`.

The repository is being developed to provide analysis code, documentation, and selected derived results to support transparency and reproducibility.

## Citation

The recommended citation and publication DOI will be added when available (see `CITATION.cff`).

Code: MIT (see `LICENSE`). This repository continues `ELBE223/paper-izw-cross-species-transfer` (state of commit b073a68) with only what the analysis and the paper need (D44, D45); working material such as the thesis scripts, raw data reports, trait reviews and uncited figures stays there.
