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

- **00_Documentation** — Datasets, behavioral harmonization, and biological traits
- **01_Preprocessing** — Signal processing and feature extraction
- **02_Models** — Classifier implementations and training
- **03_Evaluation** — Within-dataset and transfer evaluations
- **04_Statistics** — Hypothesis testing and robustness analyses
- **05_Paper_Outputs** — Manuscript figures, tables, and supplementary materials

## Running the analysis

Requirements: Python 3.11 and R (packages lme4, lmerTest, cluster, ggplot2, patchwork).
From the project folder:

1. Set up the Python environment with the locked package versions:
   `python3.11 setup_project.py`
2. Preprocess the raw data (needs the raw datasets in `data/raw/`):
   `bash run_pipeline.sh pipeline`
3. Train and evaluate the six classifiers, then the sensitivity scenarios:
   `bash run_pipeline.sh models all` and `bash run_pipeline.sh sensitivity`
4. Statistics, tables, figures and checks from the stored model results
   (`03_Evaluation/results/`, no raw data needed): `bash run_pipeline.sh stats`

Step 4 runs `04_Statistics/stats_h1_h2.py`, `04_Statistics/stats_h3.R`,
`05_Paper_Outputs/paper_figures.R` and `tests/check_paper_outputs.py`. Methodological
decisions are listed in `00_Documentation/decisions.md`.

## Data availability

Two datasets are publicly available:

- [Horsing Around – A Dataset Comprising Horse Movement](https://doi.org/10.4121/uuid:2e08745c-4178-4183-8551-f248c992cb14)
- [Japanese Black Beef Cow Behavior Classification Dataset](https://doi.org/10.5281/zenodo.5849025)

The remaining datasets are subject to access restrictions and cannot be redistributed.

The repository is being developed to provide analysis code, documentation, and selected derived results to support transparency and reproducibility.

## Citation

The recommended citation and publication DOI will be added when available.
