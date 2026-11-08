# Trait audit log

Audit trail of the trait review (D29–D39); status notes below are dated and partly superseded.
Current definitions and coding: [core_traits.md](../core_traits.md); decisions: [decisions.md](../../decisions.md).

**Current decision — D37, 2026-11-05:** the primary Core is final with five traits:
C1 body mass, C2 locomotor specialization, C3 body configuration, **relative neck
length** (ordinal, replaces C6) and **food acquisition and handling** (nominal,
replaces C7). Definitions, sources, thresholds and species assignments are in
[core_traits_definitions_sources_coding.docx](../core_traits.docx)
([Markdown rendering](../core_traits.md)); see
[D37](../../decisions.md#d37-2026-11-05--final-five-trait-core). C4 and C5 remain only as
exploratory add-backs (`core_with_c4`, `core_with_c5`); historical C6/C7 are not used in
a Core distance. Statements below on C5–C7 being queued describe the pre-D37 status.
H3 outputs were regenerated with the D37 Core on 2026-11-05 (commit `f37d483`); statements
below that H3 has not been recomputed describe the pre-D37 status.

**Decision — D39, 2026-11-06:** the Extended trait set is dropped from H3. E1–E4 were reviewed against the D37 Core (E2/E3 overlap with C2/C3; E1 already enters through the EltonTraits distances and has only an indirect link to 2 s windows; E4 separates only the hedgehog again, as C2 and C3 already do). No new Extended set is built; the Extended CSV is kept as the record of the thesis coding and is no longer read. Reasons and references: [D39](../../decisions.md#d39-2026-11-06--extended-trait-set-dropped-from-h3). Statements below on Extended describe the pre-D39 status.

**Earlier decision — D36, 2026-11-03:** Lucas approved excluding C4 from the primary H3 distance. The effective Core now contains six traits (C1–C3, C5–C7). The seven-column Core CSV preserves the historical C4 scores; `read_traits()` excludes C4 by default. `core_with_c4` adds back only C4 with all other current inputs held fixed and is explicitly exploratory. Extended remains a separate 11-trait sensitivity specification including C4. H3 fits and affected displays have not been regenerated; existing outputs are stale relative to D30/D34/D36. Earlier review statements below describe the pre-D36 status.


Started: 2026-11-01. Updated: 2026-11-02 (C4 targeted evidence audit and candidate measurement definition).
Status: **C1 confirmed (D30); C2 confirmed (D32); C3 coding adopted with evidence limits (D34); C4 excluded from primary Core (D36); C5–E4 queued**.
This document records the accepted C1/C2 specifications and the adopted C3 grouping,
with unresolved C3 evidence limits distinguished from the coding decision.
**H3 results have not yet been recomputed with the corrected mass inputs or C3 merger.**

Reviewed baseline: [d5c2ccc9bd6242a889f3608fd2d25dcd4fc05f64](https://github.com/ELBE223/paper-izw-cross-species-transfer/commit/d5c2ccc9bd6242a889f3608fd2d25dcd4fc05f64).
See [D29](../../decisions.md#d29-2026-11-01--trait-definitions-and-evidence-audit),
[D30](../../decisions.md#d30-2026-11-01--body-mass-definition-and-values-confirmed),
[D32](../../decisions.md#d32-2026-11-02--c2-three-group-definition-and-coding-confirmed),
[D33](../../decisions.md#d33-2026-11-02--c3-body-configuration-review-started),
[D34](../../decisions.md#d34-2026-11-02--c3-four-group-coding-adopted),
[D35](../../decisions.md#d35-2026-11-02--c4-trunk-motion-inventory-started), and the
earlier trait review (deleted, D40). C1/C2 are confirmed; C3 coding is adopted
without claiming complete anatomical validation. C4 scope is decided (D36); C5–E4 remain queued.

## Scope and sequence

The primary H3 distance uses the five Core traits of D37 (before: six traits, C4 excluded, D36). Extended retains
all eleven original columns as a separate sensitivity specification. D30 updated the dog and Przewalski's-horse
mass entries in both input matrices. D32 updated the hedgehog's C2 label to
`terrestrial_generalist`. D34 merges the raccoon into C3 `standard_quadruped`
in both matrices. D36 updates the reader and adds an exploratory C4 comparison; CSV values and results are unchanged.
H3 results were already known when this audit began.
Later revisions must be dated and distinguished from the original analysis; this
audit cannot retrospectively establish preregistration.

| ID | Existing column | Main question for the review | Status |
|---|---|---|---|
| C1 | `log_body_mass_g` | Which study-population mass or explicit reference fallback is defensible? | Confirmed and implemented (D30); H3 refit pending |
| C2 | `dominant_locomotor_mode` | Define locomotor specialization separately from an observed gait; justify each group. | Confirmed and implemented (D32): three groups, 7/1/1; pairwise nominal distances unchanged |
| C3 | `body_configuration_type` | Which observable anatomical criteria define the groups? | Four groups adopted and implemented (D34), 2/5/1/1; anatomical boundary and raccoon uncertainty remain documented |
| C4 | `expected_trunk_motion_amplitude` | Separate displacement from acceleration amplitude; specify behaviour and speed. | Excluded from primary Core (D36); historical scores retained for exploratory add-back; ranking remains unvalidated |
| C5 | `expected_directional_change_tendency` | Define spatial/time scale and dependence on behaviour and environment. | Exploratory add-back only (D37, `core_with_c5`); not reviewed individually |
| C6 | `expected_head_neck_contribution_to_acceleration_relevant_motion` | Separate anatomy, movement and contribution at the actual sensor location. | Replaced in Core by `relative_neck_length` (D37); historical scores kept in the CSV |
| C7 | `dominant_feeding_foraging_mode` | Separate species-typical foraging from feeding posture in the recorded data. | Replaced in Core by `food_acquisition_handling` (D37); historical scores kept in the CSV |
| C6 (D37) | `relative_neck_length` | Anatomical proxy r = C/(T + L + S); ordinal short/intermediate/long/very_long. | Adopted (D37); per-taxon neck-length review still to be added to the repository |
| C7 (D37) | `food_acquisition_handling` | Taxon-level acquisition and handling actions; three nominal groups. | Adopted (D37) |
| E1 | `activity_pattern` | Explain the indirect link between daily activity timing and short behaviour windows. | Dropped with Extended (D39): indirect link; activity already in the EltonTraits distances; definitions after Cox et al. (2021) |
| E2 | `vertical_use_motion_scope` | Distinguish habitat use from movement and assess overlap with C2/C7. | Dropped with Extended (D39): overlaps with C2 and C3 |
| E3 | `postural_compactness_body_profile_reduction` | Define observable posture changes and assess overlap with C3/E4. | Dropped with Extended (D39): same species groups as C2 |
| E4 | `defensive_posture_specialization` | Establish whether the behaviour is represented in the study and signal. | Dropped with Extended (D39): present in the data (23 rolled-up hedgehog windows, class Other), but a hedgehog-only contrast already given by C2 and C3 |

## Required record for each trait

1. **Construct and scope:** define what is measured or inferred, its level (taxon,
   dataset or individual), units, states and exclusions.
2. **Mechanism:** state why it could affect accelerometer signals or transfer, and
   what the supporting study actually demonstrates. A plausible mechanism does not
   validate an ordinal score or establish an effect on transfer performance.
3. **Coding rule:** write a reproducible rule for every category or numerical
   extraction. Define how ambiguity, taxonomic synonyms, proxies and missing data
   are handled before comparing new H3 fits.
4. **Evidence per taxon:** record the assigned value, exact source location, relevant
   population and whether the assignment is reported, calculated or inferred.
   All nine assignments need an audit trail; they need not use nine different papers.
5. **Independent check:** verify extraction and taxonomy; for judgement-based traits,
   obtain an independent coding using the same rules, preferably without transfer
   results. Record who coded what and whether results were known. Agreement does not
   establish biological validity. With nine taxa, retain the actual disagreements,
   not just an agreement coefficient. Continuous source extraction needs numerical
   checks rather than a categorical agreement statistic.
6. **Robustness:** distinguish checks already run from proposals. Consider plausible
   alternative codings and omission of the trait; never select definitions, sources
   or weights because they improve significance.
7. **Disposition:** date the decision to retain, revise, move to an exploratory
   analysis or omit the trait, with an explicit reason and preserved original values.

The desired endpoint is an auditable coding rule and a traceable value for every
taxon, with limitations proportional to the evidence. More citations cannot compensate
for an undefined construct. Taxon reference traits and measured study-animal traits
are different variables and must not be silently mixed.

## C1 — Body mass

### Accepted definition and values — closed on 2026-11-01 (D30)

Lucas approved the final dog and Przewalski's-horse choices and closed the body-mass
review. Body mass remains in Core and in the corresponding Extended column.
This decision supersedes the provisional alternatives and open coding questions
recorded in the historical audit below.

**Operational definition:** a curated positive body-mass reference for each study
taxon, expressed in grams and transformed as `ln(mass_g)`. Each row identifies
whether it is a measured cohort summary, an aggregate of source-study means,
or an external literature/database reference. The vector is not described as
uniformly measured study-animal masses or universal adult species means.

| Study taxon | Accepted reference mass (kg) | Matrix `log_body_mass_g` | Source basis |
|---|---:|---:|---|
| Bison bonasus | 500 | 13.122 | EltonTraits, exact-name reference (R3) |
| Bos taurus | 900 | 13.710 | EltonTraits, exact-name reference (R3) |
| Canis lupus familiaris | 26.746428571 | 10.194 | Two source-study means, equal weights (R7–R8) |
| Equus caballus | 250 | 12.429 | EltonTraits, exact-name reference (R3) |
| Equus ferus przewalskii | 300 | 12.612 | External literature reference (R10) |
| Erinaceus europaeus | 1.032 | 6.939 | Reported cohort mean, six animals (R5) |
| Giraffa camelopardalis | 899.9948 | 13.710 | EltonTraits, exact-name reference (R3) |
| Procyon lotor | 5.52497 | 8.617 | EltonTraits, exact-name reference (R3) |
| Vulpes vulpes | 5.47617 | 8.608 | EltonTraits, exact-name reference (R3) |

The six exact-name EltonTraits matches retain their existing numerical coding;
the checked database entries are the explicit reference basis for this version.
This does not reconstruct the historical source-selection process. The hedgehog
retains the reported 1032 g cohort mean. The primary class report lists all six
hedgehogs with usable main-class windows; D12's individual eligibility filter
applies to within-test folds, not to primary pairwise evaluation.

**Dog aggregation:** `((321.9 / 14) + (610 / 20)) / 2 = 26.74642857142857 kg`,
reported as approximately **26.75 kg**. Calculate the log from the unrounded
study-mean aggregate, then round the log to three decimals (10.194).
Giving each source study equal weight is the adopted convention, consistent
with H3's equal-weight dataset-pair aggregation; it is not a recovered
individual-weighted mean. Dog_dataset_1 includes all 14 dogs in primary transfer.
The eight Dog_dataset_2 recordings still have ambiguous animal identities.
Groth's 30.5 kg therefore remains a source-cohort approximation.

**Przewalski's horse:** adopt **300 kg** as the external reference in R10,
giving `ln(300000) = 12.6115377536`, stored as 12.612. Sänger's subjects were
three five-year-old geldings. No sex-mixture calculation or measured mean of
those three animals is claimed; the reference entry's horse-specific age,
sex, season and sample size are not established.

**Implementation and results:** the Core and Extended input CSVs now contain
10.194 for the dog and 12.612 for the Przewalski's horse. All other cells are
retained. The pre-correction input version is
[2a6a7afc](https://github.com/ELBE223/paper-izw-cross-species-transfer/commit/2a6a7afc4da11812f9bcec11848b8db6e7538085).
Existing H3 distances, fits and associated figures/tables have **not** been
recomputed and still represent the earlier inputs. They must be regenerated
from the finalized traits before reporting updated H3 findings. Classifier
predictions and H1/H2 results are unaffected by changing only trait masses.

C1 is closed for definition, reference selection and coding. Uncertain biological
representativeness, the Dog_dataset_2 identity ambiguity, source-database
limitations and the already-known H3 results remain disclosed limitations.
Closure is not a claim that sensitivity checks have passed or an independent
review has been completed.

### Historical audit record — before the D30 decision

The following source checks and provisional discussions are retained for
traceability. Statements that no values were adopted describe the earlier
audit stages; the accepted specification above is authoritative.

### Thesis rationale and working definition

**Correction after consulting the supplied thesis (2026-11-01).** Beseler (2026,
printed p. 14 / PDF p. 23; R4) explicitly describes masses from dataset metadata
and source documentation, motivated by the study animals/populations. The first
draft's preference for a uniform adult taxon reference must not be presented as
the original method or as an agreed replacement.

Working construct: **body mass used to characterize the animals or population
represented by a study taxon, expressed in grams and natural-log transformed**.
The current H3 matrix has one value per taxon. Each value must be identified as
a measured cohort summary, a general reference or an unresolved estimate.
Calling all existing values either species averages or measured study means
would be unsupported. A source/fallback and aggregation policy remains open.

| Item | Current understanding / draft rule |
|---|---|
| Analysis column | `log_body_mass_g` |
| Construct | Body mass relevant to the represented animals/population; record the source scope. |
| Analysis level | One value per taxon in the current H3 matrix, even where multiple datasets represent that taxon. |
| Transformation | `ln(mass_g)` for a positive mass; retain the source value and calculation. |
| Type | Continuous, without arbitrary bins. |
| Source scope | Distinguish measured cohort summaries, taxon references, upper bounds and unresolved values. |
| Population | Record individuals, ages, sexes and dataset coverage; do not call a mixed-age cohort an adult mean. |
| Exclusions | An upper bound does not establish a cohort mean or a typical reference mass. |
| Precision | Three log decimals in the current matrix; exponentiation only reconstructs approximate raw inputs. |
| Status | Audit the thesis rationale and value extraction before adopting a new source policy. |
### Mechanistic rationale and its limits

Heglund and Taylor (1988; R1) compared locomotion in quadrupeds of different sizes
and found systematic relationships among body size, gait and stride frequency.
This supports body mass as a biologically motivated descriptor of locomotor
differences that can affect signal periodicity. It does not demonstrate that body
mass alone predicts classifier transfer, establish ordinal acceleration amplitudes
for these nine taxa, or cover all resting and feeding movements. Body mass is a
proxy for aspects of size and mechanics, not a direct measurement of those signals.

Using a logarithm expresses proportional size differences on an additive scale.
The existing H3 workflow then combines the continuous trait with categorical traits
in Gower distance. The rationale for body mass does not by itself justify its weight
relative to the other traits.

### Source-policy questions at the start of the audit

- Start with the thesis's study-population rationale (R4). Original measurements
  in a source thesis can support a cohort mass; a general species description in
  the same document is a different kind of evidence.
- Record source, exact page/table, raw mass, estimator, population and transformation
  for every taxon. A numerical database match does not establish historical provenance.
- If a taxon has multiple datasets, specify which individuals and datasets a shared
  mass represents and how aggregation is weighted. A complete source-cohort mean
  is not automatically the mean of the subset retained in this paper.
- If study masses are missing, document a consistent reference fallback and its
  limitations. A uniform taxon-reference analysis could be a sensitivity alternative;
  this draft adopts neither a new fallback policy nor replacement values.
- Check source definitions. PanTHERIA's adult-body-mass field includes adult or
  age-unspecified records, excludes pregnant females, and uses adjusted log-scale
  values with a median-based summary (R2); it is not simply an arithmetic mean.
- EltonTraits provides mass and source code (R3). The compared rows use `Ref_117`;
  the underlying reference and population definition remain to be traced.
- Resolve taxonomy explicitly. Wolf and domestic-horse proxies are not verified
  domestic-dog and Przewalski's-horse measurements. Their comparison below does
  not approve primary use.
- Define the treatment of cohorts, reference fallbacks, missing values and
  aggregation before new H3 fits; do not choose sources using significance.
### Audit of the pre-correction baseline values

The following values were checked against the original published data files (R2,
R3), not inferred solely from a secondary package. Kilograms are shown for readability;
the audit CSV retains the original source masses in grams. Baseline masses are
**approximately reconstructed from the rounded log values**, not recovered raw inputs.

| Study taxon | Baseline implied kg (approx.) | EltonTraits kg | PanTHERIA kg |
|---|---:|---:|---:|
| Bison bonasus | 499.818 | 500.000 | 675.877 |
| Bos taurus | 899.865 | 900.000 | 618.642 |
| Canis lupus familiaris | 28.001 | 32.183 (wolf proxy) | 31.757 (wolf proxy) |
| Equus caballus | 249.946 | 250.000 | 403.599 |
| Equus ferus przewalskii | 350.109 | 250.000 (domestic-horse proxy) | not identified |
| Erinaceus europaeus | 1.032 | 0.771 | 0.778 |
| Giraffa camelopardalis | 899.865 | 899.995 | 964.655 |
| Procyon lotor | 5.525 | 5.525 | 6.374 |
| Vulpes vulpes | 5.475 | 5.476 | 4.820 |

[Machine-readable source audit](body_mass_audit.csv). Proxy rows are explicitly
flagged. No exact Przewalski's-horse entry was identified under the study name or
`Equus ferus` in these files; this is not a claim about every possible taxonomic
synonym in all trait databases.

Six exact-name EltonTraits values reproduce the baseline log masses when rounded
to three decimals: bison, cattle, domestic horse, giraffe, raccoon and fox.
This is a verified numerical correspondence, **not proof of the historical source
used to construct the Core matrix**. The earlier review's count of seven should
therefore not be carried into the paper. The follow-up below resolves the hedgehog value, identifies a matching horse
passage whose meaning is an upper bound, and leaves the dog's 28 kg derivation
unresolved. The hedgehog's difference from the database values (~0.77–0.78 kg)
is consistent with using a measured study cohort rather than a species reference.

Database differences, especially for domestic animals, need explanation; they do
not by themselves show that a database value is wrong or that it represents the
recorded population. Resolve the target definition before choosing among them.
The older review's tentative source substitutions and claimed small distance change
do not establish the new source policy or remove the need for this provenance check.

### Follow-up: supplied theses (2026-11-01)

| Taxon | Located evidence | What it establishes | Open item |
|---|---|---|---|
| Hedgehog | Cibis (2017), Table 4, printed p. 19 / PDF p. 29 (R5): 1020, 925, 1125, 1290, 955 and 875 g; reported mean 1032 g. | Arithmetic mean 1031.667 g, reported rounded to 1032 g; `ln(1032) = 6.939254`, matching Core at three decimals. This is a measured source-cohort mean. | Document whether the full cohort or the paper's retained individuals define the target population; it is not a universal species mean. |
| Przewalski's horse | Sänger (2017), section 1.3.2, printed p. 5 / PDF p. 15 (R6): mass up to 350 kg. Section 2.2, printed pp. 9–10 / PDF pp. 19–20: Jedi, Kalmoek and Joda, three five-year-old geldings. | `ln(350000) = 12.765688`, matching Core at three decimals. The mass statement is a general upper bound. No individual body masses or cohort mean were located in the supplied thesis. | Actual study masses require additional records; otherwise select and label an external reference estimate, with uncertainty. Do not present 350 kg as a measured cohort mean. |
| Domestic dog | Szangolies (2017), Table 2, printed p. 5 / PDF p. 12 (R8): 14 masses; Groth (2020), Table 2, printed p. 7 / PDF p. 18 (R7): 20 masses. | The respective full-cohort means are 22.992857 and 30.5 kg. In Szangolies, 28 kg is Lulu's individual mass and a subgroup mean; neither is the full-cohort mean. | The original choice of 28 kg remains unverified. Define a justified source/aggregation policy covering both dog datasets. |

Groth Table 2 masses in kg, in table order: 21, 31, 32, 31, 36, 28, 40, 25,
28, 30, 40, 26, 30, 34, 31, 30, 29, 28, 30, 30. This extraction documents a
comparison, not a replacement by 30.5 kg. The table includes a 0.75-year-old
animal, so an all-adult definition cannot be assumed for the complete cohort.

These findings replace the initial blanket statement that all three values lack
located documentation. They do not approve a new trait definition or establish
that the sources of all nine current masses have been traced.

### Resolution of the two source questions after the additional uploads

Checked on 2026-11-01 using full-document text searches and visual checks of
Szangolies PDF pp. 12 and 36, and Sänger PDF pp. 15 and 20. The supplied Sänger
copy has 102 PDF pages; the Szangolies thesis has 73. **The meaning of the located
values is resolved; their original adoption into Core is not independently
reconstructed, and a representative horse-cohort mass is not available in these
documents.** No replacement values have been adopted.

#### Dog: individual measurements, not a verified 28 kg cohort mean

Szangolies Table 2 lists 14 dogs, with masses in kg:

`5.5, 6.7, 10.9, 8.0, 14.1, 30.0, 28.0, 29.6, 25.0, 40.8, 24.0, 36.0, 30.0, 33.3`.

The sum is 321.9 kg. The unweighted mean is **321.9 / 14 = 22.992857 kg**
(approximately 23.0 kg); the median is 26.5 kg. Its log mass in grams is
`ln(22992.857143) = 10.042939`, unlike the existing Core value 10.240.
All 14 named dogs occur in the current harmonization/window reports, with
`Abbey` / `Abby`, `Fibonacci` / `Fibo`, and `Big Foot` / `BigFoot` as spelling
variants. This does not mean all 14 are eligible for every model/test mode.

[Extracted individual masses and source locations](body_mass_dog1_measurements.csv)
make the calculation reproducible. They are documentation, not new model inputs.

Two occurrences of 28 kg explain why finding that number alone is insufficient:

- Table 2: Lulu weighs 28.0 kg. That is an individual observation.
- Table 11, printed p. 29 / PDF p. 36, gives a cluster mass of 28.00 kg.
  However, the names attached to its two middle numerical rows do not agree
  with Table 2. Recalculation gives `(30 + 24 + 30) / 3 = 28.00 kg` for
  Duke, Emi and Helena, and `(25 + 40.8 + 28 + 29.6) / 4 = 30.85 kg` for
  Abbey, Dexter, Lulu and Zaini. Table 11 attaches those group names to the
  opposite numerical rows. This was checked on the rendered PDF, so it is
  not merely a text-extraction alignment error. Use the individual measurements
  in Table 2 rather than copying that inconsistent group-summary table.

These are possible places a 28 kg number could have been encountered; there is
**no evidence that either was the historical source of the Core value**.

Groth's 20 listed observations average 30.5 kg (R7, above). Combining the two
complete source-cohort tables without weights gives 27.408824 kg over 34
study observations; equal weighting of their two means gives 26.746429 kg.
Neither calculation establishes an exact 28 kg mean. These are arithmetic
comparisons only: 34 observations are not necessarily 34 distinct animals,
and no pooling or rounding rule has been adopted.

The current Dog_dataset_2 harmonization report additionally records 20 named
files as eight distinct recordings, with ambiguous combined identities such
as `Ami+Winston`. Consequently, the full Groth cohort mean must not be called
the measured mean of eight identified animals in the processed data. This is
a limitation already visible in the repository, not resolved by the weight table.

Provenance checks: the original thesis repository Core CSV has the same blob
as the paper's unchanged Core CSV. Its listed introduction commit
[5287a574](https://github.com/ELBE223/thesis-izw-cross-species-transfer/commit/5287a57442ba290ccf75cc2d0236e715e3fc06b3)
is an upload; the inspected `R/H3/01_H3_mixed_effects.R` and
`R/H3/02_H3_distance_proxy_mixed_modelsl.R` read the trait mass rather than
derive 28 kg from study-animal weights. They therefore do not recover the
missing historical aggregation rule.

#### Przewalski's horse: upper-bound statement and no located measured masses

Section 1.3.2 gives 350 kg as an upper bound in a species description. The
individuals in section 2.2 are **Jedi, Kalmoek and Joda**, all **five-year-old
geldings**, selected from four adult geldings in the acclimatization enclosure.
The inspected methods pages describe identity and appearance, without weights.
Full-document searches for weight/mass, weighing, scales, kg and related
measurement terms located no individual masses or cohort mean for these horses.
This is a finding about the supplied thesis, not proof that weighing records
never existed elsewhere.

Thus, the supplied source does not support the phrase 'mean body mass of the
three study horses: 350 kg'. Equally, the audit does not establish that 350 kg
is biologically impossible; the problem is the estimate's interpretation and
population basis.

To obtain a study-specific value, use actual weighing records for these three
animals and the relevant dates if available. Otherwise, choose an explicitly
external reference with documented population, sex/age and season, and assess
a justified range as sensitivity. No midpoint of a generic range or new
single value is adopted here.

Literature context: Scheibe and Streich (2003; R9) recorded female Przewalski
horses over six years and reported seasonal body-weight cycles. This supports
recording season and population when choosing a fallback. It does not supply
the weights of Sänger's male geldings or validate 350 kg as their mean.

#### Consequence for the paper

The defensible present wording is that the mass vector contains curated values
with heterogeneous provenance; the hedgehog cohort mean is traced, while
the dog aggregation and representative horse estimate need an explicit decision.
Keep this audit separate from evidence that the chosen mass vector is robust:
no H3 fits, distance comparisons or classifier reruns were performed here.
### Follow-up: actual analysis membership and horse reference search (2026-11-01)

The [dog inclusion audit](body_mass_dog_inclusion.md) checks the committed
primary results for all six classifiers and all five seeds. Pairwise transfer,
which supplies H3, uses all **14 Dog_dataset_1 dogs** and all **eight
Dog_dataset_2 recording units**. Duke is excluded only as a held-out within-test
dog; his Locomotion and Resting windows remain in pairwise training/testing.
The relevant measured Dog_dataset_1 mean is therefore **22.992857 kg**.

The eight Dog_dataset_2 units retain combined names because duplicate files
cannot be attributed uniquely to individual animals. The 30.5 kg mean from
Groth remains a source-cohort reference. Consequently **26.746429 kg**, the
equal-weight mean of the two study means, is only a proposed reference
approximation, not a recovered mean of identified analysis animals.

A numerical horse fallback has now been located: **300,000 g = 300 kg** in
Gerstner and Gerstein (2008; R10), Table 1, printed p. 1022, under
`Equus przewalskii`. It is proposed as an external study reference for
`Equus ferus przewalskii`, with `ln(300000) = 12.611538` (12.612 at
three decimals). Selection is based on an explicit taxon-specific entry, not
on reproducing the old mass or obtaining a preferred H3 result.

**This is not a measured mean for Jedi, Kalmoek and Joda or an established
population-wide adult mean.** The inspected horse entry does not specify
sex, age, season or sample size. These remain unknown; do not invent matching
geldings or a representative cohort. The article's methods combine study-animal
masses and literature estimates; the horse mass is not marked as a literature
estimate. That convention alone does not establish its precision.

Kuntz et al. (2006; R11) provide repeated individual weights in Table 3 and
show seasonal mass loss. They support retaining uncertainty, not a new pooled
mean calculated across unequal repeated measurements.

**Current recommendation for discussion:** use 300 kg as a clearly flagged
literature fallback if study-animal weights remain unavailable, and assess
sensitivity to alternative justified values before interpreting H3. The original
350 kg remains in the unchanged baseline. No candidate matrix has been adopted
and no distances or models have been recalculated.

### Methodological checks

Already present in the repository: body-mass-only and EltonTraits-based alternative
distances, Core/Extended comparisons, trait-balancing analysis, and leave-one-species-out
fits. These provide context but do not resolve the provenance of an individual value.

Proposals, **not run as part of this documentation step**:

- Verify every mass, unit, taxon match and logarithm against the selected source.
- If two source policies remain scientifically plausible, define complete alternative
  mass vectors before refitting, keep the other traits fixed, and compare the distance
  and H3 estimate/interval. First resolve missing taxa and proxy exceptions; do not
  call an incomplete or mixed vector a fully independent database replication.
- Omit body mass from Core as one part of a systematic leave-one-trait-out check.
  Report changes in the effect and uncertainty, rather than selecting a specification
  by its p-value.

### Final disposition and remaining analysis work

**C1 definition, source choices and coding are closed by D30.** Dog and horse
fallback/aggregation choices have been accepted with their documented limitations.

- [x] Retain body mass in Core and Extended, in grams with the natural-log transform.
- [x] Record the nine selected reference values and their source categories.
- [x] Verify the dog inclusion and replace the undocumented 28 kg convention.
- [x] Adopt the 300 kg horse literature fallback without claiming a measured cohort mean.
- [x] Retain the reported six-animal hedgehog cohort mean and the six exact-name database references.
- [x] Preserve baseline evidence, date the decision, and update both input matrices.
- [ ] Recompute trait distances, H3 fits and affected displays after the trait review.
- [ ] Run and report the agreed robustness checks; their outcome is not established here.

The outstanding items concern analysis execution, not a request to reopen C1.
No independent second-reviewer audit is claimed.

## C2 — Locomotor specialization

Started 2026-11-01 (D31); **definition and three-group coding confirmed by Lucas
on 2026-11-02 (D32)**. Display name: **Fortbewegungsspezialisierung / locomotor
specialization**. The input column remains `dominant_locomotor_mode`.

Construct: a coarse, nominal, taxon-level classification of locomotor anatomy
and habitual substrate use. These are operational definitions for this analysis,
not a universal scheme, measured gait frequencies, or a speed/endurance ranking.

| Final category | Short definition | Study taxa | n |
|---|---|---|---:|
| `cursorial` (broad) | Running-adapted terrestrial quadrupeds, including heavy-bodied and very long-legged running forms. | Bison, cattle, dog, domestic horse, Przewalski's horse, giraffe, red fox | 7 |
| `scansorial` | Ground locomotion and habitual climbing are characteristic components of locomotion. | Raccoon | 1 |
| `terrestrial_generalist` | Positive evidence for generalized ground locomotion without a predominant running, climbing or digging specialization under this scheme. | Hedgehog | 1 |

The finer mediportal heavy-bovine and stilt giraffe forms in L14 are deliberately
pooled into broad `cursorial`; the earlier narrow fast/sustained-running criterion
is superseded. Generalist is not a missing-evidence fallback. Sources, exact
locations, the nine final taxon assignments and all bibliography entries are in the
[final C2 review](locomotor_specialization_review.md#final-species-mapping-and-evidence).

Direct categorical support is available for horse, fox and raccoon (L1), and cattle
and giraffe (L8, with L9 anatomical context). Bison (L14–L15), domestic dog (L10–L11)
and Przewalski's horse (L12–L13) retain explicit inference or source-scope qualifications.
The hedgehog generalist interpretation uses positive locomotor evidence in L5;
White's semifossorial foraging classification (L6) is retained as counterevidence
to universal terminology, not dismissed. Supplied thesis breed descriptions
(L16–L17) establish that the dog code is a broad taxon reference across heterogeneous
breeds. It does not classify each individual dog's degree of specialization.

Only the hedgehog cell changes in each Core/Extended matrix. The R reader already
treats C2 as a nominal factor. All 36 pairwise category indicators were checked:
21 matches and 15 mismatches before and after. Thus D32 alone leaves equal-weight
Gower distances unchanged when other inputs are fixed. It is not a completed
H3 rerun or an optimized-weight sensitivity check; existing H3 outputs still await
D30's mass-input update.

The 7/1/1 split limits resolution and generalization beyond the singleton taxa.
Independent biological recoding and omission-of-C2 robustness checks have not
been completed. Coding is closed; these limitations remain part of interpretation.

## C3 — Body configuration

Review started 2026-11-02 (D33). **Lucas accepted the four-group coding on
2026-11-02 (D34)**, including the dog's standard assignment and the raccoon's
merger into that group. The biological evidence audit is not fully closed.

Construct: taxon-reference body proportions in ordinary standing posture.
The [C3 review](body_configuration_review.md#accepted-coarse-coding--d34)
contains the mapping, working interpretations, sources B1–B12 and historical audit.

| Stored category | Display interpretation | Taxa | n |
|---|---|---|---:|
| `robust_quadruped` | Rumpfbetont / trunk-dominated build | Bison; cattle | 2 |
| `standard_quadruped` | Allgemeiner Vierfüßerbau / generalized quadrupedal build | Dog; both horse taxa; raccoon; fox | 5 |
| `tall_long_necked_quadruped` | Hochbeinig/langhalsig | Giraffe | 1 |
| `compact_low_profile_body` | Kompakt/bodennah in ordinary stance | Hedgehog | 1 |

The merger is a coarse author-coded simplification, not evidence that all five
standard taxa have the same proportions. The raccoon is an uncertain assignment;
the dog code does not resolve breed variation. Direct bison/cattle dimensions help
characterize trunk build, but a common reproducible boundary against the standard
group remains to be developed. Giraffe and hedgehog also need the same explicit
rubric. No numerical cutoff, independent anatomical coding or full validation is claimed.

Implementation: only the raccoon C3 cell changes in each matrix from
`generalist_quadruped` to `standard_quadruped`. C1/C2 and all other cells stay
unchanged. The nominal pair check changes four of 36 indicators: 11 matches and
25 mismatches, previously 7 and 29. No code change is needed by the current R reader.

The agreed sensitivity comparison restores the raccoon's historical separate state
while holding all other finalized traits fixed; it has not been run. C3 remains
in Core and Extended. Omitting it is still only an additional proposed robustness
check. H3 refits and affected distances/displays remain pending, including D30's
mass corrections. The post hoc timing is explicitly recorded.

## C4 — Expected trunk motion amplitude

Review started 2026-11-02 (D35), after adopting the C3 coding.
The [C4 evidence review](trunk_motion_review.md) records the current four ordered
levels in both matrices and the targeted audit of eight primary sources:

| Existing level | Taxa | n |
|---|---|---:|
| `low` | Hedgehog | 1 |
| `moderate` | Bison; cattle; raccoon | 3 |
| `high` | Dog; both horse taxa; fox | 4 |
| `very_high` | Giraffe | 1 |

These are existing inferred scores, not measured movement amplitudes.
The R reader orders them `low < moderate < high < very_high`.
Before accepting the coding, define whether amplitude means translational
displacement, angular excursion or acceleration at a specified body location;
state units/reference normalization, behaviour, gait and speed conditions.
No new category threshold, taxon recoding or C4 model comparison has been adopted.

The follow-up proposes a candidate metric: peak-to-peak vertical movement of a
homologous cranial-thorax landmark during steady level walking, normalized by
standing shoulder height and compared under a defined dimensionless-speed range.
The reference population, homologous landmark and comparison interval would still
need specification. This is a proposed measurement, not an adopted replacement.

The eight-source audit distinguishes direct kinematics, model-based acceleration,
phase relationships and anatomical proxies. It does not establish the current
nine-taxon ordinal ranking, including the giraffe's highest category.
Recommended for discussion: omit C4 from the primary distance and retain its
existing scores in an exploratory add-back comparison, unless a comparable
measurement basis can be assembled. This scope change is now implemented under D36: six effective primary traits,
with the historical C4 scores retained for an exploratory add-back. The replacement
measurement remains unadopted.

## Final Core — D37 (2026-11-05)

Lucas declared [core_traits_definitions_sources_coding.docx](../core_traits.docx)
final. It is the authoritative specification of the primary Core; this section only
indexes it. Codes in `species_traits_core_h3_final.csv`:

| Trait | Column | Type | Taxa per state |
|---|---|---|---|
| Body mass | `log_body_mass_g` | continuous, ln(g) | values as D30 |
| Locomotor specialization | `dominant_locomotor_mode` | nominal | as D32 (7/1/1) |
| Body configuration | `body_configuration_type` | nominal | as D34 (2/5/1/1) |
| Relative neck length | `relative_neck_length` | ordinal short < intermediate < long < very_long | hedgehog, raccoon / bison, cattle, dog, fox / both horses / giraffe (2/4/2/1) |
| Food acquisition and handling | `food_acquisition_handling` | nominal | vegetation_cropping: bison, cattle, both horses, giraffe; oral_item_acquisition: dog, hedgehog, fox; manual_food_handling: raccoon (5/3/1) |

Expected link to the acceleration signal: one paragraph per trait in the document's
section of that name (added 2026-11-05; hypothesised mechanisms, not demonstrated effects).
Raccoon source theses: [trait_raccoon_theses_review.md](raccoon_theses_review.md).

Remaining evidence gaps (see D37): the per-taxon neck-length measurements and r values
are not yet in the repository; the hedgehog's `short` is expert judgement with
`intermediate` as sensitivity alternative; food-acquisition evidence is cited for raccoon
and bison only. Sensitivity analyses of these assignments have not been run.

## Implementation note for the later Extended review

Superseded by D39 (2026-11-06): the Extended distance and the cathemeral recoding were removed
from `code/stats_h3.R`. The note below describes the code before D39.

The Extended CSV and effective model inputs are not identical for activity pattern.
Under D28, `code/stats_h3.R` changes bison and both horses from `diurnal` to
`cathemeral` while reading the traits. E1 must document that effective coding and
its sources. This audit does not change either the CSV or that transformation.

## Verified references for C1

**R1 — Mechanism.** Heglund, N. C. & Taylor, C. R. (1988). Speed, stride frequency
and energy cost per stride: how do they change with body size and gait?
*Journal of Experimental Biology*, 138, 301–318.
[DOI: 10.1242/jeb.138.1.301](https://doi.org/10.1242/jeb.138.1.301).
[PubMed abstract](https://pubmed.ncbi.nlm.nih.gov/3193059/). The mechanistic statement
above is supported by the abstract; this audit does not claim a reanalysis of the
study's full measurements.

**R2 — Alternative source and definitions.** Jones, K. E., Bielby, J., Cardillo, M.,
et al. (2009). PanTHERIA: a species-level database of life history, ecology, and
geography of extant and recently extinct mammals. *Ecology*, 90, 2648.
[DOI: 10.1890/08-1494.1](https://doi.org/10.1890/08-1494.1).
[Original WR05 data file](https://esapubs.org/archive/ecol/E090/184/PanTHERIA_1-0_WR05_Aug2008.txt);
[metadata](https://esapubs.org/archive/ecol/E090/184/metadata.htm),
Table 1 (adult body mass) and Table 2 (body mass processing).
Lookup fields: `MSW05_Binomial` and `5-1_AdultBodyMass_g`; missing-value sentinels
must not be treated as measurements.

**R3 — Source comparison.** Wilman, H., Belmaker, J., Simpson, J., de la Rosa, C.,
Rivadeneira, M. M. & Jetz, W. (2014). EltonTraits 1.0: Species-level foraging
attributes of the world's birds and mammals. *Ecology*, 95, 2027.
[DOI: 10.1890/13-1917.1](https://doi.org/10.1890/13-1917.1).
[Original mammal data file](https://esapubs.org/archive/ecol/E095/178/MamFuncDat.txt);
[archived collection](https://doi.org/10.6084/m9.figshare.c.3306933).
Lookup fields: `Scientific`, `MSW3_ID`, `BodyMass-Value`, `BodyMass-Source`.
All nine comparison rows in the audit (including repeated horse and wolf proxies)
have source code `Ref_117`; that code is retained rather than replaced by an
unverified underlying citation.

Source check date: 2026-11-01. References for C2–E4 will be added when those entries
are reviewed; listing a trait above does not certify its current coding.

### Supplied thesis sources checked in the follow-up

**R4.** Beseler, L. (2026). *Cross-Species Transfer in Terrestrial Mammal Behavior
Classification Using Tri-axial Accelerometer Data*. Master's thesis, Justus Liebig
University Giessen. Supplied file: `Master’s_Thesis(20261024-112251).pdf`.
Printed p. 14 / PDF p. 23: body-mass rationale; Table S1, printed p. 48 / PDF
p. 57: Szangolies and Groth as source studies for the dog datasets.

**R5.** Cibis, J. (2017). *Automatic behaviour classification from three-axial
acceleration data for the European hedgehog (Erinaceus europaeus L., 1758)*.
Master's thesis, prepared at Leibniz-IZW, Berlin. Supplied file: `Igel.pdf`.
Table 4, printed p. 19 / PDF p. 29: weights and sexes of six study animals.

**R6.** Sänger, C. (2017). *Analyse hochaufgelöster 3D-Beschleunigungsdaten zur
automatischen Differenzierung von Verhaltensweisen bei Wisenten (Bison bonasus)
und Przewalskipferden (Equus ferus przewalskii)*. Master's thesis, University of
Potsdam / Leibniz-IZW. Supplied file: `Pferd_1.pdf`. Section 1.3.2, printed p. 5 /
PDF p. 15. The surrounding species description cites Heptner & Naumov (1966)
and Mohr (1959); these underlying works have not been verified here.
The 350 kg statement is not a measured study-cohort mean.

**R7.** Groth, R. (2020). *Analysis of three-dimensional acceleration data from
similar dogs with automatic behaviour classification by using machine learning
algorithms*. Master's thesis, University of Potsdam / Leibniz-IZW.
Supplied file: `Msc Rieka Groth 2020.pdf`. Table 2, printed p. 7 / PDF p. 18;
measurement and rounding description on printed p. 8 / PDF p. 19.
The later upload of Szangolies (2017) was checked directly; see R8 and the
resolution section above.

**R8.** Szangolies, L. (2017). *Analyse hochauflösender 3D-Beschleunigungsdaten
zur automatischen Differenzierung von Verhaltensweisen bei Tieren*.
Bachelor's thesis, University of Greifswald / Leibniz-IZW; submitted 31 October
2017. Supplied file: `Bsc_Leonna Szangolies.pdf`. Table 2, printed p. 5 / PDF
p. 12: individual weights and measurement method. Table 11, printed p. 29 /
PDF p. 36: cluster summaries, with the arithmetic/name inconsistency described
above. Both tables checked visually.

**R6 additional check.** Supplied copy `Masterarbeit Claudia Sänger(3).pdf`,
102 pages. Section 2.2, printed pp. 9–10 / PDF pp. 19–20, establishes the
study animals' identities, age and sex. Source p. 5 remains an upper-bound
statement. No study-animal weighing table or cohort mean was located.

**R9 — Seasonality context, not a replacement mass source.** Scheibe, K. M. &
Streich, W. J. (2003). Annual Rhythm of Body Weight in Przewalski Horses
(*Equus ferus przewalskii*). *Biological Rhythm Research*, 34(4), 383–395.
[DOI: 10.1076/brhm.34.4.383.26227](https://doi.org/10.1076/brhm.34.4.383.26227).
The publisher's indexed abstract was checked; the full article was not
retrieved. No numerical replacement mass was extracted or inferred from it.

**R10 — Adopted horse reference (D30).** Gerstner, G. E. & Gerstein, J. B. (2008).
Chewing Rate Allometry Among Mammals. *Journal of Mammalogy*, 89(4), 1020–1030.
[DOI: 10.1644/07-MAMM-A-188.1](https://doi.org/10.1644/07-MAMM-A-188.1).
[Publisher table](https://academic.oup.com/view-large/15006928).
Table 1, p. 1022: Przewalski's horse, `Equus przewalskii`, mass 300,000 g.
Methods checked on p. 1021. The taxon entry is verified; cohort metadata are
insufficient for claiming a universal adult mean or a match to Sänger's geldings.

**R11 — Measured seasonal context.** Kuntz, R., Kubalek, C., Ruf, T., Tataruch, F.
& Arnold, W. (2006). Seasonal adjustment of energy budget in a large wild mammal,
the Przewalski horse (*Equus ferus przewalskii*) I. Energy intake.
*Journal of Experimental Biology*, 209, 4557–4565.
[DOI: 10.1242/jeb.02535](https://doi.org/10.1242/jeb.02535).
Table 3, p. 4563, and accompanying results checked in the full article.
Individual repeated weighings support seasonal variation. They are not weights
of Sänger's study animals and were not averaged into a replacement mass here.
