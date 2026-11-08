# 02_xyz_scale_diag.R
# Check xyz scale candidates for the 12 model-ready parquet files.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
})

# ---------- settings ----------

processing_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processing"

# Script 01 parquet output folder. Put exactly 12 files here.
input_dir <- file.path(processing_root, "01", "01_parquet")

# Script 02 output structure.
output_root <- file.path(processing_root, "02")
out_parquet_dir <- file.path(output_root, "02_parquet")
out_csv_dir <- file.path(output_root, "02_csv")
out_txt_dir <- file.path(output_root, "02_txt")

expected_n_files <- 12
input_file_suffix <- "_mr.parquet"

candidate_center <- 2048
candidate_divisors <- c(
  "pm16g_div128" = 128,
  "pm8g_div256"  = 256,
  "pm4g_div512"  = 512,
  "pm2g_div1024" = 1024
)

# Keep FALSE for exact diagnostics.
use_row_sample <- FALSE
max_rows_per_dataset <- 2000000
sample_seed <- 123

# Output files.
input_report_path <- file.path(out_csv_dir, "02_input_files.csv")
scale_csv_path <- file.path(out_csv_dir, "02_xyz_scale.csv")
best_csv_path <- file.path(out_csv_dir, "02_xyz_best.csv")
report_txt_path <- file.path(out_txt_dir, "02_xyz_report.txt")

# ---------- folders ----------

create_output_dirs <- function() {
  dirs <- c(output_root, out_parquet_dir, out_csv_dir, out_txt_dir)
  purrr::walk(dirs, ~ dir.create(.x, recursive = TRUE, showWarnings = FALSE))
}

# ---------- input ----------

list_input_files <- function(input_dir) {
  if (!dir.exists(input_dir)) {
    stop("Input folder does not exist: ", input_dir)
  }

  visible_files <- list.files(
    input_dir,
    full.names = TRUE,
    recursive = FALSE,
    all.files = FALSE,
    no.. = TRUE
  )
  visible_files <- visible_files[!file.info(visible_files)$isdir]

  parquet_files <- visible_files[stringr::str_detect(basename(visible_files), "\\.parquet$")]
  other_files <- setdiff(visible_files, parquet_files)

  if (length(other_files) > 0) {
    warning(
      "Ignoring non-parquet files in input folder: ",
      paste(basename(other_files), collapse = "; ")
    )
  }

  if (length(parquet_files) != expected_n_files) {
    stop(
      "Expected exactly ", expected_n_files,
      " direct parquet files in input_dir, but found ", length(parquet_files), ".\n",
      "Input folder: ", input_dir
    )
  }

  wrong_suffix <- parquet_files[!stringr::str_ends(basename(parquet_files), input_file_suffix)]
  if (length(wrong_suffix) > 0) {
    stop(
      "All parquet files must end with ", input_file_suffix, ". Problem files: ",
      paste(basename(wrong_suffix), collapse = "; ")
    )
  }

  sort(parquet_files)
}

make_dataset_name <- function(file) {
  basename(file) %>%
    stringr::str_remove("\\.parquet$") %>%
    stringr::str_remove("_mr$")
}

make_jobs <- function(input_dir) {
  files <- list_input_files(input_dir)
  dataset_names <- purrr::map_chr(files, make_dataset_name)

  if (anyDuplicated(dataset_names) > 0) {
    stop("Duplicate dataset names found after removing file suffix.")
  }

  tibble(
    dataset_name = dataset_names,
    input_file = files,
    input_file_name = basename(files),
    input_size_mb = round(file.size(files) / 1024^2, 2)
  ) %>%
    arrange(dataset_name)
}

# ---------- helpers ----------

safe_min <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  min(x)
}

safe_max <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  max(x)
}

safe_median <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  median(x)
}

safe_mean <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  mean(x)
}

safe_quantile <- function(x, p) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  as.numeric(stats::quantile(x, probs = p, names = FALSE, na.rm = TRUE))
}

safe_prop <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_real_)
  mean(x)
}

safe_mode_num <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)

  tab <- sort(table(x), decreasing = TRUE)
  as.numeric(names(tab)[1])
}

safe_mode_chr <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) return(NA_character_)

  tab <- sort(table(x), decreasing = TRUE)
  names(tab)[1]
}

convert_raw_to_g <- function(raw, center, divisor) {
  (as.numeric(raw) - center) / divisor
}

# ---------- read ----------

read_required_columns <- function(file, dataset_name) {
  required_cols <- c(
    "dataset_name",
    "x_raw", "y_raw", "z_raw",
    "x_g", "y_g", "z_g",
    "acc_magnitude_g",
    "xyz_divisor",
    "xyz_conversion",
    "xyz_scale_inferred"
  )

  df <- tryCatch({
    ds <- arrow::open_dataset(file, format = "parquet")
    selected_cols <- intersect(required_cols, names(ds))

    ds %>%
      dplyr::select(dplyr::all_of(selected_cols)) %>%
      dplyr::collect()
  }, error = function(e) {
    message("Column-select read failed for ", basename(file), ". Using read_parquet().")
    full_df <- arrow::read_parquet(file, as_data_frame = TRUE)
    dplyr::select(full_df, dplyr::any_of(required_cols))
  })

  if (!"dataset_name" %in% names(df)) {
    df$dataset_name <- dataset_name
  }

  if (isTRUE(use_row_sample) && nrow(df) > max_rows_per_dataset) {
    set.seed(sample_seed)
    df <- df[sample.int(nrow(df), max_rows_per_dataset), , drop = FALSE]
  }

  df
}

# ---------- diagnostics ----------

diagnose_dataset_scale <- function(df, dataset_name) {
  raw_cols <- c("x_raw", "y_raw", "z_raw")
  g_cols <- c("x_g", "y_g", "z_g")

  has_raw <- all(raw_cols %in% names(df)) &&
    any(!is.na(df$x_raw)) &&
    any(!is.na(df$y_raw)) &&
    any(!is.na(df$z_raw))

  has_g <- all(g_cols %in% names(df)) &&
    any(!is.na(df$x_g)) &&
    any(!is.na(df$y_g)) &&
    any(!is.na(df$z_g))

  current_divisor <- if ("xyz_divisor" %in% names(df)) safe_mode_num(df$xyz_divisor) else NA_real_
  current_conversion <- if ("xyz_conversion" %in% names(df)) safe_mode_chr(df$xyz_conversion) else NA_character_
  current_scale <- if ("xyz_scale_inferred" %in% names(df)) safe_mode_chr(df$xyz_scale_inferred) else NA_character_

  if (!has_raw) {
    current_mag <- if (has_g) {
      sqrt(as.numeric(df$x_g)^2 + as.numeric(df$y_g)^2 + as.numeric(df$z_g)^2)
    } else {
      rep(NA_real_, nrow(df))
    }

    n_xyz_rows <- if (has_g) {
      sum(!is.na(df$x_g) & !is.na(df$y_g) & !is.na(df$z_g))
    } else {
      0L
    }

    return(tibble(
      dataset_name = dataset_name,
      tested_scale = "not_tested_no_raw_xyz",
      divisor = NA_real_,
      current_divisor = current_divisor,
      current_conversion = current_conversion,
      current_scale = current_scale,
      divisor_matches_current = NA,
      n_rows = nrow(df),
      n_xyz_rows = n_xyz_rows,
      x_raw_min = NA_real_,
      x_raw_max = NA_real_,
      y_raw_min = NA_real_,
      y_raw_max = NA_real_,
      z_raw_min = NA_real_,
      z_raw_max = NA_real_,
      saturation_low_prop = NA_real_,
      saturation_high_prop = NA_real_,
      median_magnitude_g = safe_median(current_mag),
      mean_magnitude_g = safe_mean(current_mag),
      p05_magnitude_g = safe_quantile(current_mag, 0.05),
      p95_magnitude_g = safe_quantile(current_mag, 0.95),
      distance_to_1g = abs(safe_median(current_mag) - 1),
      note = ifelse(has_g, "no raw xyz; existing g only", "no xyz available")
    ))
  }

  raw_tbl <- tibble(
    x_raw = suppressWarnings(as.numeric(df$x_raw)),
    y_raw = suppressWarnings(as.numeric(df$y_raw)),
    z_raw = suppressWarnings(as.numeric(df$z_raw))
  ) %>%
    filter(!is.na(x_raw), !is.na(y_raw), !is.na(z_raw))

  rm(df)
  invisible(gc())

  raw_summary <- tibble(
    n_xyz_rows = nrow(raw_tbl),
    x_raw_min = safe_min(raw_tbl$x_raw),
    x_raw_max = safe_max(raw_tbl$x_raw),
    y_raw_min = safe_min(raw_tbl$y_raw),
    y_raw_max = safe_max(raw_tbl$y_raw),
    z_raw_min = safe_min(raw_tbl$z_raw),
    z_raw_max = safe_max(raw_tbl$z_raw),
    saturation_low_prop = safe_prop(
      raw_tbl$x_raw <= 5 | raw_tbl$y_raw <= 5 | raw_tbl$z_raw <= 5
    ),
    saturation_high_prop = safe_prop(
      raw_tbl$x_raw >= 4090 | raw_tbl$y_raw >= 4090 | raw_tbl$z_raw >= 4090
    )
  )

  out <- purrr::imap_dfr(candidate_divisors, function(divisor, scale_name) {
    x_g <- convert_raw_to_g(raw_tbl$x_raw, candidate_center, divisor)
    y_g <- convert_raw_to_g(raw_tbl$y_raw, candidate_center, divisor)
    z_g <- convert_raw_to_g(raw_tbl$z_raw, candidate_center, divisor)
    mag <- sqrt(x_g^2 + y_g^2 + z_g^2)

    tibble(
      dataset_name = dataset_name,
      tested_scale = scale_name,
      divisor = as.numeric(divisor),
      current_divisor = current_divisor,
      current_conversion = current_conversion,
      current_scale = current_scale,
      divisor_matches_current = ifelse(
        is.na(current_divisor),
        NA,
        as.numeric(divisor) == current_divisor
      ),
      n_rows = nrow(raw_tbl),
      n_xyz_rows = raw_summary$n_xyz_rows,
      x_raw_min = raw_summary$x_raw_min,
      x_raw_max = raw_summary$x_raw_max,
      y_raw_min = raw_summary$y_raw_min,
      y_raw_max = raw_summary$y_raw_max,
      z_raw_min = raw_summary$z_raw_min,
      z_raw_max = raw_summary$z_raw_max,
      saturation_low_prop = raw_summary$saturation_low_prop,
      saturation_high_prop = raw_summary$saturation_high_prop,
      median_magnitude_g = safe_median(mag),
      mean_magnitude_g = safe_mean(mag),
      p05_magnitude_g = safe_quantile(mag, 0.05),
      p95_magnitude_g = safe_quantile(mag, 0.95),
      distance_to_1g = abs(safe_median(mag) - 1),
      note = ifelse(isTRUE(use_row_sample), "raw xyz tested on row sample", "raw xyz tested")
    )
  })

  rm(raw_tbl)
  invisible(gc())

  out
}

choose_best_scale <- function(scale_tbl) {
  scale_tbl %>%
    group_by(dataset_name) %>%
    arrange(distance_to_1g, .by_group = TRUE) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(
      recommendation = case_when(
        tested_scale == "not_tested_no_raw_xyz" & note == "no xyz available" ~
          "No xyz available. Keep as behavior-only dataset.",
        tested_scale == "not_tested_no_raw_xyz" ~
          "No raw xyz available. Keep existing g-values.",
        !is.na(divisor_matches_current) & divisor_matches_current ~
          "Best candidate matches current divisor.",
        !is.na(current_divisor) & !divisor_matches_current ~
          "Best candidate differs from current divisor. Check Script 01 divisor lookup.",
        median_magnitude_g < 0.7 ~
          "Median magnitude below 1g. Check scale or movement pattern.",
        median_magnitude_g > 1.4 ~
          "Median magnitude above 1g. Check range, offset, or strong movement.",
        saturation_low_prop > 0.01 | saturation_high_prop > 0.01 ~
          "Best by median, but raw values show possible clipping.",
        TRUE ~
          "Best candidate by median magnitude closest to 1g."
      )
    )
}

make_txt_report <- function(input_report, best_tbl, full_tbl) {
  lines <- c(
    "02 XYZ Scale Diagnostics Report",
    paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "Goal:",
    "- Check raw xyz to g scale candidates.",
    "- Read exactly 12 direct parquet files from Script 01 output.",
    "- Write diagnostic CSV and TXT reports only.",
    "- Do not modify model-ready parquet files.",
    "",
    "Folders:",
    paste0("- input: ", input_dir),
    paste0("- parquet: ", out_parquet_dir, " (reserved; no files written)"),
    paste0("- csv: ", out_csv_dir),
    paste0("- txt: ", out_txt_dir),
    "",
    paste0("Input files: ", nrow(input_report)),
    paste0("Datasets tested: ", dplyr::n_distinct(full_tbl$dataset_name)),
    paste0("Row sampling used: ", use_row_sample),
    paste0("Max rows per dataset if sampled: ", format(max_rows_per_dataset, big.mark = ",")),
    "",
    "Tested conversions:",
    "- pm16g_div128:  (raw - 2048) / 128",
    "- pm8g_div256:   (raw - 2048) / 256",
    "- pm4g_div512:   (raw - 2048) / 512",
    "- pm2g_div1024:  (raw - 2048) / 1024",
    "",
    "Interpretation:",
    "- Median acceleration magnitude close to 1g is usually plausible.",
    "- This is a heuristic diagnostic, not final biological validation.",
    "- Strong movement can increase magnitude.",
    "- Values near 0 or 4095 can indicate clipping.",
    "",
    "Best scale by dataset:"
  )

  for (i in seq_len(nrow(best_tbl))) {
    r <- best_tbl[i, ]

    low_sat <- ifelse(is.na(r$saturation_low_prop), NA_real_, 100 * r$saturation_low_prop)
    high_sat <- ifelse(is.na(r$saturation_high_prop), NA_real_, 100 * r$saturation_high_prop)

    lines <- c(
      lines,
      "",
      paste0("Dataset: ", r$dataset_name),
      paste0("- best tested scale: ", r$tested_scale),
      paste0("- best divisor: ", ifelse(is.na(r$divisor), "NA", r$divisor)),
      paste0("- current divisor: ", ifelse(is.na(r$current_divisor), "NA", r$current_divisor)),
      paste0("- current conversion: ", ifelse(is.na(r$current_conversion), "NA", r$current_conversion)),
      paste0("- divisor matches current: ", ifelse(is.na(r$divisor_matches_current), "NA", r$divisor_matches_current)),
      paste0("- rows used: ", format(r$n_rows, big.mark = ",")),
      paste0("- xyz rows: ", format(r$n_xyz_rows, big.mark = ",")),
      paste0("- median magnitude g: ", round(r$median_magnitude_g, 4)),
      paste0("- mean magnitude g: ", round(r$mean_magnitude_g, 4)),
      paste0("- p05/p95 magnitude g: ", round(r$p05_magnitude_g, 4), " / ", round(r$p95_magnitude_g, 4)),
      paste0("- distance to 1g: ", round(r$distance_to_1g, 4)),
      paste0("- saturation low/high: ", round(low_sat, 3), "% / ", round(high_sat, 3), "%"),
      paste0("- recommendation: ", r$recommendation)
    )
  }

  c(
    lines,
    "",
    "Next step:",
    "- If best divisors match Script 01, continue with resampling and windowing.",
    "- If a divisor differs, update Script 01 and rerun Script 01 and Script 02."
  )
}

# ---------- run ----------

create_output_dirs()

jobs <- make_jobs(input_dir)
readr::write_csv(jobs, input_report_path)

cat("\nStarting Script 02 xyz scale diagnostics.\n")
cat("Input files: ", nrow(jobs), "\n\n", sep = "")

scale_parts <- vector("list", nrow(jobs))
names(scale_parts) <- jobs$dataset_name

for (i in seq_len(nrow(jobs))) {
  dataset_name <- jobs$dataset_name[[i]]
  input_file <- jobs$input_file[[i]]

  cat("[", i, "/", nrow(jobs), "] Diagnosing: ", dataset_name, "\n", sep = "")

  df <- read_required_columns(input_file, dataset_name)
  scale_parts[[dataset_name]] <- diagnose_dataset_scale(df, dataset_name)

  rm(df)
  invisible(gc())
}

scale_report <- dplyr::bind_rows(scale_parts)
best_report <- choose_best_scale(scale_report)

readr::write_csv(scale_report, scale_csv_path)
readr::write_csv(best_report, best_csv_path)
writeLines(make_txt_report(jobs, best_report, scale_report), report_txt_path)

assign("script02_input_files", jobs, envir = .GlobalEnv)
assign("script02_xyz_scale_report", scale_report, envir = .GlobalEnv)
assign("script02_xyz_best_report", best_report, envir = .GlobalEnv)

cat("\nFinished Script 02.\n")
cat("Datasets tested: ", nrow(jobs), "\n", sep = "")
cat("Parquet folder: ", out_parquet_dir, "\n", sep = "")
cat("CSV folder: ", out_csv_dir, "\n", sep = "")
cat("TXT folder: ", out_txt_dir, "\n", sep = "")
cat("Best report: ", best_csv_path, "\n", sep = "")
cat("TXT report: ", report_txt_path, "\n\n", sep = "")

print(best_report, width = Inf)
