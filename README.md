# Accelerometer behavior classifiers across datasets and species

Code, documentation and results for the paper

> Beseler L, Berger A, Theissler A. *Beyond Training Data: How Well Do Accelerometer-Based
> Behavior Classifiers Generalize Across Datasets and Species?* (manuscript in preparation)

Eleven tri-axial accelerometer datasets of nine terrestrial mammal species, harmonized to
three behavioral classes (resting, locomotion, foraging). Six classifiers (RF, LightGBM,
CNN, ResNet, HYDRA, MultiRocket), three evaluation settings (within-dataset, cross-dataset,
pairwise source → target) and three hypotheses:

- **H1**: cross-dataset Macro-F1 is lower than within-dataset Macro-F1.
- **H2**: resting transfers better than locomotion and foraging.
- **H3**: cross-species Macro-F1 decreases with functional-biomechanical distance.

## Repository structure

The numbered folders follow the analysis from the raw data to the paper. Each folder
holds its code, its outputs and a README (what it does, inputs, outputs, manuscript
sections).

```
00_Documentation/     datasets, label mapping, traits, decision log (D01–D44)
01_Preprocessing/     raw data → harmonized samples → 2-s windows at 25 Hz → classes, features
02_Models/            the six classifiers
03_Evaluation/        training and evaluation (within, cross, pairwise) → results/
04_Statistics/        H1, H2 (Python) and H3 (R), sensitivity scenarios → results/
05_Paper_Outputs/     Tables 1–3, Figures 1–3, Tables S1–S20, Figures S1–S3, Text S1
config/               preprocessing settings (pipeline_settings.json)
data/                 local data, not in git (see data/README.md)
tests/                consistency check of the paper outputs
setup_project.py      creates the local folders and the Python environment
update_local.sh       runs the pipeline steps and pushes the results (local workflow)
```

## From the data to the paper

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

Every table and figure of the manuscript is in `05_Paper_Outputs/`, named after its
number (e.g. `supplementary/table_s16_h3_mixed_model.txt`).
`05_Paper_Outputs/output_manifest.csv` lists each item with its title, file, source files,
the script that made them and where the manuscript cites it.

| Manuscript | Content | Made by |
|---|---|---|
| Figure 1, Table 1; Tables S10–S11; Figure S2 | H1: within- vs. cross-dataset Macro-F1 and accuracy | `04_Statistics/stats_h1_h2.py` |
| Figure 2, Table 2; Tables S12–S14; Figure S3 | H2: cross-dataset F1 and transfer loss per class | `04_Statistics/stats_h1_h2.py` |
| Figure 3, Table 3; Tables S8–S9, S16–S19 | H3: distance and cross-species Macro-F1 | `04_Statistics/stats_h3.R` |
| Tables S1–S7, Figure S1 | Datasets, label mapping, preprocessing, features, classifiers, traits | `00_Documentation/`, `01_Preprocessing/`, `02_Models/` |
| Table S15 | Pairwise transfer between datasets | `04_Statistics/stats_h1_h2.py` |
| Table S20, Text S1 | Sensitivity scenarios with RF and LightGBM | `04_Statistics/` (all scenarios) |

All tables and figures are written by `05_Paper_Outputs/paper_figures.R`. The numbering
is defined once at the top of that script. `tests/check_paper_outputs.py` checks that it
is complete and consistent.

## Reproduce

### Paper outputs from the results in this repository (no raw data needed)

The model results (`03_Evaluation/results/`) and statistics (`04_Statistics/results/`)
are in the repository. From the project folder:

```
python3.11 04_Statistics/stats_h1_h2.py     # H1, H2 and the input of H3
Rscript 04_Statistics/stats_h3.R            # H3 (lme4, lmerTest, cluster; optional gawdis, performance)
Rscript 05_Paper_Outputs/paper_figures.R    # all tables and figures (ggplot2, patchwork)
python3.11 tests/check_paper_outputs.py     # numbering, files and cross-references
```

Python packages: `requirements.txt` (versions used: `requirements-lock.txt`); Python 3.11,
R 4.5.2. The EltonTraits distance needs `data/raw/EltonTraits/MamFuncDat.txt` (Wilman et
al. 2014) and the weighted trait distance needs the R package gawdis. Without them, those
rows of Tables 3 and S9 are left out.

### Full analysis (needs the raw data)

```
python3.11 setup_project.py && source .venv/bin/activate   # folders and environment
bash update_local.sh                       # pipeline: harmonize, windows, classes
bash update_local.sh models                # features, RF and LightGBM
bash update_local.sh models cnn resnet hydra multirocket   # signal models (hours)
bash update_local.sh sensitivity           # sensitivity scenarios (RF, LightGBM)
bash update_local.sh stats                 # H1–H3 statistics and paper outputs
```

`update_local.sh` also pulls the latest code and commits and pushes the reports and
results; the single scripts can be run on their own (see the folder READMEs). Each script
describes its input and output in its header.

## Data

Two datasets are public: cattle (Ito et al. 2022) and horses (Kamminga et al. 2019,
doi:10.4121/uuid:2e08745c-4178-4183-8551-f248c992cb14). The other nine come from theses at
the Leibniz Institute for Zoo and Wildlife Research (Leibniz-IZW) and are not shared. Raw data
are read only; every change is made in code and recorded in `00_Documentation/decisions.md`.
The dataset reports (`01_Preprocessing/reports/dataset_reports/`) contain a few example
values per column; check them before the repository is made public.

## Citation and license

See `CITATION.cff`. Code: MIT (see `LICENSE`).

This repository continues `ELBE223/paper-izw-cross-species-transfer` (state of commit
b073a68); the move to this layout is decision D44.
