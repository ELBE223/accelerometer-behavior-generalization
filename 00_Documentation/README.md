# 00_Documentation

Hand-made inputs of the analysis. The CSV files are read by the code, so each mapping
exists only once.

| File | Content | Paper |
|---|---|---|
| `datasets.csv` | Datasets: species, source, study setting, sensor position, sensor and recording settings, raw unit, segment definition, dataset-specific processing | Tables S1, S4 |
| `sensor_settings.csv` | Sensor and sampling per dataset (read by the loaders; checked against the recording settings of Table S1) | Tables S1, S4 |
| `behavior_mapping.csv` | Original label → class (and the class in the scenario with ridden gaits) | Table S3 |
| `traits/` | Core traits: definitions (`core_traits.md`, `core_trait_definitions.csv`), values per species (`species_traits_core.csv`); EltonTraits rows of the study species (`eltontraits_study_species.txt`) | Tables S7, S8, S13; Table 3; Text S2 |
| `timetree_species_list.nwk` | TimeTree 5 tree of the nine species | Tables 3, S13 |
| `decisions.md` | Methodological decisions, referred to as Dxx in the code | Methods |
