# 03_windowing_preflight.R
# Checks whether model-ready data are ready for 25 Hz / 3 s windowing.
# This script writes diagnostics only.

Sys.setenv(ARROW_NUM_THREADS = "2")

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(dplyr)
})

# ---------- settings ----------

processing_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processing"
script_id <- "03"
expected_file_count <- 12L

input_dir <- file.path(processing_root, "01", "01_parquet")
output_root <- file.path(processing_root, script_id)
out_parquet_dir <- file.path(output_root, "03_parquet")
out_csv_dir <- file.path(output_root, "03_csv")
out_txt_dir <- file.path(output_root, "03_txt")

input_report_path <- file.path(out_csv_dir, "03_input_files.csv")
summary_csv_path <- file.path(out_csv_dir, "03_windowing_summary.csv")
class_csv_path <- file.path(out_csv_dir, "03_class_summary.csv")
individual_class_csv_path <- file.path(out_csv_dir, "03_individual_class_summary.csv")
segment_csv_path <- file.path(out_csv_dir, "03_segment_summary.csv")
report_txt_path <- file.path(out_txt_dir, "03_windowing_preflight_report.txt")

target_hz <- 25L
target_window_sec <- 3
target_n_samples <- as.integer(target_hz * target_window_sec)
target_classes <- c("foraging", "locomotion", "resting")

max_rows_for_timestamp_diagnostics <- 2000000L
run_full_segment_diagnostics <- TRUE
allow_padded_short_clip_count <- TRUE

known_structure <- data.table(
  dataset_name = c(
    "Bison_dataset_1", "Cattle_dataset_1", "Dog_dataset_1", "Dog_dataset_2",
    "Fox_dataset_1", "Fox_dataset_2", "Giraffe_dataset_1", "Hedgehog_dataset_1",
    "Horse_dataset_1", "Horse_dataset_2", "Raccoon_dataset_1", "Raccoon_dataset_2"
  ),
  expected_route = c(
    "clip_repeated_timestamp", NA_character_, "clip_repeated_timestamp", "clip_repeated_timestamp",
    "mixed_or_unclear", "sample_based_per_row", "sample_based_per_row", "clip_repeated_timestamp",
    "clip_repeated_timestamp", "sample_based_per_row", "clip_repeated_timestamp", "mixed_or_unclear"
  ),
  known_hz = c(
    33.33, NA_real_, 33.33, 20.00,
    33.33, NA_real_, 33.33, 100.00,
    33.33, 100.00, 33.33, 33.33
  ),
  known_clip_sec = c(
    2.46, NA_real_, 3.30, 6.00,
    3.30, NA_real_, NA_real_, 2.64,
    2.46, NA_real_, 2.88, 3.30
  ),
  note = c(
    "Known repeated-timestamp clip data.",
    "No fixed route stored; infer from timestamps.",
    "Known repeated-timestamp clip data.",
    "Known repeated-timestamp clip data; 6 s clips can split into two 3 s windows.",
    "Mixed or unclear; inspect before final windowing.",
    "Known sample-based row-level data.",
    "Known sample-based row-level data.",
    "Known repeated-timestamp clip data.",
    "Known repeated-timestamp clip data.",
    "Known sample-based row-level data.",
    "Known repeated-timestamp clip data.",
    "Mixed or unclear; inspect before final windowing."
  )
)

required_cols <- c(
  "dataset_name", "species", "individual_id", "individual_name",
  "source_file", "source_parquet_file", "datetime", "row_nr",
  "x_g", "y_g", "z_g", "acc_magnitude_g", "main_class", "burst_uid"
)

# ---------- helpers ----------

create_output_dirs <- function() {
  dirs <- c(output_root, out_parquet_dir, out_csv_dir, out_txt_dir)
  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
}

clean_dataset_name <- function(file) {
  x <- tools::file_path_sans_ext(basename(file))
  sub("_mr$", "", x)
}

list_input_files <- function(dir) {
  if (!dir.exists(dir)) stop("Input folder does not exist: ", dir)

  files <- list.files(dir, pattern = "_mr\\.parquet$", full.names = TRUE)
  files <- sort(files)

  if (length(files) != expected_file_count) {
    stop(
      "Expected ", expected_file_count, " '*_mr.parquet' files, but found ",
      length(files), " in: ", dir
    )
  }

  data.table(
    dataset_name = vapply(files, clean_dataset_name, character(1)),
    input_file = basename(files),
    input_path = files
  )
}

safe_num <- function(x) suppressWarnings(as.numeric(x))

as_datetime_utc <- function(x) {
  if (inherits(x, "POSIXct")) return(x)
  if (inherits(x, "POSIXt")) return(as.POSIXct(x, tz = "UTC"))
  if (is.numeric(x)) return(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"))
  suppressWarnings(as.POSIXct(as.character(x), tz = "UTC"))
}

safe_median <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  stats::median(x)
}

safe_quantile <- function(x, prob) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  as.numeric(stats::quantile(x, probs = prob, na.rm = TRUE, names = FALSE, type = 7))
}

safe_min_time <- function(x) {
  x <- x[!is.na(x)]
  if (!length(x)) return(as.POSIXct(NA, tz = "UTC"))
  min(x)
}

safe_max_time <- function(x) {
  x <- x[!is.na(x)]
  if (!length(x)) return(as.POSIXct(NA, tz = "UTC"))
  max(x)
}

read_needed_columns <- function(file) {
  ds <- arrow::open_dataset(file, format = "parquet")
  cols <- intersect(required_cols, names(ds))

  dt <- ds %>%
    dplyr::select(dplyr::all_of(cols)) %>%
    dplyr::collect() %>%
    as.data.table()

  rm(ds)
  gc(FALSE)

  for (nm in required_cols) {
    if (!(nm %in% names(dt))) dt[, (nm) := NA]
  }

  setcolorder(dt, required_cols)
  dt
}

prepare_dt <- function(dt, dataset_name_from_file) {
  if (!nrow(dt)) return(dt)

  dt[, dataset_name := as.character(dataset_name)]
  dt[is.na(dataset_name) | dataset_name == "", dataset_name := dataset_name_from_file]

  dt[, species := as.character(species)]
  dt[, individual_id := as.character(individual_id)]
  dt[, individual_name := as.character(individual_name)]
  dt[is.na(individual_id) | individual_id == "", individual_id := individual_name]
  dt[is.na(individual_id) | individual_id == "", individual_id := "unknown_individual"]

  dt[, main_class := tolower(trimws(as.character(main_class)))]
  dt[, datetime := as_datetime_utc(datetime)]
  dt[, row_nr := suppressWarnings(as.integer(row_nr))]
  dt[is.na(row_nr), row_nr := .I]

  dt[, x_g := safe_num(x_g)]
  dt[, y_g := safe_num(y_g)]
  dt[, z_g := safe_num(z_g)]
  dt[, acc_magnitude_g := safe_num(acc_magnitude_g)]

  missing_mag <- is.na(dt$acc_magnitude_g) & !is.na(dt$x_g) & !is.na(dt$y_g) & !is.na(dt$z_g)
  if (any(missing_mag)) dt[missing_mag, acc_magnitude_g := sqrt(x_g^2 + y_g^2 + z_g^2)]

  dt
}

make_timestamp_diagnostics <- function(dt) {
  if (!nrow(dt)) {
    return(data.table(
      timestamp_diag_rows = 0L,
      timestamp_groups = 0L,
      repeated_timestamp_groups = 0L,
      rows_in_repeated_timestamps = 0L,
      repeated_timestamp_row_prop = NA_real_,
      median_rows_per_timestamp = NA_real_,
      p95_rows_per_timestamp = NA_real_,
      max_rows_per_timestamp = NA_integer_
    ))
  }

  n_diag <- min(nrow(dt), max_rows_for_timestamp_diagnostics)
  diag_dt <- dt[seq_len(n_diag), .(individual_id, datetime, main_class)]
  ts_groups <- diag_dt[, .N, by = .(individual_id, datetime, main_class)]

  out <- data.table(
    timestamp_diag_rows = n_diag,
    timestamp_groups = nrow(ts_groups),
    repeated_timestamp_groups = sum(ts_groups$N > 1L),
    rows_in_repeated_timestamps = sum(ts_groups[N > 1L, N]),
    repeated_timestamp_row_prop = sum(ts_groups[N > 1L, N]) / n_diag,
    median_rows_per_timestamp = safe_median(ts_groups$N),
    p95_rows_per_timestamp = safe_quantile(ts_groups$N, 0.95),
    max_rows_per_timestamp = ifelse(nrow(ts_groups) == 0L, NA_integer_, max(ts_groups$N))
  )

  rm(diag_dt, ts_groups)
  gc(FALSE)
  out
}

make_diff_diagnostics <- function(dt) {
  if (!nrow(dt)) {
    return(data.table(
      positive_diff_n = 0L,
      zero_or_negative_diff_n = 0L,
      median_positive_dt_sec = NA_real_,
      p05_positive_dt_sec = NA_real_,
      p95_positive_dt_sec = NA_real_,
      estimated_hz_from_median_dt = NA_real_
    ))
  }

  setorderv(dt, c("individual_id", "datetime", "row_nr"))
  dt[, diff_sec := as.numeric(datetime - shift(datetime), units = "secs"), by = individual_id]

  pos_diff <- dt[!is.na(diff_sec) & is.finite(diff_sec) & diff_sec > 0 & diff_sec < 3600, diff_sec]
  zero_or_neg <- dt[!is.na(diff_sec) & is.finite(diff_sec) & diff_sec <= 0, .N]
  med <- safe_median(pos_diff)

  out <- data.table(
    positive_diff_n = length(pos_diff),
    zero_or_negative_diff_n = zero_or_neg,
    median_positive_dt_sec = med,
    p05_positive_dt_sec = safe_quantile(pos_diff, 0.05),
    p95_positive_dt_sec = safe_quantile(pos_diff, 0.95),
    estimated_hz_from_median_dt = ifelse(is.na(med) || med <= 0, NA_real_, 1 / med)
  )

  rm(pos_diff)
  gc(FALSE)
  out
}

classify_structure <- function(ts_diag, diff_diag, known_route) {
  repeated_prop <- ts_diag$repeated_timestamp_row_prop[1]
  median_rows <- ts_diag$median_rows_per_timestamp[1]
  hz <- diff_diag$estimated_hz_from_median_dt[1]

  auto_guess <- if (!is.na(repeated_prop) && !is.na(median_rows) && repeated_prop > 0.50 && median_rows >= 10) {
    "clip_repeated_timestamp"
  } else if (!is.na(hz) && hz >= 5 && hz <= 250 && (is.na(repeated_prop) || repeated_prop < 0.10)) {
    "sample_based_per_row"
  } else {
    "mixed_or_unclear"
  }

  route <- if (!is.na(known_route) && known_route != "") known_route else auto_guess
  list(auto_guess = auto_guess, recommended_route = route)
}

make_segment_diagnostics <- function(dt, route, median_positive_dt_sec, known_clip_sec) {
  empty <- data.table(
    segment_method = route,
    n_segments_or_clips = NA_integer_,
    median_segment_sec = NA_real_,
    p05_segment_sec = NA_real_,
    p95_segment_sec = NA_real_,
    segments_lt_3s = NA_integer_,
    full_3s_windows_no_padding = NA_integer_,
    possible_3s_windows_if_padding = NA_integer_
  )

  if (!nrow(dt)) return(empty)

  if (route == "clip_repeated_timestamp") {
    clips <- dt[, .N, by = .(individual_id, datetime, main_class)][N > 1L]
    if (!nrow(clips)) return(empty)

    full_windows <- if (is.na(known_clip_sec)) NA_integer_ else floor(known_clip_sec / target_window_sec) * nrow(clips)
    padded_windows <- if (is.na(known_clip_sec)) {
      NA_integer_
    } else if (allow_padded_short_clip_count) {
      max(1L, floor(known_clip_sec / target_window_sec)) * nrow(clips)
    } else {
      full_windows
    }

    out <- data.table(
      segment_method = route,
      n_segments_or_clips = nrow(clips),
      median_segment_sec = known_clip_sec,
      p05_segment_sec = known_clip_sec,
      p95_segment_sec = known_clip_sec,
      segments_lt_3s = ifelse(is.na(known_clip_sec), NA_integer_, ifelse(known_clip_sec < 3, nrow(clips), 0L)),
      full_3s_windows_no_padding = as.integer(full_windows),
      possible_3s_windows_if_padding = as.integer(padded_windows)
    )

    rm(clips)
    gc(FALSE)
    return(out)
  }

  if (!isTRUE(run_full_segment_diagnostics)) return(empty)
  if (is.na(median_positive_dt_sec) || median_positive_dt_sec <= 0) return(empty)

  gap_threshold <- max(3 * median_positive_dt_sec, 0.25)

  setorderv(dt, c("individual_id", "datetime", "row_nr"))
  if (!("diff_sec" %in% names(dt))) {
    dt[, diff_sec := as.numeric(datetime - shift(datetime), units = "secs"), by = individual_id]
  }

  dt[, prev_class := shift(main_class), by = individual_id]
  dt[, new_segment := is.na(diff_sec) | diff_sec <= 0 | diff_sec > gap_threshold | main_class != prev_class]
  dt[, segment_id := cumsum(new_segment), by = individual_id]

  seg <- dt[, .(
    n_rows = .N,
    start_time = safe_min_time(datetime),
    end_time = safe_max_time(datetime)
  ), by = .(individual_id, segment_id, main_class)]

  seg[, duration_sec := as.numeric(end_time - start_time, units = "secs") + median_positive_dt_sec]
  seg[duration_sec < 0 | !is.finite(duration_sec), duration_sec := NA_real_]

  full_windows <- sum(floor(seg$duration_sec / target_window_sec), na.rm = TRUE)
  padded_windows <- if (allow_padded_short_clip_count) {
    sum(ifelse(!is.na(seg$duration_sec) & seg$duration_sec > 0, pmax(1L, floor(seg$duration_sec / target_window_sec)), 0L), na.rm = TRUE)
  } else {
    full_windows
  }

  out <- data.table(
    segment_method = route,
    n_segments_or_clips = nrow(seg),
    median_segment_sec = safe_median(seg$duration_sec),
    p05_segment_sec = safe_quantile(seg$duration_sec, 0.05),
    p95_segment_sec = safe_quantile(seg$duration_sec, 0.95),
    segments_lt_3s = sum(seg$duration_sec < target_window_sec, na.rm = TRUE),
    full_3s_windows_no_padding = as.integer(full_windows),
    possible_3s_windows_if_padding = as.integer(padded_windows)
  )

  rm(seg)
  gc(FALSE)
  out
}

make_recommendation <- function(route, known_clip_sec) {
  if (route == "clip_repeated_timestamp" && !is.na(known_clip_sec) && known_clip_sec < target_window_sec) {
    return("Short clip data. Decide whether to pad/interpolate or exclude clips below 3 s.")
  }

  if (route == "clip_repeated_timestamp" && !is.na(known_clip_sec) && known_clip_sec >= target_window_sec) {
    return("Clip data can be split or interpolated to 75 samples per 3 s window.")
  }

  if (route == "sample_based_per_row") {
    return("Use continuous homogeneous segments by individual and class, then extract 3 s windows.")
  }

  if (route == "mixed_or_unclear") {
    return("Inspect manually before windowing; dataset may need a custom route.")
  }

  "No special issue detected."
}

analyze_one_file <- function(file) {
  dataset_name_from_file <- clean_dataset_name(file)

  cat("\n---\n")
  cat("Analyzing:", basename(file), "\n")

  dt <- read_needed_columns(file)
  dt <- prepare_dt(dt, dataset_name_from_file)

  dataset_name <- unique(dt$dataset_name)[1]
  known <- known_structure[known_structure[["dataset_name"]] == dataset_name]
  if (!nrow(known)) {
    known <- data.table(
      dataset_name = dataset_name,
      expected_route = NA_character_,
      known_hz = NA_real_,
      known_clip_sec = NA_real_,
      note = "No stored structure metadata."
    )
  }

  class_summary <- dt[, .(
    rows = .N,
    n_individuals = uniqueN(individual_id),
    n_unique_datetimes = uniqueN(datetime),
    acc_magnitude_median = safe_median(acc_magnitude_g)
  ), by = .(dataset_name, main_class)]

  individual_class_summary <- dt[, .(
    rows = .N,
    n_unique_datetimes = uniqueN(datetime),
    first_datetime = safe_min_time(datetime),
    last_datetime = safe_max_time(datetime)
  ), by = .(dataset_name, individual_id, main_class)]

  ts_diag <- make_timestamp_diagnostics(dt)
  diff_diag <- make_diff_diagnostics(dt)
  structure <- classify_structure(ts_diag, diff_diag, known$expected_route[1])

  segment_diag <- make_segment_diagnostics(
    dt = dt,
    route = structure$recommended_route,
    median_positive_dt_sec = diff_diag$median_positive_dt_sec[1],
    known_clip_sec = known$known_clip_sec[1]
  )

  dataset_summary <- cbind(
    data.table(
      dataset_name = dataset_name,
      file = basename(file),
      n_rows = nrow(dt),
      n_individuals = uniqueN(dt$individual_id),
      species = paste(sort(unique(na.omit(dt$species))), collapse = "; "),
      classes = paste(sort(unique(na.omit(dt$main_class))), collapse = "; "),
      missing_xyz_rows = sum(is.na(dt$x_g) | is.na(dt$y_g) | is.na(dt$z_g)),
      missing_datetime_rows = sum(is.na(dt$datetime)),
      non_target_or_missing_class_rows = sum(is.na(dt$main_class) | !(dt$main_class %in% target_classes)),
      target_hz = target_hz,
      target_window_sec = target_window_sec,
      target_n_samples = target_n_samples,
      known_expected_route = known$expected_route[1],
      known_hz = known$known_hz[1],
      known_clip_sec = known$known_clip_sec[1],
      automatic_structure_guess = structure$auto_guess,
      recommended_route = structure$recommended_route,
      recommendation = make_recommendation(structure$recommended_route, known$known_clip_sec[1]),
      known_note = known$note[1]
    ),
    ts_diag,
    diff_diag,
    segment_diag
  )

  cat("Rows:", format(nrow(dt), big.mark = ","), "\n")
  cat("Route:", structure$recommended_route, "\n")
  cat("Full 3s windows:", format(dataset_summary$full_3s_windows_no_padding, big.mark = ","), "\n")

  rm(dt)
  gc(FALSE)

  list(
    dataset = dataset_summary,
    class = class_summary,
    individual_class = individual_class_summary,
    segment = cbind(data.table(dataset_name = dataset_name, file = basename(file)), segment_diag)
  )
}

make_text_report <- function(summary_dt) {
  lines <- c(
    "03 Windowing Preflight Report",
    paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "Goal:",
    "- Check readiness for 25 Hz / 3 s / 75-sample windowing.",
    "- Read exactly 12 model-ready parquet files from Script 01 output.",
    "- Write diagnostic CSV and TXT reports only.",
    "- Do not modify model-ready parquet files.",
    "",
    "Folders:",
    paste0("- input: ", input_dir),
    paste0("- parquet: ", out_parquet_dir, " (reserved; no files written)"),
    paste0("- csv: ", out_csv_dir),
    paste0("- txt: ", out_txt_dir),
    "",
    "Target windowing:",
    paste0("- target_hz: ", target_hz),
    paste0("- target_window_sec: ", target_window_sec),
    paste0("- target_n_samples: ", target_n_samples),
    paste0("- target classes: ", paste(target_classes, collapse = ", ")),
    "",
    paste0("Datasets checked: ", nrow(summary_dt)),
    paste0("Total rows checked: ", format(sum(summary_dt$n_rows, na.rm = TRUE), big.mark = ",")),
    "",
    "Dataset summary:"
  )

  for (i in seq_len(nrow(summary_dt))) {
    r <- summary_dt[i]
    lines <- c(
      lines,
      "",
      paste0("Dataset: ", r$dataset_name),
      paste0("- rows: ", format(r$n_rows, big.mark = ",")),
      paste0("- individuals: ", r$n_individuals),
      paste0("- classes: ", r$classes),
      paste0("- automatic structure guess: ", r$automatic_structure_guess),
      paste0("- recommended route: ", r$recommended_route),
      paste0("- estimated Hz: ", round(r$estimated_hz_from_median_dt, 3)),
      paste0("- repeated timestamp rows: ", round(100 * r$repeated_timestamp_row_prop, 2), "%"),
      paste0("- known clip sec: ", ifelse(is.na(r$known_clip_sec), "NA", r$known_clip_sec)),
      paste0("- segments/clips: ", format(r$n_segments_or_clips, big.mark = ",")),
      paste0("- full 3s windows without padding: ", format(r$full_3s_windows_no_padding, big.mark = ",")),
      paste0("- possible 3s windows if padding allowed: ", format(r$possible_3s_windows_if_padding, big.mark = ",")),
      paste0("- recommendation: ", r$recommendation)
    )
  }

  c(
    lines,
    "",
    "Next step:",
    "- Use this report to configure the actual windowing script.",
    "- Decide explicitly how to handle short clips below 3 s.",
    "- For sample-based data, build continuous segments before extracting windows."
  )
}

# ---------- run ----------

create_output_dirs()

jobs <- list_input_files(input_dir)
fwrite(jobs, input_report_path)

cat("\n==============================\n")
cat("03 WINDOWING PREFLIGHT START\n")
cat("==============================\n")
cat("Files found:", nrow(jobs), "\n")

result_list <- vector("list", nrow(jobs))

for (i in seq_len(nrow(jobs))) {
  result_list[[i]] <- analyze_one_file(jobs$input_path[i])
  gc(FALSE)
}

summary_dt <- rbindlist(lapply(result_list, `[[`, "dataset"), fill = TRUE)
class_dt <- rbindlist(lapply(result_list, `[[`, "class"), fill = TRUE)
individual_class_dt <- rbindlist(lapply(result_list, `[[`, "individual_class"), fill = TRUE)
segment_dt <- rbindlist(lapply(result_list, `[[`, "segment"), fill = TRUE)

setorder(summary_dt, dataset_name)
setorder(class_dt, dataset_name, main_class)
setorder(individual_class_dt, dataset_name, individual_id, main_class)
setorder(segment_dt, dataset_name)

fwrite(summary_dt, summary_csv_path)
fwrite(class_dt, class_csv_path)
fwrite(individual_class_dt, individual_class_csv_path)
fwrite(segment_dt, segment_csv_path)
writeLines(make_text_report(summary_dt), report_txt_path)

cat("\n==============================\n")
cat("SUMMARY\n")
cat("==============================\n")
print(summary_dt[, .(
  dataset_name,
  n_rows,
  automatic_structure_guess,
  recommended_route,
  estimated_hz_from_median_dt,
  repeated_timestamp_row_prop,
  known_clip_sec,
  full_3s_windows_no_padding,
  possible_3s_windows_if_padding
)])

cat("\n==============================\n")
cat("DONE\n")
cat("==============================\n")
cat("Output root:\n")
cat(output_root, "\n")
