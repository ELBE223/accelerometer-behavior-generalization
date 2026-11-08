# 00_Documentation

Hand-made inputs of the analysis. The CSV files are read by the code, so each mapping
exists only once.

| File | Content | Paper |
|---|---|---|
| `datasets.csv` | Datasets: species, source, setting, sensor position, raw unit, dataset-specific steps | Tables S1, S3 |
| `sensor_settings.csv` | Sensor and sampling per dataset | Tables S1, S3 |
| `behavior_mapping.csv` | Original label → class (and the class in the scenario with ridden gaits) | Table S2 |
| `traits/` | Core traits: definitions (`core_traits.md`, `core_trait_definitions.csv`), values per species, two exploratory traits | Tables S6, S7, S9 |
| `timetree_species_list.nwk` | TimeTree 5 tree of the nine species | Tables 3, S8 |
| `decisions.md` | Methodological decisions, referred to as Dxx in the code | Methods |
