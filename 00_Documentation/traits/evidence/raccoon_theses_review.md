# Raccoon source theses: evidence for the trait coding and the recorded data

Checked 2026-11-05 at Lucas's request. The two supplied theses are the source studies of
the raccoon datasets. This note records what they establish for the D37 Core traits and
for the interpretation of the raccoon data. It changes no trait value, mapping or result.

| ID | Source | Dataset |
|---|---|---|
| RT1 | Mardaus, D. (2017). *Analyse hochaufgelöster 3D-Beschleunigungsdaten zur automatischen Differenzierung verschiedener Verhaltensweisen bei Waschbären (Procyon lotor)*. Master's thesis, Freie Universität Berlin / Leibniz-IZW. Supplied file `Msc_Dominique_Mardaus_2017_Waschbär.pdf`. | Raccoon_dataset_1 (Lisa, Ottilie) |
| RT2 | Geiger, P. (2023). *Analyse dreidimensionaler Beschleunigungsdaten zur automatischen Differenzierung verschiedener Verhaltensweisen bei Waschbären*. Bachelor's thesis, Humboldt-Universität zu Berlin / Leibniz-IZW. Supplied file `Bsc_Peter_Geiger_2023_Waschbär.pdf`. | Raccoon_dataset_2 (Carlo, Emma, Wilbert) |

Page numbers are the printed page numbers.

## Findings

| Topic | RT1 (Raccoon_dataset_1) | RT2 (Raccoon_dataset_2) |
|---|---|---|
| Animals and housing | Two seven-year-old females, Lisa and Ottilie, in a c. 1500 m² near-natural enclosure with climbing trees and a pond, Wildpark Johannismühle (pp. 14–15). | Emma (female) and Carlo (male), both c. 3 years, in a 24 m² enclosure; Wilbert (male) **5 months old** at the start (September 2022), kept in a c. 4 m² cage and recorded mostly on a leash outside, at a pond and climbing structures (p. 16). |
| Body mass | Lisa 7.2 kg and Ottilie 8.4 kg at the start of recording (p. 14). | No masses of the study animals; species range 3.5–9 kg cited from Schmid (1995) (p. 7). |
| Sensor and placement | e-obs collar type 1C light, 115 g; logger meant to sit dorsally on the neck between the ears, battery ventrally; the loose collar could rotate and the logger sat mostly shifted towards the left ear (pp. 16–17). 33.33 Hz, bursts of 1.62 s and later 2.88 s every 30 s (p. 17). | Emma and Carlo: leather collars, sensor dorsally on the neck, battery ventrally. **Wilbert: dog harness, logger dorsally on the upper back**, three harness sizes as he grew (p. 19). 33.3 Hz, bursts of 3.3 s every 60 s (p. 19). |
| Locomotion | Four-beat walk, a faster lateral two-beat gait ("Pass") and gallop; climbing up and down pine trunks (p. 21). | Walking, gallop, climbing (head up or down, sideways), hanging and swimming (pp. 22–23). |
| Foraging | The ethogram includes feeding from the ground with the head low, searching (slow mix of walking and standing, head low), and eating from or rubbing items in the forepaws while sitting or standing on the hind legs (pp. 20–21). The analysed labels of this dataset are only feeding from the ground (StFrBoT) and searching (Su*) (`behavior_mapping.csv`). | Eating on land and in water, and **rhythmic scraping with the forepaws in the substrate or in water** ("Schaben Land", "Schaben Wasser") (p. 23); the forepaws' tactile sense matters for foraging in water and on the ground, and "washing" of food is reported for captivity only (p. 7, citing Graf & Fischer 2021 and Schmid 1995). Eating and grooming both involve rhythmic head movements and were confused by the classifiers (p. 43). Active behaviours, including scraping, were recorded almost only from Wilbert (p. 45). |

Windows of the primary mapping (`00_documentation/pipeline_reports/class_summary.csv`):

| Dataset | Individual | Foraging | Locomotion | Resting |
|---|---|---:|---:|---:|
| Raccoon_dataset_1 | Lisa | 108 | 162 | 81 |
| Raccoon_dataset_1 | Ottilie | 54 | 81 | 81 |
| Raccoon_dataset_2 | Wilbert (juvenile, harness) | 302 | 338 | 236 |
| Raccoon_dataset_2 | Carlo | 122 | 48 | 636 |
| Raccoon_dataset_2 | Emma | 24 | 0 | 320 |

In Raccoon_dataset_2, Wilbert supplies 302 of 448 Foraging and 338 of 386 Locomotion
windows, recorded with a back-mounted logger; the other raccoons wore collars.

## Consequences for the D37 Core traits

- **C1 body mass:** measured masses exist for Raccoon_dataset_1 only (two adult
  females, mean 7.8 kg); Raccoon_dataset_2 has none and includes a growing juvenile.
  The equal-weight study-mean convention used for the dog (D30) therefore cannot be
  applied. The EltonTraits reference (5.525 kg) stays; C1 is closed (D30) and no
  mass sensitivity was agreed.
- **C2 locomotor specialization:** both theses record habitual climbing (and
  RT2 swimming), consistent with `scansorial`.
- **C3 body configuration:** neither thesis gives body proportions beyond overall size,
  so they neither support nor contradict the merger into `standard_quadruped` (D34).
  The agreed check (raccoon as a separate group) remains the appropriate test.
- **Relative neck length:** no neck or vertebral measurements; Davis (1964) remains
  the basis of `short`.
- **Food acquisition and handling:** `manual_food_handling` describes the taxon. In the
  recorded Foraging windows, forepaw handling appears in Raccoon_dataset_2 (scraping on
  land and in water, mostly Wilbert) but not in the analysed labels of
  Raccoon_dataset_1 (feeding from the ground and searching with the head low).

## Consequences for the data and the paper

- Sensor placement is not uniform within Raccoon_dataset_2: most active windows come
  from a juvenile wearing a back-mounted harness. Collar-based arguments (for example
  the neck-length mechanism) apply to the other four raccoons, not to these windows.
- Placement, age and housing differ between the two raccoon datasets. Placement per
  dataset and individual should be listed in the dataset table (Table S1).
- No analysis was changed. Leaving out Wilbert, or using a raccoon cohort mass, would be
  new analysis choices. Each would need a decision before any fit and was not part of
  the agreed sensitivity analyses (D38).
