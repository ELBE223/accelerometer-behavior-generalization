# Supplementary Text S1. Sensitivity scenarios

The sensitivity scenarios were specified before any model was trained. Each changes one
element of the primary analysis to show how far the conclusions depend on preprocessing
and labeling choices. The primary analysis uses 2.0-s windows at 25 Hz, with 50% overlap
in training and none in evaluation. It uses only windows whose samples all belong to one
of three classes, and all eligible individuals.

| Scenario | Change from the primary analysis |
|---|---|
| No training overlap | 2.0-s windows without overlap in training (evaluation unchanged) |
| 2.4-s windows | 2.4-s windows (60 samples) without overlap in training and evaluation |
| Majority label (80%) | A window takes the class of at least 80% of its samples instead of requiring all samples to belong to one class; samples with an excluded label or without a label count against the 80% |
| Four classes (with Other) | Behaviors outside the three target classes are kept as a fourth class, Other |
| Ridden gaits as locomotion | Ridden gaits of Horse 2 (walking, trotting and galloping with a rider) and jumping are assigned to Locomotion |
| Eligible individuals only | Only individuals with all three classes and at least ten evaluation windows in each, in all evaluations |

Because of the computing time of the signal-based networks, all scenarios were run with
Random Forest and LightGBM only, with the same five training seeds and the same
statistical procedures as the primary analysis. For a comparable H3 reference, the primary
mixed model was also fitted to the RF and LightGBM results of the primary analysis alone.
The scenarios are compared descriptively with the primary analysis (Table S20).

In every scenario, within-dataset Macro-F1 exceeded cross-dataset Macro-F1 for both
classifiers (median paired differences 0.087–0.158; Wilcoxon p ≤ 0.023), compared with
0.096–0.101 in the primary analysis. Cross-dataset F1 differed among behavioral classes
(H2) in all scenarios except for RF with 2.4-s windows (χ²(2) = 4.91, p = 0.086). In the
four-class scenario, the Friedman test compared four classes and is therefore not directly
comparable. The association between trait distance and cross-species Macro-F1 (H3) stayed
negative and non-significant in all scenarios (β −0.011 to −0.001 per SD; p ≥ 0.347), as
in the primary model fitted to RF and LightGBM (β −0.010, p = 0.526).
