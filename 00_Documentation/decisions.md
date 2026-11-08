# Decision log

One entry per decision: what was decided, why, and which datasets are affected.
Entries marked **draft** are proposals; they become **confirmed** after review and
before any model is trained with them. The thesis procedure is given for comparison
(scripts in `code/thesis_reference/`, details in `raw_data_review.md`).

## Template

### YYYY-MM-DD – Short title
- Status: draft / confirmed
- Datasets: all / <dataset>
- Decision:
- Reason:
- Thesis:
- Alternatives considered:

---

### D01 2026-10-24 – Fix the primary configuration before any results
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: The preprocessing settings in D04–D10 are fixed before models are trained.
  Variants are reported as pre-specified sensitivity analyses (D11), in full and
  regardless of their outcome. No setting is chosen by classification performance.
- Reason: Choosing window length, overlap or labels by performance on the evaluation
  data inflates the results and cannot be separated from the transfer question.
- Fixed: 2026-10-24, commit d168e17 (all decisions D01–D20 confirmed; any later change
  is a new, dated entry).
- Thesis: settings were fixed in the scripts; no comparison of variants.
- Alternatives considered: a preliminary comparison of variants with RF and CNN to
  select the configuration; rejected, because any selection rule needs held-out data
  that the transfer design does not have to spare.

### D02 2026-10-24 – Raw data read only, one loader per dataset
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: Each dataset has its own loader in `code/` that reads `01_raw_data/<dataset>/`
  unchanged and writes one harmonized sample table to `02_processed_data/<dataset>/`
  with: dataset, individual, segment, time (s), x, y, z (g), original label, source file.
  The original labels are kept; the mapping to classes is applied later from one table
  (D10).
- Reason: Every step is reproducible from the raw data, and the mapping can be changed
  without reprocessing.
- Thesis: dataset-specific R scripts (`02.R`) wrote the mapped class only.
- Alternatives considered: none.

### D03 2026-10-24 – Acceleration in g
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: All axes in g. e-obs raw counts (12 bit): (raw − 2048) / 512, i.e. ±4 g,
  unless the documentation of a dataset gives a tag-specific calibration, which is then
  used. m/s² values are divided by 9.80665. Clipped values (at the sensor range) are
  counted per dataset.
- Reason: Models and features need a common unit; the conversion is the one of the
  thesis, so the results stay comparable.
- Thesis: (raw − 2048) / 512 for all e-obs datasets, Horse_dataset_2 / 256.
- Alternatives considered: per-window standardization instead of a physical unit;
  removes gravity and posture information that separates resting postures.
- Open: sensor range and calibration per dataset from the documentation.

### D04 2026-10-24 – Segments
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: A segment is a stretch of samples without interruption: one burst in burst
  data; in continuous data, a new segment starts at a time gap of more than 1.5 sampling
  intervals (even a single missing sample), at a change of individual or recording, at
  a repeated time stamp, or where time goes backwards. Windows never cross segment
  boundaries; missing samples are not interpolated.
- Reason: A window across a gap combines unrelated movement, and filling gaps would add
  values that were not measured. The cost is small: in Cattle_dataset_1, 888 of about
  1 030 gaps are single missing samples, and the 515 segments shorter than one window
  hold 0.9 % of all samples (1.2 % of the labeled samples).
- Thesis: similar (`03_windowing_preflight.R`), with a gap factor of 3.
- Alternatives considered: bridging single missing samples by interpolation (gap factor
  3 as in the thesis); about 1 % more data for interpolated values.

### D05 2026-10-24 – Resampling to 25 Hz with anti-aliasing
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: Each segment is resampled to 25 Hz with a polyphase filter (anti-aliasing
  low-pass when the rate is reduced). The time axis is never stretched: a segment keeps
  its real duration.
- Reason: All models need the same number of samples per window. 25 Hz keeps the thesis
  rate and is the native rate of Cattle_dataset_1. Linear interpolation without a
  low-pass filter folds movement above 12.5 Hz into lower frequencies.
- Thesis: 25 Hz by linear interpolation; clips shorter than 2.46 s were stretched to 62
  samples (Hedgehog 731 of 1 037 windows, Fox_dataset_1 90 of 913).
- Alternatives considered: 20 Hz (closer to the lowest native rate, 18.74 Hz); rejected
  for comparability. Up-sampling of 18.74 and 20 Hz data adds no information but keeps
  the format.

### D06 2026-10-24 – Windows: 2 s, step 1 s
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: Windows of 2.0 s (50 samples at 25 Hz) on a fixed grid from the start of each
  segment, step 1.0 s (50 % overlap). Segments shorter than 2.0 s give no window; they are
  counted, not padded or stretched. Each window has a flag `non_overlapping` for the
  windows on the 2-s grid (offsets 0, 2, 4 … s), which form the windowing without overlap.
- Reason: With the burst lengths of the theses (`sensor_settings.csv`), a 2-s window fits
  into every burst setting except the first phase of Raccoon_dataset_1 (1.62 s): one
  window per burst of 2.46–2.88 s (Bison, Horse_dataset_1, Giraffe, Hedgehog,
  Raccoon_dataset_1 phase 2), two per 3.3-s burst, more in longer bursts and continuous
  recordings. A window of 2.46–2.48 s (thesis) needs the whole 82-sample burst and no
  sample may be missing.
  The authors of Horse_dataset_2 used the same setting (200 samples at 100 Hz, 50 %
  overlap; `settings.csv` of the dataset).
- Thesis: 2.46 s (62 samples at 25 Hz; one 82-sample burst at 33.33 Hz), no overlap.
- Alternatives considered: 2.4 s without overlap (sensitivity C, D11).
- Consequence (run of 2026-10-24): Hedgehog bursts have up to 264 samples, but a median
  of 194 rows in the data; 1 248 of 2 473 bursts (32 % of the samples) are shorter than
  2 s and give no window, 1 225 windows remain. Accepted. Raccoon_dataset_1 phase 1
  (1.62 s) would give no window; the data contain only phase 2.

### D07 2026-10-24 – Window labels after windowing
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: Window positions do not depend on labels. Labels are assigned afterwards:
  primary analysis with pure windows only (all samples belong to the same class of the
  mapping, D10; `code/assign_classes.py`); windows with mixed or missing labels are
  excluded and counted per dataset and class (`class_report.txt`).
  Data with one label per burst give pure windows by construction.
- Reason: Placement independent of behavior changes; the excluded share is reported, so
  a possible selection bias is visible.
- Thesis: homogeneous segments first, windows inside them; majority vote for Giraffe.
- Alternatives considered: majority label (sensitivity, D11).

### D08 2026-10-24 – Overlapping windows for training only
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: Training uses all windows (50 % overlap); evaluation uses only the windows
  with `non_overlapping`. Training and test data are always separated by individual
  (within-dataset) or by dataset (cross-dataset) before windows are selected.
- Reason: Each part of the test data is counted once; overlapping windows from the same
  burst never end up on both sides of a split.
- Thesis: no overlap in training or test.
- Alternatives considered: overlap in both; inflates the effective test size.

### D09 2026-10-24 – Training cap spread over segments
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: The cap of 250 training windows per class is drawn across segments: first at
  most one window per segment (random, fixed seed), then a second per segment, and so on,
  until the cap is reached. The number of segments and individuals behind each training
  set is reported.
- Reason: With overlap, a plain random draw can take many near-identical windows from a
  few bursts.
- Thesis: random draw of 250 windows per class.
- Alternatives considered: plain random draw.

### D10 2026-10-24 – Behavior mapping table
- Status: confirmed (Lucas, 2026-10-24); StB (Raccoon_dataset_1) clarified 2026-10-27:
  "Stehen, Kopf bewegt" (Mardaus 2017, Tab. 2), grouped with StH and StN as standing and
  resting (Tab. 5–7), so Resting as in the thesis
- Datasets: all
- Decision: One table `00_documentation/behavior_mapping.csv` with the classes Foraging,
  Locomotion, Resting, Other and Exclude. Primary analysis: Foraging, Locomotion,
  Resting; Other only in the 4-class sensitivity analysis (D11); Exclude never.
  Columns: dataset, original label, class, sensitivity class (D11 E, where it differs),
  thesis class (from the thesis scripts;
  Horse_dataset_2 from the converted thesis files, Cattle_dataset_1 inferred from the
  thesis window counts), class in the mapping table of the dataset, status (as
  thesis / differs from thesis), pure test windows of the run of 2026-10-24 (for orientation
  only; class-level counts come from the pipeline), note.
  Rules used across datasets:
  - R1 Drinking is Foraging (as in the thesis for Bison, Fox_dataset_1, Giraffe).
  - R2 Ruminating is Resting (as in the thesis for Cattle and Giraffe).
  - R3 Not behavior of the animal itself: handled, carried or shaken by people,
    calibration markers (STARTSHAKE, ENDSHAKE) – Exclude.
  - R4 Unspecified, unknown or mixed labels (Cattle ETC, Horse_dataset_2 unknown,
    Raccoon_dataset_2 L/St) – Exclude.
  - R5 Gaits under a rider (and the probably ridden jumping) – Exclude and Other;
    Locomotion in the thesis and in sensitivity analysis E (D11).
  - R6 Sniffing and searching are Foraging (as in the thesis).
  - R7 Climbing and walking in any place are Locomotion.
  - Grooming, scratching, shaking, social and fighting behavior are Other.
  A window has a class if all its samples are labeled and map to the same class; two
  original labels of one class in a window are fine (`code/assign_classes.py`).
- Reason: One place for all mapping decisions, with reasons, applied by code.
- Thesis: mapping in each `02.R`; Other dropped before windowing.
- Alternatives considered: 4 classes with Other as primary analysis; Other differs too
  much between species to be one class for transfer (sensitivity, D11).

### D11 2026-10-24 – Pre-specified sensitivity analyses
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: Reported in addition to the primary analysis (2 s, 50 %/0 %, pure windows,
  3 classes, 25 Hz):
  - A: 2 s windows without overlap in training;
  - C: 2.4 s windows (60 samples) without overlap, close to the thesis windows (2.46 s)
    and with a margin in the 2.46-s bursts of Bison, Horse_dataset_1 and Giraffe;
  - majority class instead of pure windows: at least 80 % of the samples of a window in
    one class (`class_share` >= 0.8 in `classes.parquet`; samples with an Exclude label
    or without label count against it);
  - 4 classes including Other;
  - E: ridden gaits of Horse_dataset_2 as Locomotion, as in the thesis (column
    `sensitivity_class` of `behavior_mapping.csv`; agreed with Lucas, 2026-10-24).
  - F: only individuals that meet the thesis rule (all three main classes with at
    least 10 evaluation windows), in all evaluations (D12; agreed with Lucas,
    2026-10-24).
  Each is interpreted descriptively against the primary analysis, as in
  `ANALYSIS_PLAN.md` of the thesis repository.
- Reason: shows how much the conclusions depend on preprocessing choices.
- Thesis: none for preprocessing.
- Alternatives considered: none.

### D12 2026-10-24 – Individuals included
- Status: confirmed (Lucas, 2026-10-24): option 2
- Datasets: all
- Decision: All individuals stay in training and in the tests between datasets. The
  thesis rule (all three main classes with at least 10 evaluation windows) applies only
  to the test individual of within-dataset folds (one individual held out). The thesis
  rule for all evaluations is sensitivity analysis F (D11).
- Reason: In a transfer from dataset A to dataset B the whole dataset B is tested, and
  Macro-F1 over its classes is defined as long as the dataset has all classes; an
  individual without one class does not distort it. In a within-dataset fold the test
  individual alone is scored, so it needs all classes. With the thesis rule for
  everything, only one of six hedgehogs (Fred) would remain, which makes folds between
  hedgehogs impossible. Run of 2026-10-24 (`pipeline_reports/class_report.txt`): the
  thesis rule leaves out Duke (Dog_dataset_1, no Foraging), 5 of 6 hedgehogs, Niro,
  Noortje, Pan and Viva (Horse_dataset_2) and Emma (Raccoon_dataset_2, no Locomotion).
- Thesis: thesis rule for everything (`07_make_final_model_datasets_updated.R`); it
  removed 2 of 14 dogs (Duke, and Lumpi after the loss of his bursts, D19), 4 of 6
  hedgehogs, 4 of 11 horses (Horse_dataset_2) and Emma.
- Alternatives considered: option 1, the thesis rule for everything (kept as
  sensitivity analysis F).

### D13 2026-10-24 – No reduction of Fox_dataset_2 during preprocessing
- Status: not applicable (Fox_dataset_2 left out, D14)
- Datasets: Fox_dataset_2
- Decision: All labeled bursts are processed. Its size affects training only through the
  cap (D09); if test sets must be reduced, then per individual × class with a fixed seed.
- Reason: A random 25 % share can remove rare classes and is hard to justify.
- Thesis: all windows (68 319).
- Alternatives considered: random 25 % of the data.

### D14 2026-10-24 – Fox_dataset_2 left out until its label provenance is clear
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: Fox_dataset_2
- Decision: Fox_dataset_2 is left out: no loader, no windows, no analysis. It is only
  taken up again when Lucas decides so explicitly, e.g. once it is known how its labels
  were created (observations: include; model predictions: at most a separate
  sensitivity analysis with model-derived labels). A plausibility check (VeDBA per class
  compared with Fox_dataset_1; agreement of a model trained on Fox_dataset_1) can support
  that decision, but does not replace it. The raw data and the dataset report stay as
  documentation.
- Reason: If Fox_dataset_2 labels are predictions of a model trained on captive foxes
  (Rast et al. 2020, possibly the Fox_dataset_1 animals), a test on Fox_dataset_2 measures
  agreement with that model, not behavior; training on it passes the model's errors on.
  Transfer Fox_dataset_1 → Fox_dataset_2 would be inflated in particular.
- Consequence: the red fox is represented by Fox_dataset_1 only (2 individuals).
- Thesis: included as a regular dataset (68 319 windows, the largest dataset).
- Alternatives considered: keep it and exclude only the fox–fox pairs; does not remove
  the bias of using predictions as ground truth for other species.

### D15 2026-10-24 – Dog_dataset_2: one unit per recording
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: Dog_dataset_2
- Decision: Files with identical acceleration values are one recording; it is kept once.
  The unit for splits is the recording, named after all its files (e.g. `Ami+Winston`),
  not a dog name. Each recording has its own `Number` (8 recordings, 8 values; two files
  also contain 302, apparently a typo of 4302), listed in the harmonization report.
  Implemented in `code/loaders/dog_dataset_2.py`.
- Reason: The raw files contain the same recordings under several dog names and dates;
  keeping all copies would put identical data on both sides of an individual split and
  multiply the dataset.
- Thesis: 7 units keyed by `Number`; no duplicate windows.
- Alternatives considered: exclude the dataset; not needed, since the 8 recordings are
  consistent in themselves.

### D16 2026-10-24 – Example values in the dataset reports
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: The dataset reports keep a few example values per column ("first values").
  Raw data are not shared otherwise (no direct access, not in git). Before the repository
  is made public, the example values are removed from the reports and from the history.
- Reason: The examples show formats (time stamps, codes) that summaries do not; the
  repository is private.

### D17 2026-10-24 – Bursts in table exports
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: Dog_dataset_1, Dog_dataset_2, Fox_dataset_1, Giraffe_dataset_1,
  Hedgehog_dataset_1, Raccoon_dataset_1, Raccoon_dataset_2 (`code/loaders/bursts.py`)
- Decision: The rows are read in file order. A new burst starts where the individual, the
  file or a key column (tag, recording file, tag day) change, where the time goes
  backwards, or where it jumps by more than 1 s (inside a burst the time is either the
  burst start in every row or the time of each sample). A run longer than the burst
  length (two bursts with the same time) is cut into pieces of the burst length. Bursts
  with exactly the same acceleration values as an earlier burst are copies: with the same
  labels one is kept, with different labels all copies are dropped.
- Reason: The exports have no sample number, so the burst borders come from the time
  column; copies would count the same movement twice and could put it on both sides of
  a split. The report counts each case (runs cut, cuts not matching the burst length,
  copies, key changes without a new time).
- Thesis: bursts from the time stamps (`04_make_native_windows.R`); copies not checked.
- Alternatives considered: keep one copy also when the labels differ (the label would be
  chosen arbitrarily).

### D18 2026-10-24 – Sampling rates where documents and data differ
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: Giraffe_dataset_1, Fox_dataset_1, Dog_dataset_2
- Decision: Giraffe_dataset_1 33.33 Hz (thesis PDF: 33.8 Hz); Fox_dataset_1 33.33 Hz
  (thesis: 33 Hz); Dog_dataset_2 20 Hz with 124 samples per burst (Settings.rtf: 130).
- Reason: Giraffe: the sample times step by 0.0299–0.03 s and the last of 82 samples
  lies 2.43 s after the burst start, which fits 33.33 Hz (33.8 Hz would give 2.40 s);
  33.8 Hz is not an e-obs setting, the other e-obs datasets use 33.33 Hz. Fox: 110
  samples in 3.3 s and the sample times of some recordings give 33.33 Hz; 33 Hz is
  rounded. Dog_dataset_2: the bursts in the files have 124 rows. The loaders report the
  measured steps, so the values are checked on every run.
- Thesis: 33.333 Hz for Giraffe_dataset_1 and Fox_dataset_1 in the windowing.
- Alternatives considered: the values of the documents; contradicted by the data.

### D19 2026-10-24 – Dog_dataset_1: clock times HH.MM:SS
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: Dog_dataset_1 (Lumpi)
- Decision: Clock times written with a dot after the hour (HH.MM:SS, e.g. 10.38:45) are
  read as HH:MM:SS (10:38:45). The loader lists the number of rows and examples.
- Reason: 48 400 rows (440 bursts, 30–31 Mar 2017) in Lumpi's file have this form. Read
  as text by pandas they become HH:00:00.MMSS (10:00:00.3845), which puts up to 175
  bursts of 3.3 s within 0.3 s. Read as HH:MM:SS they are 5 s apart, as in the other dog
  files. The bursts themselves (110 rows each) were cut correctly either way; only the
  time stamps change.
- Thesis: `Dog_dataset_1/02.R` parsed the times with `%H:%M:%S`, so these 48 400 rows got
  no time and were dropped (`drop_missing_datetime_rows` in `01_harmonize_model_ready.R`):
  440 of Lumpi's 547 bursts were lost, and Lumpi is not in the thesis windows (12 of 14
  dogs; with these bursts Lumpi has all three classes, 151–173 windows each).
- Alternatives considered: keep the times as they are (wrong start times of 440 bursts).

### D20 2026-10-24 – Dog_dataset_1: rows with another dog's code
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: Dog_dataset_1 (Emi)
- Decision: Rows whose `Tier` code differs from the dog of the file are left out. This
  concerns 8 690 rows (79 bursts) coded HEL in Emi's file. The loader compares them with
  Helena's file (same times, same values, same labels) and reports the result.
- Reason: The rows are coded as Helena and lie after Emi's last burst (09:40:55–09:47:25
  vs. 09:06:50–09:38:45). All 79 bursts have the start time and label (KNA) of Helena's
  79 KNA bursts, but other values (median mean difference 262 counts, about 0.5 g), so
  they come from another collar than Helena's file. Several dogs were recorded at once
  (simultaneous bursts in other dogs, `raw_data_review.md`), so they are probably
  Emi's collar data with Helena's observation copied onto them: the signal of one dog
  with the label of another. Neither Emi nor Helena can take them with certainty.
- Thesis: individuals from the `Tier` code; the thesis windows have EMI 304 and HEL 282
  windows, i.e. Emi without these rows and Helena with her own file only.
- Alternatives considered: keep them as Emi's with label KNA (only if the BSc thesis
  shows that both dogs were observed chewing then).

### D21 2026-10-24 – Window features
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: The 26 features of the thesis (`06_feature_extraction.R`), computed per
  2-s window at 25 Hz by `code/features.py` (`04_features/<dataset>/features.parquet`):
  VeDBA mean, SD and maximum; ODBA mean and SD; per axis SD, RMS, IQR, skewness, excess
  kurtosis and zero crossings; dominant frequency, spectral centroid and normalized
  spectral entropy of the VeDBA series. All on the dynamic acceleration (window mean
  removed), with the same definitions as the R script (SD with n − 1, R quantile type 7).
- Reason: Same features as in the thesis, so differences to the thesis come from the
  preprocessing. Posture (the static part) is not a feature; this keeps the features
  less dependent on how the collar sits on different species.
- Thesis: the same features on 2.46-s windows (frequency resolution 0.40 Hz; here 0.5 Hz).
- Alternatives considered: adding posture features (mean per axis, pitch, roll);
  not done, for comparability.

### D22 2026-10-24 – Classifiers of the first run
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: Random Forest (scikit-learn defaults) and LightGBM (defaults, objective
  multiclass), with random_state = seed; no tuning, as in the thesis. CNN, ResNet, HYDRA
  and MultiRocket follow with the same splits and training sets.
- Reason: The two fastest models test the whole chain first; default settings leave no
  room for tuning on test data.
- Thesis: the same settings (`05_Random_Forest.py`, `06_LightGBM.py`).

### D23 2026-10-24 – Evaluation modes
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision (`code/train_models.py`):
  - within: leave one individual out per dataset. Test individuals meet the thesis rule
    (all three classes with at least 10 evaluation windows, D12); the model is trained
    on all other individuals of the dataset. Predictions of all folds are pooled into one
    Macro-F1 per dataset; the number of individuals, eligible individuals and folds is
    reported.
  - cross: trained on all other datasets, tested on one.
  - pairwise: trained on dataset A, tested on dataset B, for all ordered pairs; pairs of
    the same species (dogs, horses, raccoons) are flagged (the "inter" mode of the
    thesis). One model per source dataset serves all its targets.
  - global: all datasets pooled; per dataset 25 % of the individuals (at least one) are
    held out, drawn per seed.
  - Training: windows with overlap (D08), at least 30 per class, at most 250 per class
    (per dataset and class when datasets are pooled), spread over segments (D09).
    Tests: all evaluation windows (no overlap) of the test individuals or dataset; cross
    and pairwise tests need at least two classes with at least 5 windows (thesis).
  - Metrics as in the thesis: accuracy, macro precision, recall and F1 over the three
    classes (a class without test windows counts 0), per-class values and confusion
    matrices.
- Reason: The thesis design, so the results stay comparable; within-dataset with every
  individual as test unit instead of one random 25 % split, which is unstable with two or
  three individuals (planned in `ANALYSIS_PLAN.md` of the thesis repository).
- Thesis: within with one random 25 % split of the individuals; the other modes as here.

### D24 2026-10-24 – Seeds
- Status: confirmed (Lucas, 2026-10-24)
- Datasets: all
- Decision: Every analysis runs with the seeds 42, 43, 44, 45 and 46. A seed fixes the
  draw of the training windows (cap), the held-out individuals of the global mode and the
  random state of the model. Results are reported as mean and SD over the seeds; how the
  seeds enter the tests of H1–H3 is decided with the statistics scripts.
- Reason: With 250 windows per class, the draw of the training windows changes the
  result; five draws show how much.
- Thesis: seed 42 only.

### D25 2026-10-25 – Signal-based classifiers
- Status: confirmed (Lucas, 2026-10-25)
- Datasets: all
- Decision: CNN, ResNet, HYDRA and MultiRocket with the settings of the thesis scripts
  (`code/models.py`), on the window signals (3 axes × 50 samples, g), with the same
  splits, training windows and seeds as RF and LightGBM (D23, D24):
  - CNN (3 convolution blocks, 32/64/128 filters) and ResNet (stem and 3 residual
    blocks) as in `01_CNN.py` and `02_ResNet.py`: channels standardized with the mean and
    SD of the training windows, Adam (learning rate 1e-3, no weight decay), batch 256,
    30 epochs, dropout 0.25, no validation split, no early stopping, no class weights.
    On the CPU, with fixed seeds (reproducible); the thesis used the Apple GPU (MPS).
  - HYDRA and MultiRocket: aeon `HydraClassifier` and `MultiRocketClassifier` with
    defaults and random_state = seed, as in `03_HYDRA.py` and `04_MultiRocket.py`;
    n_jobs only changes the speed.
- Reason: Same models as in the thesis. Unlike the features (D21), the signal models see
  the static part (posture), as in the thesis.
- Thesis: the same settings on 62-sample windows.


### D26 2026-10-25 – Statistics of H1–H3
- Status: confirmed (Lucas, 2026-10-25: seeds, mean over the seeds, report the variability;
  Lucas, 2026-10-27: the rest)
- Datasets: all with results
- Decision (`code/stats_h1_h2.py`, `code/stats_h3.R`; output `06_statistics/<scenario>/`):
  - Seeds: the mean over the five seeds is the value of a model and dataset (H1, H2) or
    dataset pair (H3) in the tests. The SD over the seeds is reported per model and mode
    (`seed_variability.csv`), and the primary H3 model is also fitted to each seed
    separately (descriptive).
  - H1: within vs. cross Macro-F1 (accuracy secondary) per dataset, paired Wilcoxon
    signed-rank test per model, rank-biserial correlation, gaps. Datasets: all with a
    within value (10; Hedgehog_dataset_1 has none, D12). Sensitivity: only the datasets in
    which every individual is a test unit (7), because in Dog_dataset_1, Horse_dataset_2 and
    Raccoon_dataset_2 the cross test also scores individuals that are not within test units
    (D12); scenario F (D11) gives the same windows in all datasets.
  - H2: cross F1 per class, Friedman test per model (blocks: test datasets in which every
    class has at least 5 test windows), Kendall's W, paired Wilcoxon tests of all class
    pairs with Holm correction per model, interpreted only after a significant Friedman
    test. The same for the transfer loss (within F1 − cross F1 per class).
  - Wilcoxon tests: exact two-sided p-values; normal approximation with continuity
    correction only with ties or zero differences (`test_method`), as `wilcox.test` in R.
    Differences are rounded to 12 decimals, so floating-point noise does not hide ties.
  - H3: the primary model of the thesis (Macro-F1 ~ z(core Gower distance) + model + random
    intercepts of the unordered pair, ordered pair, source and target species; LRT of ML
    fits, estimate and 95 % CI from the REML fit with Satterthwaite df), with the core traits
    of the thesis (`species_traits_core_h3_final.csv`). Species by scientific name, so the
    two horse datasets are different species, as in the thesis H3 script; pairs of the same
    species are left out. Also reported: interaction with the model and slopes per model,
    directional and pair-only random effects, Spearman correlations (Holm), and S1–S3 of
    `ANALYSIS_PLAN.md`. z-scores are computed on the records of each analysis. Without a
    within value for Hedgehog_dataset_1, S1 leaves out all pairs with the hedgehog and S2
    those with the hedgehog as target (the plan assumed partial values for every dataset).
- Reason: The seeds are repeated draws of the same experiment, not independent
  observations; using them as separate cases would inflate n. Tests and models as
  pre-specified in the thesis and in `ANALYSIS_PLAN.md`.
- Check: the Python tests give the same V, χ² and p-values as `wilcox.test`,
  `friedman.test` and `p.adjust` in R (RF and LightGBM results of 2026-10-24).
- Thesis: seed 42 only; H1 and H2 with the normal approximation (`exact = FALSE`); H3
  with the same models.
- R² (Nakagawa, 2026-10-27): computed from the variance of the fixed-effect predictions,
  the random-intercept variances and the residual variance, also for singular fits
  (`performance::r2_nakagawa` gave no conditional and a too high marginal R² there).


### D27 2026-10-27 – Sensitivity analyses with RF and LightGBM
- Status: confirmed (Lucas, 2026-10-27)
- Datasets: all
- Decision: The scenarios of D11 (A, C, majority, four_classes, E, F) are trained with
  Random Forest and LightGBM only, in all modes and with the seeds of D24, and analysed with
  the statistics of D26 (`05_results/<scenario>/`, `06_statistics/<scenario>/`).
  C: windows of 2.4 s (60 samples at 25 Hz) placed every 2.4 s, so every window is
  non-overlapping and used for training and test; built from the harmonized samples with
  `make_windows.py --variant C` (settings under `variants` in `pipeline_settings.json`),
  classes and features with `--variant C`, into `03_windows_C/` and `04_features_C/`.
  All of it runs with `bash code/update_local.sh sensitivity`. For the comparison, the
  primary H3 model is also fitted with RF and LightGBM only (`stats_h3.R`, "RF and LGBM only
  (D27)"), because the scenarios have these two models only.
- Reason: With the four signal models a scenario takes about 30 h (about a week for all
  six), with RF and LightGBM a few minutes. The scenarios are compared descriptively with
  the primary analysis (D11), for which the two feature models suffice; the signal models
  are reported for the primary analysis.
- Thesis: none.
- Alternatives considered: all six models in every scenario.


### D28 2026-10-27 – Robustness of H3
- Status: confirmed (Lucas, 2026-10-27; proposals P6–P8 of `trait_review.md`)
- Datasets: all with results
- Decision (`code/stats_h3.R`, every scenario; reported next to the primary model of D26,
  which stays the test of H3):
  - Leave one species out: the primary model refitted without all pairs of one species,
    for each of the nine species, with the distance z-scored again (as
    `03_H3_LOSO_R2.R` of the thesis); range of β and number of refits with p < 0.05
    (`h3_loso.csv`).
  - The primary model with other distances (z-scored), as in
    `02_H3_distance_proxy_mixed_modelsl.R` of the thesis:
    - extended expert traits (`species_traits_extended_sensitivity_full_final.csv`,
      Gower, equal weights), with activity pattern "cathemeral" for Bison bonasus and
      both horses (P6; the thesis coded them diurnal);
    - EltonTraits (Wilman et al. 2014; `01_raw_data/EltonTraits/MamFuncDat.txt`, not
      shared; values used in `h3_elton_traits.csv`): core (log body mass, foraging
      stratum, activity) and extended (plus diet), Gower; names as in the thesis: Canis
      lupus for the dog, Equus ferus, otherwise Equus caballus, for the Przewalski's horse,
      Giraffa reticulata only if G. camelopardalis is missing; skipped without the file;
    - divergence time from TimeTree (`timetree_species_list.nwk` of the thesis: tree
      height minus the depth of the most recent common ancestor; Canis lupus, Equus ferus);
    - absolute difference of log body mass (core table; P8).
- Reason: With nine species, three species (hedgehog, raccoon, giraffe) dominate the
  distance, and the expert coding is one of several possible codings
  (`trait_review.md`, sections 5 and 6).
- Thesis: the same analyses in separate scripts, seed 42 only.
- Alternatives considered: none.

### D29 2026-11-01 – Trait definitions and evidence audit
- Status: draft (documentation work requested by Lucas on 2026-11-01; no revised
  trait values or analysis settings adopted)
- Datasets: the nine study taxa in H3
- Work: Start a trait-by-trait codebook in `trait_codebook.md`, covering the seven Core
  and four additional Extended traits. The first worked entry is body mass; the
  published source comparisons and unresolved provenance are in
  `trait_body_mass_audit.csv`.
- Proposal for body mass: a documented taxon-level adult reference mass, in grams,
  natural-log transformed; exact taxon matches and any proxy exceptions recorded.
  The definition and final source policy remain open for discussion.
- Reason: Every trait needs a definition, mechanistic rationale, reproducible coding
  and evidence for each taxon. A mechanistic citation does not by itself substantiate
  an ordinal species score.
- Analysis status: Existing Core/Extended input files, code and results are unchanged.
  The reviewed baseline is `d5c2ccc9bd6242a889f3608fd2d25dcd4fc05f64`.
- Timing: H3 results were already known at the start of this audit. Any later
  source corrections or recodings will be dated, with the original matrix retained;
  this review is not a retrospective preregistration.

- Follow-up on 2026-11-01 after the author pointed to the supplied theses:
  - Beseler (2026), printed p. 14, explicitly motivates dataset/study-population
    masses. The initial uniform-taxon-reference proposal above is not adopted
    and must not be described as the original method.
  - Cibis (2017), Table 4, supports the hedgehog's 1032 g as a rounded mean of
    six measured animals; its natural log matches the current Core value.
  - Saenger (2017), section 1.3.2, contains a matching 350 kg upper-bound
    statement, not a measured Przewalski's-horse cohort mean.
  - Groth (2020), Table 2, lists 20 masses averaging 30.5 kg; this does not
    establish the current 28 kg dog value. Original extraction and Szangolies
    (2017) remain to be checked, including aggregation across dog datasets.
  - The codebook and source audit distinguish cohorts, references and bounds.
    This is a documentation correction only. All analysis inputs and results
    remain unchanged; the final source/aggregation policy stays open.

- Additional source check on 2026-11-01 after uploads of Szangolies and Saenger:
  - Szangolies (2017), Table 2, contains 14 measured dog masses; their
    unweighted mean is 22.992857 kg. Extracted values and source locations are
    saved in `trait_body_mass_dog1_measurements.csv`.
  - The value 28 kg occurs as Lulu's individual mass and as a cluster mean.
    Table 11's two middle group-name assignments conflict with the numerical
    means recalculated from Table 2. Neither occurrence proves the historical
    reason for assigning 28 kg to all dogs in Core.
  - Groth's complete source cohort averages 30.5 kg. The processed dataset's
    ambiguous combined animal identities prevent calling this the measured
    mean of eight identified retained dogs.
  - Saenger's 350 kg statement is an upper bound. The study animals are Jedi,
    Kalmoek and Joda (five-year-old geldings); no individual weights or cohort
    mean were located in the supplied thesis.
  - Status: source meanings and source-cohort arithmetic are checked; final
    dog aggregation and horse reference selection remain open. No trait value,
    analysis setting, code or result is changed by this documentation commit.

- Analysis-membership and literature follow-up on 2026-11-01:
  - Checked primary metrics and within-fold records for all six classifiers,
    seeds 42–46, plus the identical post-cap training logs. All 14 Dog_dataset_1
    dogs enter pairwise training/testing; Duke alone lacks a within test fold.
    All eight ambiguous Dog_dataset_2 recording groups enter both evaluations.
    Detailed IDs and global splits are in `trait_body_mass_dog_inclusion.md`.
  - The 22.992857 kg Dog_dataset_1 mean therefore matches its primary transfer
    cohort. The Groth 30.5 kg mean is only a source-cohort reference while
    Dog_dataset_2 identity remains unresolved. Their equal-study average,
    26.746429 kg, is a proposed approximation, not a measured pooled-cohort mean.
  - Located a horse reference of 300 kg in Gerstner and Gerstein (2008), Table 1,
    p. 1022, DOI 10.1644/07-MAMM-A-188.1. Proposed external fallback only;
    no claim that it measures Saenger's three geldings or a universal adult mean.
    The source entry does not identify horse-specific sex/age/season/sample size.
  - No replacement mass, candidate matrix, analysis setting, code or result is
    adopted or changed. Final aggregation/fallback and sensitivity decisions
    remain open; literature search and inclusion auditing are documented.


### D30 2026-11-01 – Body-mass definition and values confirmed
- Status: confirmed by Lucas on 2026-11-01; C1 definition/source-selection/coding closed.
- Decision: Retain body mass in Core and Extended as a curated taxon-level reference,
  in grams, natural-log transformed. Distinguish measured cohort summaries,
  source-study aggregates, and external literature/database references.
- Dog: replace the undocumented 28 kg convention with the equal-weight mean of
  the two source-study means: `((321.9 / 14) + (610 / 20)) / 2 = 26.74642857142857 kg`,
  displayed as approximately 26.75 kg. Transform the unrounded aggregate;
  `ln(mass_g) = 10.1941562321`, stored as **10.194** in both input matrices.
  All 14 Dog_dataset_1 dogs are represented in primary transfer. Groth's 30.5 kg
  remains a source-cohort approximation because the eight Dog_dataset_2 recordings
  cannot be uniquely attributed to named animals. The accepted value is not a
  measured pooled mean of all analysis animals.
- Przewalski's horse: replace the previous upper-bound-based convention with
  **300 kg**, an external reference from Gerstner and Gerstein (2008), Table 1,
  p. 1022, DOI 10.1644/07-MAMM-A-188.1. `ln(300000) = 12.6115377536`, stored as
  **12.612** in both matrices. No measured mean for Sänger's three five-year-old
  geldings and no sex-mixture derivation are claimed.
- Retained values: the six exact-name EltonTraits references and Cibis's reported
  1032 g hedgehog cohort mean retain the existing log entries. The codebook and
  audit CSV list all nine source categories. Database matching does not reconstruct
  the historical source-selection process or establish study-cohort representativeness.
- Implementation: only the two mass cells in each Core/Extended input CSV change;
  all other cells and the model code are unchanged. The prior matrices remain in Git
  at `2a6a7afc4da11812f9bcec11848b8db6e7538085`; the original audit baseline is retained.
- Analysis status: existing H3 distances, fits, figures and tables have not been
  recomputed and still use the earlier mass entries. Recompute them from finalized
  traits before reporting updated H3 results and report robustness checks separately.
  Classifier predictions and H1/H2 results do not require recalculation for this change.
- Timing: the decision was made after the previous H3 findings were known. It is
  documented as a source/coding revision, not preregistration or a completed
  sensitivity validation. No new model fit was used to choose the mass values.
- Remaining traits: C2–C7 and E1–E4 remain in the review queue.


### D31 2026-11-01 – C2 locomotor-specialization review started
- Status: display-name clarification and review direction agreed by Lucas;
  operational category rules and final species mapping remain under review.
- Construct: taxon-level locomotor specialization, evaluated from habitual locomotion
  and limb-function evidence. The interpretation does not use behavioural-label
  proportions or an unmeasured majority-of-time threshold.
- Work: `trait_locomotor_specialization_review.md` records a four-state working scheme,
  evidence criteria, unresolved-case handling, initial sources and all nine review rows.
  The generalist state requires positive evidence; missing evidence is not a category.
- Existing column: `dominant_locomotor_mode`; unchanged for compatibility while the
  biological definition is reviewed. Core and Extended codes have not changed.
- Method: record exact taxon/source/locator, direct assignment versus inference and
  uncertainty. The hedgehog is the priority unresolved case. Resolve coding before
  refitting; assess reasonable alternatives and omission of C2 without selecting by p-value.
- Numerical check: C2 is nominal. In the current seven-plus-one-plus-one grouping,
  renaming only the hedgehog singleton would leave all 36 pairwise C2 distances unchanged.
- Analysis status: documentation only. C1 remains closed under D30; existing H3 outputs
  still await the previously documented mass-input update. No classifier or H3 rerun.

#### D31 follow-up — 2026-11-02: targeted hedgehog evidence
- The C2 review now documents three additional sources (L5–L7), exact locations,
  access limits and conflicting classifications for *Erinaceus europaeus*.
- Working recommendation: `terrestrial_generalist` under the locomotor construct.
  This is an explicit interpretation, not a completed or independently validated
  species-coding decision; the published `semifossorial` alternative is retained.
- The distinction between locomotor mechanics and a burrowing/foraging
  classification is documented. Other taxa still require the same evidence review.
- Scope: documentation only. No C2 input, C1 value, analysis code or result changed;
  no model rerun. The existing singleton-distance check remains applicable.

#### D31 follow-up — 2026-11-02: five additional taxa and category scope
- Added L8–L15 and species-specific evidence/locators for European bison, cattle,
  domestic dog, Przewalski's horse and giraffe to the C2 review.
- Published or anatomical support is now documented beyond the initial wolf,
  domestic-horse and okapi proxies. Direct classifications, anatomical inference,
  taxonomic scope and breed limitations are distinguished.
- The search revealed a coarse-versus-fine classification issue. The original
  working `cursorial` criterion is not treated as finalized; source terminology
  cannot be merged without an explicit mapping rule.
- European-bison coding remains unresolved, and the study-dog breed scope still
  needs documentation. These are not grounds to assign a default generalist code.
- No category expansion, species recoding or model rerun was adopted. If further
  species change groups, recalculate distances; the earlier hedgehog-singleton
  check does not establish invariance for such changes.
- Documentation only: C1 values and Core/Extended inputs, code and results are unchanged.


### D32 2026-11-02 – C2 three-group definition and coding confirmed
- Status: confirmed by Lucas on 2026-11-02; C2 definition/source mapping/coding closed.
- Construct: coarse, nominal, taxon-level **locomotor specialization**, based on
  locomotor anatomy and habitual substrate use. The machine-readable column remains
  `dominant_locomotor_mode`. No gait frequency, activity budget, speed or endurance
  ranking is inferred.
- Final definitions and occupancy:

  | Category | Operational definition | Study taxa | n |
  |---|---|---|---:|
  | `cursorial` (broad) | Running-adapted terrestrial quadrupeds, including heavy-bodied and very long-legged running forms. | Bison, cattle, dog, both horse taxa, giraffe, red fox | 7 |
  | `scansorial` | Ground locomotion and habitual climbing are characteristic components of locomotion. | Raccoon | 1 |
  | `terrestrial_generalist` | Positive evidence for generalized ground locomotion without a predominant running, climbing or digging specialization under this scheme. | Hedgehog | 1 |

- Mapping: explicitly pool the finer mediportal heavy-bovine and stilt giraffe forms
  into broad `cursorial`. This operational choice supersedes D31's narrow
  fast/sustained-running criterion; it is not a universal classification or a claim
  that all sources use the same boundaries. No extra analysis states are introduced.
- Evidence: the final nine-row mapping in `trait_locomotor_specialization_review.md`
  distinguishes direct assignments from inference, exact taxa from proxies, and
  source/cohort limitations. Bison coding is an accepted anatomical/coarse-mapping
  inference. The hedgehog decision uses Neveu et al. (2001), retaining White (2003)
  as conflicting burrowing/foraging terminology.
- Dog scope: Szangolies (2017), section 2.1.1/Table 2, documents a heterogeneous
  14-dog cohort; Groth (2020), the same section/table, describes mainly Labrador
  and some Golden Retrievers in the 20-dog source cohort. C2 is a broad domestic-dog
  reference, not a uniform individual specialization. Breed variation and ambiguous
  identities of the eight processed Dog_dataset_2 groups remain limitations.
- Implementation: change only `Erinaceus europaeus` from `semifossorial` to
  `terrestrial_generalist` in each Core/Extended CSV. All other cells, schema, row
  order and CRLF line endings are preserved. C1 remains closed under D30.
  Pre-adoption inputs are preserved at
  `37e57fbdfdeb2a7cd03e3ba3ead0b84ec7b3cbb2`.
- Verification: both matrices contain the same nine-taxon C2 mapping and 7/1/1 counts.
  Exactly one field changes per matrix. All 36 unordered nominal pair indicators
  are identical before/after (21 matches, 15 mismatches). The R reader uses a nominal
  factor with no fixed C2 state list. With all other inputs fixed, the singleton
  rename leaves primary and equal-weight Extended Gower distances unchanged.
- Limits and analysis status: the two singleton groups limit inference about
  categories beyond their taxa. No independent biological recoding, classifier
  rerun, H3 fit or optimized-weight sensitivity rerun is claimed. Existing H3
  outputs still await D30's mass-input update. Omission or actual regrouping of
  taxa is a separate robustness analysis; changing a singleton's name is not one.
- Timing: this is a documented post hoc coding decision; previous H3 findings were
  known. No new fit was used to choose categories, and no preregistration is claimed.
  C3–C7 and E1–E4 remain in the review queue.


### D33 2026-11-02 – C3 body-configuration review started
- Status: Lucas agreed to examine the robust/standard boundary and separate raccoon
  group. Review direction accepted; final coding and Core/Extended scope remain open.
- Working construct: taxon-reference body proportions, especially relative trunk,
  limb and neck dimensions in ordinary standing posture. Distinguish these from
  body mass, locomotor specialization and temporary/defensive posture.
- Evidence: `trait_body_configuration_review.md` records seven primary sources,
  exact source locations and access limits. Inspected skeletal studies do not
  establish the current whole-body grouping of bison/cattle versus horses/canids.
  The long-bone bovid study includes B. bison, not B. bonasus; exact European-bison
  evidence in the patellar study addresses a different anatomical target.
- Findings: the dog group requires a breed/cohort rule for body shape. The
  raccoon's functional anatomy has empirical support, but it does not automatically
  define a separate body-proportions class. Neither a foot-posture replacement nor
  a three-state merger is adopted.
- Recommendation only: retain C3 in the finalized primary distance if one explicit,
  reproducible anatomical rule can be supported for all nine taxa. If this cannot
  be achieved within scope, consider omitting it from the primary distance while
  retaining historical coding in an exploratory sensitivity analysis.
  This recommendation is not a decision to change the current seven-trait Core.
- Numerical audit: Core and Extended have the same C3 mapping, with group sizes
  2/4/1/1/1 and 7 matching versus 29 mismatching unordered taxon pairs. Merging the
  robust and standard groups would change 8 indicators; also adding the raccoon
  would change another 6. These are checked arithmetic examples only.
- Scope: documentation only. Input matrices, C1/D30, C2/D32, analysis code and
  outputs are unchanged. No H3 refit, omission analysis or independent biological
  recoding was performed. Any adopted change must be specified before refitting;
  existing outputs also still await the D30 mass-input update.


#### D33 follow-up — 2026-11-02: direct body proportions and source compatibility
- Added B8–B11 to the C3 review. Direct European-bison body measurements and
  Japanese Black reference dimensions strengthen the proportions-based route;
  a riding-horse protocol identifies concrete measurement endpoints.
- Proposed refinement: interpret robust as trunk-dominated build relative to body
  height and limb proportions. This is a working construct, not an adopted
  threshold, final code, group merger or decision to remove C3.
- Source compatibility remains material: cadaver versus standing measurements,
  different length/depth endpoints, age/sex/breed scope, and differing sample
  counts for individual dimensions. Ratios of reported summary means were checked
  arithmetically but are not mean individual ratios or a nine-taxon trait vector.
- Excluded a birth-to-yearling pooled cattle summary as an adult reference.
  No new C1 values were taken from the anatomy literature.
- Status remains open for the shared robust/standard rule and raccoon assignment.
  Five current C3 categories and all input cells, code and outputs are unchanged.
  No model rerun or independent anatomical coding was performed.

### D34 2026-11-02 – C3 four-group coding adopted
- Status: Lucas accepted the proposed four groups after selecting standard for the
  dog and considering a coarse raccoon merger. This adopts the mapping, not a claim
  that the full anatomical evidence audit or independent validation is complete.
- Construct: taxon-reference body proportions in ordinary standing posture.
  Display labels are trunk-dominated, generalized quadrupedal, tall/long-necked and
  compact/low-profile. The stored column and retained state names stay unchanged.
- Mapping: `robust_quadruped` = bison/cattle (2);
  `standard_quadruped` = dog/both horses/raccoon/fox (5);
  `tall_long_necked_quadruped` = giraffe (1);
  `compact_low_profile_body` = hedgehog (1).
- Evidence: the C3 review adds B12 (Reinecke & Angielczyk 2024,
  DOI 10.1093/iob/obae038) as contextual support for a generalized raccoon body plan,
  not validation of the proposed interspecific group.
- Limitations: raccoon remains an uncertain author assignment; the dog code spans
  heterogeneous breeds. The common robust/standard boundary and a reproducible
  all-taxon anatomical rubric remain unresolved. Category adoption is not complete
  source validation. No numerical thresholds or reviewer agreement are claimed.
- Implementation: change only the raccoon's C3 field from `generalist_quadruped`
  to `standard_quadruped` in both Core and Extended input CSVs. All other cells,
  schema, row order and CRLF line endings are preserved, including C1/D30 and C2/D32.
  Prior inputs: `a4acac071d99a0209f2dbcf108e0509085be2b6e`.
- Verification: 2/5/1/1 counts agree between matrices. Four of 36 nominal pair
  indicators change, all involving raccoon versus dog, either horse, or fox:
  matches increase 7→11 and mismatches decrease 29→25. C3 is already read as nominal.
- Agreed follow-up: compare four groups with the historical separate raccoon group,
  restoring only that cell and holding all other finalized inputs fixed.
  This sensitivity has not been run. C3 omission remains a proposal; the primary
  Core still contains seven traits and Extended still adds four traits.
- Analysis status: no full distance matrix, H3 fit, classifier or robustness rerun.
  Existing H3 outputs await both D30's mass corrections and this C3 change.
  This is a post hoc coding revision made without a new fit, not preregistration.

### D35 2026-11-02 – C4 trunk-motion inventory started
- Status: review started at Lucas's request to continue to the next trait;
  no new C4 definition or species coding adopted.
- Existing column: `expected_trunk_motion_amplitude`. Both input matrices have
  low = hedgehog (1), moderate = bison/cattle/raccoon (3),
  high = dog/both horses/fox (4), very_high = giraffe (1).
- The existing reader treats the four states as ordered. These are inferred
  reference scores, not observed displacement or acceleration measurements.
- Next decision: specify physical quantity, body location/reference frame,
  units or normalization, and behaviour/gait/speed conditions before justifying
  the ordering and each taxon assignment. Neck or stride evidence alone does not
  establish a trunk-amplitude score.
- Work recorded in `trait_trunk_motion_review.md`. C4 values, analysis code and
  outputs remain unchanged; the C3 input change is documented separately in D34.

#### D35 follow-up — 2026-11-02: targeted C4 evidence audit
- Work: `trait_trunk_motion_review.md` now records eight primary sources with
  access/locator details and a disposition for all nine current taxon scores.
  This was a targeted literature audit, not an exhaustive systematic review.
- Candidate definition, not adopted: relative peak-to-peak vertical excursion
  of a homologous cranial-thorax landmark during steady, level walking, expressed
  relative to standing shoulder height. A comparable dimensionless-speed interval,
  exact landmark, source-population scope and aggregation rule remain to be fixed.
- Findings: available measurements use different locations, quantities and gait
  conditions. The current four-level ordinal ranking is not established by the
  reviewed evidence. Missing support does not justify assigning a lower score.
- Recommendation only: omit C4 from the primary distance and add its historical
  scores in an explicitly exploratory sensitivity comparison with other finalized
  inputs held fixed. Alternatively, rebuild C4 from compatible kinematic references.
  Neither option, new category cutoffs nor replacement taxon values are adopted.
- Scope: documentation only; both trait matrices, C1/D30, C2/D32, C3/D34, code and
  outputs remain unchanged. Core still has seven traits; Extended has eleven.
  No H3 refit, full distance comparison, classifier run or independent coding check.


### D36 2026-11-03 – C4 excluded from primary Core
- Lucas confirmed exclusion after the C4 audit: no common evidence basis validates the ordinal ranking.
- Primary distance now uses C1–C3 and C5–C7 (six traits). The Core CSV retains all historical values; the R reader explicitly excludes C4 for primary analyses, including gawdis, seed and LOSO fits.
- Added `core_with_c4`: equal-weight seven-trait Gower distance and the same mixed-model specification, labelled exploratory. All other current trait values are held fixed. This is not a comparison with an old full input matrix.
- Extended remains a separate 11-trait sensitivity specification including C4; its comparison cannot isolate C4.
- With complete data and equal weights, remaining primary traits have weight 1/6 rather than 1/7. No replacement C4 measurement or new scores are adopted.
- Post hoc scope decision: earlier H3 findings were known; no new fit informed this choice. C5–C7 and E1–E4 still require review.
- Existing H3 outputs and figures are not regenerated in this change and remain stale relative to D30/D34/D36. Classifier predictions and H1/H2 are unaffected.
- Validation: static checks of primary exclusion, add-back dispatch and output/model labels; R runtime unavailable in this editing environment, so no R execution or model validation is claimed.

### D37 2026-11-05 – Final five-trait Core
- Status: confirmed. Lucas declared the document
  [`core_traits_definitions_sources_coding.docx`](core_traits_definitions_sources_coding.docx)
  (Markdown rendering: [`core_traits_definitions_sources_coding.md`](core_traits_definitions_sources_coding.md))
  final on 2026-11-05. It defines the primary H3 Core. Lucas's confirmation adopts the C5
  restriction and the food-acquisition groups, which the uploaded version still called
  proposals. At Lucas's request the same day, the document's wording was changed to the final
  status (title paragraph, food-acquisition coding, species-table caption, "Scope and next
  step" and "Decision status"; "working definition" → "operational definition" for C2).
  No definition, threshold, source or species assignment was changed; the uploaded
  version is preserved in commit `accef88`.
- Primary Core, five traits with equal weights: log body mass (C1, D30), locomotor
  specialization (C2, D32), body configuration (C3, D34), **relative neck length** (new,
  ordinal) and **food acquisition and handling** (new, nominal).
- Relative neck length: r = C/(T + L + S) (cervical / thoracic + lumbar + sacral
  vertebral lengths); `short` r < 0.30, `intermediate` 0.30 ≤ r < 0.40, `long`
  0.40 ≤ r < 1.00, `very_long` r ≥ 1.00 (thresholds set by us). Hedgehog and raccoon
  `short` (2), bison, cattle, dog and fox `intermediate` (4), both horses `long` (2),
  giraffe `very_long` (1). Sources: Belyaev et al. 2024, Supplement S1; Davis 1964,
  Table 10 (indirect, Procyon). Hedgehog by expert judgement (`intermediate` named as
  plausible sensitivity alternative); cattle close to 0.30; one or two specimens per taxon.
- Food acquisition and handling: `vegetation_cropping` = bison, cattle, both horses,
  giraffe (5); `oral_item_acquisition` = dog, hedgehog, fox (3);
  `manual_food_handling` = raccoon (1). Priority where actions overlap: manual handling,
  then vegetation cropping. Our synthesis, not a published classification.
- Changes against D36: C5 (`expected_directional_change_tendency`) leaves the primary
  distance and becomes an exploratory add-back (`core_with_c5`, like `core_with_c4`,
  D36). C6 (`expected_head_neck_contribution_to_acceleration_relevant_motion`) is
  replaced by relative neck length, C7 (`dominant_feeding_foraging_mode`) by food
  acquisition and handling; neither historical column is used in a Core distance.
  C5–C7 were not reviewed individually before this decision.
- Implementation: two columns, `relative_neck_length` and `food_acquisition_handling`,
  appended to `species_traits_core_h3_final.csv`; all historical cells, row order and CRLF
  line endings unchanged. `code/stats_h3.R` reads the primary traits from an explicit list
  (`core_traits`), with ordinal levels per trait; `core_with_c4` and `core_with_c5` each
  add one historical trait to the five-trait Core. `code/paper_figures.R`: Table S7 shows
  the five traits; the Figure 3 caption says five core traits.
- Extended: unchanged (11 columns of the extended CSV, C1–C7 of the thesis numbering plus
  E1–E4; C1–C3 as updated by D30/D32/D34). It is therefore no longer "Core plus four";
  whether Extended should be rebuilt on the D37 Core is open (E1–E4 not yet reviewed).
- Verification of the inputs: food acquisition gives 13 matching and 23 differing of the
  36 species pairs (historical C7: 7 and 29). Correlation of the 36 pairwise Gower
  distances of the D37 Core with the D36 six-trait Core: 0.928; with `core_with_c4`
  0.988, `core_with_c5` 0.974, Extended 0.907.
- Timing: the decision was made before any H3 fit with these inputs. Afterwards, the
  primary scenario was run once in the cloud editing session to test the code (R 4.3.3,
  lme4 1.1-35; without gawdis and without the EltonTraits raw file, so S3 and the
  EltonTraits distances were skipped). That run's outputs were not committed; its results
  are known. The committed H3 outputs and figures remain stale (pre-D30 inputs) until they
  are regenerated locally with the full setup.
- Official run, 2026-11-05: Lucas ran `code/update_local.sh stats` locally with gawdis and
  the EltonTraits file (commit `f37d483`); all scenarios' H3 outputs, Table 3, Tables S7–S12
  and the figures now use the D37 Core. No input or specification changed between the test
  run and this run; the primary estimate is identical: β −0.024 [−0.060, 0.011] per SD of
  the distance, LR χ²(1) 2.58, p 0.108.
- Reporting, 2026-11-05 (Lucas's request): the exploratory add-backs core + C4 and core + C5
  are reported in the supplementary table of model variants and other distances (group
  "Exploratory"), not in Figure S6. The same change merges the unmerged table restructuring
  of branch `claude/modest-feynman-m0xkou` (`d5dd469`: Table 3 primary model only; variants
  and other distances in a supplementary table; supplementary tables numbered in figure
  order). Since then the core-trait table is Table S8 (Table S7 above refers to the earlier
  numbering) and the variants table Table S11. Text outputs were regenerated from the
  committed statistics of `f37d483`; figures are unchanged.
- Open items: the neck-length review with the per-taxon measurements and r values is not in
  the repository (the document links a private ChatGPT library file); add it to
  `00_documentation/`. Per-taxon evidence for the food-acquisition assignments is limited
  to the cited raccoon and bison sources. Planned sensitivities (not run): hedgehog neck
  length `intermediate`, raccoon as separate C3 group (D34), omission of single traits.

### D38 2026-11-05 – Trait sensitivity analyses of H3 (plan fixed before fitting)
- Status: confirmed. Lucas asked on 2026-11-05 to run the three agreed sensitivity
  analyses once. This entry is committed before any of these fits.
- Unchanged: the primary analysis (D37 Core, primary model) is the test of H3.
- Analyses: each replaces the core distance in the primary model (same fixed and random
  effects, distance z-scored) and is fitted once. All other inputs stay fixed:
  1. **Raccoon as a separate body-configuration group:** the raccoon's C3 value is set to
     the historical `generalist_quadruped` (agreed follow-up of D34).
  2. **Hedgehog neck length intermediate:** the hedgehog's relative neck length is set to
     `intermediate`, the alternative named in the D37 document.
  3. **Leave one trait out:** five distances, each over four of the five core traits with
     equal weights.
- Reporting: β, 95 % CI, LR test and singular-fit flag of every analysis, in the
  supplementary table of model variants (group "Trait sensitivity"), whatever the
  result. They are described as robustness checks, never as tests of H3. No result can
  replace the primary specification or prompt further trait variants.
- Not part of this plan: a raccoon cohort mass, leaving out individuals (for example
  the back-mounted juvenile in Raccoon_dataset_2, see `trait_raccoon_theses_review.md`),
  or the same-species comparison. Each would need its own decision before any fit.
- Execution: code test in the cloud session after this commit; official outputs from
  the local run (`update_local.sh stats`, with gawdis and EltonTraits).
- Document addition, 2026-11-05 (Lucas's request): the D37 document gains the section
  "Expected link to the acceleration signal" (one hypothesised mechanism per trait) and
  references [11]–[13] (Heglund & Taylor 1988; Shepard et al. 2008; Basu et al. 2019).
  No definition, threshold or assignment changed. The DOIs of [11] and [13] were checked
  earlier (codebook R1; trait review); [12] could not be re-checked from the cloud session.
- Accidental run of the superseded specification, 2026-11-05 19:16: `update_local.sh stats`
  ran on `main` (commit `c5fd3bb`) before the D37/D38 branch was merged, so it used the D36
  code (six traits: C1–C3 and the historical C5–C7). Primary model there: β −0.044
  [−0.080, −0.008] per SD, LR χ²(1) 5.95, p 0.015 (singular fit). This result became known
  after D37 and D38 were fixed and changes neither: D37 is the specification of the paper,
  and the D36 core is not reinstated because of its result. The outputs of `c5fd3bb` are
  discarded by merging `main` into the D37/D38 branch with the branch's files kept
  (outputs of `f37d483`); the official D37/D38 outputs come from the next local run on the
  merged `main`. The D36 result is reported here for transparency, not as an analysis.

### D39 2026-11-06 – Extended trait set dropped from H3
- Status: confirmed (Lucas, 2026-11-06)
- Datasets: all with results (H3 only)
- Decision: the extended expert-trait distance of D28
  (`species_traits_extended_sensitivity_full_final.csv`, 11 columns) is no longer computed
  or reported, and no new Extended set is built on the D37 Core. `code/stats_h3.R` drops
  the distance together with the D28 recoding of activity pattern (cathemeral for bison
  and both horses); `code/paper_figures.R` and `code/figures.py` drop its row in Figure S6
  and Table S11 and its column in Table S9. The CSV stays in the repository as the record
  of the thesis coding; no code reads it. The D37 Core and every other H3 analysis are
  unchanged.
- Reason: after D37 the Extended file was no longer "Core plus four": it combines the
  historical C4–C7 with E1–E4, which had not been reviewed. The four additions were
  checked against the D37 Core, together with directional change tendency (C5), the other
  movement aspect the Core does not describe:
  - **E2 vertical use / motion scope** and **E3 postural compactness** separate the same
    species as locomotor specialization (C2) and body configuration (C3); they add no
    information of their own.
  - **E1 activity pattern** has published, comparable definitions. Cox et al. (2021),
    Methods: "nocturnal—active only at night; crepuscular—active only during twilight
    (around sunrise and sunset); cathemeral—active throughout the day and night,
    interspersed with rest periods; diurnal—active only during the day". Species are
    classified after the Handbook of the Mammals of the World, with a separate flag for
    diel flexibility. The species values are in their Supplementary Data 2 (figshare,
    doi:10.6084/m9.figshare.13623014). They were not checked here because figshare cannot
    be reached from the cloud session. Refinetti (2008) treats diurnal and nocturnal as
    the ends of a continuum that also varies within species. However, the time of day
    does not change the acceleration signal of a behaviour within a 2 s window; any effect
    would come from the recording setting, not from the species. Activity already enters
    H3 through the EltonTraits distances (D28), so an expert coding would duplicate them.
  - **E4 defensive posture**: rolling up is well documented for the hedgehog (Reeve 1994)
    and occurs in the data (`eingekugelt` 22 and `zusammengekugelt` 1 windows, class
    Other). Only the hedgehog differs, so in the Gower distance the trait adds one more
    hedgehog-versus-rest contrast. C2 and C3 already provide two such contrasts: the
    hedgehog is the only `terrestrial_generalist` and the only `compact_low_profile_body`.
    The hedgehog already dominates the distance (`trait_review.md`, section 6).
  - **Directional change tendency (C5)**: a mechanism exists (turns cost energy; Wilson
    et al. 2013), but path tortuosity (straightness and sinuosity
    indices; Benhamou 2004) is measured on paths over minutes to hours and depends on
    scale, behavioural state and habitat; no comparable species values exist. Tri-axial
    accelerometers do not register rotation about the yaw axis (Gunner et al. 2020), and
    turning in enclosures and on test courses depends on the setting. C5 stays only as the
    exploratory add-back `core_with_c5` of D37, unchanged.
- Remaining robustness of H3 (unchanged): leave one species out; EltonTraits core and with
  diet (including activity); log body mass alone; divergence time (D28); trait
  sensitivity (D38); exploratory add-backs C4 and C5 (D36/D37).
- Timing and transparency: the decision was made with the Extended result known. Official
  run `f37d483`, primary scenario: β −0.051 [−0.086, −0.015] per SD, LR χ²(1) 8.06,
  p 0.005 (primary model: p 0.108); in the six sensitivity scenarios, p 0.062–0.294.
  The reasons above concern the construction of the set, not its result. Dropping it
  removes one of the two other distances with p < 0.05 (the other is the exploratory
  core + C4, p 0.047, singular fit). The paper should state that the extended expert
  traits of the thesis were dropped and why, and that this distance had shown an effect.
- Thesis: Extended traits (thesis Core plus E1–E4, horses and bison coded diurnal) as a
  distance proxy in `R/H3/02_H3_distance_proxy_mixed_modelsl.R`.
- Execution, 2026-11-06 (Lucas's request to remove Extended from the outputs now): no model
  was refitted. In the committed outputs of `7a0add0` (all seven scenarios), the
  Extended rows of `h3_models.csv` and `h3_fixed_effects.csv`, the Extended columns of
  `h3_data.csv` and `h3_distances.csv`, and the three Extended lines of
  `statistics_h3.txt` were removed; a check confirmed that every other value is
  unchanged. This is what the D39 code produces, because each distance is fitted on
  its own. Then `code/paper_figures.R` (R 4.3.3, ggplot2 3.4.4) and `code/figures.py`
  (matplotlib 3.11.2) were run in the cloud session; only the affected files were kept:
  Figure S6 and its caption, Tables S9 and S11, and `07_figures/fig5_h3`. All other
  figures and `contents.txt` keep the local rendering of `7a0add0`. The next local run
  (`bash code/update_local.sh stats`) regenerates everything with the local versions.
- Verification, 2026-11-06: `code/stats_h3.R` with the D39 code was rerun in a scratch copy
  in the cloud session (R 4.3.3, lme4 1.1-35.1, lmerTest 3.1-3; without gawdis and the
  EltonTraits file, so S3 and both EltonTraits distances were skipped). For all other
  analyses of all seven scenarios, β, SE, CI, LR χ², p and R² agree with the committed
  outputs to within 2 × 10⁻⁷; Satterthwaite df and the Figure 3 prediction differ by
  less than 5 × 10⁻⁴. The rerun was not committed; the committed outputs keep the local
  S3 and EltonTraits results.
- References:
  - Cox, D. T. C., Gardner, A. S. & Gaston, K. J. (2021). Diel niche variation in mammals
    associated with expanded trait space. *Nature Communications*, 12, 1753.
    [doi:10.1038/s41467-021-22023-4](https://doi.org/10.1038/s41467-021-22023-4).
    Methods (p. 7) and Data availability (p. 8) checked in the full text supplied by Lucas.
  - Bennie, J. J., Duffy, J. P., Inger, R. & Gaston, K. J. (2014). Biogeography of time
    partitioning in mammals. *PNAS*, 111, 13727–13732.
    [doi:10.1073/pnas.1216063110](https://doi.org/10.1073/pnas.1216063110) (abstract only).
  - Refinetti, R. (2008). The diversity of temporal niches in mammals. *Biological Rhythm
    Research*, 39, 173–192.
    [doi:10.1080/09291010701682690](https://doi.org/10.1080/09291010701682690) (abstract only).
  - Benhamou, S. (2004). How to reliably estimate the tortuosity of an animal's path:
    straightness, sinuosity, or fractal dimension? *Journal of Theoretical Biology*, 229,
    209–220 (abstract and secondary citations only).
  - Gunner, R. M., Wilson, R. P., Holton, M. D., et al. (2020). A new direction for
    differentiating animal activity based on measuring angular velocity about the yaw
    axis. *Ecology and Evolution*, 10, 7872–7886.
    [doi:10.1002/ece3.6515](https://doi.org/10.1002/ece3.6515) (abstract only).
  - Wilson, R. P., Griffiths, I. W., Legg, P. A., et al. (2013). Turn costs change the value
    of animal search paths. *Ecology Letters*, 16, 1145–1150.
    [doi:10.1111/ele.12149](https://doi.org/10.1111/ele.12149) (abstract only).
  - Reeve, N. (1994). *Hedgehogs*. T & A D Poyser, London (not checked; cited from a review).

### D40 2026-11-06 – Repository cleanup and manuscript numbering
- Status: confirmed (Lucas, 2026-11-06: delete obsolete files, drop `code/figures.py`, use
  the revised H1/H2 figures, MIT license, supplement numbered as in the manuscript draft)
- Datasets: all (no data, model or statistic changed)
- Paper output (`code/paper_figures.R`): `08_paper/main/` (Figures 1–3, Tables 1–3) and
  `08_paper/supplement/` (Figures S1–S8, Tables S1–S21); PNG only (600 dpi). Short titles and
  captions as txt files, a legend in every plot; classes always ordered Resting, Locomotion,
  Foraging; main figure titles as in the manuscript draft; US spelling (Lucas, 2026-11-06).
  - Tables 1–3 follow the draft layout. Table 3 now lists the distance effect per distance
    measure (core traits = test of H3, EltonTraits, body mass, phylogeny); the full primary
    model (before Table 3) is Table S16.
  - Figures 1–2 (and S2–S3) use the design of the former
    `code/paper_figures_h1_h2_revised.R`; Figure 1 shows the 10 datasets with both values.
  - Supplementary tables in the order of first mention: S1 datasets, S2 label mapping,
    S3 features, S4 preprocessing, S5 classifiers, S6 trait definitions, S7 trait values,
    S8 species distances, S9 H3 robustness; S10–S21 results (H1, H2, pairwise, H3,
    scenarios, seeds). S1–S6 are new; the others keep their content.
- Files (old → new):
  - `species_traits_core_h3_final.csv` → `traits/species_traits_core.csv` (five core
    traits) and `traits/species_traits_exploratory.csv` (C4, C5 for the add-backs); the
    historical C6/C7 columns are deleted.
  - `core_traits_definitions_sources_coding.docx/.md` → `traits/core_traits.docx/.md`;
    new `traits/core_trait_definitions.csv` (Table S6).
  - `trait_codebook.md` → `traits/evidence/trait_audit_log.md`; the trait reviews and
    body-mass files → `traits/evidence/` without the `trait_` prefix.
  - Deleted: `species_traits_extended_sensitivity_full_final.csv`, `trait_review.md`,
    `code/figures.py`, `07_figures/`, `code/paper_figures_h1_h2_revised.R`,
    `code/checks/find_horse_original.py`, `08_paper/H1–H3/`, `08_paper/Supp/`.
  - `datasets.csv` gains source, public, doi, setting, sensor position, raw unit and
    dataset-specific steps (Tables S1, S4; unknown entries marked TBD);
    `sensor_settings.csv` gains `used` (settings that give windows).
  - New: `LICENSE` (MIT), `CITATION.cff`; README rewritten.
  - Paths in D01–D39 refer to the layout before D40.
- Check: `code/stats_h3.R` with the new trait files gives byte-identical H3 tables to the
  run before the move (cloud, without gawdis and EltonTraits). `08_paper/` was
  regenerated in the cloud session (R 4.3.3, ggplot2 3.4.4); the numbers of Tables 1–2
  match the draft. The next local `update_local.sh stats` re-renders with the local setup.
- Open: TBD entries in `datasets.csv` (settings, sensor positions, years of the Giese and
  Brandes theses); the neck-length review for `traits/evidence/`; the .docx still links the
  private review file.

### D41 2026-11-06 – Dataset provenance in Table S1
- Status: confirmed (Lucas, 2026-11-06: complete the TBD entries where sources allow)
- Datasets: Fox_dataset_1, Giraffe_dataset_1, Hedgehog_dataset_1, Horse_dataset_1, Horse_dataset_2
- Decision: `datasets.csv` and `sensor_settings.csv` filled from these sources:
  - Horse_dataset_2: riding stable, riding sessions and pasture; device on a collar around
    the neck; IMU at 100 Hz (Kamminga et al. 2019, *Data* 4:131; dataset
    doi:10.4121/uuid:2e08745c-4178-4183-8551-f248c992cb14; abstract and dataset page).
  - Fox_dataset_1: two captive foxes in a game park enclosure, e-obs 1C collars,
    33.33 Hz, 3.3 s bursts (Rast et al. 2020, *PLOS ONE* 15:e0227317, doi:10.1371/journal.pone.0227317;
    abstract). Its raw data are probably the public Dryad dataset of that paper
    (doi:10.5061/dryad.gtht76hhj); not checked, so `public` stays "no".
  - Giraffe_dataset_1: Brandes (2018) MSc thesis (file name of the supplied thesis);
    giraffes of the Zoological Garden Berlin with e-obs tags on top of the head
    (Brandes, Sicks & Berger 2021, *Sensors* 21:2229; abstract).
  - Horse_dataset_1: acclimatization enclosure (Sänger 2017, section 2.2; trait audit log).
  - Hedgehog_dataset_1: captive, from the labels for handling by people (carried, moved,
    shaken).
- Still TBD: setting of Bison_dataset_1, Dog_dataset_1 and Dog_dataset_2; sensor position
  of Dog_dataset_2 and Hedgehog_dataset_1; year of the Giese thesis.
- Addition, 2026-11-06 (theses supplied by Lucas):
  - Dog_dataset_1 (Szangolies 2017, sections 2.1.1 and 2.2, pp. 5–8): 14 privately owned
    dogs, recorded March–May 2017 in and around Berlin in their familiar surroundings with
    the owners; e-obs tags taped to the dog's own collar, at the nape. Setting A: 110
    samples per axis at 33.3 Hz (3.3 s) every 5 s. Setting B (25 Hz, 68 samples) was used
    for some dogs but is not in the data (all 6,135 bursts have 110 samples), so the rate is
    now confirmed instead of assumed.
  - Dog_dataset_2 (Groth 2020, sections 2.1.1–2.1.4, pp. 6–9): Labrador and Golden
    Retrievers, privately owned, recorded at different places in Berlin and Brandenburg,
    mostly outdoors with the owners; e-obs tags taped to the collars (their position on the
    collar could shift and was noted).
  - Fox_dataset_1: Szangolies (2017, p. 6) describes the foxes of the Giese study as one red
    fox and one Arctic fox (*Vulpes lagopus*) of the Tierpark Berlin, whereas Rast et al.
    (2020) report two female red foxes. To be checked in the Giese thesis before submission;
    nothing changed.
  - Bison_dataset_1 and Horse_dataset_1 (Sänger 2017, sections 2.1–2.3, pp. 8–10): 50 ha
    acclimatization zone of Sielmanns Naturlandschaft Döberitzer Heide, west of Berlin,
    with supplementary feeding; leather collars with the e-obs tag in the middle of the nape.
  - Fox_dataset_1 (Giese, December 2016, sections 2.1–2.2, pp. 7–8): two female red foxes,
    Dana and Silver, about eight years old, in the outdoor enclosure of the Eichholz Tier- und
    Freizeitpark Germendorf (Oranienburg, Brandenburg); e-obs 1C light neck collars with the
    battery on the ventral side. Silver has an almost white coat, which probably explains the
    "Arctic fox" in Szangolies (2017); the species question is resolved, both are *Vulpes
    vulpes*.
  - Hedgehog_dataset_1 (Cibis 2017, sections 2.1–2.3, pp. 5–10): free-ranging European
    hedgehogs on an open grass field in Treptower Park, Berlin, observed after sunset in June
    and July 2016; one rehabilitated animal in an allotment garden. The tag was glued to
    trimmed spines on the last third of the back. This replaces the earlier entry "captive",
    which had been inferred from the handling labels and was wrong.
  - No TBD entries remain in `datasets.csv`.

### D42 2026-11-06 – Reference check and neck-length evidence
- Status: confirmed (Lucas, 2026-11-06: check all references and DOIs)
- Datasets: none (documentation only; no statistic changed)
- DOI check: every DOI in `README.md`, `00_documentation/` and the neck-length review (55)
  was queried at Crossref (api.crossref.org). All 51 Crossref DOIs resolve; title, first
  author, year, volume and pages agree with our citations. Corrected: Neveu et al. (2001) title
  "unspecialised" (core_traits.md and .docx), volume of Tijssen et al. (2021), volume and
  article number of Rast et al. (2020) in `raw_data_review.md`. Year differences that are only
  online vs. issue year are kept (Basu et al. 2019, online 2018, vol. 222; Kahvecioğlu et al.
  2026, online 2025, vol. 16). The four DataCite DOIs (4TU, Dryad, figshare) are not in
  Crossref; they are taken from the dataset pages and the papers that cite them.
- Neck-length evidence: Lucas's review (5 November 2026) is now
  `traits/evidence/relative_neck_length_review.md`. The ten Belyaev et al. Table S1 rows were
  recomputed: all reference ratios and all nine categories match `species_traits_core.csv`.
  Not adopted from the review: the 0.5/0.5 weighting of body configuration and neck length
  (D37 uses equal weights) and its sensitivity variants other than hedgehog `intermediate`
  (D38), e.g. cattle `short`. The private link in `core_traits.docx` now points to the review
  in the repository. Table S6 cites Belyaev et al. 2021 and 2023, the original sources of the
  ungulate measurements in the 2024 supplement.

### D43 2026-11-06 – Added sensitivity: cattle relative neck length short
- Status: confirmed (Lucas, 2026-11-06)
- Datasets: all with results (H3 only)
- Decision: one more trait-sensitivity analysis in the D38 group: the primary model with
  the core distance after setting the cattle's relative neck length to `short` (all other
  inputs fixed). Reported in Table S9 with the mark † (added after the results were known).
- Reason: the cattle ratio (0.311) lies near the 0.30 limit; the two adult specimens give
  0.293 and 0.330 (neck-length review, D42). The review had listed this variant; D38 did not.
- Timing and transparency: decided after all H3 results, including the D38 analyses, were
  known. It is a robustness check, not a test of H3, and cannot change the primary
  specification. Cloud run (2026-11-06, without gawdis and EltonTraits, which this analysis
  does not use): β −0.027 [−0.063, 0.008] per SD, LR χ²(1) 3.14, p 0.076 (primary model:
  β −0.024, p 0.108). All other estimates unchanged. Official values from the next local run.

### D44 2026-11-08 – Repository layout 00–05 and numbering as in the manuscript
- Status: draft (Lucas, 2026-11-08: build the new repository with numbered folders and the
  table logic of the manuscript; the manuscript draft of 8 November 2026 stays unchanged
  for now). Confirm after review of the branch `setup/repository-structure`.
- Datasets: all (no data, model or statistic changed)
- Repository: `ELBE223/accelerometer-behavior-generalization` continues
  `ELBE223/paper-izw-cross-species-transfer` at commit b073a68 (files copied, history stays
  in the old repository).
- Layout (old → new):
  - `00_documentation/` → `00_Documentation/` (registry, mapping, decisions, traits);
    `code/thesis_reference/` → `00_Documentation/thesis_reference/`
  - `code/` (pipeline, loaders, checks) → `01_Preprocessing/`;
    `00_documentation/{dataset_reports,pipeline_reports,thesis_checks}` →
    `01_Preprocessing/reports/`
  - `code/models.py` → `02_Models/`; `code/train_models.py` → `03_Evaluation/`;
    `05_results/` → `03_Evaluation/results/`
  - `code/stats_h1_h2.py`, `code/stats_h3.R` → `04_Statistics/`; `06_statistics/` →
    `04_Statistics/results/`
  - `code/paper_figures.R` → `05_Paper_Outputs/`; `08_paper/{main,supplement}` →
    `05_Paper_Outputs/{main,supplementary,additional}`; `contents.txt` →
    `output_manifest.csv`
  - `code/pipeline_settings.json` → `config/`; `code/setup_project.py`,
    `code/update_local.sh` → project folder
  - local data (not in git): `01_raw_data/`, `02_processed_data/`, `03_windows[_C]/`,
    `04_features[_C]/` → `data/raw/`, `data/processed/`, `data/windows[_C]/`,
    `data/features[_C]/`
  - Script names are unchanged, so earlier entries still find them; paths in D01–D43 refer
    to the earlier layouts.
- Numbering: the manuscript draft (2026-11-08) is the reference; numbers, file names and
  where each item is cited are set in one block at the top of `paper_figures.R`.
  - Tables S3 and S4 swapped: S3 dataset-specific preprocessing (conversion factors,
    cited first in Methods 2.2), S4 window features.
  - Table S21 (seed variability) and Figures S4–S8 are not cited in the manuscript; they are
    written to `05_Paper_Outputs/additional/` without a number. The table notes no longer
    refer to them ("Values of Figure S4/S6/S7/S8").
  - Table S15 (pairwise transfer) keeps its number; the manuscript does not cite it yet
    (proposal: Methods 2.3 at the pairwise transfer).
  - Titles as in the manuscript draft: Table 2 "Behavioral differences in cross-dataset
    F1.", Table 3 "Associations between biological distance and cross-species Macro-F1.",
    Figure 1 "Within- and cross-dataset Macro-F1.", Figure 2 "Cross-dataset F1 by
    behavioral class."
  - Supplementary Text S1 (cited in Results 3.1): draft with the scenario definitions of
    D11 and D27 in `05_Paper_Outputs/supplementary/text_s01_sensitivity_scenarios.md`.
  - New check `tests/check_paper_outputs.py` (run by `update_local.sh stats`): manifest
    complete, numbers without gaps, no outdated files, every cross-reference exists.
- Check (cloud session, Python 3.11, R 4.3.3 without gawdis and EltonTraits):
  `stats_h1_h2.py` in the new layout writes CSV files byte-identical to the committed
  ones; `stats_h3.R` gives CSV files identical to those of the old layout in the same
  environment (the committed H3 results are those of the local run and were not replaced).
  `paper_figures.R`: the tables differ from those of b073a68 only in their number, the
  titles above, the source paths and the dropped references to unnumbered figures; all
  rows are identical. The PNG files are those of the last local run, renamed (the plots
  have no number in them).
- Open: placeholders in the manuscript (Table SX in Methods 2.1 → Table S1; Table SX at
  the end of 2.5 → robustness: Tables S9, S18, S19; sensitivity scenarios: Text S1 and
  Table S20; Figure SX in 2.4 and 2.5: remove, only Figures S1–S3 are numbered); cite
  Table S15; final wording of Text S1; the separate trait supplement draft (not in this
  repository) must cite Table S9, not S11, for the distance sensitivities; move the local
  data folders into `data/` (`data/README.md`).

### D45 2026-11-08 – Repository reduced to what the analysis and the paper need
- Status: confirmed (Lucas, 2026-11-08: fill the new structure only with what is really
  needed; remove the working files, the raw data reports, the model result details, the
  uncited outputs, the trait evidence and the Word version of the trait document)
- Datasets: all (no data, model or statistic changed)
- Removed from this repository (all kept in `ELBE223/paper-izw-cross-species-transfer`, which
  stays as the archive):
  - Working files: `00_Documentation/thesis_reference/` (thesis R scripts, not run),
    `00_Documentation/raw_data_review.md`, `01_Preprocessing/checks/check_thesis_windows.py`
    and its report.
  - Raw data reports: `01_Preprocessing/dataset_report.py` and its reports (they contained
    example values of the non-public raw data; mode `reports` of `update_local.sh` dropped);
    the text reports per dataset and step of the pipeline (now local only, `.gitignore`).
    In git remain the summaries `class_summary.csv`, `window_summary.csv` and
    `activity_levels.csv` (each also for variant C).
  - Model result details: `confusion.csv`, `importance.csv`, `training_sets.csv` and
    `within_folds.csv` of every model and scenario (about 11 MB; local only,
    `.gitignore`). The statistics read `metrics.csv` only; `skipped.csv` and `summary.txt`
    stay.
  - Uncited outputs: the former Figures S4–S8 and Table S21 (`05_Paper_Outputs/additional/`)
    and their code in `paper_figures.R`, with helpers and palette entries no output used.
    The script now makes exactly the items the manuscript cites; an item without a number
    stops it.
  - Traits: `traits/evidence/` (reviews and audits behind each value) and
    `traits/core_traits.docx`; `traits/core_traits.md` is the version in this repository
    and points to the archive for the evidence. Table S6 cites `core_traits.md`.
- Check: `paper_figures.R` gives the same tables and captions as before except the source
  of the trait text in the note of Table S6; `tests/check_paper_outputs.py` passes.

### D46 2026-11-08 – Python packages installed from the lock file
- Status: confirmed (Lucas, 2026-11-08)
- Datasets: all (no data, model or statistic changed)
- Problem: `setup_project.py` installed the newest versions of `requirements.txt` and wrote
  them to `requirements-lock.txt` on every run. The first run in the new layout
  (2026-11-08) therefore replaced the lock file with torch 2.15.0, while the results and
  Table S5 come from torch 2.14.1 (lock file unchanged from 2026-10-25 to 2026-11-06, the
  period of all model runs: scikit-learn 1.9.1, lightgbm 4.7.0, torch 2.14.1, aeon 1.6.0,
  numpy 2.3.5, pandas 3.0.6).
- Decision: `requirements-lock.txt` is restored to these versions and is the installed
  environment: `setup_project.py` runs `pip install -r requirements-lock.txt` and no longer
  writes the file; `update_local.sh` neither resets nor commits it. Newer versions only with
  `setup_project.py --update`, which rewrites the lock file and needs a new decision entry.
- Check: in a test environment, a package upgraded by hand is set back to the locked version,
  the lock file stays unchanged, extra packages are reported, and `--update` rewrites it.

### D47 2026-11-08 – Review of Tables S1–S5 against Methods 2.1–2.2
- Status: confirmed (Lucas, 2026-11-08)
- Datasets: all (no data, model or statistic changed)
- Checked: all numbers match the manuscript draft of 2026-11-08 (61 individuals, 82,028
  training and 54,987 evaluation windows, Hedgehog 1 without a within-dataset value, 26
  features, classifier settings, seeds and libraries). Table S5 unchanged.
- Changes:
  - Table S1: footnote for Dog 2 (no animal identities; each of its 8 recordings is treated
    as an individual), which the manuscript cites in Methods 2.1 (placeholder Table SX);
    column Public merged into Source ("; public").
  - Raccoon_dataset_2: native rate 33.33 Hz instead of 33.3 Hz in `sensor_settings.csv`
    (same e-obs rate: 110 samples in 3.3 s; the thesis gives 33.3 Hz), as for all other
    e-obs datasets (Tables S1, S3). Results are unaffected: the rate sets only the time axis
    within a burst and the resampling ratio, which is 3/4 for both values; windows are
    placed by sample index.
  - Table S2: column Scenario E replaced by a footnote (only Horse 2 changes class).
  - Table S3: US spelling ("behavior", `datasets.csv`). Table S4: column "n" → "Number".
- Table S2 keeps the original labels (codes and German terms of the theses) without English
  descriptions (Lucas, 2026-11-08); a footnote says that their definitions are in the sources
  and available on request. A draft of English descriptions (212 labels, 72 marked for
  checking) was given to Lucas for questions from reviewers.

### D48 2026-11-08 – Review of Tables S6–S9; divergence time of the two horses
- Status: confirmed (Lucas, 2026-11-08)
- Datasets: all with results (H3, phylogenetic distance only)
- Checked against Methods 2.4/2.5 and Results 3.3: Tables S6 and S7 unchanged (five core
  traits, coding, sources, uncertainties). Cattle and giraffe have the same body mass
  reference (900 kg, EltonTraits; D30), so their body mass difference is 0. Table S9 keeps
  all variants: they were fixed before the results (D28, D38) and are reported in full (D01);
  Methods 2.5 should name them (within-dataset adjustment, retention, gawdis, EltonTraits with
  diet, RF and LightGBM only, exploratory traits).
- Divergence time, domestic vs. Przewalski's horse: the TimeTree tree of the thesis gave
  11.2 Myr; the TimeTree pairwise query (Lucas, 2026-11-08) gives 10.1 Myr (CI 8.0–12.1,
  adjusted 8.7; 15 studies) for Equus caballus vs. Equus ferus, which TimeTree treats as the
  tarpan. Both are older than the genus Equus (4.0–4.5 Myr; Orlando et al. 2013, Nature
  499:74–78, p. 74). In that paper the populations of the domestic and the Przewalski's horse
  diverged 38–72 kyr ago (pp. 74 and 76); the most recent common ancestor of their genome
  sequences is 341–431 kyr old (p. 76, Fig. 3a). Decision: this pair uses the midpoint of
  the population divergence, 0.055 Myr (`divergence_overrides` in `stats_h3.R`); the tree
  file stays as exported, all other pairs keep their TimeTree values. With 0.05, 0.055 or
  0.36 Myr the model gives the same result (cloud: β 0.002, p 0.935–0.936). As the two
  horses count as separate species in H3, this changes the phylogenetic-distance model.
  Cloud preview (R 4.3.3; this row matches the local run to 1e-9 with the old value):
  β 0.002 [−0.030, 0.033] per SD, LR χ²(1) 0.01, p 0.935, R² 0.36 (before: 0.001
  [−0.031, 0.032], 0.00, 0.973). Official values from the next local run.
- Tables: S8 note on the horse pair; values below 1 Myr with three decimals; note that the
  gawdis and EltonTraits-with-diet columns are used only in the robustness analyses
  (Table S9). S9 note: "EltonTraits with and without diet".
- Manuscript (later): Methods 2.4 "divergence times from TimeTree 5 (Kumar et al., 2022),
  except domestic vs. Przewalski's horse (Orlando et al., 2013)"; Table 3, row
  phylogenetic distance, from the local run.

### D49 2026-11-08 – Review of Tables S10–S14 against Results 3.1–3.2
- Status: confirmed (Lucas, 2026-11-08)
- Datasets: all (no data, model or statistic changed)
- Checked: every value cited in Results 3.1–3.2 matches (Wilcoxon tests, Friedman tests,
  Holm-adjusted comparisons, transfer loss of ResNet: χ² 8.60, p 0.014; resting vs. foraging
  Holm p 0.041). Table S12 and Figures S2–S3 unchanged.
- Changes:
  - Table S10: Hedgehog 1 with its cross-dataset Macro-F1 and accuracy (from
    `seed_means.csv`; no within-dataset value, not in the H1 tests), so all eleven
    cross-dataset values are reported.
  - Tables S11 and S13: medians and IQR with three decimals, as Table 1 and the text; Table
    S11 column "p-value" → "p method" (exact or normal approximation).
  - Table S14: note without the leftover rule for dashes.
- Manuscript (later): Methods 2.5 says the H1 comparison was repeated for the seven datasets
  in which every individual is a test unit; Results 3.1 should report it: there all six
  classifiers differ (Macro-F1; CNN p 0.031, ResNet p 0.047, the others p 0.016; Table S11).
