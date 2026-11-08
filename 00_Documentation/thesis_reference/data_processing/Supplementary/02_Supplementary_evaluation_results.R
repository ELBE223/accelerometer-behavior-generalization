# =============================================================================
# Supplementary evaluation results
# Table S8, Table S9, and Figure S3
# =============================================================================
# Table S8: Inter-dataset transfer results
# Table S9: Pooled multi-dataset evaluation results
# Figure S3: Inter-dataset vs pooled multi-dataset Macro-F1
# =============================================================================

# ── 1. Setup ──────────────────────────────────────────────────────────────────
if (!requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman", repos = "https://cloud.r-project.org")
}

pacman::p_load(readr, dplyr, tidyr, ggplot2, purrr, tibble, stringr)


# ── 2. Paths ──────────────────────────────────────────────────────────────────
base_dir      <- "/Volumes/Z Slim/11_05_2026_Data_Analysis"
models_dir    <- file.path(base_dir, "Models")
output_r_root <- file.path(base_dir, "Output_R")
out_dir       <- file.path(output_r_root, "Supplementary_Evaluation")

csv_dir   <- file.path(out_dir, "csv")
plots_dir <- file.path(out_dir, "plots")
txt_dir   <- file.path(out_dir, "txt")

if (!dir.exists(models_dir)) {
  stop("Models folder not found: ", models_dir)
}

for (d in c(output_r_root, out_dir, csv_dir, plots_dir, txt_dir)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}


# ── 3. Constants ──────────────────────────────────────────────────────────────
model_levels    <- c("CNN", "ResNet", "HYDRA", "MultiRocket", "RF", "LGBM")
behavior_levels <- c("Foraging", "Locomotion", "Resting")

inter_label  <- "Inter-dataset transfer"
pooled_label <- "Pooled multi-dataset evaluation"


# ── 4. Dataset lookup ─────────────────────────────────────────────────────────
# Keep this lookup aligned with Supplementary Table S1.
dataset_lookup <- tribble(
  ~dataset, ~common_name, ~scientific_name,
  "Bison_dataset_1",    "European bison",     "Bison bonasus",
  "Cattle_dataset_1",   "Cattle",             "Bos taurus",
  "Dog_dataset_1",      "Domestic dog",       "Canis lupus familiaris",
  "Dog_dataset_2",      "Domestic dog",       "Canis lupus familiaris",
  "Horse_dataset_1",    "Domestic horse",     "Equus caballus",
  "Horse_dataset_2",    "Przewalski's horse", "Equus ferus przewalskii",
  "Hedgehog_dataset_1", "European hedgehog",  "Erinaceus europaeus",
  "Giraffe_dataset_1",  "Giraffe",            "Giraffa camelopardalis",
  "Raccoon_dataset_1",  "Raccoon",            "Procyon lotor",
  "Raccoon_dataset_2",  "Raccoon",            "Procyon lotor",
  "Fox_dataset_1",      "Red fox",            "Vulpes vulpes",
  "Fox_dataset_2",      "Red fox",            "Vulpes vulpes"
)


# ── 5. Input registry ─────────────────────────────────────────────────────────
mode_dir <- function(model, mode) {
  file.path(models_dir, model, paste0(mode, "_", model), "statistics")
}

input_registry <- expand_grid(
  model = model_levels,
  evaluation = c("inter", "pooled")
) %>%
  mutate(
    statistics_dir = ifelse(
      evaluation == "inter",
      map_chr(model, ~ mode_dir(.x, "Inter")),
      map_chr(model, ~ mode_dir(.x, "Global"))
    ),
    metrics_file = ifelse(
      evaluation == "inter",
      file.path(statistics_dir, "metrics_all.csv"),
      file.path(statistics_dir, "overall_metrics.csv")
    ),
    behavior_file = ifelse(
      evaluation == "inter",
      file.path(statistics_dir, "behavior_metrics_all.csv"),
      file.path(statistics_dir, "behavior_metrics.csv")
    ),
    statistics_dir_exists = dir.exists(statistics_dir),
    metrics_exists = file.exists(metrics_file),
    behavior_exists = file.exists(behavior_file)
  )


# ── 6. Helpers ────────────────────────────────────────────────────────────────
print_section <- function(x) {
  cat("\n", strrep("=", 18), x, strrep("=", 18), "\n", sep = " ")
}

fmt_num <- function(x, digits = 3) {
  ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
}

format_mean_sd <- function(mean_val, sd_val) {
  ifelse(is.na(mean_val), "NA", sprintf("%.3f ± %.3f", mean_val, sd_val))
}

format_median_iqr <- function(median_val, q1_val, q3_val) {
  ifelse(
    is.na(median_val),
    "NA",
    sprintf("%.3f [%.3f, %.3f]", median_val, q1_val, q3_val)
  )
}

sanitize_id <- function(x) {
  x <- as.character(x)
  x <- str_replace_all(x, "[^A-Za-z0-9_]+", "_")
  str_replace_all(x, "^_+|_+$", "")
}

normalize_behavior <- function(x) {
  x <- str_to_lower(str_trim(as.character(x)))
  case_when(
    x == "foraging"   ~ "Foraging",
    x == "locomotion" ~ "Locomotion",
    x == "resting"    ~ "Resting",
    TRUE ~ as.character(x)
  )
}

ensure_cols <- function(df, cols) {
  for (cc in cols) {
    if (!cc %in% names(df)) {
      df[[cc]] <- NA
    }
  }
  df
}

first_existing_col <- function(df, candidates) {
  hit <- candidates[candidates %in% names(df)][1]
  if (length(hit) == 0 || is.na(hit)) {
    return(rep(NA_character_, nrow(df)))
  }
  as.character(df[[hit]])
}

safe_read_csv <- function(file) {
  if (is.na(file) || !file.exists(file)) {
    return(tibble())
  }
  read_csv(file, show_col_types = FALSE)
}

safe_sum_n <- function(df) {
  if (nrow(df) == 0) {
    return(NA_real_)
  }
  n_col <- c("N", "n", "count", "rows")
  n_col <- n_col[n_col %in% names(df)][1]
  if (length(n_col) == 0 || is.na(n_col)) {
    return(nrow(df))
  }
  sum(as.numeric(df[[n_col]]), na.rm = TRUE)
}

parse_train_test_from_pair <- function(pair_id) {
  tmp <- tibble(pair_id = as.character(pair_id)) %>%
    separate(
      pair_id,
      into = c("train_dataset_parsed", "test_dataset_parsed"),
      sep = "__to__",
      remove = FALSE,
      fill = "right",
      extra = "merge"
    )
  tmp %>% select(train_dataset_parsed, test_dataset_parsed)
}

read_recursive_files <- function(stats_dir, target_name) {
  if (!dir.exists(stats_dir)) {
    return(character())
  }
  files <- list.files(stats_dir, recursive = TRUE, full.names = TRUE)
  files[basename(files) == target_name]
}

read_recursive_table <- function(stats_dir, target_name, model) {
  files <- read_recursive_files(stats_dir, target_name)
  if (length(files) == 0) {
    return(tibble())
  }
  
  map_dfr(files, function(f) {
    parent_id <- basename(dirname(f))
    dt <- read_csv(f, show_col_types = FALSE)
    dt %>%
      mutate(
        model = model,
        source_file = f,
        pair_id = first_existing_col(., c("pair_id")),
        pair_id = ifelse(is.na(pair_id) | pair_id == "", parent_id, pair_id),
        pair_id_clean = sanitize_id(pair_id)
      )
  })
}

empty_behavior_wide <- function() {
  tibble(
    model = character(),
    pair_id_clean = character(),
    f1_foraging = numeric(),
    f1_locomotion = numeric(),
    f1_resting = numeric()
  )
}

make_behavior_wide <- function(df) {
  if (nrow(df) == 0 || !"behavior" %in% names(df) || !"f1" %in% names(df)) {
    return(empty_behavior_wide())
  }
  
  if (!"pair_id_clean" %in% names(df)) {
    df$pair_id_clean <- sanitize_id(first_existing_col(df, c("pair_id")))
  }
  if (!"model" %in% names(df)) {
    df$model <- NA_character_
  }
  
  out <- df %>%
    mutate(behavior = normalize_behavior(behavior)) %>%
    filter(behavior %in% behavior_levels) %>%
    select(model, pair_id_clean, behavior, f1) %>%
    distinct() %>%
    pivot_wider(
      names_from = behavior,
      values_from = f1,
      names_prefix = "f1_"
    ) %>%
    rename_with(~ str_to_lower(.x), starts_with("f1_"))
  
  ensure_cols(out, c("f1_foraging", "f1_locomotion", "f1_resting")) %>%
    select(model, pair_id_clean, f1_foraging, f1_locomotion, f1_resting)
}

empty_balance_summary <- function(out_col) {
  tibble(model = character(), pair_id_clean = character(), !!out_col := numeric())
}

summarise_balance_recursive <- function(stats_dir, target_name, model, out_col) {
  dt <- read_recursive_table(stats_dir, target_name, model)
  if (nrow(dt) == 0) {
    return(empty_balance_summary(out_col))
  }
  
  n_col <- c("N", "n", "count", "rows")
  n_col <- n_col[n_col %in% names(dt)][1]
  
  if (length(n_col) == 0 || is.na(n_col)) {
    dt %>%
      group_by(model, pair_id_clean) %>%
      summarise("{out_col}" := n(), .groups = "drop")
  } else {
    dt %>%
      group_by(model, pair_id_clean) %>%
      summarise("{out_col}" := sum(as.numeric(.data[[n_col]]), na.rm = TRUE), .groups = "drop")
  }
}

add_species_pair <- function(df) {
  df %>%
    left_join(dataset_lookup, by = c("train_dataset" = "dataset")) %>%
    rename(
      source_common_name = common_name,
      source_scientific_name = scientific_name
    ) %>%
    left_join(dataset_lookup, by = c("test_dataset" = "dataset")) %>%
    rename(
      target_common_name = common_name,
      target_scientific_name = scientific_name
    ) %>%
    mutate(
      species_pair_common = ifelse(
        is.na(source_common_name) | is.na(target_common_name),
        NA_character_,
        paste(source_common_name, "->", target_common_name)
      ),
      species_pair_scientific = ifelse(
        is.na(source_scientific_name) | is.na(target_scientific_name),
        NA_character_,
        paste(source_scientific_name, "->", target_scientific_name)
      )
    )
}

read_dataset_metrics <- function(stats_dir) {
  candidates <- c(
    file.path(stats_dir, "metrics_by_analysis_dataset.csv"),
    file.path(stats_dir, "dataset_metrics.csv"),
    file.path(stats_dir, "metrics_by_dataset.csv")
  )
  hit <- candidates[file.exists(candidates)][1]
  if (length(hit) == 0 || is.na(hit)) {
    return(tibble())
  }
  safe_read_csv(hit)
}

summarise_metric_vector <- function(x) {
  x <- x[is.finite(x) & !is.na(x)]
  if (length(x) == 0) {
    return(tibble(
      n = 0,
      mean = NA_real_,
      sd = NA_real_,
      median = NA_real_,
      q1 = NA_real_,
      q3 = NA_real_,
      mean_sd = NA_character_,
      median_iqr = NA_character_
    ))
  }
  
  mean_val <- mean(x)
  sd_val <- ifelse(length(x) > 1, sd(x), NA_real_)
  median_val <- median(x)
  q1_val <- quantile(x, 0.25, names = FALSE)
  q3_val <- quantile(x, 0.75, names = FALSE)
  
  tibble(
    n = length(x),
    mean = mean_val,
    sd = sd_val,
    median = median_val,
    q1 = q1_val,
    q3 = q3_val,
    mean_sd = format_mean_sd(mean_val, sd_val),
    median_iqr = format_median_iqr(median_val, q1_val, q3_val)
  )
}

write_txt_report <- function(file, lines) {
  writeLines(lines, con = file, useBytes = TRUE)
}

save_plot <- function(plot_obj, file, width_mm = 180, height_mm = 120) {
  ggsave(
    filename = file,
    plot = plot_obj,
    width = width_mm,
    height = height_mm,
    units = "mm",
    dpi = 300
  )
}


# ── 7. Load Table S8 data ─────────────────────────────────────────────────────
read_inter_model <- function(model) {
  stats_dir <- mode_dir(model, "Inter")
  metrics <- safe_read_csv(file.path(stats_dir, "metrics_all.csv"))
  
  if (nrow(metrics) == 0) {
    return(tibble())
  }
  
  metrics <- metrics %>%
    mutate(
      model = model,
      evaluation = inter_label,
      pair_id = first_existing_col(., c("pair_id")),
      train_dataset = first_existing_col(., c("train_dataset", "source_dataset")),
      test_dataset = first_existing_col(., c("test_dataset", "target_dataset")),
      pair_id = ifelse(
        is.na(pair_id) | pair_id == "",
        paste0(train_dataset, "__to__", test_dataset),
        pair_id
      ),
      pair_id_clean = sanitize_id(pair_id)
    )
  
  parsed <- parse_train_test_from_pair(metrics$pair_id)
  metrics <- bind_cols(metrics, parsed) %>%
    mutate(
      train_dataset = ifelse(is.na(train_dataset) | train_dataset == "", train_dataset_parsed, train_dataset),
      test_dataset = ifelse(is.na(test_dataset) | test_dataset == "", test_dataset_parsed, test_dataset)
    ) %>%
    select(-train_dataset_parsed, -test_dataset_parsed)
  
  behavior <- safe_read_csv(file.path(stats_dir, "behavior_metrics_all.csv"))
  if (nrow(behavior) > 0) {
    behavior <- behavior %>%
      mutate(
        model = model,
        pair_id = first_existing_col(., c("pair_id")),
        train_dataset = first_existing_col(., c("train_dataset", "source_dataset")),
        test_dataset = first_existing_col(., c("test_dataset", "target_dataset")),
        pair_id = ifelse(
          is.na(pair_id) | pair_id == "",
          paste0(train_dataset, "__to__", test_dataset),
          pair_id
        ),
        pair_id_clean = sanitize_id(pair_id)
      )
  } else {
    behavior <- read_recursive_table(stats_dir, "behavior_metrics.csv", model)
  }
  
  behavior_wide <- make_behavior_wide(behavior)
  train_n <- summarise_balance_recursive(stats_dir, "train_balance.csv", model, "n_train")
  test_n  <- summarise_balance_recursive(stats_dir, "test_balance.csv", model, "n_test")
  
  out <- metrics %>%
    left_join(behavior_wide, by = c("model", "pair_id_clean")) %>%
    left_join(train_n, by = c("model", "pair_id_clean")) %>%
    left_join(test_n, by = c("model", "pair_id_clean")) %>%
    add_species_pair() %>%
    mutate(
      split_id = "directional source-target pair",
      source_dataset = train_dataset,
      target_dataset = test_dataset
    )
  
  out <- ensure_cols(
    out,
    c(
      "family_id", "accuracy", "macro_precision", "macro_recall",
      "macro_f1", "f1_foraging", "f1_locomotion", "f1_resting",
      "n_train", "n_test", "source_common_name", "target_common_name",
      "source_scientific_name", "target_scientific_name"
    )
  )
  
  out %>%
    transmute(
      model,
      evaluation,
      split_id,
      family_id,
      pair_id,
      source_dataset,
      target_dataset,
      species_pair_common,
      species_pair_scientific,
      macro_f1,
      accuracy,
      macro_precision,
      macro_recall,
      f1_foraging,
      f1_locomotion,
      f1_resting,
      n_train,
      n_test,
      source_common_name,
      target_common_name,
      source_scientific_name,
      target_scientific_name
    )
}

print_section("Load inter-dataset results")
inter_results <- map_dfr(model_levels, read_inter_model)
inter_results <- ensure_cols(
  inter_results,
  c(
    "model", "evaluation", "split_id", "family_id", "pair_id",
    "source_dataset", "target_dataset", "species_pair_common",
    "species_pair_scientific", "macro_f1", "accuracy", "macro_precision",
    "macro_recall", "f1_foraging", "f1_locomotion", "f1_resting",
    "n_train", "n_test", "source_common_name", "target_common_name",
    "source_scientific_name", "target_scientific_name"
  )
)
if (nrow(inter_results) > 0) {
  inter_results <- inter_results %>%
    mutate(model = factor(model, levels = model_levels)) %>%
    arrange(model, source_dataset, target_dataset) %>%
    mutate(model = as.character(model))
}


# ── 8. Load Table S9 data ─────────────────────────────────────────────────────
read_pooled_model <- function(model) {
  stats_dir <- mode_dir(model, "Global")
  overall <- safe_read_csv(file.path(stats_dir, "overall_metrics.csv"))
  
  if (nrow(overall) == 0) {
    return(tibble())
  }
  
  behavior <- safe_read_csv(file.path(stats_dir, "behavior_metrics.csv"))
  behavior_wide <- make_behavior_wide(
    behavior %>%
      mutate(
        model = model,
        pair_id_clean = "pooled"
      )
  )
  
  if (nrow(behavior_wide) == 0) {
    behavior_wide <- tibble(
      model = model,
      pair_id_clean = "pooled",
      f1_foraging = NA_real_,
      f1_locomotion = NA_real_,
      f1_resting = NA_real_
    )
  }
  
  train_balance <- safe_read_csv(file.path(stats_dir, "train_balance.csv"))
  test_balance  <- safe_read_csv(file.path(stats_dir, "test_balance.csv"))
  
  dataset_metrics <- read_dataset_metrics(stats_dir)
  dataset_macro_f1 <- if ("macro_f1" %in% names(dataset_metrics)) {
    as.numeric(dataset_metrics$macro_f1)
  } else {
    numeric()
  }
  dataset_summary <- summarise_metric_vector(dataset_macro_f1)
  
  out <- overall %>%
    mutate(
      model = model,
      evaluation = pooled_label,
      split_id = "single pooled holdout split",
      source_dataset = "pooled training datasets",
      target_dataset = "pooled test split",
      n_train = safe_sum_n(train_balance),
      n_test = safe_sum_n(test_balance),
      n_train_dataset_behavior_groups = ifelse(nrow(train_balance) > 0, nrow(train_balance), NA_integer_),
      n_test_dataset_behavior_groups = ifelse(nrow(test_balance) > 0, nrow(test_balance), NA_integer_),
      dataset_level_n = dataset_summary$n,
      dataset_macro_f1_mean = dataset_summary$mean,
      dataset_macro_f1_sd = dataset_summary$sd,
      dataset_macro_f1_median = dataset_summary$median,
      dataset_macro_f1_q1 = dataset_summary$q1,
      dataset_macro_f1_q3 = dataset_summary$q3,
      dataset_macro_f1_mean_sd = dataset_summary$mean_sd,
      dataset_macro_f1_median_iqr = dataset_summary$median_iqr
    ) %>%
    bind_cols(behavior_wide %>% select(f1_foraging, f1_locomotion, f1_resting))
  
  out <- ensure_cols(
    out,
    c(
      "accuracy", "macro_precision", "macro_recall", "macro_f1",
      "f1_foraging", "f1_locomotion", "f1_resting"
    )
  )
  
  out %>%
    transmute(
      model,
      evaluation,
      split_id,
      source_dataset,
      target_dataset,
      macro_f1,
      accuracy,
      macro_precision,
      macro_recall,
      f1_foraging,
      f1_locomotion,
      f1_resting,
      n_train,
      n_test,
      n_train_dataset_behavior_groups,
      n_test_dataset_behavior_groups,
      dataset_level_n,
      dataset_macro_f1_mean,
      dataset_macro_f1_sd,
      dataset_macro_f1_median,
      dataset_macro_f1_q1,
      dataset_macro_f1_q3,
      dataset_macro_f1_mean_sd,
      dataset_macro_f1_median_iqr
    )
}

print_section("Load pooled multi-dataset results")
pooled_results <- map_dfr(model_levels, read_pooled_model)
pooled_results <- ensure_cols(
  pooled_results,
  c(
    "model", "evaluation", "split_id", "source_dataset", "target_dataset",
    "macro_f1", "accuracy", "macro_precision", "macro_recall",
    "f1_foraging", "f1_locomotion", "f1_resting", "n_train", "n_test",
    "n_train_dataset_behavior_groups", "n_test_dataset_behavior_groups",
    "dataset_level_n", "dataset_macro_f1_mean", "dataset_macro_f1_sd",
    "dataset_macro_f1_median", "dataset_macro_f1_q1", "dataset_macro_f1_q3",
    "dataset_macro_f1_mean_sd", "dataset_macro_f1_median_iqr"
  )
)
if (nrow(pooled_results) > 0) {
  pooled_results <- pooled_results %>%
    mutate(model = factor(model, levels = model_levels)) %>%
    arrange(model) %>%
    mutate(model = as.character(model))
}


# ── 9. Tables ────────────────────────────────────────────────────────────────
print_section("Build tables")

table_s8 <- inter_results %>%
  mutate(
    macro_f1_formatted = fmt_num(macro_f1),
    f1_foraging_formatted = fmt_num(f1_foraging),
    f1_locomotion_formatted = fmt_num(f1_locomotion),
    f1_resting_formatted = fmt_num(f1_resting)
  ) %>%
  select(
    source_dataset,
    target_dataset,
    species_pair_common,
    species_pair_scientific,
    model,
    macro_f1,
    f1_foraging,
    f1_locomotion,
    f1_resting,
    n_train,
    n_test,
    split_id,
    family_id,
    pair_id,
    accuracy,
    macro_precision,
    macro_recall,
    macro_f1_formatted,
    f1_foraging_formatted,
    f1_locomotion_formatted,
    f1_resting_formatted,
    source_common_name,
    target_common_name,
    source_scientific_name,
    target_scientific_name
  )

table_s8_summary <- table_s8 %>%
  group_by(model) %>%
  summarise(
    n_pairs = sum(is.finite(macro_f1)),
    mean_macro_f1 = mean(macro_f1, na.rm = TRUE),
    sd_macro_f1 = sd(macro_f1, na.rm = TRUE),
    median_macro_f1 = median(macro_f1, na.rm = TRUE),
    q1_macro_f1 = quantile(macro_f1, 0.25, na.rm = TRUE, names = FALSE),
    q3_macro_f1 = quantile(macro_f1, 0.75, na.rm = TRUE, names = FALSE),
    macro_f1_mean_sd = format_mean_sd(mean_macro_f1, sd_macro_f1),
    macro_f1_median_iqr = format_median_iqr(median_macro_f1, q1_macro_f1, q3_macro_f1),
    mean_f1_foraging = mean(f1_foraging, na.rm = TRUE),
    mean_f1_locomotion = mean(f1_locomotion, na.rm = TRUE),
    mean_f1_resting = mean(f1_resting, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(model = factor(model, levels = model_levels)) %>%
  arrange(model) %>%
  mutate(model = as.character(model))

table_s9 <- pooled_results %>%
  mutate(
    macro_f1_formatted = fmt_num(macro_f1),
    f1_foraging_formatted = fmt_num(f1_foraging),
    f1_locomotion_formatted = fmt_num(f1_locomotion),
    f1_resting_formatted = fmt_num(f1_resting)
  ) %>%
  select(
    model,
    evaluation,
    split_id,
    macro_f1,
    f1_foraging,
    f1_locomotion,
    f1_resting,
    n_train,
    n_test,
    n_train_dataset_behavior_groups,
    n_test_dataset_behavior_groups,
    dataset_level_n,
    dataset_macro_f1_mean_sd,
    dataset_macro_f1_median_iqr,
    accuracy,
    macro_precision,
    macro_recall,
    macro_f1_formatted,
    f1_foraging_formatted,
    f1_locomotion_formatted,
    f1_resting_formatted,
    dataset_macro_f1_mean,
    dataset_macro_f1_sd,
    dataset_macro_f1_median,
    dataset_macro_f1_q1,
    dataset_macro_f1_q3
  )

table_s9_summary <- table_s9 %>%
  select(
    model,
    macro_f1,
    f1_foraging,
    f1_locomotion,
    f1_resting,
    n_train,
    n_test,
    dataset_macro_f1_mean_sd,
    dataset_macro_f1_median_iqr
  )


# ── 10. Figure S3 ─────────────────────────────────────────────────────────────
print_section("Build Figure S3")

figure_s3_data <- bind_rows(
  table_s8 %>%
    transmute(
      model,
      evaluation = inter_label,
      macro_f1,
      unit_id = pair_id
    ),
  table_s9 %>%
    transmute(
      model,
      evaluation = pooled_label,
      macro_f1,
      unit_id = split_id
    )
) %>%
  filter(is.finite(macro_f1)) %>%
  mutate(
    model = factor(model, levels = model_levels),
    evaluation = factor(evaluation, levels = c(inter_label, pooled_label))
  )

p_figure_s3 <- ggplot(figure_s3_data, aes(x = model, y = macro_f1)) +
  geom_boxplot(
    data = figure_s3_data %>% filter(evaluation == inter_label),
    aes(group = model),
    width = 0.55,
    outlier.shape = NA,
    fill = "grey92",
    colour = "grey25",
    linewidth = 0.4
  ) +
  geom_point(
    data = figure_s3_data %>% filter(evaluation == inter_label),
    aes(shape = evaluation),
    position = position_jitter(width = 0.10, height = 0, seed = 42),
    size = 1.8,
    alpha = 0.6,
    colour = "grey20"
  ) +
  geom_point(
    data = figure_s3_data %>% filter(evaluation == pooled_label),
    aes(shape = evaluation),
    size = 4.0,
    stroke = 1.4,
    fill = "white",
    colour = "black"
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    expand = expansion(mult = c(0.01, 0.04))
  ) +
  scale_shape_manual(values = c(16, 23)) +
  labs(
    x = "Model",
    y = "Macro-F1",
    shape = "Evaluation setting"
  ) +
  theme_bw(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3),
    panel.border       = element_rect(colour = "grey40", fill = NA, linewidth = 0.4),
    axis.text.x        = element_text(angle = 0, hjust = 0.5),
    legend.position    = "bottom",
    legend.key         = element_blank(),
    plot.margin        = margin(8, 10, 8, 8)
  )


# ── 11. Write outputs ─────────────────────────────────────────────────────────
print_section("Write outputs")

write_csv(input_registry, file.path(csv_dir, "00_supplementary_evaluation_input_registry.csv"))
write_csv(dataset_lookup, file.path(csv_dir, "01_dataset_species_lookup.csv"))
write_csv(table_s8, file.path(csv_dir, "Table_S8_inter_dataset_transfer_results.csv"))
write_csv(table_s8_summary, file.path(csv_dir, "Table_S8_inter_dataset_transfer_summary_by_model.csv"))
write_csv(table_s9, file.path(csv_dir, "Table_S9_pooled_multi_dataset_evaluation_results.csv"))
write_csv(table_s9_summary, file.path(csv_dir, "Table_S9_pooled_multi_dataset_summary_by_model.csv"))
write_csv(figure_s3_data, file.path(csv_dir, "Figure_S3_plot_data.csv"))

save_plot(
  p_figure_s3,
  file.path(plots_dir, "Figure_S3_inter_vs_pooled_macro_f1.png"),
  width_mm = 180,
  height_mm = 120
)

report_lines <- c(
  "Supplementary evaluation results",
  "================================",
  "",
  "Generated outputs:",
  "- Table S8: Inter-dataset transfer results",
  "- Table S9: Pooled multi-dataset evaluation results",
  "- Figure S3: Diagnostic comparison of inter-dataset and pooled multi-dataset Macro-F1",
  "",
  "Input structure:",
  "- Inter-dataset results are read from Models/<Model>/Inter_<Model>/statistics/.",
  "- Pooled multi-dataset results are read from Models/<Model>/Global_<Model>/statistics/.",
  "- Behaviour metrics are read from aggregated files when available; otherwise pair folders are scanned recursively.",
  "",
  paste0("Inter rows in Table S8: ", nrow(table_s8)),
  paste0("Pooled rows in Table S9: ", nrow(table_s9)),
  paste0("Figure S3 rows: ", nrow(figure_s3_data)),
  "",
  "Inter-dataset Macro-F1 summary by model:",
  capture.output(print(table_s8_summary, n = Inf)),
  "",
  "Pooled multi-dataset results:",
  capture.output(print(table_s9_summary, n = Inf)),
  "",
  "Missing input overview:",
  capture.output(
    print(
      input_registry %>%
        select(model, evaluation, statistics_dir_exists, metrics_exists, behavior_exists),
      n = Inf
    )
  )
)

write_txt_report(
  file.path(txt_dir, "01_supplementary_evaluation_results_report.txt"),
  report_lines
)

files_written <- c(
  file.path(csv_dir, "00_supplementary_evaluation_input_registry.csv"),
  file.path(csv_dir, "01_dataset_species_lookup.csv"),
  file.path(csv_dir, "Table_S8_inter_dataset_transfer_results.csv"),
  file.path(csv_dir, "Table_S8_inter_dataset_transfer_summary_by_model.csv"),
  file.path(csv_dir, "Table_S9_pooled_multi_dataset_evaluation_results.csv"),
  file.path(csv_dir, "Table_S9_pooled_multi_dataset_summary_by_model.csv"),
  file.path(csv_dir, "Figure_S3_plot_data.csv"),
  file.path(plots_dir, "Figure_S3_inter_vs_pooled_macro_f1.png"),
  file.path(txt_dir, "01_supplementary_evaluation_results_report.txt")
)

write_txt_report(
  file.path(txt_dir, "02_supplementary_evaluation_files_written.txt"),
  files_written
)

print(p_figure_s3)
message("Supplementary evaluation outputs saved to: ", out_dir)