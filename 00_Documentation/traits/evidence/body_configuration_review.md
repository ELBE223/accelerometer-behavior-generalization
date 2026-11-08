# C3 — Body configuration: definition and evidence review

Started: 2026-11-02. Updated: 2026-11-02 (D34 four-group coding adopted).
Status: **four-group coding accepted and implemented (D34); anatomical boundaries and validation remain qualified**.
Lucas accepted the proposed coarse grouping after choosing the standard code for
the dog and discussing the raccoon. This closes the current coding choice, not
the outstanding evidence audit. C3 remains in the seven-trait Core and in Extended.
No H3 results or robustness analyses have been recomputed.

## Accepted coarse coding — D34

Construct: taxon-reference body proportions in ordinary standing posture, with
attention to relative trunk, limb and neck dimensions. These are qualitative
author-coded reference groups, not measured study-animal shapes or a validated
universal taxonomy.

| Stored category | Display name | Working anatomical interpretation | Study taxa | n |
|---|---|---|---|---:|
| `robust_quadruped` | Rumpfbetont / trunk-dominated build | Relatively deep/broad trunk in relation to body height and limb proportions. | Bison bonasus; Bos taurus | 2 |
| `standard_quadruped` | Allgemeiner Vierfüßerbau / generalized quadrupedal build | Broad reference grouping of ordinary quadrupedal proportions; within-group shape differences are deliberately retained. A fully reproducible boundary against the other states remains to be specified. | Canis lupus familiaris; Equus caballus; Equus ferus przewalskii; Procyon lotor; Vulpes vulpes | 5 |
| `tall_long_necked_quadruped` | Hochbeinig/langhalsig / tall, long-necked build | Marked relative elongation of the neck and limbs. | Giraffa camelopardalis | 1 |
| `compact_low_profile_body` | Kompakt/bodennah / compact, low-profile build | Compact trunk and low body profile in ordinary stance; defensive rolling is outside C3. | Erinaceus europaeus | 1 |

The machine column and the four retained state names stay unchanged for
compatibility. Display labels clarify the intended interpretation without
claiming a new quantitative classification.

### Rationale and remaining evidence limits

The dog keeps its existing standard code as a coarse reference across the
heterogeneous source cohorts. This is Lucas's accepted coding choice; breed
variation documented in B5 and the source studies is not thereby resolved.

For the raccoon, B12 explicitly describes a generalized body plan. This provides
context for a coarse merger, but the study measures trabecular development rather
than testing our grouping with horses and canids. The merger is an author
inference, not a published assignment to our C3 class. Raccoon is flagged as an
uncertain assignment. Its accepted C2 scansorial state remains unchanged.

Direct bison and cattle dimensions (B8–B9) support examining trunk proportions.
They do not yet establish a common boundary against horses, canids and raccoon.
The standard state must not become a default for absent evidence. A common
anatomical rubric and dedicated checks of the giraffe and hedgehog criteria remain
necessary before describing C3 as fully supported. No independent recoding,
category thresholds or validation statistics are claimed.

### Implementation and numerical check

In each Core/Extended CSV, only the raccoon C3 field changes:
`generalist_quadruped` → `standard_quadruped`. Dog and all other values remain
unchanged, including C1/D30 and C2/D32, row order, schema and CRLF line endings.
The immediately preceding inputs are preserved at
[a4acac071d99a0209f2dbcf108e0509085be2b6e](https://github.com/ELBE223/paper-izw-cross-species-transfer/commit/a4acac071d99a0209f2dbcf108e0509085be2b6e).

Both matrices now have group sizes 2/5/1/1. Of the 36 unordered taxon pairs,
11 match and 25 differ on C3, compared with 7 matches and 29 differences before.
Exactly four indicators change from mismatch to match: raccoon–dog,
raccoon–domestic horse, raccoon–Przewalski's horse and raccoon–fox.
This verifies the coding effect only; full distance matrices and models were
not recomputed. The R reader already handles C3 as a nominal factor.

### Agreed follow-up, not completed analysis

Compare the accepted four-state coding with the historical separate raccoon state
in a sensitivity analysis, holding all other finalized inputs fixed. Restore only
that C3 cell for the comparison rather than using an old full matrix with outdated
mass values. Omission of C3 remains an additional proposed robustness check, not
an adopted change to the primary trait set.

Existing H3 outputs predate the corrected mass inputs and this C3 merger and must
be regenerated after the trait review. Classifier predictions and H1/H2 are
unaffected by changing this trait input. The decision was made after earlier H3
findings were known; no new fit informed the merger and no preregistration is claimed.

## Historical review before D34

The following D33 sections describe the earlier five-state inputs and proposals.
Their references to current groups, unresolved adoption and unchanged inputs apply
to that earlier stage. The D34 section above is authoritative for the accepted
mapping; the unresolved evidence limitations remain relevant.

## Working construct

Working display name: **Body proportions / Körperproportionen**.
Existing input column: `body_configuration_type`.

Proposed construct: taxon-reference body proportions, especially the relative
dimensions of trunk, limbs and neck, considered in ordinary standing posture.
The construct must be separated from absolute body mass (C1), locomotor
specialization (C2), movement amplitudes (C4/C6), and defensive or temporary
postural compactness (E3/E4). These distinctions do not imply statistical
independence among the traits.

Body and limb geometry has a plausible biomechanical rationale (B1–B2).
That rationale does not validate our present five categories or establish an
effect on accelerometer transfer performance. C3 needs a common anatomical rule
applied to every taxon; descriptive labels alone are insufficient.

## Current input groups

Both Core and Extended currently use the following mapping. Nothing in this
review changes the input matrices.

| Current category | Taxa | n |
|---|---|---:|
| `robust_quadruped` | Bison bonasus; Bos taurus | 2 |
| `standard_quadruped` | Canis lupus familiaris; Equus caballus; Equus ferus przewalskii; Vulpes vulpes | 4 |
| `tall_long_necked_quadruped` | Giraffa camelopardalis | 1 |
| `compact_low_profile_body` | Erinaceus europaeus | 1 |
| `generalist_quadruped` | Procyon lotor | 1 |

The current R reader treats C3 as a nominal factor. Of 36 unordered taxon pairs,
7 share a category and 29 differ. All pairs involving one of the three singleton
categories are mismatches. This is a property of the chosen partition, not evidence
that the corresponding anatomical differences have equal magnitude.

## Targeted source audit — 2026-11-02

Search scope: whole-body proportions; bovid robustness and horse comparisons;
domestic-dog shape variation; raccoon limb anatomy and locomotion. Sources were
checked for anatomical construct, taxonomic match and what they actually measured.
This was a focused search, not an exhaustive systematic review. Not finding a
common coding rule in these sources is not proof that none exists.

| Question | Evidence and locator | Implication for C3 |
|---|---|---|
| Can body proportions be treated explicitly? | B1, Abstract, models body and limb dimensions; B2, Abstract/Introduction, distinguishes limb dimensions and inertial properties. | Supports specifying anatomy and measurements. Neither source supplies our five-state whole-body scheme. |
| Does robust bovid anatomy justify a separate group? | B3, Abstract, Introduction and Methods/Table 2: long-bone shape varies with mass and habitat; the sample includes Bos taurus and Bison bison, not B. bonasus. B4, indexed Abstract/Introduction/Results: exact B. bonasus and B. taurus patellae. | Relevant anatomical evidence, but bone or patellar robustness is not interchangeable with trunk build. These studies do not establish a whole-body boundary separating our bison/cattle from both horse taxa, dogs and foxes. |
| Are all domestic dogs one standard body shape? | B5, publisher Abstract and indexed Results: 27 measurements in 1,155 dogs; size and length-versus-width shape appear on different principal components. | A single dog code hides shape variation across breeds. A breed/cohort rule is needed; the C2 acceptance of a broad dog locomotor category does not settle C3. |
| Does raccoon anatomy differ from canids? | B6, publisher Abstract: cineradiographic hip/pelvic movement and articular comparisons identify ambulatory versus cursorial patterns, including raccoons and domestic dogs. | There is real functional anatomy behind the distinction. It concerns mobility and locomotion, so it does not by itself establish a separate whole-body proportions category. |
| Does a generalist label uniquely describe raccoon body shape? | B7, Discussion, paragraph on long-bone robustness and Fig. 7: raccoon forelimb bones are described as slender, a feature also occurring in other carnivoran lineages. | A whole-animal label cannot be inferred from one skeletal region or from generalist ecology. It would also be unsound to merge raccoon with canids solely on this evidence. |

### Robust versus standard

The issue is the level of measurement. Bone robustness can be operationalized
as relative diameter, cross-section or three-dimensional shape; trunk robustness
would require a different definition. A mass threshold is not a substitute for
either. The current categories have no recorded threshold or comparable
multivariate rule that covers all six taxa assigned to robust or standard.

The source populations also matter. The long-bone bovid comparison has an American
bison proxy, whereas the patellar study has European bison but a different anatomical
target. Neither supplies the missing horse comparison under one common whole-body
criterion. No new source masses are adopted; C1 remains closed.

### The separate raccoon group

The evidence supports a distinction in joint function and limb use. Our
interpretation is that this evidence is more directly relevant to C2, and possibly
to a carefully defined motion trait, than to the proposed C3 proportions construct.
It does not invalidate the accepted C2 scansorial code: published ambulatory and
scansorial schemes can describe different aspects of the same animal.

Replacing `generalist_quadruped` with “plantigrade” would introduce a different
trait, foot-contact posture. It would require applying that definition to all nine
taxa and reassessing overlap and weighting. Merely calling the raccoon robust,
compact or standard would also require evidence under the same rule as every
other species. No such replacement is adopted here.

## Follow-up — direct body proportions and measurement compatibility

The follow-up search on 2026-11-02 moves beyond isolated skeletal elements.
It found direct European-bison body measurements (B8), breed-matched Japanese
Black cattle measurements (B9), and a published riding-horse measurement protocol
(B10). These improve the evidence for a proportions-based C3. They do not yet
validate the existing five-state assignment.

| Source population | Measurements available | Scope / compatibility limit |
|---|---|---|
| B8: European bison, sex and age classes | Withers height, oblique body length, heart girth and thorax depth; Methods pp. 86–87 and Table 3 pp. 102–104. | Body dimensions were taken on dead animals. The standing-posture working construct therefore needs an explicit comparability assessment. |
| B9: Japanese Black steers | Withers height, chest depth/width, body length and other dimensions; Methods and Table 1. | About 9.1 months at the start and 21 months at the end of the test. This is a reference population, not the accelerometer cohort. |
| B10: eight adult riding horses | Defined manual measures of height, chest depth/width and body length, taken in a standard standing position. | Six Thoroughbreds and two crossbreds; not a universal horse reference and not the recorded horse cohort. |

**Concrete measurement issue.** B8 defines total body length from muzzle to tail
base along the back, and separately an oblique shoulder-to-ischial length.
B10 uses a shoulder-to-hindquarter surface path. Its chest-depth definition starts
at the highest withers point, whereas B8 uses a dorsal point behind the scapula.
Equal variable names therefore do not establish homologous measurements. Withers
height also contains the contribution of the dorsal profile, so a chest-depth/height
ratio is not a pure measure of leg length or ground clearance.

As a descriptive extraction check, the following ratios use published group
means. They are **not adopted trait values, individual mean ratios, classification
thresholds or a statistical comparison with horses**:

| Reference group | Mean depth / mean withers height (cm) | Ratio of reported means |
|---|---|---:|
| B8: male bison, at least 72 months | 94 / 172 | 0.547 |
| B8: female bison, at least 72 months | 79 / 152 | 0.520 |
| B9: steers at the finish of fattening | 71.78 / 134.16 | 0.535 |

Within each row the reported sample sizes for depth and height differ
(B8 males 35/39, females 85/87; B9 4553/4559). The ratios therefore use summary
statistics from partly different subsets, not matched individual measurements.
They support examining relative trunk depth; they do not establish a universal
robust/standard divide. No corresponding nine-taxon vector is available from
this audit.

A further cattle lead (B11) pools repeated measurements from birth to yearling
age. Its summary dimensions must not be silently used as an adult body-shape
reference. This is a source-scope exclusion, not a judgement about the quality
of that study.

### Refined working definition and decision checkpoint

A more explicit candidate meaning for `robust_quadruped` is **a trunk-dominated
quadrupedal build, evaluated from relative trunk depth and breadth in relation
to body height and limb proportions**. This replaces the vague interpretation
“large/heavy animal” at the conceptual level. It is a working definition only:
the choice of measurements, treatment of variation and criterion separating
groups still need to be fixed.

The new evidence makes a body-proportions rationale for bison/cattle more concrete.
It does not demonstrate that all horses, study dogs and foxes fall on one side of
a shared boundary, or that the raccoon warrants its own body-shape state.
`standard_quadruped` cannot simply mean every taxon without measurements.
The raccoon also must not be moved into it solely because the old generalist
label lacks an adequate definition.

Before a final categorical decision, use the same anatomy-based rubric for each
taxon, record whether its evidence describes a species reference or the actual
cohort, and mark borderline cases explicitly. Qualitative, literature-supported
judgement is possible; a numerical cutoff is not mandatory. The rubric must
nevertheless make disagreement and exceptions visible. No cutoff or regrouping
has been selected in this follow-up, and no independent coding is claimed.

## Disposition of the nine current codes

| Taxon | Current C3 | Disposition from this pass |
|---|---|---|
| Bison bonasus | robust_quadruped | Direct body-proportions evidence added in B8; specimen condition and common category boundary remain unresolved. Earlier exact-species patellar and B. bison long-bone evidence are retained with their different scopes. |
| Bos taurus | robust_quadruped | Japanese Black reference body measurements added in B9; a common anatomical rule versus horses and canids remains to be established. |
| Canis lupus familiaris | standard_quadruped | Explicit breed/cohort scope needed for body shape. The accepted C2 scope does not validate this C3 state. |
| Equus caballus | standard_quadruped | B10 supplies explicit riding-horse measurement methods; matching of landmarks and breed/cohort scope remains necessary. No final robust/standard boundary is validated. |
| Equus ferus przewalskii | standard_quadruped | No common robust/standard whole-body criterion validated in this pass; do not treat domestic-horse evidence as an exact match. |
| Erinaceus europaeus | compact_low_profile_body | Retained for now; relative limb/trunk dimensions and separation from defensive posture need a dedicated check under any revised rule. |
| Giraffa camelopardalis | tall_long_necked_quadruped | Retained for now; neck and limb proportions need an explicit definition applicable to all taxa, rather than an exception based on appearance. |
| Procyon lotor | generalist_quadruped | Functional generalism is documented, but a distinct body-proportions category is not established by the inspected evidence. |
| Vulpes vulpes | standard_quadruped | No common robust/standard whole-body criterion validated in this pass; comparative carnivoran limb anatomy alone does not define the whole-body group. |

## Recommendation and alternatives — not adopted

**Recommendation:** do not finalize the existing five-state C3 solely by adding
citations. For a final primary analysis, retain a body-proportions trait only if
one explicit, reproducible rule and comparable evidence can be supplied for all
nine taxa. If that cannot be achieved within the paper's scope, the pragmatic
alternative is a primary distance without C3 and an explicitly exploratory
sensitivity analysis retaining the historical C3 coding. This is a recommendation,
not an implemented change to Core or Extended.

A revised morphology representation could use specified relative measurements,
for example limb length relative to trunk length, trunk breadth/depth relative to
trunk length, and neck length relative to trunk length. These are candidate axes,
not extracted values or a proposed three-column replacement. They need:

- homologous landmarks, consistent standing posture and compatible specimen age;
- an explicit species-reference or study-cohort interpretation, especially for dogs;
- uncertainty and missing-data handling, with no thresholds invented from photographs;
- checks for remaining allometry: division by a length does not automatically remove
  dependence on body mass;
- a stated weighting rule if several shape variables replace one C3 column.

A qualitative classification can also be defensible if the anatomical criteria,
tie rules and species evidence are explicit and reproducible. Quantitative
measurements are not the only acceptable option. Simply reducing five groups to
three does not resolve the present construct problem. Group number and definitions
must not be selected for a more favourable H3 result.

An independent anatomical coding check would strengthen either revised scheme;
none has been performed here. The literature audit does not constitute independent
validation of the author-coded categories.

## Numerical consequences and analysis status

The group count and all 36 nominal pair indicators were checked in Core and
Extended; their C3 mappings agree. No full distance matrix or H3 model was rerun.

Unlike the C2 singleton rename, merging C3 groups would change distances.
For illustration only, joining the two robust taxa to the four standard taxa
changes 8 C3 pair indicators. Also joining the raccoon changes another 6,
for 14 changed pairs in total. These are arithmetic examples, not proposed final
species assignments or executed sensitivity analyses.

Omitting C3 changes the primary equal-weight Gower calculation from seven traits
to six; with complete data, the remaining traits each receive 1/6 rather than 1/7
of the total. A revised primary analysis and the historical seven-trait sensitivity
must therefore be recalculated and labelled explicitly if that option is adopted.
New trait values, category merging, or omission must be dated before a new H3 fit.

This commit is documentation only. C1/D30 and C2/D32 remain confirmed; inputs,
analysis code and outputs are unchanged. Existing H3 outputs still await the D30
mass-input update. C3 remains open, with the robust/standard rule and raccoon
construct mismatch now documented rather than silently accepted.

## References and access

**B1.** Prothero, J. (1992). Scaling of bodily proportions in adult terrestrial
mammals. *American Journal of Physiology*, 262(3 Pt 2), R492–R503.
[DOI](https://doi.org/10.1152/ajpregu.1992.262.3.R492);
[PubMed](https://pubmed.ncbi.nlm.nih.gov/1558220/).
Indexed abstract checked; publisher full text was inaccessible. No species values
or unseen measurement tables were extracted.

**B2.** Kilbourne, B. M. & Hoffman, L. C. (2013). Scale Effects between Body Size
and Limb Design in Quadrupedal Mammals. *PLoS ONE*, 8(11), e78392.
[DOI/full text](https://doi.org/10.1371/journal.pone.0078392).
Abstract and Introduction checked in the preceding C3 introduction. Mechanistic
context; not a direct source for this whole-body categorization.

**B3.** Etienne, C., Filippo, A., Cornette, R. & Houssaye, A. (2021).
Effect of mass and habitat on the shape of limb long bones: A morpho-functional
investigation on Bovidae (Mammalia: Cetartiodactyla).
*Journal of Anatomy*, 238(4), 886–904.
[DOI/full text](https://doi.org/10.1111/joa.13359).
Issue year 2021; online 18 November 2020. Publisher Abstract, Introduction,
Methods 2.1–2.4 and Table 2 checked. The supplementary specimen list was not
inspected. No horse comparison or exact European-bison long-bone sample is claimed.

**B4.** Kahvecioğlu, O. et al. (2026). Patellar shape diversity as a functional
indicator of locomotor specialization in selected ruminant species.
*Scientific Reports*, 16, 3418.
[DOI](https://doi.org/10.1038/s41598-025-33370-3);
[PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC12835180/).
Indexed Abstract/Introduction/Results checked; direct pages were access-blocked
during this pass. The whole-body robust/standard grouping was not tested by this
patella-specific comparison.

**B5.** Sutter, N. B., Mosher, D. S., Gray, M. M. & Ostrander, E. A. (2008).
Morphometrics within dog breeds are highly reproducible and dispute Rensch's rule.
*Mammalian Genome*, 19, 713–723.
[DOI](https://doi.org/10.1007/s00335-008-9153-6);
[author manuscript](https://pmc.ncbi.nlm.nih.gov/articles/PMC2748280/).
Publisher Abstract and indexed manuscript Results checked. Full measurement-table
extraction was not performed. This is evidence for breed-dependent shape variation,
not a matched measurement series for the study dogs.

**B6.** Jenkins, F. A., Jr. & Camazine, S. M. (1977). Hip structure and locomotion
in ambulatory and cursorial carnivores. *Journal of Zoology*, 181(3), 351–370.
[DOI/publisher](https://doi.org/10.1111/j.1469-7998.1977.tb03249.x).
Publisher Abstract checked. Its raccoon name appears as “Procyon tolor”; this is
recorded as a source spelling error, not a different study taxon. Domestic dog is
listed as Canis familiaris. No unseen full-text measurements are reported.

**B7.** Martín-Serra, A., Figueirido, B. & Palmqvist, P. (2014).
A Three-Dimensional Analysis of Morphological Evolution and Locomotor Performance
of the Carnivoran Forelimb. *PLoS ONE*, 9(1), e85574.
[DOI/full text](https://doi.org/10.1371/journal.pone.0085574).
Abstract, Methods and Discussion text associated with Fig. 7 checked, including
the explicit Procyon lotor example. The supplementary specimen tables were not
inspected. Evidence concerns forelimb bone shape, not whole-body proportions.

**B8.** Krasińska, M. & Krasiński, Z. A. (2002). Body mass and measurements of
the European bison during postnatal development. *Acta Theriologica*, 47(1), 85–106.
[Institutional full-text PDF](https://ibs.bialowieza.pl/g2/pdf/1357.pdf).
Methods pp. 86–87, Results p. 94 and Table 3 pp. 102–104 checked in extracted
full-text PDF content. The body-mass values do not replace C1.

**B9.** Kemmotsu, N. et al. (2024). Incorporating body measurement traits to
increase genetic gain of feed efficiency and carcass traits in Japanese Black
steers. *Journal of Animal Science*, 102, skae176.
[DOI](https://doi.org/10.1093/jas/skae176);
[PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC11306786/).
Indexed primary Methods (Animals and phenotypic data) and Table 1 checked;
publisher metadata/Abstract also accessible. Direct PMC page access was blocked.
No matched individual measurements or supplement were extracted.

**B10.** Matsuura, A. et al. (2021). Body measurement of riding horses with a
versatile tablet-type 3D scanning device. *Journal of Equine Science*, 32(3), 73–80.
[DOI](https://doi.org/10.1294/jes.32.73);
[full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC8437753/).
Methods (Horses; Conventional manual measurements), named M1–M10 definitions
and Table 2 cohort information checked. No numerical Table 1 body dimensions
were extracted; no horse ratio is reported in this review.

**B11 — Excluded adult-reference lead.** Malau-Aduli, A. E. O. et al. (2004),
principal-component/ridge-regression study of Japanese Black cattle body
measurements and body weight. *Journal of Animal and Veterinary Advances*,
3(12), 856–863.
[Publisher PDF](https://makhillpublications.co/files/published-files/mak-java/2004/12-856-863.pdf).
Indexed first-page Abstract and Table 1 checked: measurements span birth to
yearling age. The pooled means are not used to code adult body proportions.


**B12.** Reinecke, T. & Angielczyk, K. D. (2024). Raccoons Reveal Hidden Diversity
in Trabecular Bone Development. *Integrative Organismal Biology*, 6(1), obae038.
[DOI/full text](https://doi.org/10.1093/iob/obae038);
[author manuscript](https://pmc.ncbi.nlm.nih.gov/articles/PMC11495488/).
Indexed primary Introduction, Methods and Conclusion checked on 2026-11-02;
direct PMC opening returned an access check. The conclusion describes a generalized
body plan. The measurements concern humeral/femoral trabeculae, not a comparative
whole-body classification; no shared category with our horses or canids is validated.
