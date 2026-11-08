# 00_Documentation

Everything the analysis decides by hand: which datasets, which labels, which traits and
why. The CSV files are read directly by the code, so each mapping exists only once.

| File | Content | Read by | Paper |
|---|---|---|---|
| `datasets.csv` | Registry of the 12 datasets: species, source, public/DOI, setting, sensor position, raw unit, dataset-specific rules | all pipeline steps, `paper_figures.R` | Tables S1, S3 |
| `sensor_settings.csv` | Sensors and sampling per dataset and setting (rate, bursts, status of each value) | `01_Preprocessing/loaders/common.py`, `paper_figures.R` | Tables S1, S3 |
| `behavior_mapping.csv` | Original label → class (Resting, Locomotion, Foraging, Other, Exclude), with the thesis class and the class of scenario E | `assign_classes.py`, `paper_figures.R` | Table S2 |
| `decisions.md` | Decision log D01–D45: every processing and analysis decision, with reason and status | — | Methods |
| `timetree_species_list.nwk` | TimeTree 5 tree of the nine species (phylogenetic distance) | `04_Statistics/stats_h3.R` | Tables 3, S8 |
| `traits/` | Core traits of H3: definitions and values per species | `stats_h3.R`, `paper_figures.R` | Tables S6, S7 |

## traits/

| File | Content |
|---|---|
| `core_trait_definitions.csv` | The five core traits: definition, coding, sources, main uncertainty (Table S6) |
| `species_traits_core.csv` | Values of the five core traits per species (Table S7; input of the Gower distance) |
| `species_traits_exploratory.csv` | Two traits excluded from the core (trunk motion, directional change), for the exploratory rows of Table S9 |
| `core_traits.md` | Full definitions, sources, coding rules and the link of each trait to the acceleration signal |

Fox_dataset_2 is in the registry but left out of the analysis (D14).
Paths in decisions D01–D43 refer to the earlier layouts; D44 lists the old and new
locations. The trait reviews and audits behind each value (D29–D39, D42), the thesis
scripts and the raw data review are kept in the archived repository
`ELBE223/paper-izw-cross-species-transfer` (D45).
