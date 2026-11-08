# Core Trait Definitions Sources and Coding

> Definitions and coding of the five core traits (D37). Machine-readable values:
> [species_traits_core.csv](species_traits_core.csv).

The final core set covers body mass, locomotor specialization, body configuration, relative neck length, and food acquisition and handling. Literature supports the traits and source data; some categories are our own analytical assignments.

| Trait | Definition | Selected sources | Coding |
|---|---|---|---|
| **Body mass** | The selected body mass reference for each study taxon, used as a measure of body size. Depending on the taxon, this is an external reference value, a cohort mean, or an aggregate of study means. | Wilman et al. (2014) [1]: EltonTraits.<br>Gerstner & Gerstein (2008) [2]: Przewalski’s horse.<br>Cohort sources are specified in the legend. | Continuous: natural logarithm of mass in grams, ln(mass in g). One reference value per taxon; no size categories. |
| **Locomotor specialization** | Broad classification based on locomotor anatomy and habitual substrate use. Describes specialization rather than the frequency of individual gaits. | Kilbourne & Hoffman (2013) [3]: locomotor groups.<br>Neveu et al. (2001) [4]: generalized locomotion in the hedgehog. | Nominal, three groups:<br>cursorial<br>scansorial<br>terrestrial generalist<br>Our broad grouping of the literature evidence. |
| **Body configuration** | Broad relative proportions of the trunk, limbs, and neck in an ordinary standing posture. Describes overall body form independently of momentary movement. | Prothero (1992) [5]: body proportions.<br>Krasińska & Krasiński (2002) [6]: European bison body measurements.<br>Neither source provides our four groups. | Nominal, four groups:<br>robust quadruped<br>standard quadruped<br>tall long-necked quadruped<br>compact low-profile body<br>Our morphological classification. |
| **Relative neck length** | Length of the cervical vertebral column relative to the combined thoracic, lumbar, and sacral regions. An anatomical proxy, not a measure of actual neck movement. | Belyaev et al. (2024), Supplement S1 [7]: vertebral measurements.<br>Davis (1964), Table 10 [8]: indirect evidence for Procyon. | Ordinal, four groups based on r = C/(T + L + S):<br>short: r < 0.30<br>intermediate: 0.30 ≤ r < 0.40<br>long: 0.40 ≤ r < 1.00<br>very long: r ≥ 1.00<br>Thresholds defined by us. |
| **Food acquisition and handling** | Characteristic actions used to acquire and handle food at the taxon level. Does not encode feeding height or the proportions of observed foraging windows. | Iwaniuk & Whishaw (1999) [9]: raccoon food handling with the forepaws.<br>Kowalczyk et al. (2019) [10]: dietary flexibility in European bison. | Nominal, three groups:<br>vegetation cropping<br>oral item acquisition<br>manual food handling<br>Our synthesis; not a published, validated three-group classification. |

Each selected source supports the aspect stated in the table. The selection complements the taxon-specific evidence and uncertainty records summarized in [decisions.md](../decisions.md) (D30–D37). Categories and assignment rules are explained in the legend.

## Species assignments

Assignments for the nine study taxa under the final core set.

| Species | Body mass ln(g) | Locomotor specialization | Body configuration | Relative neck length | Food acquisition and handling |
|---|---:|---|---|---|---|
| *Bison bonasus* | 13.122 | cursorial | robust quadruped | intermediate | vegetation cropping |
| *Bos taurus* | 13.710 | cursorial | robust quadruped | intermediate | vegetation cropping |
| *Canis lupus familiaris* | 10.194 | cursorial | standard quadruped | intermediate | oral item acquisition |
| *Equus caballus* | 12.429 | cursorial | standard quadruped | long | vegetation cropping |
| *Equus ferus przewalskii* | 12.612 | cursorial | standard quadruped | long | vegetation cropping |
| *Erinaceus europaeus* | 6.939 | terrestrial generalist | compact low-profile body | short\* | oral item acquisition |
| *Giraffa camelopardalis* | 13.710 | cursorial | tall long-necked quadruped | very long | vegetation cropping |
| *Procyon lotor* | 8.617 | scansorial | standard quadruped | short† | manual food handling |
| *Vulpes vulpes* | 8.608 | cursorial | standard quadruped | intermediate | oral item acquisition |

Body mass values are the existing log-transformed entries in the trait matrix, retained at three decimal places. They have not been recalculated from rounded kilogram values.

**\*** The short-neck assignment for the European hedgehog is based on expert judgement; intermediate is a plausible sensitivity alternative.

**†** The short-neck assignment for the raccoon is supported indirectly by the Procyon proportions reported by Davis (1964). Other neck-length assignments also have limited anatomical sample sizes; see the legend.

## Expected link to the acceleration signal

Each trait describes a way in which the same behavior may produce a different acceleration signal in different species. These are hypothesised mechanisms that motivate the selection of the traits; they are not demonstrated effects on transfer performance.

**Body mass.** Larger quadrupeds move with lower stride frequencies at equivalent speeds [11], so the cadence and frequency content of locomotion and other periodic movements shift with body size; a classifier trained on one size class may misread the rhythm of another.

**Locomotor specialization.** Limb design and habitual substrate use shape gait mechanics [3]. Climbing or generalized slow ground locomotion produce movement patterns and logger orientations that do not occur in cursorial species, so locomotion of different groups may look different in the signal.

**Body configuration.** The static component of the acceleration reflects how the body and the logger are oriented relative to gravity [12]. Body proportions in standing posture change the tilt of trunk and neck and hence the posture signal that separates resting from active behavior.

**Relative neck length.** With collar-mounted loggers, head and neck movements are recorded directly: a long neck allows larger head excursions during feeding and moves with the gait in walking giraffes [13], whereas a short neck couples the logger more closely to trunk motion. The argument does not apply to back-mounted loggers, such as the harness of one juvenile raccoon in the study data.

**Food acquisition and handling.** The Foraging class combines the actions used to obtain food: repeated cropping bites with the head lowered, intermittent search and pick-up of single items, or grasping and scraping with the forepaws [9]. These actions differ in rhythm and in the body parts that move, so Foraging windows may transfer better between species that acquire food in the same way.

## Legend and assignment rules

**Data types.** Continuous = a numerical value; nominal = categories without rank; ordinal = ordered categories. Relative neck length is ordered short < intermediate < long < very long. Distances between these categories are not measured anatomical distances. Spaces and hyphens in the English category labels are replaced by underscores in the corresponding data codes.

**Locomotor specialization.** Cursorial broadly denotes terrestrial locomotion adapted to running, including heavy ungulates; it does not rank running performance. Scansorial combines ground locomotion with habitual climbing. Terrestrial generalist denotes generalized ground locomotion without dominant running, climbing, or digging specialization. The hedgehog is therefore a generalist under this operational definition; alternative ecological descriptions such as semifossorial are not excluded.

**Body configuration.** Robust quadruped = a substantial, trunk-dominated build (European bison, cattle); standard quadruped = a generalized quadrupedal body form (dog, both horse taxa, raccoon, fox); tall long-necked quadruped = tall limbs and a markedly elongated neck (giraffe); compact low-profile body = a compact body held close to the ground (hedgehog). These groups have no uniform measurement thresholds. The raccoon assignment and variation among dog breeds remain sources of uncertainty.

**Relative neck length.** C, T, L, and S denote the lengths of the cervical, thoracic, lumbar, and sacral vertebral regions. Seven taxa are covered by compatible vertebral measurements, with only one or two adult specimens per taxon. Davis provides indirect support for short in Procyon: a cervical share of 21–22% of C + T + L implies a maximum C/(T + L) of approximately 0.282, even before adding S to the denominator. Measurement comparability and small samples limit confidence. The hedgehog assignment remains expert judgement, with intermediate as a plausible sensitivity alternative. Cattle are close to the 0.30 threshold; the dog specimen does not represent variation across breeds.

**Food acquisition and handling.** Vegetation cropping = biting, plucking, or stripping plant material (European bison, cattle, both horse taxa, giraffe); oral item acquisition = primarily oral acquisition of individual food items or prey without characteristic specialized forepaw handling (dog, hedgehog, fox); manual food handling = characteristic grasping, examining, or manipulating with the forepaws (raccoon). Where actions overlap, pronounced manual handling takes priority, followed by vegetation cropping. The classification implies neither exclusive use of an action nor a measured frequency threshold.

**Body mass provenance.** EltonTraits provides six references: European bison, cattle, domestic horse, giraffe, raccoon, and fox. The 300 kg reference for Przewalski’s horse comes from Gerstner & Gerstein [2], Table 1. The hedgehog value of 1.032 kg comes from Cibis (2017), Table 4. The dog value of 26.7464 kg is the equally weighted mean of two study means from Szangolies (2017), Table 2, and Groth (2020), Table 2. It is not a pooled mean of all dogs analysed in the model. Full cohort sources are available from the authors on request.

**Scope and next step.** Literature data, derived categories, and expert assignments are documented separately. Sources and clearly defined categories do not by themselves validate an association with transfer performance. The adopted classification should be evaluated through sensitivity analyses of uncertain assignments and omission of individual traits; these analyses have not yet been performed.

**Decision status.** Final (5 November 2026, decision D37). Body mass, locomotor specialization, and body configuration are retained from the previous decisions. Relative neck length and the three food acquisition and handling groups are adopted; they replace the earlier head-neck contribution and feeding/foraging mode traits. Trunk motion amplitude and directional change tendency are excluded from the main distance and used only in exploratory comparisons. These tables do not report a newly calculated H3 analysis.

## Selected references

**[1]** Wilman, H., et al. (2014). EltonTraits 1.0: Species-level foraging attributes of the world’s birds and mammals. Ecology, 95, 2027. [Source](https://doi.org/10.1890/13-1917.1)

**[2]** Gerstner, G. E., & Gerstein, J. B. (2008). Chewing Rate Allometry Among Mammals. Journal of Mammalogy, 89, 1020–1030. Table 1 provides the reference mass for Przewalski’s horse. [Source](https://doi.org/10.1644/07-MAMM-A-188.1)

**[3]** Kilbourne, B. M., & Hoffman, L. C. (2013). Scale Effects between Body Size and Limb Design in Quadrupedal Mammals. PLoS ONE, 8, e78392. [Source](https://doi.org/10.1371/journal.pone.0078392)

**[4]** Neveu, P., Villanova, J., & Gasc, J.-P. (2001). Modelisation of an unspecialised quadruped walking mammal. Comparative Biochemistry and Physiology A, 131, 135–144. [Source](https://doi.org/10.1016/S1095-6433(01)00460-3)

**[5]** Prothero, J. (1992). Scaling of bodily proportions in adult terrestrial mammals. American Journal of Physiology, 262, R492–R503. [Source](https://doi.org/10.1152/ajpregu.1992.262.3.R492)

**[6]** Krasińska, M., & Krasiński, Z. A. (2002). Body mass and measurements of the European bison during postnatal development. Acta Theriologica, 47, 85–106. [Source](https://ibs.bialowieza.pl/g2/pdf/1357.pdf)

**[7]** Belyaev, R. I., et al. (2024). Running, jumping, hunting, and scavenging: Functional analysis of vertebral mobility and backbone properties in carnivorans. Journal of Anatomy, 244, 205–231. Supplement S1, including the ungulate data. [Source](https://doi.org/10.1111/joa.13955)

**[8]** Davis, D. D. (1964). The giant panda: A morphological study of evolutionary mechanisms. Fieldiana Zoology Memoirs, 3. Table 10, p. 75, reports the Procyon proportions. [Source](https://libsysdigi.library.uiuc.edu/OCA/Books2010-10/giantpandamorpho03davi/giantpandamorpho03davi.pdf)

**[9]** Iwaniuk, A. N., & Whishaw, I. Q. (1999). How skilled are the skilled limb movements of the raccoon (Procyon lotor)? Behavioural Brain Research, 99, 35–44. [Source](https://doi.org/10.1016/S0166-4328(98)00067-9)

**[10]** Kowalczyk, R., et al. (2019). Foraging plasticity allows a large herbivore to persist in a sheltering forest habitat: DNA metabarcoding diet analysis of the European bison. Forest Ecology and Management, 449, 117474. [Source](https://doi.org/10.1016/j.foreco.2019.117474)

**[11]** Heglund, N. C., & Taylor, C. R. (1988). Speed, stride frequency and energy cost per stride: how do they change with body size and gait? Journal of Experimental Biology, 138, 301–318. [Source](https://doi.org/10.1242/jeb.138.1.301)

**[12]** Shepard, E. L. C., et al. (2008). Identification of animal movement patterns using tri-axial accelerometry. Endangered Species Research, 10, 47–60. [Source](https://doi.org/10.3354/esr00084)

**[13]** Basu, C. K., Wilson, A. M., & Hutchinson, J. R. (2019). The locomotor kinematics and ground reaction forces of walking giraffes. Journal of Experimental Biology, 222, jeb159277. [Source](https://doi.org/10.1242/jeb.159277)

### Traceability of species values

Decisions on the traits are in [decisions.md](../decisions.md) (D30–D38, D43, D48). The detailed evidence behind each value (cohort sources for body mass, vertebral measurements and r values of the relative neck length) is available from the authors on request. The references listed here are a targeted selection and do not imply complete direct evidence for every assignment.
