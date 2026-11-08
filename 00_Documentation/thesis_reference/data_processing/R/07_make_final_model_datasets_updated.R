# 07_make_final_model_datasets.R
# Builds final per-dataset parquet files for raw-window and feature models.

Sys.setenv(ARROW_NUM_THREADS = "2")

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(ggplot2)
})

# ---------- settings ----------

processing_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processing"
processed_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processed"
script_id <- "07"
expected_dataset_count <- 12L

window_input_dir <- file.path(processing_root, "04", "04_parquet")
feature_input_dir <- file.path(processing_root, "06", "06_parquet")

out_windows_dir <- file.path(processed_root, "data_processed_final")
out_features_dir <- file.path(processed_root, "data_processed_features")
out_report_dir <- file.path(processed_root, "07_reports")
out_csv_dir <- file.path(out_report_dir, "07_csv")
out_txt_dir <- file.path(out_report_dir, "07_txt")
out_fig_dir <- file.path(out_report_dir, "07_figures")

report_txt_path <- file.path(out_txt_dir, "07_final_model_datasets_report.txt")
individual_csv_path <- file.path(out_csv_dir, "07_individual_class_summary.csv")
excluded_csv_path <- file.path(out_csv_dir, "07_excluded_individuals.csv")
dataset_csv_path <- file.path(out_csv_dir, "07_dataset_output_summary.csv")
figure_s1_csv_path <- file.path(out_csv_dir, "Figure_S1_behavior_class_distribution.csv")
table_s5_csv_path <- file.path(out_csv_dir, "Table_S5_dataset_filtering_retained_windows.csv")
figure_s1_png_path <- file.path(out_fig_dir, "Figure_S1_behavior_class_distribution.png")

# Target behavior classes.
target_main_classes <- c("foraging", "locomotion", "resting")

# Dataset order follows Table S1 in the Supplementary Material.
dataset_order_dt <- data.table(
  dataset_id = sprintf("%02d", 1:12),
  dataset_name = c(
    "Bison_dataset_1",
    "Cattle_dataset_1",
    "Dog_dataset_1",
    "Dog_dataset_2",
    "Horse_dataset_1",
    "Horse_dataset_2",
    "Hedgehog_dataset_1",
    "Giraffe_dataset_1",
    "Raccoon_dataset_1",
    "Raccoon_dataset_2",
    "Fox_dataset_1",
    "Fox_dataset_2"
  )
)

# Rule 1: keep only individuals with all target classes.
require_all_classes_per_individual <- TRUE

# Rule 2: optional minimum windows per class and individual.
# Set to 1 to exclude only missing classes.
# Recommended start: 10. Increase to 20 or 30 for stricter modeling.
min_windows_per_class <- 10L

# Optional manual exclusion list.
# Example:
# manual_exclude_individuals <- data.table(
#   dataset_name = c("Fox_dataset_2"),
#   individual_id = c("REPLACE_WITH_ID")
# )
manual_exclude_individuals <- data.table(
  dataset_name = character(),
  individual_id = character()
)

# Output folders are dedicated final folders. Clear them before writing.
clear_output_dirs <- TRUE
compression_codec <- "zstd"

# ---------- setup ----------

for (d in c(out_windows_dir, out_features_dir, out_report_dir, out_csv_dir, out_txt_dir, out_fig_dir)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

if (clear_output_dirs) {
  unlink(list.files(out_windows_dir, full.names = TRUE, all.files = FALSE), recursive = TRUE, force = TRUE)
  unlink(list.files(out_features_dir, full.names = TRUE, all.files = FALSE), recursive = TRUE, force = TRUE)
}

# ---------- helpers ----------

safe_chr <- function(x, fallback = NA_character_) {
  x <- as.character(x)
  x[is.na(x) | trimws(x) == ""] <- fallback
  x
}

clean_dataset_name <- function(x) {
  x <- basename(x)
  x <- sub("_mr$", "", x)
  x <- sub("_features$", "", x)
  x
}

sanitize_file_name <- function(x) {
  x <- gsub("[^A-Za-z0-9_\\-]+", "_", as.character(x))
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  ifelse(nchar(x) == 0, "UNKNOWN", x)
}

list_dataset_dirs <- function(input_dir) {
  if (!dir.exists(input_dir)) stop("Input folder does not exist: ", input_dir)
  dirs <- sort(list.dirs(input_dir, full.names = TRUE, recursive = FALSE))
  dirs <- dirs[file.info(dirs)$isdir]
  dirs[order(basename(dirs))]
}

read_dataset_dir <- function(dataset_dir) {
  files <- sort(list.files(dataset_dir, pattern = "\\.parquet$", full.names = TRUE, recursive = FALSE))
  if (!length(files)) return(data.table())
  
  rbindlist(
    lapply(files, function(f) as.data.table(arrow::read_parquet(f))),
    fill = TRUE,
    use.names = TRUE
  )
}

add_individual_key <- function(dt, dataset_label = NA_character_) {
  setDT(dt)
  
  if (!"dataset_name" %in% names(dt)) dt[, dataset_name := dataset_label]
  if (!"individual_id" %in% names(dt)) dt[, individual_id := NA_character_]
  if (!"individual_name" %in% names(dt)) dt[, individual_name := NA_character_]
  
  dt[, dataset_name := safe_chr(dataset_name, dataset_label)]
  dt[, individual_id := safe_chr(individual_id, NA_character_)]
  dt[, individual_name := safe_chr(individual_name, NA_character_)]
  
  dt[, individual_label_tmp := individual_id]
  dt[is.na(individual_label_tmp), individual_label_tmp := individual_name]
  dt[is.na(individual_label_tmp), individual_label_tmp := "UNKNOWN"]
  dt[, individual_key := paste(dataset_name, individual_label_tmp, sep = "__")]
  dt[, individual_label_tmp := NULL]
  
  dt
}

standardize_classes <- function(dt) {
  if (!"main_class" %in% names(dt)) stop("Column missing: main_class")
  dt[, main_class := tolower(trimws(as.character(main_class)))]
  dt[main_class %in% target_main_classes]
}

manual_keys <- function(exclusion_dt) {
  if (!nrow(exclusion_dt)) return(character())
  tmp <- copy(exclusion_dt)
  if (!"individual_name" %in% names(tmp)) tmp[, individual_name := NA_character_]
  add_individual_key(tmp)
  unique(tmp$individual_key)
}

make_individual_summary <- function(dt, dataset_name, manual_key_vec) {
  if (!nrow(dt)) {
    return(data.table(
      dataset_name = dataset_name,
      individual_key = character(),
      individual_id = character(),
      individual_name = character(),
      foraging = integer(),
      locomotion = integer(),
      resting = integer(),
      total_windows = integer(),
      classes_present = integer(),
      missing_classes = character(),
      min_class_n = integer(),
      has_all_classes = logical(),
      passes_min_class_n = logical(),
      manual_exclude = logical(),
      final_keep = logical(),
      exclusion_reason = character()
    ))
  }
  
  counts <- dt[, .N, by = .(dataset_name, individual_key, individual_id, individual_name, main_class)]
  wide <- dcast(
    counts,
    dataset_name + individual_key + individual_id + individual_name ~ main_class,
    value.var = "N",
    fill = 0
  )
  
  for (cls in target_main_classes) {
    if (!cls %in% names(wide)) wide[, (cls) := 0L]
  }
  
  setcolorder(wide, c("dataset_name", "individual_key", "individual_id", "individual_name", target_main_classes))
  
  wide[, total_windows := rowSums(.SD), .SDcols = target_main_classes]
  wide[, classes_present := rowSums(.SD > 0), .SDcols = target_main_classes]
  wide[, min_class_n := do.call(pmin, c(.SD, list(na.rm = TRUE))), .SDcols = target_main_classes]
  wide[, has_all_classes := classes_present == length(target_main_classes)]
  wide[, passes_min_class_n := min_class_n >= min_windows_per_class]
  wide[, manual_exclude := individual_key %in% manual_key_vec]
  
  wide[, missing_classes := apply(.SD, 1L, function(x) {
    miss <- target_main_classes[as.integer(x) == 0L]
    if (!length(miss)) "none" else paste(miss, collapse = " | ")
  }), .SDcols = target_main_classes]
  
  wide[, final_keep := TRUE]
  if (require_all_classes_per_individual) {
    wide[has_all_classes == FALSE, final_keep := FALSE]
  }
  wide[passes_min_class_n == FALSE, final_keep := FALSE]
  wide[manual_exclude == TRUE, final_keep := FALSE]
  
  wide[, exclusion_reason := "kept"]
  wide[has_all_classes == FALSE, exclusion_reason := paste0("missing_classes: ", missing_classes)]
  wide[has_all_classes == TRUE & passes_min_class_n == FALSE,
       exclusion_reason := paste0("min_class_n_below_", min_windows_per_class)]
  wide[manual_exclude == TRUE, exclusion_reason := "manual_exclude"]
  
  wide[order(dataset_name, individual_key)]
}

write_dataset_outputs <- function(dt, out_file) {
  arrow::write_parquet(dt, out_file, compression = compression_codec)
}

# ---------- run ----------

window_dirs <- list_dataset_dirs(window_input_dir)
feature_dirs <- list_dataset_dirs(feature_input_dir)

window_names <- basename(window_dirs)
feature_names <- basename(feature_dirs)

if (length(window_dirs) != expected_dataset_count) {
  stop("Expected ", expected_dataset_count, " window dataset folders, found ", length(window_dirs))
}

if (length(feature_dirs) != expected_dataset_count) {
  stop("Expected ", expected_dataset_count, " feature dataset folders, found ", length(feature_dirs))
}

if (!setequal(window_names, feature_names)) {
  stop("Window and feature dataset folders do not match.")
}

expected_dataset_names <- dataset_order_dt$dataset_name

missing_window_datasets <- setdiff(expected_dataset_names, window_names)
unexpected_window_datasets <- setdiff(window_names, expected_dataset_names)
missing_feature_datasets <- setdiff(expected_dataset_names, feature_names)
unexpected_feature_datasets <- setdiff(feature_names, expected_dataset_names)

if (length(missing_window_datasets) || length(unexpected_window_datasets)) {
  stop(
    "Window dataset folders do not match dataset_order_dt. Missing: ",
    paste(missing_window_datasets, collapse = ", "),
    " | Unexpected: ",
    paste(unexpected_window_datasets, collapse = ", ")
  )
}

if (length(missing_feature_datasets) || length(unexpected_feature_datasets)) {
  stop(
    "Feature dataset folders do not match dataset_order_dt. Missing: ",
    paste(missing_feature_datasets, collapse = ", "),
    " | Unexpected: ",
    paste(unexpected_feature_datasets, collapse = ", ")
  )
}

manual_key_vec <- manual_keys(manual_exclude_individuals)
all_names <- expected_dataset_names

individual_summary_list <- vector("list", length(all_names))
dataset_summary_list <- vector("list", length(all_names))
class_summary_list <- vector("list", length(all_names))

cat("\n==============================\n")
cat("07 FINAL MODEL DATASETS START\n")
cat("==============================\n")

for (i in seq_along(all_names)) {
  dataset_name <- all_names[i]
  cat("\nDATASET:", dataset_name, "\n")
  
  win_dir <- file.path(window_input_dir, dataset_name)
  feat_dir <- file.path(feature_input_dir, dataset_name)
  
  win_dt <- read_dataset_dir(win_dir)
  feat_dt <- read_dataset_dir(feat_dir)
  
  add_individual_key(win_dt, dataset_name)
  add_individual_key(feat_dt, dataset_name)
  win_dt <- standardize_classes(win_dt)
  feat_dt <- standardize_classes(feat_dt)
  
  ind_dt <- make_individual_summary(win_dt, dataset_name, manual_key_vec)
  keep_keys <- ind_dt[final_keep == TRUE, individual_key]
  
  win_out <- win_dt[individual_key %in% keep_keys]
  feat_out <- feat_dt[individual_key %in% keep_keys]
  
  out_window_file <- file.path(out_windows_dir, paste0(sanitize_file_name(dataset_name), ".parquet"))
  out_feature_file <- file.path(out_features_dir, paste0(sanitize_file_name(dataset_name), ".parquet"))
  
  write_dataset_outputs(win_out, out_window_file)
  write_dataset_outputs(feat_out, out_feature_file)
  
  mismatch <- nrow(win_out) != nrow(feat_out)
  
  dataset_summary_list[[i]] <- data.table(
    dataset_name = dataset_name,
    windows_before = nrow(win_dt),
    features_before = nrow(feat_dt),
    windows_after = nrow(win_out),
    features_after = nrow(feat_out),
    individuals_before = uniqueN(win_dt$individual_key),
    individuals_after = uniqueN(win_out$individual_key),
    individuals_excluded = uniqueN(win_dt$individual_key) - uniqueN(win_out$individual_key),
    min_windows_per_class = min_windows_per_class,
    window_feature_row_mismatch = mismatch,
    output_window_file = out_window_file,
    output_feature_file = out_feature_file,
    status = ifelse(mismatch, "check_window_feature_mismatch", "ok")
  )
  
  individual_summary_list[[i]] <- ind_dt
  class_summary_list[[i]] <- win_out[, .(retained_windows = .N), by = .(dataset_name, main_class)]
  
  cat("  windows:", format(nrow(win_dt), big.mark = ","), "->", format(nrow(win_out), big.mark = ","), "\n")
  cat("  features:", format(nrow(feat_dt), big.mark = ","), "->", format(nrow(feat_out), big.mark = ","), "\n")
  cat("  individuals excluded:", uniqueN(win_dt$individual_key) - uniqueN(win_out$individual_key), "\n")
  
  rm(win_dt, feat_dt, win_out, feat_out)
  gc(FALSE)
}

individual_dt <- rbindlist(individual_summary_list, fill = TRUE, use.names = TRUE)
dataset_dt <- rbindlist(dataset_summary_list, fill = TRUE, use.names = TRUE)
class_dt <- rbindlist(class_summary_list, fill = TRUE, use.names = TRUE)

# Attach stable dataset IDs/order used in Supplementary tables and figures.
individual_dt <- merge(dataset_order_dt, individual_dt, by = "dataset_name", all.y = TRUE)
dataset_dt <- merge(dataset_order_dt, dataset_dt, by = "dataset_name", all.y = TRUE)
setorder(individual_dt, dataset_id, individual_key)
setorder(dataset_dt, dataset_id)

excluded_dt <- individual_dt[final_keep == FALSE][order(dataset_id, exclusion_reason, individual_key)]

# Figure S1 source data: retained behavior windows after individual filtering.
class_dt <- class_dt[, .(retained_windows = sum(retained_windows)), by = .(dataset_name, main_class)]
class_grid_dt <- CJ(dataset_name = all_names, main_class = target_main_classes, unique = TRUE)
figure_s1_dt <- merge(class_grid_dt, class_dt, by = c("dataset_name", "main_class"), all.x = TRUE)
figure_s1_dt[is.na(retained_windows), retained_windows := 0L]
figure_s1_dt <- merge(dataset_order_dt, figure_s1_dt, by = "dataset_name", all.y = TRUE)
figure_s1_dt[, class_order := match(main_class, target_main_classes)]
setorder(figure_s1_dt, dataset_id, class_order)
figure_s1_dt[, total_retained_windows := sum(retained_windows), by = dataset_name]
figure_s1_dt[, proportion := ifelse(total_retained_windows > 0, retained_windows / total_retained_windows, NA_real_)]
figure_s1_dt[, dataset_label := paste0(dataset_id, " ", dataset_name)]
figure_s1_dt[, main_class := factor(main_class, levels = target_main_classes)]
figure_s1_dt[, class_order := NULL]

# Table S5: final analysis-ready dataset table.
table_s5_dt <- dcast(
  figure_s1_dt[, .(dataset_id, dataset_name, main_class, retained_windows)],
  dataset_id + dataset_name ~ main_class,
  value.var = "retained_windows",
  fill = 0
)

for (cls in target_main_classes) {
  if (!cls %in% names(table_s5_dt)) table_s5_dt[, (cls) := 0L]
}

setnames(
  table_s5_dt,
  old = target_main_classes,
  new = paste0(target_main_classes, "_windows")
)

exclusion_reason_dt <- excluded_dt[, .(
  exclusion_reason = paste(unique(exclusion_reason), collapse = " | ")
), by = .(dataset_name)]

table_s5_dt <- merge(
  dataset_dt[, .(
    dataset_id,
    dataset_name,
    original_individuals = individuals_before,
    excluded_individuals = individuals_excluded,
    retained_individuals = individuals_after,
    total_retained_windows = windows_after
  )],
  table_s5_dt,
  by = c("dataset_id", "dataset_name"),
  all.x = TRUE
)

table_s5_dt <- merge(table_s5_dt, exclusion_reason_dt, by = "dataset_name", all.x = TRUE)
table_s5_dt[is.na(exclusion_reason), exclusion_reason := "none"]
setcolorder(
  table_s5_dt,
  c(
    "dataset_id",
    "dataset_name",
    "original_individuals",
    "excluded_individuals",
    "exclusion_reason",
    "retained_individuals",
    "foraging_windows",
    "locomotion_windows",
    "resting_windows",
    "total_retained_windows"
  )
)
setorder(table_s5_dt, dataset_id)

# Figure S1: relative class distribution; totals are printed above bars.
plot_dt <- copy(figure_s1_dt)
plot_dt[, dataset_label := factor(dataset_label, levels = unique(plot_dt[order(dataset_id)]$dataset_label))]
plot_dt[, main_class_plot := factor(
  main_class,
  levels = target_main_classes,
  labels = c("Foraging", "Locomotion", "Resting")
)]
label_dt <- unique(plot_dt[, .(dataset_label, total_retained_windows)])

figure_s1_plot <- ggplot(plot_dt, aes(x = dataset_label, y = proportion, fill = main_class_plot)) +
  geom_col(width = 0.8) +
  geom_text(
    data = label_dt,
    aes(
      x = dataset_label,
      y = 1.025,
      label = paste0("n=", format(total_retained_windows, big.mark = ","))
    ),
    inherit.aes = FALSE,
    size = 3,
    angle = 90,
    hjust = 0
  ) +
  scale_fill_manual(
    values = c(
      "Foraging"   = "#66C2A5",
      "Locomotion" = "#8DA0CB",
      "Resting"    = "#E78"
    )
  ) +
  scale_y_continuous(
    labels = function(x) paste0(round(x * 100), "%"),
    limits = c(0, 1.16),
    expand = c(0, 0)
  ) +
  labs(
    x = "Dataset",
    y = "Retained windows (%)",
    fill = "Behavior class",
    title = ""
  ) +
  theme_bw(base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.major.x = element_blank(),
    plot.title = element_text(face = "bold")
  )

ggsave(figure_s1_png_path, figure_s1_plot, width = 11, height = 6.5, dpi = 300)

write.csv(individual_dt, individual_csv_path, row.names = FALSE)
write.csv(excluded_dt, excluded_csv_path, row.names = FALSE)
write.csv(dataset_dt, dataset_csv_path, row.names = FALSE)
write.csv(figure_s1_dt, figure_s1_csv_path, row.names = FALSE)
write.csv(table_s5_dt, table_s5_csv_path, row.names = FALSE)

window_out_files <- list.files(out_windows_dir, pattern = "\\.parquet$", full.names = TRUE)
feature_out_files <- list.files(out_features_dir, pattern = "\\.parquet$", full.names = TRUE)

if (length(window_out_files) != expected_dataset_count) {
  stop("Expected ", expected_dataset_count, " final window parquet files, found ", length(window_out_files))
}

if (length(feature_out_files) != expected_dataset_count) {
  stop("Expected ", expected_dataset_count, " final feature parquet files, found ", length(feature_out_files))
}

report_lines <- c(
  "07 Final Model Datasets Report",
  paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "Goal:",
  "- Create exactly 12 final raw-window parquet files for CNN/ResNet/HYDRA/MultiRocket.",
  "- Create exactly 12 final feature parquet files for RF/LightGBM.",
  "- Exclude individuals that do not pass behavior-class rules.",
  "",
  "Folders:",
  paste0("- window input: ", window_input_dir),
  paste0("- feature input: ", feature_input_dir),
  paste0("- final windows: ", out_windows_dir),
  paste0("- final features: ", out_features_dir),
  paste0("- reports: ", out_report_dir),
  paste0("- figures: ", out_fig_dir),
  "",
  "Filter rules:",
  paste0("- require_all_classes_per_individual: ", require_all_classes_per_individual),
  paste0("- target classes: ", paste(target_main_classes, collapse = ", ")),
  paste0("- min_windows_per_class: ", min_windows_per_class),
  paste0("- manual exclusions: ", nrow(manual_exclude_individuals)),
  "",
  paste0("Final window parquet files: ", length(window_out_files)),
  paste0("Final feature parquet files: ", length(feature_out_files)),
  paste0("Total windows before: ", format(sum(dataset_dt$windows_before, na.rm = TRUE), big.mark = ",")),
  paste0("Total windows after: ", format(sum(dataset_dt$windows_after, na.rm = TRUE), big.mark = ",")),
  paste0("Total features before: ", format(sum(dataset_dt$features_before, na.rm = TRUE), big.mark = ",")),
  paste0("Total features after: ", format(sum(dataset_dt$features_after, na.rm = TRUE), big.mark = ",")),
  paste0("Excluded individuals: ", nrow(excluded_dt)),
  "",
  "Dataset summary:"
)

for (i in seq_len(nrow(dataset_dt))) {
  r <- dataset_dt[i]
  report_lines <- c(
    report_lines,
    "",
    paste0("Dataset: ", r$dataset_name),
    paste0("- windows before/after: ", format(r$windows_before, big.mark = ","), " / ", format(r$windows_after, big.mark = ",")),
    paste0("- features before/after: ", format(r$features_before, big.mark = ","), " / ", format(r$features_after, big.mark = ",")),
    paste0("- individuals before/after/excluded: ", r$individuals_before, " / ", r$individuals_after, " / ", r$individuals_excluded),
    paste0("- status: ", r$status)
  )
}

report_lines <- c(report_lines, "")

if (nrow(excluded_dt)) {
  report_lines <- c(report_lines, "Excluded individuals:")
  for (i in seq_len(nrow(excluded_dt))) {
    r <- excluded_dt[i]
    report_lines <- c(
      report_lines,
      paste0(
        "- ", r$dataset_name,
        " | individual_id=", r$individual_id,
        " | individual_name=", r$individual_name,
        " | counts foraging/locomotion/resting=",
        r$foraging, "/", r$locomotion, "/", r$resting,
        " | reason=", r$exclusion_reason
      )
    )
  }
} else {
  report_lines <- c(report_lines, "Excluded individuals: none")
}

report_lines <- c(
  report_lines,
  "",
  "Supplementary outputs:",
  paste0("- Figure S1 PNG: ", figure_s1_png_path),
  paste0("- Figure S1 source CSV: ", figure_s1_csv_path),
  paste0("- Table S5 CSV: ", table_s5_csv_path),
  "",
  "Next step:",
  "- Use data_processed_final for raw time-series models.",
  "- Use data_processed_features for feature-based models.",
  "- Use individual_key for leakage-safe train/test splitting."
)

writeLines(report_lines, report_txt_path)

cat("\n==============================\n")
cat("07 FINAL MODEL DATASETS DONE\n")
cat("Final window files :", length(window_out_files), "\n")
cat("Final feature files:", length(feature_out_files), "\n")
cat("Excluded individuals:", nrow(excluded_dt), "\n")
cat("Report:", report_txt_path, "\n")
cat("Figure S1 PNG:", figure_s1_png_path, "\n")
cat("Table S5 CSV:", table_s5_csv_path, "\n")
cat("==============================\n")
