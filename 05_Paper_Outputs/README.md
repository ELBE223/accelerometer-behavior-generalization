# 05_Paper_Outputs

All tables and figures of the manuscript and the supplement, numbered, titled and annotated
as there.

| Folder / file | Content |
|---|---|
| `main/` | Tables 1–3, Figures 1–3 (with captions) |
| `supplementary/` | Tables S1–S17; Figures S1 (workflow), S2 (transfer loss), S3 (confusion matrices) with captions; Texts S1–S2 |
| `assets/` | Hand-made source of Figure S1 (workflow diagram), copied to `supplementary/` |
| `output_manifest.csv` | Each item with its title, file, source data, the script that made them, and where it is cited |

Tables are tab-separated text (in Word: Insert > Table > Convert Text to Table): title,
header row(s), rows, then the table note. `<br>` marks a line break within a cell (Table S1;
in Word: replace `<br>` with `^l`), `—` an empty cell. All files except Texts S1–S2 and the
workflow image are written by `paper_figures.R`; the numbering is defined once at its top,
and generated files are deleted before each run. `tests/check_paper_outputs.py` checks that
the items, titles, numbering, files and cross-references agree with the manuscript and the
supplement. Run both with `bash run_pipeline.sh stats`.
