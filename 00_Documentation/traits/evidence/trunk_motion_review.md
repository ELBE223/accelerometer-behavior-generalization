# C4 — Expected trunk motion amplitude: evidence and decision review

**Current decision — D36, 2026-11-03:** Lucas approved excluding C4 from the primary H3 distance. The effective Core now contains six traits (C1–C3, C5–C7). The seven-column Core CSV preserves the historical C4 scores; `read_traits()` excludes C4 by default. `core_with_c4` adds back only C4 with all other current inputs held fixed and is explicitly exploratory. Extended remains a separate 11-trait sensitivity specification including C4. H3 fits and affected displays have not been regenerated; existing outputs are stale relative to D30/D34/D36. Earlier review statements below describe the pre-D36 status.


Started: 2026-11-02 (D35). Updated: 2026-11-02 (targeted literature audit).
Status: **candidate measurement definition proposed; current four-level ranking not validated; no recoding or Core-scope change**.

## Current inputs

Column: `expected_trunk_motion_amplitude`, identical in Core and Extended.

| Existing level | Study taxa | n |
|---|---|---:|
| `low` | Erinaceus europaeus | 1 |
| `moderate` | Bison bonasus; Bos taurus; Procyon lotor | 3 |
| `high` | Canis lupus familiaris; Equus caballus; Equus ferus przewalskii; Vulpes vulpes | 4 |
| `very_high` | Giraffa camelopardalis | 1 |

The R reader treats these as ordered: `low < moderate < high < very_high`.
They are inherited inferred scores, not measured amplitudes. This audit does not
reconstruct their original derivation or confirm the ranking.

## Decision-ready assessment

There is primary evidence that trunk movement can be measured and depends on the
measurement location and locomotor conditions. The inspected evidence does not
supply a common, comparable four-level ranking for these nine taxa. Absence of
support does not justify replacing a score with a lower category.

**Recommendation for discussion:** use a primary distance without C4 and retain
the existing C4 scores only as an explicitly exploratory sensitivity specification,
unless a common measurement/evidence basis can be assembled. An alternative is to
rebuild C4 from standardized kinematics using the candidate definition below.
Neither option is adopted in this update. The current Core still has seven traits.

A qualitative ordinal trait is possible in principle, but it needs reproducible
criteria and evidence for the ordering across taxa. Renaming the four levels,
merging them or adding general biomechanical citations would not by itself supply
that missing basis. Categories must not be chosen to improve H3 significance.

## Candidate operational definition — not yet adopted

Working name: **relative vertical excursion of the cranial thorax during steady,
level walking**. This deliberately specifies one component of movement. It is
not all-direction trunk mobility, spinal flexion, neck motion or acceleration.

| Item | Proposed specification / remaining requirement |
|---|---|
| Anatomical point | A documented homologous dorsal cranial-thorax landmark near the shoulder girdle. Withers markers are a practical starting point; their exact anatomical identity must be reconciled across taxa. |
| Frame and quantity | Vertical position relative to the ground; maximum minus minimum during one full stride, defined from successive contacts of the same foot. |
| Units | Retain raw excursion in cm; express the candidate comparison as a percentage of standing shoulder height from the same reference individual/population. |
| Behaviour | Straight, steady walking on level ground. Exclude running, climbing, feeding, defensive postures, turning and marked acceleration/deceleration. |
| Speed | Compare a defined overlapping dimensionless-speed interval, for example using `Fr = v^2/(g h)`. The target interval is not yet selected. Preferred speeds alone do not establish equivalence. |
| Population | Record taxon, age, sex, breed, health and source-population scope. Do not silently equate literature subjects with the accelerometer cohorts. |
| Aggregation | Summarize repeated strides within individuals before forming a declared population summary; report between-individual spread. Do not let unequal stride counts silently determine weights. |
| Extraction | Use published compatible summaries or independent kinematic trajectories. Record marker/sensor location, filtering and derivation. No nine-taxon reference vector has been extracted. |
| Scale | A continuous value would preserve the measurement. Four category thresholds would require an additional justified rule; none are proposed here. |

Proposed per-stride quantity:

`relative_excursion_percent = 100 * (max(z) - min(z)) / shoulder_height`.

Normalizing by a length does not automatically remove allometry or establish
independence from C1/C3. Compatible gait, speed, landmarks and population scope
remain necessary. The definition is our proposed operational choice, not a
published universal standard.

For a simple sinusoidal displacement `z(t) = A sin(2*pi*f*t)`, acceleration
amplitude is `(2*pi*f)^2 * A`, where A is half the peak-to-peak displacement.
This mathematical example explains why displacement amplitude alone is not an
acceleration ranking. A walking reference also cannot be assumed to describe
resting or foraging movements without further support.

## Targeted primary-source audit

Search date: 2026-11-02. Searches covered the nine taxon names, trunk/withers
kinematics, vertical displacement, walking, gait and amplitude, followed by
primary references. This was a focused audit, not an exhaustive systematic review.

| ID | Located evidence and locator | Consequence for C4 |
|---|---|---|
| T1 — Basu et al. 2019 | Three zoo giraffes walking at 0.74–1.30 m/s; Methods, Results and Fig. 8. Withers-marker kinematics complement model-derived trunk accelerations; the speed-dependent angular range concerns the neck. | Relevant direct and model-based data, but no validated highest trunk-excursion class relative to our other taxa. |
| T2 — Dunbar et al. 2008 | Three domestic horses; Methods and Table 1. Reported vertical withers displacement: 7 ± 1 cm walking, 9 ± 1 cm trotting, 18 ± 5 cm cantering (means ± SD). | A single unconditional species score hides gait/speed dependence. These are neither the paper's horse cohort nor Przewalski measurements. |
| T3 — Griffin et al. 2004 | Abstract: canine kinematics and ground forces across walking speeds; forequarter/hindquarter coordination contributes to whole-body centre-of-mass motion. | Distinguish body landmarks from whole-body COM. No compatible numerical reference or interspecific high category was extracted from the accessed abstract. |
| T4 — Tijssen et al. 2021 | Methods and vertical-displacement Results: IMU-derived trajectories at specified body locations in 17 dairy cows, nine Swedish Red and eight Swedish Holstein, walking at self-selected pace. | Direct cattle evidence; breed and protocol differ from Japanese Black cattle. No common cross-species category threshold or numerical withers summary was extracted. |
| T5 — Loscher et al. 2016 | Methods and Table 1: 19 species, but spatial calibration only for eight domestic horses; other animals contribute phase relationships. The cattle sample is zebu, not Japanese Black cattle. | The multispecies sample cannot be treated as a calibrated amplitude comparison establishing our rank order. |
| T6 — Neveu et al. 2001 | Abstract and indexed Introduction: hedgehog treadmill cinefluorography and a dynamic model. | A relevant methodological lead; accessed text does not supply a comparable reference amplitude or justify low. Full measurement tables were not available. |
| T7 — Jenkins & Camazine 1977 | Abstract: walking raccoon/canid hip and pelvic kinematics. | Pelvic movement and femoral abduction are not the proposed vertical thorax measure. They do not establish moderate versus high here. |
| T8 — Boszczyk et al. 2001 | Abstract: comparative lumbar vertebral measurements, explicitly including Przewalski's horse. | Exact-taxon anatomical context, not in-vivo vertical excursion or a high score. |

T2 compares conditions differing in both gait and speed. No numerical source
summary has been selected as a new C4 input.

## Audit disposition for every taxon

The disposition concerns support under the proposed common construct, not proof
that an existing score is biologically false.

| Taxon | Current score | Disposition after this pass |
|---|---|---|
| Bison bonasus | moderate | No directly comparable reference located in this focused search; morphology/body mass alone does not establish the score. |
| Bos taurus | moderate | T4 gives relevant measured trajectories, with population and method limits; the category remains unsupported by a shared rule. |
| Canis lupus familiaris | high | T3/T5 provide locomotor evidence; no common amplitude threshold or breed/cohort reference supports this rank yet. |
| Equus caballus | high | Direct kinematic evidence exists (T2/T5), but does not validate a gait-independent high class. |
| Equus ferus przewalskii | high | T8 is structural anatomy; domestic-horse kinematics are an explicit proxy, not an exact-taxon measurement. |
| Erinaceus europaeus | low | T6 is a relevant lead; low is not established from the accessed material. |
| Giraffa camelopardalis | very_high | T1 does not establish this comparative highest category. No replacement score proposed. |
| Procyon lotor | moderate | T7's joint/pelvic findings do not validate the proposed vertical-excursion category. |
| Vulpes vulpes | high | No compatible exact-taxon vertical-thorax reference located. T7 uses the name Vulpes fulva and a different anatomical quantity; no silent taxonomic/measurement substitution. |

No absent reference is converted to zero, low or a default category. No source
normalization, digitization from inaccessible figures or individual-level
reanalysis is claimed.

## Concrete alternatives for the paper — awaiting decision

1. **Pragmatic recommendation:** omit C4 from the primary distance, then add the
   original C4 coding in an exploratory sensitivity comparison with all other
   finalized traits held fixed. This would compare six versus seven Core traits;
   the existing 11-trait Extended comparison remains a separate specification.
2. **Rebuild the measurement:** adopt a clearly delimited construct, assemble
   comparable reference measurements and revisit the scale. This requires more
   than an additional citation and may require raw-data reanalysis or new data.

Under equal weights with complete observations, omission changes each remaining
Core trait's share from 1/7 to 1/6. Neither alternative has been run, so no claim
about a changed H3 effect, significance or robustness can be made.

A satisfactory review must also distinguish external biological references from
properties estimated from the classification datasets. The latter would represent
a different analysis with its own independence and validation requirements.

## References and access

**T1.** Basu, C., Wilson, A. M. & Hutchinson, J. R. (2019).
The locomotor kinematics and ground reaction forces of walking giraffes.
*Journal of Experimental Biology*, 222, jeb159277.
[DOI](https://doi.org/10.1242/jeb.159277);
[published article PDF](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/10/Basu-et-al_2019_The-locomotor-kinematics-and-ground-reaction-forces-of-walking-giraffes.pdf).
PDF text: pp. 3, 5, 8–10; Fig. 8 caption. No new trajectory extraction.

**T2.** Dunbar, D. C., Macpherson, J. M., Simmons, R. W. & Zarcades, A. (2008).
Stabilization and mobility of the head, neck and trunk in horses during overground
locomotion: comparisons with humans and other primates.
*Journal of Experimental Biology*, 211, 3889–3907.
[DOI](https://doi.org/10.1242/jeb.020578);
[full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC2768006/).
Methods and Table 1 checked as HTML text.

**T3.** Griffin, T. M., Main, R. P. & Farley, C. T. (2004).
Biomechanics of quadrupedal walking: how do four-legged animals achieve inverted
pendulum-like movements? *Journal of Experimental Biology*, 207, 3545–3558.
[DOI](https://doi.org/10.1242/jeb.01177);
[PubMed abstract](https://pubmed.ncbi.nlm.nih.gov/15339951/).
Abstract checked; the attempted full-PDF retrieval failed.

**T4.** Tijssen, M. et al. (2021).
Kinematic gait characteristics of straight line walk in clinically sound dairy cows.
*PLOS ONE*, 16, e0253479.
[DOI/full text](https://doi.org/10.1371/journal.pone.0253479).
Methods, vertical-displacement Results and figure captions checked as HTML text.
Supplementary displacement curves were not digitized.

**T5.** Loscher, D. M., Meyer, F., Kracht, K. & Nyakatura, J. A. (2016).
Timing of head movements is consistent with energy minimization in walking ungulates.
*Proceedings of the Royal Society B*, 283, 20161908.
[DOI](https://doi.org/10.1098/rspb.2016.1908);
[PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5136594/);
[author-provided full-text copy](https://www.researchgate.net/publication/311774009_Timing_of_head_movements_is_consistent_with_energy_minimization_in_walking_ungulates).
Results pp. 2–3, Table 1 and Methods pp. 6–7 checked in the author-provided copy;
direct PMC/publisher access was blocked during this pass.

**T6.** Neveu, P., Villanova, J. & Gasc, J. P. (2001).
Modelisation of an unspecialised quadruped walking mammal.
*Comparative Biochemistry and Physiology Part A*, 131, 135–144.
[DOI](https://doi.org/10.1016/S1095-6433(01)00460-3);
[PubMed](https://pubmed.ncbi.nlm.nih.gov/11733172/).
Abstract and indexed publisher Introduction checked; full measurements not inspected.

**T7.** Jenkins, F. A., Jr & Camazine, S. M. (1977).
Hip structure and locomotion in ambulatory and cursorial carnivores.
*Journal of Zoology*, 181, 351–370.
[DOI/abstract](https://doi.org/10.1111/j.1469-7998.1977.tb03249.x).
Publisher Abstract checked. Its Procyon tolor spelling is retained as a source
error; the canid names are Canis familiaris and Vulpes fulva. Full measurements
were not inspected.

**T8.** Boszczyk, B. M., Boszczyk, A. A. & Putz, R. (2001).
Comparative and functional anatomy of the mammalian lumbar spine.
*The Anatomical Record*, 264, 157–168.
[DOI/abstract](https://doi.org/10.1002/ar.1156).
Publisher Abstract checked; no movement values inferred from vertebral dimensions.

## Implementation status

Documentation only. All trait inputs, model code and existing outputs are unchanged.
C1/D30 and C2/D32 remain confirmed; the accepted four-group C3 coding/D34 remains
implemented with its recorded evidence limitations. C4 remains under review.
No new H3 fit, classifier run, distance comparison or independent coding check was
performed. Previous H3 findings were already known; this audit is not preregistration.
