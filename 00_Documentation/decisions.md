# Methodological decisions

The decisions behind the analysis, in the order of the Methods. The code refers to them by
number (Dxx). The primary configuration (D02–D12) was fixed on 2026-10-24, before any model
was trained (D01).

## Datasets and behavior classes (Methods 2.1)

- **D01** No setting was chosen by classification performance; variants are reported as
  pre-specified sensitivity scenarios (D11), regardless of their outcome.
- **D02** Raw data are read only. One loader per dataset (`01_Preprocessing/loaders/`)
  writes a harmonized table: individual, segment, time, x, y, z (g), original label.
- **D10** Original labels are mapped to Resting, Locomotion, Foraging, Other or Exclude
  (`behavior_mapping.csv`, Table S2):
  - Drinking, sniffing and searching are Foraging.
  - Ruminating is Resting.
  - Climbing and walking in any place are Locomotion.
  - Grooming, scratching, shaking, social and fighting behavior are Other.
  - Handling by people, calibration markers, and unspecified, unknown or mixed labels are
    Exclude.
  - Gaits under a rider (Horse 2) are Exclude; ridden gaits and jumping are Locomotion in
    scenario "Ridden gaits as locomotion".
- **D12** All individuals are used for training and for cross-dataset and pairwise
  testing. A within-dataset test individual needs all three classes with at least 10
  evaluation windows each.
- **D15** Dog 2 has no animal identities: files with identical acceleration values are one
  recording, kept once, and each recording is an analytical unit (8 recordings).

## Signal preprocessing (Methods 2.2)

- **D03** Acceleration in g: e-obs counts as (raw − 2048) / 512 (±4 g); m s⁻² divided
  by 9.80665.
- **D04** Segments: one per burst; continuous data are split at gaps longer than 1.5
  sampling intervals, at changes of individual or recording, and at repeated or decreasing
  time stamps. Missing samples are not interpolated.
- **D17** Bursts in table exports: a new burst starts at a change of individual, file or
  recording key, when the time goes backwards or jumps by more than 1 s. Duplicated bursts
  are kept once if their labels agree and dropped if they differ.
- **D18** Where documents and data differ, the data decide: Giraffe 1 and Fox 1 at
  33.33 Hz, Dog 2 at 20 Hz with 124 samples per burst.
- **D19, D20** Dog 1: clock times written as HH.MM:SS are read as HH:MM:SS; rows coded for
  another dog are left out.
- **D05** Each segment is resampled to 25 Hz with a polyphase filter (anti-aliasing); its
  duration is kept.
- **D06** Windows of 2.0 s (50 samples) every 1.0 s within segments; shorter segments give
  no window.
- **D07** Labels are assigned after windowing. Primary analysis: only windows whose samples
  all belong to the same class.
- **D21** 26 window features of the dynamic acceleration (window mean removed) for RF and
  LightGBM (Table S4).

## Classifiers (Methods 2.2)

- **D22** Random Forest and LightGBM with default settings, without tuning.
- **D25** CNN, ResNet, HYDRA and MultiRocket on the window signals (Table S5); networks on
  the CPU with fixed seeds.
- **D24** Five seeds (42–46) fix the training-window draw and the random state of the
  models; the mean over the seeds enters the statistics.
- **D46** Python packages are installed with the versions of `requirements-lock.txt`, the
  versions of all model runs.

## Transfer evaluation (Methods 2.3)

- **D23** Within-dataset: leave one individual out, predictions of all folds pooled.
  Cross-dataset: train on all other datasets. Pairwise: train on one dataset, test on
  another (pairs of the same species flagged).
- **D08** Training uses overlapping windows; evaluation uses non-overlapping windows only.
  Training and test data are separated by individual or dataset before windows are drawn.
- **D09** Training windows: at least 30 per class; at most 250 per dataset and class,
  drawn across segments (one window per segment first, then a second, and so on).

## Biological distances (Methods 2.4)

- **D30** Body mass: one curated reference per taxon, ln(g); dog: mean of the two study
  means (26.75 kg).
- **D32, D34** Locomotor specialization (three groups) and body configuration (four groups),
  coded as in `traits/core_traits.md`.
- **D36** Trunk motion amplitude and directional change tendency are not core traits; they
  are used only in the exploratory analyses of Table S9.
- **D37** Five core traits, Gower distance with equal weights (Tables S6–S8).
- **D48** Divergence times from TimeTree 5, except domestic vs. Przewalski's horse: TimeTree
  gives 10.1 Myr (older than the genus Equus); the midpoint of their population divergence
  of 38–72 kyr (Orlando et al. 2013), 0.055 Myr, is used.

## Statistics and robustness (Methods 2.5)

- **D26** Seed means are the values in all tests. H1: paired Wilcoxon signed-rank tests with
  rank-biserial correlation. H2: Friedman tests with Kendall's W; pairwise Wilcoxon tests
  with Holm correction, interpreted only after a significant Friedman test. H3: dyadic
  mixed model; likelihood-ratio test of ML fits, estimates from the REML fit (Satterthwaite
  df), R² after Nakagawa.
- **D28** H3 robustness (Table S9, S18): other random-effects structures, adjustment for
  within-dataset Macro-F1, retention as response, weighted trait distance (gawdis),
  EltonTraits with and without diet, body mass difference, divergence time,
  leave-one-species-out refits, and the primary model per seed (Table S19).
- **D38** Trait sensitivity of the core distance, fixed before fitting: raccoon in a
  separate body configuration group, hedgehog neck length intermediate, each trait left
  out. **D43** adds cattle neck length short, decided after the results were known
  (marked † in Table S9).
- **D11** Sensitivity scenarios (Text S1, Table S20): no training overlap, 2.4-s windows,
  majority label (80%), four classes, ridden gaits as locomotion, eligible individuals only.
- **D27** The scenarios are run with RF and LightGBM only; the primary H3 model is also
  fitted to these two classifiers, as a reference for the scenarios.
