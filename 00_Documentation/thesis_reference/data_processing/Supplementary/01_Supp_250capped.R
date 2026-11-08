# Figure S2: Training-cap diagnostic
# Shows why 250 windows per dataset-behavior group were used

library(readr)
library(dplyr)
library(ggplot2)
library(scales)

# Paths
input_file <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Models/Diagnostics_Class_Distribution/cap_feasibility_long.csv"

out_dir <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processing/Supplementary/plots/figures"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Check input
if (!file.exists(input_file)) {
  stop("File not found: ", input_file)
}

# Read data
cap_long <- read_csv(input_file, show_col_types = FALSE)

# Summarise feasibility per cap
cap_summary <- cap_long %>%
  group_by(cap_candidate) %>%
  summarise(
    dataset_behavior_groups = n(),
    groups_reaching_cap = sum(can_reach_cap_in_train_approx, na.rm = TRUE),
    prop_groups_reaching_cap = mean(can_reach_cap_in_train_approx, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(cap_candidate)

# Save summary table
write_csv(
  cap_summary,
  file.path(out_dir, "Figure_S2_training_cap_summary.csv")
)

# Plot
p <- ggplot(
  cap_summary,
  aes(
    x = factor(cap_candidate),
    y = prop_groups_reaching_cap
  )
) +
  geom_col(width = 0.7) +
  geom_hline(
    yintercept = 0.75,
    linetype = "dashed"
  ) +
  geom_vline(
    xintercept = which(cap_summary$cap_candidate == 250),
    linetype = "dotted"
  ) +
  geom_text(
    aes(label = paste0(groups_reaching_cap, "/", dataset_behavior_groups)),
    vjust = -0.4,
    size = 3.5
  ) +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, 1.08),
    breaks = seq(0, 1, 0.25)
  ) +
  labs(
    x = "Training cap candidate",
    y = "Dataset-behavior groups reaching cap",
    title = "",
    subtitle = ""
  ) +
  theme_classic(base_size = 12)

# Save figure
ggsave(
  filename = file.path(out_dir, "Figure_S2_training_cap_diagnostic.png"),
  plot = p,
  width = 7,
  height = 4.5,
  dpi = 300
)

ggsave(
  filename = file.path(out_dir, "Figure_S2_training_cap_diagnostic.pdf"),
  plot = p,
  width = 7,
  height = 4.5
)

# Print plot
print(p)

# Console message
message("Figure S2 saved to: ", out_dir)