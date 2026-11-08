# Raw data review

Date: 2026-10-24. Based on the first run of `code/dataset_report.py` (reports in
`dataset_reports/`) and the thesis preprocessing scripts in `code/thesis_reference/`.
The thesis data processing scripts 01–07 are in
`code/thesis_reference/data_processing/R/`.

## 1. Findings that may affect the thesis results

Checked on the windowed thesis data with `code/checks/check_thesis_windows.py`
(`thesis_checks/thesis_windows_check.txt`, input
`old/11_05_2026_Data_Analysis/Data_Processed/data_processed_final`).

1. **Bison summary sheets: not used.** `Bison_dataset_1/02.R` reads every sheet with
   `ID, Datum, Zeit, X, Y, Z, Code`, which includes `GESAMT` and `GESAMT FERTIG`. The
   thesis windows, however, contain only Flake, Döschi and Arena, and no window occurs
   twice (in any dataset or across datasets).
2. **Split unit: by animal.** `individual_key` is `<dataset>__<individual_id>`, with the
   animal or tag ID, in all 12 datasets.
3. **Horse_dataset_1, Jedi: one unit.** Both Jedi sheets have `individual_id` 4935 and
   form one `individual_key`.
4. **Units: converted to g** before windowing (signal about ±1, clipped at ±4 g;
   Horse_dataset_2 at ±8 g).

Thesis windowing, from the same check: 25 Hz, 2.46 s windows (62 samples, i.e. one
82-sample burst at 33.33 Hz), no overlap; longer bursts and continuous recordings give
several consecutive windows.

Still open:

5. **Clips shorter than 2.46 s were stretched to 62 samples** (`resample_by_position` in
   `04_make_native_windows.R`: linear interpolation over the clip position). Affected
   windows: Hedgehog 731 of 1 037 (clips 1.47–2.02 s at an assumed 100 Hz, stretched by a
   factor of 1.2–1.7), Fox_dataset_1 90 of 913, Bison 1, Dog_dataset_2 1; Giraffe clips
   are 82 samples (2.4599 s) and practically unchanged. Stretching slows the movement down
   and shifts its frequencies. Resampling to 25 Hz used linear interpolation without an
   anti-aliasing filter.
6. **Individuals in the thesis windows**: `07_make_final_model_datasets_updated.R` kept
   only individuals with all three classes and at least 10 windows per class. Removed:
   2 of 14 dogs (Dog_dataset_1), 4 of 6 hedgehogs, 4 of 11 horses (Horse_dataset_2),
   1 of 3 raccoons (Emma, Raccoon_dataset_2); Dog_dataset_2 has 7 dogs, all from sensor
   setting 6568. The list is in `07_reports/07_csv/07_excluded_individuals.csv` of the
   thesis folder.
7. **Sampling rates** of the burst datasets are confirmed from the theses
   (`sensor_settings.csv`). Hedgehog: 100 Hz, 264-sample bursts (2.64 s). Giraffe: the
   data are from the e-obs collar (33.8 Hz in the thesis PDF; the sample times in the
   data fit 33.33 Hz, which the thesis windowing also used; D18). Raccoon_dataset_1 has
   1.62-s bursts for 11 weeks and 2.88-s bursts for 2 weeks; all thesis windows come from
   the 2.88-s bursts.
8. **Metadata: the two horse datasets have swapped species.** The window files give
   `Equus caballus` as species of Horse_dataset_1 (Przewalski's horses, Saenger), and
   the dataset lookup of `Supplementary/02_Supplementary_evaluation_results.R` (aligned
   with Supplementary Table S1) gives Horse_dataset_1 as domestic horse and
   Horse_dataset_2 (Horsing Around, domestic horses) as Przewalski's horse. Tables and
   figures that use this lookup name the two datasets wrongly; whether the H3 distance
   scripts use it too is to be checked.
9. **Fox_dataset_1: copied bursts, and thesis windows across a burst and its copy.**
   The two master files hold 453 bursts twice (identical values and time stamps; 455 of
   992 bursts are copies, all within one fox; D17). The thesis cut the data into clips
   at each new time stamp (`route` clip_repeated_timestamp), so a burst and its copy
   became one clip of 220 samples (6.6 s): 744 of the 913 thesis windows come from such
   clips. The second window of each of these clips (`window_id_in_source` 2, 374
   windows) runs from the end of the burst into the start of its copy, a signal that was
   never recorded. The thesis windows have 537 different clip start times, the same as
   the 537 different bursts found here. 30 clips each of 9, 33 and 34 samples (0.3–1 s;
   probably bursts with a time per sample, cut at whole seconds) were stretched to 62
   samples (the 90 windows of item 5). So about half of the Fox_dataset_1 thesis
   windows (374 + 90 of 913) are artifacts. As the copies stay within one fox, they did
   not leak between the two individuals.
   Dog_dataset_2 has the same pattern on a small scale: 6 clips of 248 samples (30
   windows) are two bursts with one time stamp, most likely a burst and its copy (25
   copied bursts within recordings here). The new loaders find copies and never join two
   bursts (D17).
10. **Behavior mapping** (`behavior_mapping.csv`, D10): the thesis scripts and the mapping
   tables differ in Horse_dataset_1 (TRK), Raccoon_dataset_1 (StN, StB) and
   Raccoon_dataset_2 (several labels); Horse_dataset_2 ridden gaits were Locomotion.
11. **Dog_dataset_1, Lumpi lost in the thesis.** 440 of Lumpi's 547 bursts have clock
   times written HH.MM:SS (D19). The thesis read them as missing and dropped the rows;
   Lumpi does not appear in the thesis windows. Here Lumpi has 151 Foraging, 173
   Locomotion and 172 Resting evaluation windows.

## 2. Datasets

| Dataset | Data | Individuals | Sampling | Unit | Labels |
|---|---|---|---|---|---|
| Bison_dataset_1 | 1 Excel; sheets per animal + GESAMT, GESAMT FERTIG, ANZAHL | 3 (Flake, Döschi, Arena) | bursts (~246–328 rows per time stamp, every 30 s); rate from thesis PDF | raw counts | `Code` (29), `Verhalten`, `Verhalten_Kopf` |
| Cattle_dataset_1 | 6 CSV (public, Japanese Black Beef) | 6 cows | 25 Hz continuous | g | per sample; 13 behaviors + ETC (other) + empty (no video, 39 %) |
| Dog_dataset_1 | 14 txt (R export with row names) | 14 dogs | 1 s time stamps; rate from thesis PDF | raw counts | codes as in the thesis mapping: SIT, LIG, STE, GEH, REN, SPR, KNA, SCH, BUD |
| Dog_dataset_2 | 20 text files without extension (`Data_Dog_Raw/<name>_6568`); thesis parquet in `converted_thesis/` | 20 names | 4 sensor settings: 33.33/20 Hz, bursts 3.3/6 s (Settings.rtf) | raw counts | already mapped to 3 classes |
| Fox_dataset_1 | 2 Excel (sheet `data` + `qa`) | 2 (Dana, Silva) | bursts; rate from thesis PDF | raw counts | 7 main categories + 29 subcategories |
| Fox_dataset_2 | Movebank e-obs: 6 ACC CSV + behaviour CSV per fox | 6 (tags 1639, 1644, 4142, 5009, 5010, 5011) | bursts every 120 s; 18.74 Hz (1639, 1644) and 33.33 Hz (others) | raw counts | one label per burst (7) in separate files |
| Giraffe_dataset_1 | 1 Excel sheet, 983 754 rows | 3 (`animal`), 31 tag days | 33.33 Hz in bursts | raw counts | `beh_code` (49), `cat_code` (14) |
| Hedgehog_dataset_1 | 1 Excel sheet | 6 names on 3 tags | bursts (~194 rows every 20 s) | raw counts | 17 German labels |
| Horse_dataset_1 | 1 Excel; 5 animal sheets + GESAMT, ANZAHL | 4 used in the thesis (Joda, Kalmoek, Jedi ×2) + Pernot_Sultan ("NICHT IN GESAMT") | 33.33 Hz in bursts | raw counts | `Code`, `Verhalten`, `Verhalten_Kopf` |
| Horse_dataset_2 | original download (Horsing Around zip: 147 CSV parts, settings, activity distribution); thesis parquet in `converted_thesis/` | 18 horses, 11 with labels | 100 Hz (`settings.csv`); no time column, `segment` IDs | m/s² (±8 g, clipped at ±78.5) | 17 labels incl. ridden gaits (walking, trotting, galloping with rider) |
| Raccoon_dataset_1 | 1 Excel sheet | 2 | bursts (~96 rows per time stamp) | raw counts | 17 detailed codes |
| Raccoon_dataset_2 | 3 Excel (`merged`) | 3 (Carlo, Emma, Wilbert) | bursts (110–220 rows every 60 s) | raw counts | German behavior names |

## 3. Notes per dataset

- **Bison_dataset_1**: use the three animal sheets only. The mapping table (RTF) lists
  codes such as SKO, LIO, FSG, HFO, the data contain SKN, LIN, FSH, HFN; the thesis
  script maps both variants.
- **Cattle_dataset_1**: the ReadMe states a ±2 g sensor, but values reach about 3.8 g.
  Time goes backwards a few times per file and a few time stamps repeat; check before
  windowing. No thesis R script in the folder.
- **Dog_dataset_1**: the header has one field less than the data rows (R row names);
  the first report run misread it, fixed in the report script. `Tag` is the weekday.
  The thesis maps BUD to Other. `Mapping_table_behavior.rtf` swaps two classes (SIT, LIG,
  STE under Locomotion; GEH, REN, SPR under Resting); the thesis script maps them
  correctly (SIT, LIG, STE Resting; GEH, REN, SPR Locomotion). `Burst`/`Nummer` is not
  the collar: dogs with the same number have bursts at the same times with different
  values (e.g. Mio and Timba, 3680, 433 bursts on 31 Mar 2017), so several dogs were
  recorded at once and the number is probably the recording session or download. In
  Lumpi's file 440 bursts have clock times of the form HH.MM:SS (D19). Emi's file also
  contains 8 690 rows coded HEL (79 bursts, all KNA, after Emi's last burst); they have
  the start times and label of Helena's 79 KNA bursts but other values, so they come
  from another collar than Helena's file, probably Emi's. They are left out (D20).
- **Simultaneous recordings** (same number and burst start time, different animals, no
  identical values): Dog_dataset_1 1 153 bursts (Mio, Timba, Lumpi, Fibo, Dexter),
  Raccoon_dataset_1 14 (Lisa, Ottilie), Raccoon_dataset_2 57 (Carlo, Emma); none in
  Fox_dataset_1, Giraffe_dataset_1 and Hedgehog_dataset_1.
- **Dog_dataset_2**: raw files are 20 text files without extension, one per dog name,
  all from sensor 6568 (20 Hz, bursts of 124 samples every 13 s). **Several files hold
  the same recording**: identical acceleration values, clock times, labels and `Number`,
  only the date and the dog name differ (e.g. Emily 14.12.2018, Frida 7.11.2018, Trude
  13.11.2018; all `Number` 4266). Judging from identical class counts, the 20 names
  form 8 groups (Emily/Frida/Trude, Gaucho/Harvey/Kalle, Jeanne/Lulu/Nelo/Pipper,
  Käthe/Knut, Marley/Ziva, Cooper/Dorle, Amy/Dexter, Ami/Winston), i.e. 8 recordings.
  Which dog each recording belongs to is unclear; to be asked to the data providers.
  The thesis windows have 7 units keyed by `Number` and no duplicate windows, so the
  copies did not enter the thesis results.
- **Fox_dataset_1**: the thesis maps DRINKING to Foraging, which the mapping table does
  not list. `Verhalten_unterkategorie` is the name of the recording file (29 files for
  Dana, 38 for Silva in the `qa` sheet; the number after the dot is the number of bursts,
  e.g. `34uB.20-ACC` has 2 200 rows = 20 × 110); the label is
  `Verhalten_ueberkategorie`. Silva's `Datum` is stored as Excel day numbers, and some of
  her recordings have a time per sample (0.03 s steps). The fox in Silva_ACC_master is
  called Silver in `Tier`.
- **Giraffe_dataset_1**: `time_s` is the burst start, `time_ss` the time of each sample;
  the steps fit 33.33 Hz, not the 33.8 Hz of the thesis PDF (D18). `cat_code` is the
  category of `beh_code`, but 1St_GuTi occurs under RUM and STA and 3FuTi under FED and
  FEG; the thesis mapped `cat_code` and split STA by `beh_code`. The label in the new
  pipeline is therefore `<cat_code>/<beh_code>` (e.g. `STA/1St_Gu`).
- **Fox_dataset_2**: `fox_1644_behaviour.csv` = `fox_1644_180` + `fox_1644_82` (the two
  burst lengths of tag 1644); use one of them. Nearly every burst over weeks has a label,
  so the origin of the labels (direct observation or a model prediction) must be known.
  Labeled bursts: about 262 000; a reduction, if needed, per individual × behavior.
- **Hedgehog_dataset_1**: `wird bewegt`, `wird getragen`, `wird geschüttelt` (handled by
  people) and `STARTSHAKE`/`ENDSHAKE` (calibration markers) are not animal behavior and
  should be excluded, not mapped to Other.
- **Horse_dataset_1**: Pernot_Sultan is marked "NICHT IN GESAMT" and was not used.
- **Horse_dataset_2**: the original download is in `original_download/` (MATLAB copies not
  extracted). The CSV parts have at most 1 048 575 rows (Excel row limit); only parts with
  a `label` column contain labels. According to `activity_distribution.csv`, 7 of the 18
  horses have only unlabeled data, so 11 horses are usable, the same as in the thesis.
  The dataset authors used 2-s windows (200 samples at 100 Hz) with 50 % overlap. Ridden
  gaits (`walking-rider`, `trotting-rider`, `galloping-rider`) need a mapping decision.
- **Raccoon_dataset_2**: the sheets of Carlo and Emma are filled down to the last Excel
  row (1 048 575 rows, most of them empty apart from the name).

## 4. Open questions

1. **Fox_dataset_2: labels probably predicted by a model, not observed** (to be confirmed).
   - Rast, Kimmig, Giese & Berger (2020), *Machine learning goes wild: Using data from
     captive individuals to infer wildlife behaviours*, PLOS ONE, 15, e0227317,
     doi:10.1371/journal.pone.0227317 (checked 2026-11-06, D42): an ANN
     trained on two observed captive foxes (33.33 Hz, 110-sample bursts) classified the
     behavior of free-ranging foxes in Berlin; no direct validation in the field.
   - Fox_dataset_1 matches that training data: two captive foxes (Dana, Silva), 33.33 Hz,
     110-sample bursts, thesis by L. Giese, a co-author of Rast et al.
   - The Fox_dataset_2 labels (eating, grooming, other, resting, stocking, trotting,
     walking) share five of seven categories with Fox_dataset_1 (drinking, foraging,
     grooming, resting, stocking, trotting, walking), and nearly every burst over weeks
     has a label.
   - Fox_dataset_2 combines sources ("Verschiedene Quellen, verschiedene Frequenzen!",
     Informationen.rtf): tags 1639 and 1644 from 2011 at 18.74 Hz, the others from
     2016–2018 at 33.33 Hz. The Movebank study ("Movement ecology of red foxes in dynamic
     agricultural landscapes", BioMove project, 2015–2018) does not cover 2011.
   - Open: which project each tag comes from, and whether its labels are ANN predictions.
     Question to A. Berger (co-author of Rast et al.). Handling until then: D14.
2. Dog_dataset_2: which dog each of the 8 recordings belongs to (20 names, copies of the
   same recording under several names); to be asked to the data providers (D15).
3. Horse_dataset_2: resolved, original download in `original_download/`.
4. Cattle_dataset_1: processed directly by `01_harmonize_model_ready.R`? (no `02.R`).
5. Dog_dataset_1: sampling rate (33.333 Hz assumed) to be confirmed in the BSc thesis.
   Horse_dataset_2: confirmed (100 Hz, settings.csv).
6. Hedgehog_dataset_1: bursts in the data are shorter than the 264 samples of the
   settings (median 194, i.e. 1.94 s); bursts under 2 s give no 2-s window: 1 248 of
   2 473 bursts (32 % of the samples). 1 225 windows remain (D06).
7. Dog_dataset_1: what `Burst`/`Nummer` stands for (recording session?), and whose
   collar the 79 bursts coded HEL in Emi's file come from (D20); Szangolies BSc thesis.
