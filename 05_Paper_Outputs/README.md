# 05_Paper_Outputs

All tables and figures of the manuscript, numbered as cited there.

| Folder / file | Content |
|---|---|
| `main/` | Tables 1–3, Figures 1–3 (with captions) |
| `supplementary/` | Tables S1–S20, Figures S1–S3, Text S1 |
| `output_manifest.csv` | Each item with its title, file, source data, the script that made them, and where the manuscript cites it |

Tables are tab-separated text (in Word: Insert > Table > Convert Text to Table). All files
except Text S1 are written by `paper_figures.R`; the numbering is defined once at its top.
`tests/check_paper_outputs.py` checks that numbering, files and cross-references agree.
Run both with `bash run_pipeline.sh stats`.
