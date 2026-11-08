# C2 — Locomotor specialization: definition and coding review

Started: 2026-11-01. Final coding adopted: 2026-11-02.
Status: **definition and three-group coding confirmed by Lucas (D32)**.
This decision supersedes the provisional category definitions and unresolved
dispositions in D31. The earlier evidence audit is preserved below as history.
Pre-adoption inputs and documentation:
[37e57fb](https://github.com/ELBE223/paper-izw-cross-species-transfer/commit/37e57fbdfdeb2a7cd03e3ba3ead0b84ec7b3cbb2).

## Final construct and short definitions — D32

Display name: **Locomotor specialization / Fortbewegungsspezialisierung**.
Existing machine-readable column: `dominant_locomotor_mode`.

C2 is a coarse, nominal, taxon-level ecomorphological classification of locomotor
anatomy and habitual substrate use. The three definitions below are our
operational rules, informed by the cited literature. They are not a universal
mammalian taxonomy, a gait label, an observed activity budget, or a ranking of
speed or endurance. Coding does not use the frequencies of our behaviour labels.

| Final category | Short operational definition | Taxa in this study | n |
|---|---|---|---:|
| `cursorial` (broad anatomical sense) | Terrestrial quadrupeds with a locomotor apparatus adapted to running; this coarse group includes heavy-bodied and very long-legged running forms. | European bison, cattle, domestic dog, domestic horse, Przewalski's horse, giraffe, red fox | 7 |
| `scansorial` | Taxa for which ground locomotion and habitual climbing are characteristic components of locomotion. | Raccoon | 1 |
| `terrestrial_generalist` | Taxa with positive evidence for generalized ground locomotion, without a predominant running, climbing or digging specialization under this scheme. | European hedgehog | 1 |

**Mapping rule.** Compatible exact-taxon classifications are used directly;
functional-anatomical evidence may support an explicitly identified author
inference. Being able to run, living on land, or failure to find a specialist
classification is insufficient by itself. For these nine taxa, the finer
mediportal heavy-bovine and stilt giraffe forms discussed in L14 are deliberately
pooled into broad `cursorial`. This is our coarse mapping decision, not a claim
that L14 calls all of them its narrower cursorial subtype. L8–L9 support the
broader anatomical usage. The earlier fast/sustained-running criterion in D31
is superseded; no minimum speed, endurance or unmeasured anatomical threshold
is imposed.

The adopted data have three occupied states. `semifossorial` is not retained as
a fourth state, and `mediportal` and `stilt` are not added as separate states.
The decision is confined to the present nine-taxon analysis; new taxa would
require an explicit review rather than automatic allocation to a residual group.

## Final species mapping and evidence

All nine dispositions below were accepted by Lucas on 2026-11-02 following the
author/assistant source audit. Source identifiers and links are listed below.
Direct published assignments and author interpretations remain distinguished.

| Study taxon | Final C2 code | Evidence and locator | Basis and retained limitation |
|---|---|---|---|
| *Bison bonasus* | `cursorial` | L14, Methods and Figs. 3e/4a; L15, Introduction/Results. | Author inference from exact-species functional anatomy and the explicit coarse pooling rule. An exact-species categorical cursorial entry was not verified; L8's *B. bison* entry is a congeneric proxy only. |
| *Bos taurus* | `cursorial` | L8, Table 1; L15, Introduction/Results. | Direct broad cursorial assignment in L8; finer heavy-bovine form pooled by our rule. Does not measure the performance of the study cattle or resolve breed variation. |
| *Canis lupus familiaris* | `cursorial` | L10, Fig. 1B, Table 1 and Methods; L11, Abstract/Summary; cohort scope in L16–L17. | Author inference using domestic-dog anatomy in L10's combined cursorial/saltatorial group. A broad taxon reference across breeds, not a uniform degree of running specialization in every dog. |
| *Equus caballus* | `cursorial` | L1, Table 1. | Direct exact-taxon cursorial assignment, used at taxon level rather than as a measurement of the recorded horses. |
| *Equus ferus przewalskii* | `cursorial` | L12, sections 4.6.2 and 4.6.4, pp. 37–38 and 41; L13, section 3.3 and Tables 2/4. | Comparative inference supported by exact-taxon anatomy and inclusion in a cursorial Equidae scheme. Source names *E. przewalskii* and `Eq. f. przewalsii` are mapped to the study taxon. |
| *Erinaceus europaeus* | `terrestrial_generalist` | L5, Abstract/Introduction; counterevidence L6, Table A1 p. 129 and definitions pp. 122/124; context L7, Discussion. | Author inference primarily from the unspecialised walking model in L5. L6 genuinely uses semifossorial in a burrowing/foraging classification; this alternative is preserved, not treated as an erroneous source. |
| *Giraffa camelopardalis* | `cursorial` | L8, Table 1; L9, Abstract/opening Introduction; finer scheme L14, Methods. | Direct broad anatomical support; the finer stilt form is pooled by our rule. Long limbs do not establish exceptional speed, endurance or equivalence with horses. |
| *Procyon lotor* | `scansorial` | L1, Table 1. | Direct exact-taxon scansorial assignment; no observed climbing time share is inferred for the study recordings. |
| *Vulpes vulpes* | `cursorial` | L1, Table 1. | Direct exact-taxon cursorial assignment under the adopted coarse scheme; finer classifications may use different boundaries. |

### Domestic-dog scope

The supplied theses were checked at section 2.1.1 and Table 2. Szangolies (2017;
L16, printed pp. 4–5 / PDF pp. 11–12) describes 14 dogs of deliberately diverse
breeds and morphologies, including terriers, retrievers, bulldogs and mixed breeds.
All 14 are represented in primary transfer according to the
[analysis-membership audit](body_mass_dog_inclusion.md).

Groth (2020; L17, printed pp. 6–7 / PDF pp. 17–18) describes a 20-dog source
cohort consisting mainly of Labrador Retrievers and some Golden Retrievers.
The eight processed Dog_dataset_2 recording groups still cannot be assigned
uniquely to named dogs; source-cohort membership is not a verified list of
20 retained analysis animals.

C2 therefore describes a broad domestic-dog anatomical reference, not the
measured locomotor specialization of each individual. Breed differences documented
by L11 and the heterogeneous first cohort limit that interpretation. The cohort
check resolves the scope of the coding decision; it does not remove that biological
variation or solve the remaining Dog_dataset_2 identity ambiguity. No C1 mass
decision is reopened.

### Hedgehog interpretation

L5 supplies positive evidence for generalized locomotor mechanics, so the generalist
code is not a default for missing information. L6's semifossorial designation
concerns a different burrowing/foraging construct and remains valid counterevidence
to a claim of universal terminology. The accepted code does not imply an inability
to dig, climb or swim. The source access limits and the full reasoning are retained
in the historical audit below.

## Implementation, checks and limits

D32 changes only the hedgehog's C2 cell from `semifossorial` to
`terrestrial_generalist` in both
[Core](../species_traits_core.csv) and
Extended (deleted, D40).
All nine species have the same final C2 code in both matrices. C1 and every other
cell, row order, column name and CSV line ending are preserved.

The existing reader in `code/stats_h3.R` creates a nominal factor for C2 and
does not require a fixed category list. Verification compares the complete old
and new matrices and all 36 unordered C2 pair indicators: **21 same-category
and 15 different-category pairs before and after; no pair changes**. Only the
name of a singleton changes. With other inputs fixed, primary equal-weight Core
and equal-weight Extended Gower distances are therefore unchanged by D32.
This check is not a model fit or a rerun of optimized-weight sensitivity analyses.

The 7/1/1 distribution has limited resolution: the two smaller groups each contain
one taxon, and the large group pools considerable functional diversity. C2 cannot
establish a general category effect independently of those taxa. Possible overlap
with C3, C7 and E2 remains a methodological consideration; omission-of-C2 checks
and any biologically justified regrouping should be reported as separate robustness
analyses, not as completed validation. Relabelling the hedgehog singleton alone
cannot test sensitivity to a different grouping.

Definition, source mapping and coding are closed under D32. Independent biological
recoding has not been performed, and this post hoc audit is not preregistration.
No classifier or H3 model was rerun. Existing H3 outputs still await the previously
documented D30 mass-input update and must not be presented as recomputed results.

## Historical D31 audit — superseded working definitions

The following sections preserve the evidence search and reasoning before D32.
References to “working”, “current”, “unresolved” or “not adopted” describe that
historical stage, not the final disposition above. In particular, the four-state
proposal and narrow running criterion are superseded.

### Construct and purpose

Working display name: **Locomotor specialization** / **Fortbewegungsspezialisierung**.

Operational definition: a qualitative ecomorphological classification of habitual
locomotion and associated limb design, assigned at the study-taxon level from
anatomical and species-ecology evidence. It is not calculated from the proportions
of the paper's behaviour labels, speed in a particular window, or captive activity
budgets. “Dominant” does not imply an unmeasured majority-of-time threshold.

Mechanistic hypothesis: differences in limb function and habitual locomotion may
affect the movement patterns recorded by accelerometers. Comparative morphology
supports a relationship between locomotor categories and limb structure (L1–L2).
It does not by itself establish an effect on this paper's transfer performance,
especially across different sensor placements and behaviours.

The existing machine-readable column `dominant_locomotor_mode` remains unchanged
during review, so scripts and archived results keep their current schema. A later
column rename, if useful, must cover readers and exports together; changing a
display name does not require changing the numerical analysis.

### Working categories and evidence criteria

These are our proposed operational rules, informed by L1–L3. They are not claimed
to be a universally standardized four-category classification. Literature definitions
and taxonomic scopes differ; document those differences rather than silently mixing
incompatible criteria.

| Working category | Inclusion criterion | Insufficient evidence by itself |
|---|---|---|
| `terrestrial_generalist` | Positive evidence for generalized ground locomotion, without a predominant running, climbing or digging specialization under this scheme. | Living on land, or failure to find a more specific classification. |
| `cursorial` | An explicit running-specialization assignment, or documented limb-function evidence supporting fast or sustained terrestrial running as a characteristic adaptation. | Being able to walk/run, moving on the ground, or having a “Locomotion” label. |
| `scansorial` | Evidence for habitual climbing capacity/use as a characteristic locomotor adaptation in an animal that also uses the ground. | An isolated observation of climbing or occurrence near trees. |
| `semifossorial` | Evidence for recurrent active excavation as part of ordinary shelter/foraging ecology, supported by an explicit specialist assignment or relevant functional anatomy; this is not a wholly subterranean category. | Scratching, occasional digging, searching leaf litter, or occupying a burrow made by another animal. |

**Open issue from the expanded search:** the meaning of `cursorial` varies across
sources. The five-taxon review below documents why anatomical specialization and
finer running-form classifications cannot be pooled without an explicit rule.
The category criteria above remain provisional.

The set is tailored to the nine-taxon review and can be revised before adoption
if the evidence does not support it. “Generalist” is not a catch-all for uncertainty.
No measured speed, time-share or skeletal threshold is invented where the sources
do not supply one.

For an assignment, seek either (a) a direct taxon-specific classification in a
comparative study whose definition is compatible with the rule, or (b) species-level
ecological and functional evidence together supporting an explicitly labelled
reviewer inference. Record sample/breed/subspecies limitations and counterevidence.
A study about carnivorans or rodents cannot automatically assign all other mammals.

If two specializations are equally supported or the sources conflict, leave the
**audit decision unresolved**, record the plausible alternatives and resolve the
rule or examine both in sensitivity analysis. Do not force a tie by a hidden
priority order. “Unresolved” is an audit status, not an extra biological category;
do not put it into the analysis matrix.

### Evidence table: current audit

“Current” describes the unchanged input matrix. A source that supports that code
does not mean the complete C2 review is finished.

| Study taxon | Current | Evidence checked in this pass | Status / next evidence needed |
|---|---|---|---|
| Bison bonasus | cursorial | Exact-species functional evidence in L14–L15; the cursorial bison row in L8 is B. bison. | Mapping unresolved: distinguish the broad running-adaptation category from finer running forms. See targeted review below. |
| Bos taurus | cursorial | L8, Table 1, explicitly assigns cursorial; L15 adds exact-species morphology. | Published support for the coarse code; definition and breed scope require the same rule as the other taxa. |
| Canis lupus familiaris | cursorial | Domestic-dog anatomy in L10; breed-specific functional differences in L11. | Coarse cursorial interpretation has exact-taxon support; applicability to the study breeds remains to be documented. |
| Equus caballus | cursorial | L1, Table 1, explicitly assigns Cursorial. | Direct support located; check fit to the rule and source scope. |
| Equus ferus przewalskii | cursorial | Exact-taxon comparative evidence in L12 and inclusion in L13's equid study. | Cursorial interpretation supported; distinguish species evidence from a family-level classification rule. |
| Erinaceus europaeus | semifossorial | Targeted review of L5–L7 below; locomotor and foraging classifications differ. | Proposed: terrestrial_generalist under the working C2 construct; interpretation, counterevidence and access limits documented. Not yet adopted. |
| Giraffa camelopardalis | cursorial | Direct classification in L8 and cursorial morphology in L9. | Coarse anatomical code supported; morphology is not a speed/endurance score. |
| Procyon lotor | scansorial | L1, Table 1, explicitly assigns Scansorial. | Direct support located; confirm compatible definition and ecology. |
| Vulpes vulpes | cursorial | L1, Table 1, explicitly assigns Cursorial. | Direct support located; confirm compatible definition and ecology. |

The targeted review below supersedes the initial abstract-only assessment of the
hedgehog. A generic database tag still requires its definition and underlying
evidence to be checked; the current code now has a published precedent, although
its fit to the working C2 construct remains disputed.

### Targeted hedgehog review — 2026-11-02

Question: does `semifossorial` describe the locomotor specialization of
*Erinaceus europaeus* under our working rule, or does `terrestrial_generalist`
better represent the evidence? This is a targeted literature search, not a
systematic review. Search topics included the exact species, locomotion,
limb anatomy, burrowing and both candidate categories.

| Evidence | Locator and taxonomic scope | Interpretation and limits |
|---|---|---|
| L5: Neveu et al. (2001) use hedgehog kinematics and anatomy to model an unspecialised quadruped. | Abstract and Introduction; exact species, *E. europaeus*. Treadmill cinefluorography and cadaver measurements. | Positive evidence for generalized terrestrial locomotor mechanics. This walking study does not test digging specialization. Our category name is an inference, not their four-state coding. |
| L6: White (2003) explicitly codes *E. europaeus* as Semifossorial. | Table A1, continued, p. 129, Foraging Mode column; definitions p. 122 and classification procedure p. 124. | Genuine counterevidence. Here the distinction concerns surface feeding by burrowing mammals versus underground feeding. Classification uses feeding-site descriptions in metabolic sources, supplemented by Nowak (1999), rather than a limb-specialization test. |
| L7: Bolfíková & Hulva (2012) describe hedgehogs as lacking a semifossorial life strategy. | Discussion, paragraph on excess homozygosity/population substructure; study includes *E. europaeus* and *E. roumanicus*. | Ecological context, citing Reeve (1982). This is not a direct excavation experiment or an independent locomotor classification. Reeve's original study has not been inspected. |

**Working recommendation:** `terrestrial_generalist` is the better-supported
interpretation for our specifically locomotor construct, primarily because L5
addresses the relevant mechanics directly. Retain L6 as a documented alternative,
not as an erroneous citation. The papers use different constructs, and L7 also
shows that ecological terminology is not uniform. We do not claim a literature
consensus or infer an inability to dig.

The mapping remains a judgement under our proposed rule. It should be reviewed
alongside the other eight taxa using the same criteria before final adoption.
Further direct evidence for habitual excavation and associated functional
specialization could change the assessment. Coding must not be selected from H3
fit or significance. No second independent biological reviewer is claimed.

Access: L5 abstract, publisher Introduction and exposed section excerpts were
available; its complete full text was not reviewed. L6 author-uploaded full text
was checked at the locations listed above. L7 publisher PDF Discussion was
checked. L4 remains an abstract-only anatomical lead. These access levels must
not be represented as complete full-text review of every source.

This update records evidence and a proposed interpretation only. It does not
adopt a new species code or alter Core/Extended inputs. The singleton-distance
invariance documented below still applies if this is the only category change.

### Targeted review of five additional taxa — 2026-11-02

Scope: European bison, cattle, domestic dog, Przewalski's horse and giraffe.
Searches combined exact and alternative scientific names with locomotor
classification, cursoriality, limb anatomy and functional morphology. This was a
targeted source audit, not an exhaustive or preregistered systematic review.
The existing codes were not treated as conclusions that the search had to confirm.

| Taxon | Evidence and exact location | Coding interpretation / limitation |
|---|---|---|
| *Bison bonasus* | L14, Methods running-form definitions and Figs. 3e/4a, includes European-bison anatomy. L15, Introduction and Results, examines bison and cattle patellar form and discusses load-bearing morphology. | Exact-species evidence is now available, but an explicit exact-species `cursorial` assignment compatible with our rule has not been verified. L8's *Bison bison* row is a congeneric proxy only. Keep this mapping unresolved. |
| *Bos taurus* | L8, Table 1: cursorial, three femora. Its Methods describe a subadult museum sample; this is a published classification, not a running-performance experiment. L15 additionally examines cattle and breed variation. | Supports a broad anatomical code. Neither source establishes the performance of our Japanese Black cattle cohort; coarse versus finer running classifications must be reconciled consistently. |
| *Canis lupus familiaris* | L10, Fig. 1B, Table 1 and Materials and Methods: ten domestic-dog femora in the combined cursorial/saltatorial comparison group. L11, Abstract/Summary, compares greyhound and pit-bull limb-bone mechanics. | Supports an author-inferred coarse cursorial interpretation using domestic-dog evidence, rather than relying solely on wolves. The combined group is not a separate four-state dog code. Breed-specific specialization varies; neither sample has been matched to our study dogs. |
| *Equus ferus przewalskii* | L12, section 4.6.2 (pp. 37–38) describes *E. przewalskii* anatomy; section 4.6.4 (p. 41) contrasts it with heavily built, noncursorial fossil horses. L13, section 3.3, classifies Equidae as cursorial; Tables 2/4 include `Eq. f. przewalsii` (source spelling). | Exact-taxon evidence supports the cursorial interpretation. L13 applies a family-level running-form scheme, not an independent speed test for the thesis animals. Taxonomic synonyms and the source spelling are explicitly mapped to our input taxon. |
| *Giraffa camelopardalis* | L8, Table 1: cursorial, three femora. L9, opening Introduction and Abstract, explicitly discusses cursorial anatomy alongside constrained locomotor performance. | Strong support for an anatomical interpretation. Long distal limbs do not establish exceptional running performance or biomechanical equivalence with horses and dogs. |

#### Definition issue exposed by this search

L14 uses a finer scheme with a separate mediportal form for heavy bovines and a
stilt form for giraffes. Its cursorial subtype is therefore not interchangeable
with the broader anatomical usage in L8–L9. Gambaryan (1974) is the underlying
scheme cited by L13–L14; that original book has not been inspected in this audit.
L14's supplementary tables have also not been inspected, so no unseen
per-specimen classification is claimed.

**Recommendation before final coding:** explicitly choose the level of biological
classification and document a mapping between source categories and C2. If a
coarse running-specialization group is retained, explain its inclusion criteria
and the functional diversity it pools. If the original fast/sustained-running
criterion is kept narrowly, reassess the large bovines instead of assuming that
any published use of “cursorial” satisfies it. Neither a new `mediportal` state nor
automatic pooling has been adopted here. Category rules must apply consistently
to all nine taxa, without reference to which mapping improves H3.

Remaining work is now mainly this construct/mapping decision, the study-dog
breed scope, and a final consistent review of all nine rows. The bison is not a
missing-evidence default generalist. More detailed running categories should not
be added solely because one paper uses them.

Access checked: L8 indexed Methods and Table 1; L9 institutional full-text PDF
(Abstract and opening Introduction); L10 author-uploaded full text (Methods,
Fig. 1B, Table 1 and Discussion); L11 publisher Summary/Abstract; L12 author-hosted
full-text PDF at the sections above; L13 full-text PDF at the cited methods/tables;
L14 indexed main-text methods and figure captions, without its supplement;
L15 indexed publisher Abstract, Introduction, Results and citation metadata.
Complete full-text review of every article is not claimed.

### Reproducible coding workflow

1. Freeze the construct, category definitions and ambiguity rule before a new H3 fit.
   Resolve the coarse-versus-fine category mapping, the bison and dog scope, and
   the provisional hedgehog recommendation consistently across all nine taxa.
2. For each species, record the candidate code, evidence statement, citation and
   exact table/page/section, species match, source population, direct assignment
   versus inference, conflicting evidence, reviewer/date, and final disposition.
   A general mechanism reference and a species-code reference serve different roles.
3. Obtain a second biological review using the same rule where feasible, without
   providing transfer scores as a coding criterion. Keep the actual disagreements.
   Existing H3 findings are already known; no retrospective blinding or independent
   review is claimed for the present author/assistant audit.
4. Once all nine entries are resolved, save the dated final mapping, preserve the
   old mapping in Git, and update Core and Extended consistently. Do not rename or
   recode the analysis inputs as a side effect of collecting preliminary evidence.
5. Recalculate affected distances and H3 summaries only after the trait revisions
   are fixed. Compare scientifically plausible alternatives and omission of C2;
   report effect sizes and uncertainty, without choosing the code by significance.

### Statistical interpretation and overlap

The current R reader treats C2 as a **nominal factor**, not an ordinal score.
The primary equal-weight Gower distance gives this trait 0 for a matching category
and 1 for a mismatch before combining traits. There is no ordering such as
generalist < cursorial < scansorial < semifossorial.

The present mapping has seven cursorial species and two singleton categories.
Among 36 unordered species pairs, 21 share a C2 category and 15 do not.
**Renaming only the hedgehog's singleton from semifossorial to terrestrial_generalist
would leave every C2 pair distance unchanged**, provided no other taxon changes
group. A more accurate name can improve biological interpretation without changing
H3 numerically. This was checked by comparing all 36 nominal pair indicators;
no revised category was adopted and no H3 model was run.

If bison, cattle or other taxa change group, the hedgehog-only invariance result
no longer establishes unchanged distances. Recalculate the complete distance
matrix for any such adopted mapping before reporting revised H3 results.

The use of equal mismatch penalties is an explicit simplification of overlapping
specializations, not a measured biomechanical distance. Do not invent numeric
closeness between category pairs without evidence. Check overlap with C3 body
configuration, C7 foraging mode and E2 vertical-use scope. Splitting C2 into several
binary traits would change its effective weight and requires a separate decision.

## Primary references checked

**L1.** Kilbourne, B. M. & Hoffman, L. C. (2013). Scale Effects between Body Size
and Limb Design in Quadrupedal Mammals. *PLoS ONE*, 8(11), e78392.
[DOI](https://doi.org/10.1371/journal.pone.0078392);
[full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC3832634/).
Checked: Methods, Study Sample, and Table 1. Basis for the broad specialization
vocabulary and the three exact-taxon table assignments above. No body masses
from this paper replace the C1 values.

**L2.** Samuels, J. X., Meachen, J. A. & Sakai, S. A. (2013).
Postcranial morphology and the locomotor habits of living and extinct carnivorans.
*Journal of Morphology*, 274(2), 121–146.
[DOI](https://doi.org/10.1002/jmor.20077);
[PubMed](https://pubmed.ncbi.nlm.nih.gov/22972188/).
Abstract checked: anatomical differentiation among locomotor groups supports the
mechanistic rationale. It is not used here as an unseen species-by-species coding table.

**L3.** Carvalho Coutinho, L. & de Oliveira, J. A. (2017).
Relating appendicular skeletal variation of sigmodontine rodents to locomotion
modes in a phylogenetic context. *Journal of Anatomy*, 231(4), 543–567.
[DOI](https://doi.org/10.1111/joa.12665);
[full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC5603790/).
Checked: Determination of locomotion modes. Helps distinguish habitual excavation
and generalized terrestrial locomotion; its rodent categories do not independently
validate the hedgehog code or a mammal-wide classification.

**L4.** Neveu, P. & Gasc, J.-P. (2002). Lipotyphla limb myology comparison.
*Journal of Morphology*, 252(2), 183–201.
[DOI](https://doi.org/10.1002/jmor.1098);
[PubMed](https://pubmed.ncbi.nlm.nih.gov/11921044/).
Abstract checked only. This is a relevant anatomical lead for Erinaceus europaeus;
a definitive locomotor-specialization assignment was not extracted.

**L5.** Neveu, P., Villanova, J. & Gasc, J.-P. (2001).
Modelisation of an unspecialised quadruped walking mammal.
*Comparative Biochemistry and Physiology Part A: Molecular & Integrative
Physiology*, 131(1), 135–144.
[DOI](https://doi.org/10.1016/S1095-6433(01)00460-3);
[publisher](https://www.sciencedirect.com/science/article/abs/pii/S1095643301004603);
[PubMed](https://pubmed.ncbi.nlm.nih.gov/11733172/).

**L6.** White, C. R. (2003). The Influence of Foraging Mode and Arid Adaptation
on the Basal Metabolic Rates of Burrowing Mammals.
*Physiological and Biochemical Zoology*, 76(1), 122–134.
[DOI](https://doi.org/10.1086/367940);
[author-uploaded full text](https://www.researchgate.net/publication/10804233_The_Influence_of_Foraging_Mode_and_Arid_Adaptation_on_the_Basal_Metabolic_Rates_of_Burrowing_Mammals).

**L7.** Bolfíková, B. & Hulva, P. (2012). Microevolution of sympatry: landscape
genetics of hedgehogs Erinaceus europaeus and E. roumanicus in Central Europe.
*Heredity*, 108, 248–255.
[DOI](https://doi.org/10.1038/hdy.2011.67);
[publisher PDF](https://www.nature.com/articles/hdy201167.pdf).
Issue year 2012; first published online in 2011.

**L8.** Serrat, M. A. et al. (2007). Variation in mammalian proximal femoral
development: comparative analysis of two distinct ossification patterns.
*Journal of Anatomy*, 210(3), 249–258.
[DOI](https://doi.org/10.1111/j.1469-7580.2007.00694.x);
[article](https://pmc.ncbi.nlm.nih.gov/articles/PMC2100278/).

**L9.** Basu, C. & Hutchinson, J. R. (2022). Low effective mechanical advantage
of giraffes' limbs during walking reveals trade-off between limb length and
locomotor performance. *PNAS*, 119(28), e2108471119.
[DOI](https://doi.org/10.1073/pnas.2108471119);
[institutional PDF](https://rvc-repository.worktribe.com/preview/1586980/Basu%202022%20Giraffid%20EMA.pdf).

**L10.** Bouma, H. W. et al. (2013). Mammal Hip Morphology and Function:
Coxa Recta and Coxa Rotunda. *The Anatomical Record*, 296(2), 250–256.
[DOI](https://doi.org/10.1002/ar.22634);
[author-uploaded full text](https://www.researchgate.net/publication/233901723_Mammal_Hip_Morphology_and_Function_Coxa_Recta_and_Coxa_Rotunda).

**L11.** Kemp, T. J., Bachus, K. N., Nairn, J. A. & Carrier, D. R. (2005).
Functional trade-offs in the limb bones of dogs selected for running versus fighting.
*Journal of Experimental Biology*, 208, 3475–3482.
[DOI](https://doi.org/10.1242/jeb.01814);
[PubMed](https://pubmed.ncbi.nlm.nih.gov/16155220/).

**L12.** Eisenmann, V. (2022). Old World Fossil Equus (Perissodactyla, Mammalia),
Extant Wild Relatives and Incertae Sedis Forms. *Quaternary*, 5(3), 38.
[DOI](https://doi.org/10.3390/quat5030038);
[author-hosted PDF](https://veraeisenmann.com/public/WEB/PUBLICATIONS/2010-2024/2022%20165%20Old%20World%20Fossil%20Equus%2C%20quaternary-05-00038-v3.pdf).

**L13.** Belyaev, R. I., Kuznetsov, A. N. & Prilepskaya, N. E. (2023).
Truly dorsostable runners: Vertebral mobility in rhinoceroses, tapirs, and horses.
*Journal of Anatomy*, 242, 568–591.
[DOI](https://doi.org/10.1111/joa.13799);
[full-text PDF](https://www.rhinoresourcecenter.com/pdf_files/168/1682158253.pdf).
Issue year 2023; copyright/online publication in 2022.

**L14.** Belyaev, R. I., Kuznetsov, A. N. & Prilepskaya, N. E. (2021).
How the even-toed ungulate vertebral column works: Comparison of intervertebral
mobility in 33 genera. *Journal of Anatomy*, 239(6), 1370–1399.
[DOI](https://doi.org/10.1111/joa.13521);
[article](https://pmc.ncbi.nlm.nih.gov/articles/PMC8602029/).

**L15.** Kahvecioğlu, O. et al. (2026). Patellar shape diversity as a functional
indicator of locomotor specialization in selected ruminant species.
*Scientific Reports*, 16, 3418.
[DOI](https://doi.org/10.1038/s41598-025-33370-3).
Publisher citation year/version of record: 2026; initially published online
26 December 2025, version of record dated 26 January 2026.

**L16.** Szangolies, L. (2017). *Analyse hochauflösender 3D-Beschleunigungsdaten
zur automatischen Differenzierung von Verhaltensweisen bei Tieren*.
Bachelor's thesis, University of Greifswald / Leibniz-IZW; submitted 31 October 2017.
Supplied file: `Bsc_Leonna Szangolies.pdf`. Section 2.1.1 and Table 2,
printed pp. 4–5 / PDF pp. 11–12, checked for dog breed/cohort scope.
This source describes the recorded cohort, not a formal locomotor-category scheme.

**L17.** Groth, R. (2020). *Analysis of three-dimensional acceleration data from
similar dogs with automatic behaviour classification by using machine learning
algorithms*. Master's thesis, University of Potsdam / Leibniz-IZW.
Supplied file: `Msc Rieka Groth 2020.pdf`. Section 2.1.1 and Table 2,
printed pp. 6–7 / PDF pp. 17–18, checked for the source cohort's breeds.
The breed detail on printed p. 7 distinguishes Labrador and Golden Retrievers;
the preceding broad “one breed” description is not treated as a literal
single-breed inventory. See the separate inclusion audit for processed-data limits.

## Current disposition

**C2 definition and coding confirmed and implemented (D32, 2026-11-02).**
Final distribution: seven broad cursorial taxa, one scansorial raccoon and one
terrestrial-generalist hedgehog. Literature evidence, author inference, contrary
terminology and breed/cohort limitations are documented. Analytical robustness
beyond the verified nominal-distance invariance remains separate from this coding
decision. C1 remains closed under D30; later traits remain in the review queue.
