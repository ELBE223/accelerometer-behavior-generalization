# Supplementary Text S1. Sensitivity scenarios

> **Draft.** The scenario definitions are taken from `00_Documentation/decisions.md`
> (D11, D27). The wording for the supplement is still to be written. Results: Table S20.

The sensitivity scenarios were specified before any model was trained (D01, D11). They
test how far the conclusions depend on preprocessing and labeling choices. Each scenario
changes one element of the primary analysis. The primary analysis uses 2.0-s windows
with 50% overlap in training and none in evaluation, pure windows, three classes, 25 Hz
and all eligible individuals.

| Scenario | Change from the primary analysis |
|---|---|
| A | 2.0-s windows without overlap in training |
| C | 2.4-s windows (60 samples) without overlap; close to the 2.46-s windows of the theses, with a margin in the 2.46-s bursts of Bison 1, Horse 1 and Giraffe 1 |
| Majority class | A window is assigned to a class if at least 80% of its samples belong to that class, instead of all samples (samples with an excluded label or without a label count against it) |
| Four classes | Other is kept as a fourth class |
| E | Ridden gaits of Horse 2 are assigned to Locomotion, as in the original thesis |
| F | Only individuals with all three classes and at least 10 evaluation windows each, in all evaluations |

Because of computing time, all scenarios were run with Random Forest and LightGBM only
(D27), with the same five seeds and the same statistics as the primary analysis. For a
comparable H3 reference, the primary mixed model was also fitted to the RF and LightGBM
results alone. The scenarios are interpreted descriptively against the primary analysis.
