# 05_vedba_qc.R
# Computes VEDBA summaries and QC from native 62-sample windows.

Sys.setenv(ARROW_NUM_THREADS = "2")

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(ggplot2)
})

# ---------- settings ----------

processing_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processing"
script_id <- "05"
expected_dataset_count <- 12L

input_dir <- file.path(processing_root, "04", "04_parquet")
output_root <- file.path(processing_root, script_id)
out_parquet_dir <- file.path(output_root, "05_parquet")
out_csv_dir <- file.path(output_root, "05_csv")
out_txt_dir <- file.path(output_root, "05_txt")
out_plot_dir <- file.path(output_root, "05_plots")

report_txt_path <- file.path(out_txt_dir, "05_vedba_qc_report.txt")
input_csv_path <- file.path(out_csv_dir, "05_input_folders.csv")
global_csv_path <- file.path(out_csv_dir, "05_vedba_dataset_summary.csv")
qc_csv_path <- file.path(out_csv_dir, "05_vedba_behavior_order_qc.csv")

target_hz <- 25L
target_window_sec <- 2.46
target_n <- 62L

target_main_classes <- c("foraging", "locomotion", "resting")
behavior_levels <- c("Resting", "Foraging", "Locomotion")
expected_vedba_order <- c("Resting", "Foraging", "Locomotion")

write_compact_parquet <- TRUE
write_window_csv <- FALSE
write_plots <- TRUE
max_plot_rows <- 100000L
min_windows_per_behavior <- 20L

x_cols <- sprintf("x_%03d", seq_len(target_n))
y_cols <- sprintf("y_%03d", seq_len(target_n))
z_cols <- sprintf("z_%03d", seq_len(target_n))

meta_cols <- c(
  "dataset_name", "species", "individual_id", "individual_name",
  "source_file", "source_parquet_file", "main_class", "route",
  "window_id_in_source", "source_start_datetime", "window_start_datetime",
  "target_hz", "target_window_sec", "target_n_samples",
  "source_n_samples", "source_duration_sec_est", "original_hz_est",
  "short_clip_fixed_length", "full_native_from_source", "min_input_samples_ok"
)

# ---------- setup ----------

for (d in c(output_root, out_parquet_dir, out_csv_dir, out_txt_dir, out_plot_dir)) {
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
}

# ---------- helpers ----------

safe_chr <- function(x, fallback = "UNKNOWN") {
  x <- as.character(x)
  x[is.na(x) | trimws(x) == ""] <- fallback
  x
}

safe_name <- function(individual_name, individual_id) {
  out <- safe_chr(individual_name, fallback = "")
  id <- safe_chr(individual_id, fallback = "UNKNOWN")
  idx <- is.na(out) | trimws(out) == ""
  out[idx] <- id[idx]
  out[is.na(out) | trimws(out) == ""] <- "UNKNOWN"
  out
}

sanitize_file_name <- function(x) {
  x <- gsub("[^A-Za-z0-9_\\-]+", "_", as.character(x))
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  ifelse(nchar(x) == 0, "UNKNOWN", x)
}

format_num <- function(x, digits = 5) {
  ifelse(is.finite(x), sprintf(paste0("%.", digits, "f"), x), "NA")
}

as_true <- function(x) {
  y <- tolower(trimws(as.character(x)))
  !is.na(y) & y %in% c("true", "1", "yes")
}

behavior_label <- function(x) {
  x <- tolower(trimws(as.character(x)))
  fifelse(x == "resting", "Resting",
    fifelse(x == "foraging", "Foraging",
      fifelse(x == "locomotion", "Locomotion", NA_character_)
    )
  )
}

safe_schema_names <- function(file) {
  ds <- arrow::open_dataset(file, format = "parquet")
  names(ds$schema)
}

read_selected_parquet <- function(file, cols) {
  schema_names <- safe_schema_names(file)
  cols_existing <- intersect(cols, schema_names)
  dt <- as.data.table(arrow::read_parquet(file, col_select = cols_existing))
  missing_cols <- setdiff(cols, names(dt))
  for (nm in missing_cols) dt[, (nm) := NA]
  setcolorder(dt, cols)
  dt
}

# ---------- VEDBA ----------

compute_vedba <- function(dt) {
  x_mat <- as.matrix(dt[, ..x_cols]); storage.mode(x_mat) <- "double"
  y_mat <- as.matrix(dt[, ..y_cols]); storage.mode(y_mat) <- "double"
  z_mat <- as.matrix(dt[, ..z_cols]); storage.mode(z_mat) <- "double"

  x_static <- rowMeans(x_mat, na.rm = TRUE)
  y_static <- rowMeans(y_mat, na.rm = TRUE)
  z_static <- rowMeans(z_mat, na.rm = TRUE)

  x_static[!is.finite(x_static)] <- NA_real_
  y_static[!is.finite(y_static)] <- NA_real_
  z_static[!is.finite(z_static)] <- NA_real_

  x_dyn <- sweep(x_mat, 1L, x_static, "-")
  y_dyn <- sweep(y_mat, 1L, y_static, "-")
  z_dyn <- sweep(z_mat, 1L, z_static, "-")

  vedba <- rowMeans(sqrt(x_dyn^2 + y_dyn^2 + z_dyn^2), na.rm = TRUE)
  vedba[!is.finite(vedba)] <- NA_real_
  vedba
}

read_one_part <- function(part_file) {
  dt <- read_selected_parquet(part_file, c(meta_cols, x_cols, y_cols, z_cols))
  if (!nrow(dt)) return(data.table())

  dt[, main_class := tolower(trimws(as.character(main_class)))]
  dt <- dt[main_class %in% target_main_classes]
  if (!nrow(dt)) return(data.table())

  dt[, vedba := compute_vedba(dt)]
  dt[, behavior := behavior_label(main_class)]
  dt[, name := safe_name(individual_name, individual_id)]
  dt <- dt[!is.na(behavior) & is.finite(vedba)]

  keep_cols <- c(meta_cols, "behavior", "name", "vedba")
  keep_cols <- intersect(keep_cols, names(dt))
  dt[, ..keep_cols]
}

read_dataset_windows <- function(dataset_dir) {
  part_files <- sort(list.files(dataset_dir, pattern = "\\.parquet$", full.names = TRUE))
  if (!length(part_files)) return(list(dt = data.table(), part_files = character()))

  out_list <- vector("list", length(part_files))
  for (i in seq_along(part_files)) {
    cat("  part", i, "of", length(part_files), "\n")
    out_list[[i]] <- read_one_part(part_files[i])
    gc(FALSE)
  }

  list(
    dt = rbindlist(out_list, fill = TRUE, use.names = TRUE),
    part_files = part_files
  )
}

# ---------- summaries ----------

make_summaries <- function(dt) {
  behavior_summary <- dt[, .(
    n_windows = .N,
    n_individuals = uniqueN(name),
    vedba_mean = mean(vedba, na.rm = TRUE),
    vedba_median = median(vedba, na.rm = TRUE),
    vedba_sd = sd(vedba, na.rm = TRUE),
    vedba_min = min(vedba, na.rm = TRUE),
    vedba_max = max(vedba, na.rm = TRUE)
  ), by = .(behavior)]
  setorder(behavior_summary, behavior)

  individual_summary <- dt[, .(
    n_windows = .N,
    n_behaviors = uniqueN(behavior),
    behaviors_present = paste(sort(unique(as.character(behavior))), collapse = " | "),
    vedba_mean = mean(vedba, na.rm = TRUE),
    vedba_median = median(vedba, na.rm = TRUE),
    vedba_sd = sd(vedba, na.rm = TRUE),
    vedba_min = min(vedba, na.rm = TRUE),
    vedba_max = max(vedba, na.rm = TRUE)
  ), by = .(name)]
  setorder(individual_summary, name)

  individual_behavior_summary <- dt[, .(
    n_windows = .N,
    vedba_mean = mean(vedba, na.rm = TRUE),
    vedba_median = median(vedba, na.rm = TRUE),
    vedba_sd = sd(vedba, na.rm = TRUE),
    vedba_min = min(vedba, na.rm = TRUE),
    vedba_max = max(vedba, na.rm = TRUE)
  ), by = .(name, behavior)]
  setorder(individual_behavior_summary, name, behavior)

  route_summary <- dt[, .(
    n_windows = .N,
    vedba_mean = mean(vedba, na.rm = TRUE),
    vedba_median = median(vedba, na.rm = TRUE)
  ), by = .(route)]
  setorder(route_summary, route)

  list(
    behavior = behavior_summary,
    individual = individual_summary,
    individual_behavior = individual_behavior_summary,
    route = route_summary,
    flagged_individuals = individual_summary[n_behaviors <= 2]
  )
}

# ---------- QC ----------

qc_one_dataset <- function(behavior_summary, dataset_name) {
  dt <- copy(behavior_summary)
  dt[, behavior := as.character(behavior)]

  wide_n <- setNames(rep(NA_integer_, length(expected_vedba_order)), expected_vedba_order)
  wide_m <- setNames(rep(NA_real_, length(expected_vedba_order)), expected_vedba_order)

  for (b in expected_vedba_order) {
    if (b %in% dt$behavior) {
      row <- dt[behavior == b][1]
      wide_n[b] <- as.integer(row$n_windows)
      wide_m[b] <- as.numeric(row$vedba_median)
    }
  }

  missing_behaviors <- expected_vedba_order[is.na(wide_m)]
  min_n <- suppressWarnings(min(wide_n, na.rm = TRUE))
  if (!is.finite(min_n)) min_n <- NA_integer_

  delta_foraging_resting <- wide_m["Foraging"] - wide_m["Resting"]
  delta_locomotion_foraging <- wide_m["Locomotion"] - wide_m["Foraging"]

  if (length(missing_behaviors)) {
    status <- "WARN"
    reason <- paste0("Missing behavior(s): ", paste(missing_behaviors, collapse = ", "))
  } else if (any(wide_n < min_windows_per_behavior, na.rm = TRUE)) {
    status <- "WARN"
    reason <- paste0("Low behavior sample size; min n = ", min_n)
  } else if (isTRUE(delta_foraging_resting > 0) && isTRUE(delta_locomotion_foraging > 0)) {
    status <- "PASS"
    reason <- "Expected VEDBA order holds."
  } else {
    status <- "WARN"
    reason <- "Expected VEDBA order does not hold; inspect labels, route, or sensor placement."
  }

  data.table(
    dataset_name = dataset_name,
    status = status,
    reason = reason,
    resting_n = wide_n["Resting"],
    foraging_n = wide_n["Foraging"],
    locomotion_n = wide_n["Locomotion"],
    resting_median = wide_m["Resting"],
    foraging_median = wide_m["Foraging"],
    locomotion_median = wide_m["Locomotion"],
    delta_foraging_minus_resting = delta_foraging_resting,
    delta_locomotion_minus_foraging = delta_locomotion_foraging,
    min_behavior_windows = min_n
  )
}

# ---------- reports ----------

build_dataset_txt <- function(dataset_name, dt, part_files, summaries, qc_row) {
  overall <- dt[, .(
    n_windows = .N,
    n_individuals = uniqueN(name),
    n_behaviors = uniqueN(behavior),
    vedba_mean = mean(vedba, na.rm = TRUE),
    vedba_median = median(vedba, na.rm = TRUE),
    vedba_sd = sd(vedba, na.rm = TRUE),
    vedba_min = min(vedba, na.rm = TRUE),
    vedba_max = max(vedba, na.rm = TRUE)
  )]

  short_native_n <- sum(as_true(dt$short_clip_fixed_length), na.rm = TRUE)
  full_native_n <- sum(as_true(dt$full_native_from_source), na.rm = TRUE)

  lines <- c(
    paste0("Dataset: ", dataset_name),
    paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    paste0("Part files read: ", length(part_files)),
    paste0("Window rows with valid VEDBA: ", format(overall$n_windows, big.mark = ",")),
    paste0("Individuals: ", overall$n_individuals),
    paste0("Behaviors: ", paste(sort(unique(dt$behavior)), collapse = " | ")),
    paste0("Target: ", target_hz, " Hz, ", target_window_sec, " s, ", target_n, " samples"),
    paste0("Short fixed-length windows: ", format(short_native_n, big.mark = ",")),
    paste0("Full native windows: ", format(full_native_n, big.mark = ",")),
    "",
    "Overall VEDBA:",
    paste0("  mean: ", format_num(overall$vedba_mean)),
    paste0("  median: ", format_num(overall$vedba_median)),
    paste0("  sd: ", format_num(overall$vedba_sd)),
    paste0("  min: ", format_num(overall$vedba_min)),
    paste0("  max: ", format_num(overall$vedba_max)),
    "",
    "Behavior summary:"
  )

  for (i in seq_len(nrow(summaries$behavior))) {
    x <- summaries$behavior[i]
    lines <- c(lines, paste0(
      "  - ", x$behavior,
      " | n_windows=", format(x$n_windows, big.mark = ","),
      " | individuals=", x$n_individuals,
      " | median=", format_num(x$vedba_median),
      " | mean=", format_num(x$vedba_mean)
    ))
  }

  lines <- c(lines, "", "Route summary:")
  for (i in seq_len(nrow(summaries$route))) {
    x <- summaries$route[i]
    lines <- c(lines, paste0(
      "  - ", x$route,
      " | n_windows=", format(x$n_windows, big.mark = ","),
      " | median=", format_num(x$vedba_median)
    ))
  }

  lines <- c(
    lines,
    "",
    "VEDBA behavior-order QC:",
    paste0("  status: ", qc_row$status),
    paste0("  reason: ", qc_row$reason),
    paste0("  resting median: ", format_num(qc_row$resting_median)),
    paste0("  foraging median: ", format_num(qc_row$foraging_median)),
    paste0("  locomotion median: ", format_num(qc_row$locomotion_median))
  )

  if (nrow(summaries$flagged_individuals)) {
    lines <- c(lines, "", "Flagged individuals (<= 2 behaviors):")
    for (i in seq_len(nrow(summaries$flagged_individuals))) {
      x <- summaries$flagged_individuals[i]
      lines <- c(lines, paste0(
        "  - ", x$name,
        " | n_behaviors=", x$n_behaviors,
        " | behaviors=", x$behaviors_present,
        " | n_windows=", format(x$n_windows, big.mark = ",")
      ))
    }
  } else {
    lines <- c(lines, "", "Flagged individuals (<= 2 behaviors): none")
  }

  lines
}

write_dataset_plot <- function(dataset_name, dt, summaries) {
  if (!isTRUE(write_plots) || !nrow(dt)) return(NA_character_)

  plot_dt <- copy(dt)
  if (nrow(plot_dt) > max_plot_rows) {
    set.seed(42)
    plot_dt <- plot_dt[sample(.N, max_plot_rows)]
  }

  panel_names <- summaries$individual$name
  plot_dt[, name := factor(name, levels = panel_names)]
  plot_dt[, behavior := factor(behavior, levels = behavior_levels)]

  n_panels <- uniqueN(plot_dt$name)
  ncol_facets <- if (n_panels <= 4L) max(1L, n_panels) else 4L
  nrow_facets <- ceiling(n_panels / ncol_facets)
  y_max <- max(plot_dt$vedba, na.rm = TRUE)
  if (!is.finite(y_max) || y_max <= 0) y_max <- 1

  p <- ggplot(plot_dt, aes(x = behavior, y = vedba)) +
    geom_violin(trim = FALSE, scale = "width", na.rm = TRUE) +
    geom_boxplot(width = 0.12, outlier.size = 0.3, na.rm = TRUE) +
    facet_wrap(~ name, ncol = ncol_facets, scales = "fixed") +
    scale_x_discrete(drop = FALSE, limits = behavior_levels) +
    coord_cartesian(ylim = c(0, y_max)) +
    labs(
      title = paste0(dataset_name, " - VEDBA by behavior and individual"),
      subtitle = paste0(target_hz, " Hz / ", target_window_sec, " s / ", target_n, " samples"),
      x = "Behavior",
      y = "VEDBA"
    ) +
    theme_bw(base_size = 11) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold")
    )

  png_file <- file.path(out_plot_dir, paste0(sanitize_file_name(dataset_name), "_vedba.png"))
  ggsave(
    filename = png_file,
    plot = p,
    width = max(8, ncol_facets * 3.4),
    height = max(4.5, nrow_facets * 3.2),
    dpi = 300
  )

  png_file
}

# ---------- process ----------

process_dataset <- function(dataset_dir) {
  dataset_name <- basename(dataset_dir)
  safe_ds <- sanitize_file_name(dataset_name)

  cat("\n==============================\n")
  cat("Dataset:", dataset_name, "\n")
  cat("==============================\n")

  res <- read_dataset_windows(dataset_dir)
  dt <- res$dt
  part_files <- res$part_files

  if (!nrow(dt)) {
    txt_file <- file.path(out_txt_dir, paste0(safe_ds, "_vedba_qc.txt"))
    writeLines(c(
      paste0("Dataset: ", dataset_name),
      paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      "No valid VEDBA rows found."
    ), con = txt_file)

    return(list(
      summary = data.table(
        dataset_name = dataset_name,
        n_windows = 0L,
        n_individuals = 0L,
        n_behaviors = 0L,
        part_files = length(part_files),
        vedba_mean = NA_real_,
        vedba_median = NA_real_,
        vedba_sd = NA_real_,
        vedba_min = NA_real_,
        vedba_max = NA_real_,
        compact_parquet = NA_character_,
        plot_file = NA_character_
      ),
      qc = data.table(
        dataset_name = dataset_name,
        status = "FAIL",
        reason = "No valid VEDBA rows found."
      )
    ))
  }

  summaries <- make_summaries(dt)
  qc_row <- qc_one_dataset(summaries$behavior, dataset_name)

  compact_parquet <- NA_character_
  if (isTRUE(write_compact_parquet)) {
    compact_parquet <- file.path(out_parquet_dir, paste0(safe_ds, "_vedba.parquet"))
    arrow::write_parquet(dt, compact_parquet, compression = "zstd")
  }

  if (isTRUE(write_window_csv)) {
    fwrite(dt, file.path(out_csv_dir, paste0(safe_ds, "_vedba_windows.csv")))
  }

  fwrite(summaries$behavior, file.path(out_csv_dir, paste0(safe_ds, "_behavior_summary.csv")))
  fwrite(summaries$individual, file.path(out_csv_dir, paste0(safe_ds, "_individual_summary.csv")))
  fwrite(summaries$individual_behavior, file.path(out_csv_dir, paste0(safe_ds, "_individual_behavior_summary.csv")))
  fwrite(summaries$route, file.path(out_csv_dir, paste0(safe_ds, "_route_summary.csv")))

  plot_file <- write_dataset_plot(dataset_name, dt, summaries)

  txt_file <- file.path(out_txt_dir, paste0(safe_ds, "_vedba_qc.txt"))
  writeLines(build_dataset_txt(dataset_name, dt, part_files, summaries, qc_row), con = txt_file)

  dataset_summary <- dt[, .(
    n_windows = .N,
    n_individuals = uniqueN(name),
    n_behaviors = uniqueN(behavior),
    part_files = length(part_files),
    vedba_mean = mean(vedba, na.rm = TRUE),
    vedba_median = median(vedba, na.rm = TRUE),
    vedba_sd = sd(vedba, na.rm = TRUE),
    vedba_min = min(vedba, na.rm = TRUE),
    vedba_max = max(vedba, na.rm = TRUE),
    compact_parquet = compact_parquet,
    plot_file = plot_file
  )]
  dataset_summary[, dataset_name := dataset_name]
  setcolorder(dataset_summary, c("dataset_name", setdiff(names(dataset_summary), "dataset_name")))

  cat("Windows:", format(dataset_summary$n_windows, big.mark = ","), "\n")
  cat("QC:", qc_row$status, "-", qc_row$reason, "\n")

  rm(dt, summaries)
  gc(FALSE)

  list(summary = dataset_summary, qc = qc_row)
}

build_global_report <- function(input_dt, global_summary, qc_dt) {
  lines <- c(
    "05 VEDBA QC Report",
    paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "Goal:",
    "- Read native window parquet files from Script 04.",
    "- Compute window-level VEDBA from x/y/z windows.",
    "- Write compact VEDBA parquet files, summaries, plots, and QC reports.",
    "",
    "Folders:",
    paste0("- input: ", input_dir),
    paste0("- parquet: ", out_parquet_dir),
    paste0("- csv: ", out_csv_dir),
    paste0("- txt: ", out_txt_dir),
    paste0("- plots: ", out_plot_dir),
    "",
    "Target representation:",
    paste0("- target_hz: ", target_hz),
    paste0("- target_window_sec: ", target_window_sec),
    paste0("- target_n_samples: ", target_n),
    "",
    paste0("Dataset folders found: ", nrow(input_dt)),
    paste0("Datasets processed: ", nrow(global_summary)),
    paste0("Total valid VEDBA windows: ", format(sum(global_summary$n_windows, na.rm = TRUE), big.mark = ",")),
    paste0("QC PASS: ", sum(qc_dt$status == "PASS", na.rm = TRUE)),
    paste0("QC WARN: ", sum(qc_dt$status == "WARN", na.rm = TRUE)),
    paste0("QC FAIL: ", sum(qc_dt$status == "FAIL", na.rm = TRUE)),
    "",
    "Dataset summary:"
  )

  for (i in seq_len(nrow(global_summary))) {
    x <- global_summary[i]
    q <- qc_dt[dataset_name == x$dataset_name][1]
    lines <- c(lines, paste0(
      "- ", x$dataset_name,
      " | windows=", format(x$n_windows, big.mark = ","),
      " | individuals=", x$n_individuals,
      " | behaviors=", x$n_behaviors,
      " | median=", format_num(x$vedba_median),
      " | QC=", q$status
    ))
  }

  lines <- c(lines, "", "QC notes:")
  for (i in seq_len(nrow(qc_dt))) {
    q <- qc_dt[i]
    lines <- c(lines, paste0("- ", q$dataset_name, " | ", q$status, " | ", q$reason))
  }

  c(
    lines,
    "",
    "Notes:",
    "- VEDBA behavior order is a heuristic QC signal, not a hard biological rule.",
    "- Sensor placement, species, and behavior definitions can change the expected order.",
    "- Downstream feature extraction should keep the 62-sample window setting."
  )
}

# ---------- run ----------

if (!dir.exists(input_dir)) stop("Input folder does not exist: ", input_dir)

dataset_dirs <- sort(list.dirs(input_dir, full.names = TRUE, recursive = FALSE))
dataset_dirs <- dataset_dirs[vapply(dataset_dirs, function(d) {
  length(list.files(d, pattern = "\\.parquet$", full.names = TRUE)) > 0L
}, logical(1))]

input_dt <- data.table(
  dataset_name = basename(dataset_dirs),
  dataset_dir = dataset_dirs,
  n_part_files = vapply(dataset_dirs, function(d) length(list.files(d, pattern = "\\.parquet$", full.names = TRUE)), integer(1))
)
setorder(input_dt, dataset_name)
fwrite(input_dt, input_csv_path)

if (nrow(input_dt) != expected_dataset_count) {
  stop(
    "Expected ", expected_dataset_count, " dataset folders with parquet parts, but found ",
    nrow(input_dt), " in: ", input_dir
  )
}

cat("\n==============================\n")
cat("05 VEDBA QC START\n")
cat("==============================\n")

results <- vector("list", nrow(input_dt))
for (i in seq_len(nrow(input_dt))) {
  results[[i]] <- process_dataset(input_dt$dataset_dir[i])
}

global_summary <- rbindlist(lapply(results, `[[`, "summary"), fill = TRUE, use.names = TRUE)
qc_dt <- rbindlist(lapply(results, `[[`, "qc"), fill = TRUE, use.names = TRUE)

setorder(global_summary, dataset_name)
setorder(qc_dt, dataset_name)

fwrite(global_summary, global_csv_path)
fwrite(qc_dt, qc_csv_path)

arrow::write_parquet(global_summary, file.path(out_parquet_dir, "05_vedba_dataset_summary.parquet"), compression = "zstd")
arrow::write_parquet(qc_dt, file.path(out_parquet_dir, "05_vedba_behavior_order_qc.parquet"), compression = "zstd")

writeLines(build_global_report(input_dt, global_summary, qc_dt), con = report_txt_path)

cat("\n==============================\n")
cat("05 VEDBA QC SUMMARY\n")
cat("==============================\n")
print(global_summary[, .(dataset_name, n_windows, n_individuals, n_behaviors, vedba_median)])
cat("\nQC:\n")
print(qc_dt[, .(dataset_name, status, reason)])

cat("\n==============================\n")
cat("DONE\n")
cat("==============================\n")
cat("Output root:\n")
cat(output_root, "\n")
