# Dog inclusion audit for the body-mass trait

Checked: 2026-11-01. Scope: the committed **primary** analysis, all six
classifiers and seeds 42–46. Reviewed commit:
[0311f0c64c622c64a208049e31e4cebf032040c9](https://github.com/ELBE223/paper-izw-cross-species-transfer/commit/0311f0c64c622c64a208049e31e4cebf032040c9).

This inclusion audit describes the primary results at the reviewed commit.
Scenarios other than primary were not audited here. **Subsequent decision D30
accepts 26.746429 kg (reported as 26.75 kg) as the dog's source-study reference
and updates both trait matrices; existing H3 outputs still use the prior inputs.**

## Finding relevant to H3

**Dog_dataset_1 contributes all 14 identified dogs to pairwise transfer;
Dog_dataset_2 contributes all eight retained recording units.** Duke is excluded
only as the held-out test dog in primary within-dataset evaluation. He is present
in pairwise training and testing. No mass calculation for primary H3 should drop
Duke merely because he lacks a within-dataset test fold.

H3 uses pairwise transfer results, averaged over dataset pairs within an ordered
species pair (`code/stats_h3.R::species_pairs`). It uses one trait profile for
Canis lupus familiaris. Both dog datasets therefore matter, although this does
not identify the true animals underlying Dog_dataset_2.

## Dog_dataset_1: identities, weights and evaluation membership

Weights come from Szangolies (2017), Table 2, printed p. 5 / PDF p. 12,
transcribed in [trait_body_mass_dog1_measurements.csv](body_mass_dog1_measurements.csv).
All rows below enter primary cross/pairwise evaluation. Counts exclude Other and
refer to non-overlapping windows in the three main classes.

| Repository ID | Name in source | Mass (kg) | Held-out within fold | Cross/pairwise test windows |
|---|---|---:|---|---:|
| Abby | Abbey | 25.0 | Yes | 330 |
| BigFoot | Big Foot | 36.0 | Yes | 269 |
| Chica | Chica | 5.5 | Yes | 581 |
| Dexter | Dexter | 40.8 | Yes | 416 |
| Duke | Duke | 30.0 | No: no Foraging | 223 |
| Emi | Emi | 24.0 | Yes | 304 |
| Fibo | Fibonacci | 14.1 | Yes | 498 |
| Helena | Helena | 30.0 | Yes | 282 |
| Lulu | Lulu | 28.0 | Yes | 477 |
| Lumpi | Lumpi | 6.7 | Yes | 496 |
| Malka | Malka | 8.0 | Yes | 342 |
| Mio | Mio | 10.9 | Yes | 488 |
| Timba | Timba | 33.3 | Yes | 504 |
| Zaini | Zaini | 29.6 | Yes | 558 |
| **Total** | **14 dogs** | **321.9 kg summed** | **13 folds per seed/model** | **5,768** |

The mean of these 14 measured masses is **22.992857142857 kg**. Their median
is 26.5 kg. Removing Duke would instead give 22.453846 kg over 13 dogs, but
that is only the within-test subgroup and is not the primary H3 cohort.

Duke supplies 109 Locomotion and 114 Resting evaluation windows, and no Foraging.
The within results pool 5,545 windows; adding his 223 gives the 5,768 cross
and pairwise windows. Lumpi is retained in current primary results; older thesis
exclusions must not be carried over to this pipeline.

The post-cap pairwise training logs show 250 windows per class for every seed:
13 dogs in Foraging, and all 14 in Locomotion and Resting. Thus the inclusion of
all 14 is supported by the saved training counts as well as the loader and rules.

## Dog_dataset_2: recordings with unresolved animal identities

The loader groups files whose complete acceleration arrays are identical and
keeps one copy per group (D15). The harmonization report records 20 named files
but only eight different recordings; copies have matching labels but differing
date/time metadata. Joining file names describes provenance uncertainty. It does
not establish that every named dog contributed a distinct observation.

| Retained recording ID | Cross/pairwise test windows | Held-out within fold | Individual mass |
|---|---:|---|---|
| Ami+Winston | 486 | Yes | Not identifiable from the retained recording |
| Amy+Dexter | 462 | Yes | Not identifiable from the retained recording |
| Cooper+Dorle | 459 | Yes | Not identifiable from the retained recording |
| Emily+Frida+Trude | 597 | Yes | Not identifiable from the retained recording |
| Gaucho+Harvey+Kalle | 546 | Yes | Not identifiable from the retained recording |
| Jeanne+Lulu+Nelo+Pipper | 513 | Yes | Not identifiable from the retained recording |
| Käthe+Knut | 480 | Yes | Not identifiable from the retained recording |
| Marley+Ziva | 396 | Yes | Not identifiable from the retained recording |
| **Total** | **3,939** | **8 folds per seed/model** | **Unresolved** |

The displayed Käthe spelling is Unicode-normalized for readability; the raw
repository ID uses a decomposed umlaut. Frida in the file names corresponds to
Frieda in the thesis weight list.

Each of the three classes in the post-cap pairwise training log contains all
eight recording units in every seed. There is no further identity-based exclusion
that turns the 20-name source cohort into eight unambiguously named dogs.

The loader's choice of the first file within each duplicate group is an
implementation choice, **not evidence that its filename identifies the true
animal**. A weight must not be assigned on that basis.

Groth (2020), Table 2, printed p. 7 / PDF p. 18, describes 20 dogs with an
arithmetic mean mass of 30.5 kg. That remains a **source-cohort reference**;
it is not the verified mean mass of eight identified analysis animals.
Animal-to-recording mapping requires independent original metadata.

## Global split: actual held-out units

Global holds out three Dog_dataset_1 units and two Dog_dataset_2 units per seed;
the other units form that dataset's training pool. All six classifiers have
the same recorded split identities.

| Seed | Dog_dataset_1 test dogs | Dog_dataset_2 test recordings |
|---|---|---|
| 42 | Chica, Duke, Malka | Ami+Winston, Marley+Ziva |
| 43 | Emi, Helena, Zaini | Käthe+Knut, Marley+Ziva |
| 44 | Abby, BigFoot, Fibo | Cooper+Dorle, Emily+Frida+Trude |
| 45 | Lulu, Lumpi, Timba | Ami+Winston, Cooper+Dorle |
| 46 | Chica, Dexter, Lumpi | Cooper+Dorle, Emily+Frida+Trude |

## Consequence for choosing one dog mass

The reference accepted in D30, 26.746429 kg, equals
`(321.9 / 14 + 30.5) / 2`: equal weighting of the two **source-study means**.
It is adopted as an explicitly declared study-reference approximation.
The inclusion audit does not upgrade it to a measured pooled-cohort mean.

Pooling 34 source-table observations gives 27.408824 kg. The tables do not
establish 34 unique animals across studies, nor that all 20 Dog_dataset_2 names
represent distinct retained animals. Likewise, replacing 20 by eight in the
denominator does not solve the identity problem. None of these calculations
independently establishes the current 28 kg value.

Lucas confirmed this aggregation on 2026-11-01 (D30). The unrounded aggregate is
transformed to ln(grams) and stored as 10.194 in Core and Extended. The old 28 kg
convention is superseded for new fits. Sensitivity to defensible alternatives
remains to be assessed; no new H3 fit or p-value was used to select this value.

## Reproducible evidence checked

- `00_documentation/decisions.md`, D12 and D15.
- `code/train_models.py`: thesis_rule, run_within, run_cross, run_pairwise,
  run_global, and spread_cap.
- `code/loaders/dog_dataset_2.py`: duplicate recording groups and naming.
- `00_documentation/pipeline_reports/class_report.txt`: named class counts.
- `00_documentation/pipeline_reports/Dog_dataset_2_harmonized.txt`: duplicate groups.
- `05_results/primary/{cnn,hydra,lgbm,multirocket,resnet,rf}/metrics.csv`:
  all dog-target rows checked; seed, mode, source/target, counts, class supports
  and global test identities agree across models.
- The corresponding `within_folds.csv` files: each has 65 Dog_dataset_1 and
  40 Dog_dataset_2 rows (five seeds); test identities and supports agree.
- All six `training_sets.csv` files have the same Git blob
  `98be9ddd84515949c63834871c1fd89f4b3bff73`. Its RF copy was read to verify
  post-cap dog counts for every primary pairwise training set.
- `code/stats_h3.R`: pairwise dataset-to-species aggregation.

The audit uses committed results and preprocessing records; the classifiers were
not rerun and the uncommitted raw files were not independently reprocessed.
