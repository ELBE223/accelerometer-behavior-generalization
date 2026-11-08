if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(arrow, dplyr, tibble, purrr, readxl, stringr)

in_dir <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_2/Data_Horse_Proccessed"
settings_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_2/settings.xlsx"
out_dir <- file.path(in_dir, "qa_datetime_hz")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(in_dir)) stop("Input folder not found: ", in_dir)

expected_mode <- "auto"   # auto, sample, window
fallback_srs <- 100
fallback_overlap <- 0.5
fallback_window_size <- 200
reference_start_time <- as.POSIXct("2017-01-01 09:00:00", tz = "UTC")
tolerance_seconds <- 1e-6

read_settings_values <- function(path) {
  out <- list(
    srs = fallback_srs,
    overlap = fallback_overlap,
    window_size = fallback_window_size,
    source = "fallback"
  )
  
  if (!file.exists(path)) return(out)
  
  sheets <- tryCatch(readxl::excel_sheets(path), error = function(e) character(0))
  if (length(sheets) == 0) return(out)
  
  for (sheet in sheets) {
    x <- tryCatch(readxl::read_excel(path, sheet = sheet), error = function(e) NULL)
    if (is.null(x) || nrow(x) == 0) next
    
    names(x) <- stringr::str_trim(names(x))
    has_needed <- all(c("srs", "overlap", "window_size") %in% names(x))
    if (!has_needed) next
    
    srs <- suppressWarnings(as.numeric(x$srs[[1]]))
    overlap <- suppressWarnings(as.numeric(x$overlap[[1]]))
    window_size <- suppressWarnings(as.numeric(x$window_size[[1]]))
    
    if (is.finite(srs) && is.finite(overlap) && is.finite(window_size)) {
      out$srs <- srs
      out$overlap <- overlap
      out$window_size <- window_size
      out$source <- basename(path)
      return(out)
    }
  }
  
  out
}

parse_datetime_col <- function(x) {
  if (inherits(x, "POSIXct") || inherits(x, "POSIXt")) {
    return(as.POSIXct(x, tz = "UTC"))
  }
  
  if (inherits(x, "Date")) {
    return(as.POSIXct(x, tz = "UTC"))
  }
  
  if (is.numeric(x)) {
    out_num <- tryCatch(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"), error = function(e) NULL)
    if (!is.null(out_num)) return(out_num)
  }
  
  suppressWarnings(as.POSIXct(
    x,
    tz = "UTC",
    tryFormats = c(
      "%Y-%m-%d %H:%M:%OS",
      "%Y-%m-%d %H:%M:%S",
      "%d.%m.%Y %H:%M:%OS",
      "%d.%m.%Y %H:%M:%S",
      "%d.%m.%Y %H:%M"
    )
  ))
}

safe_stat <- function(x, fun, fallback = NA_real_) {
  if (length(x) == 0 || all(is.na(x))) return(fallback)
  fun(x, na.rm = TRUE)
}

check_against_step <- function(dt_diff, expected_step, tolerance_seconds) {
  if (length(dt_diff) == 0 || all(is.na(dt_diff))) {
    return(list(
      expected_step = expected_step,
      mean_abs_dev = NA_real_,
      max_abs_dev = NA_real_,
      within_tol_n = NA_integer_,
      within_tol_pct = NA_real_
    ))
  }
  
  dev <- abs(dt_diff - expected_step)
  within <- dev <= tolerance_seconds
  
  list(
    expected_step = expected_step,
    mean_abs_dev = mean(dev, na.rm = TRUE),
    max_abs_dev = max(dev, na.rm = TRUE),
    within_tol_n = sum(within, na.rm = TRUE),
    within_tol_pct = 100 * mean(within, na.rm = TRUE)
  )
}

classify_fit <- function(sample_fit, window_fit, expected_mode = "auto") {
  if (expected_mode == "sample") return("sample")
  if (expected_mode == "window") return("window")
  
  s <- sample_fit$within_tol_pct
  w <- window_fit$within_tol_pct
  
  if (is.na(s) && is.na(w)) return("unknown")
  if (!is.na(s) && !is.na(w)) {
    if (abs(s - w) < 0.001) return("ambiguous")
    return(ifelse(s > w, "sample", "window"))
  }
  
  if (!is.na(s)) return("sample")
  if (!is.na(w)) return("window")
  "unknown"
}

settings_vals <- read_settings_values(settings_path)
srs <- settings_vals$srs
overlap <- settings_vals$overlap
window_size <- settings_vals$window_size

sample_step <- 1 / srs
window_step <- window_size * (1 - overlap) / srs

cat("\n==============================\n")
cat("DateTime QA settings\n")
cat("==============================\n")
cat("Settings source:", settings_vals$source, "\n")
cat("srs:", srs, "\n")
cat("overlap:", overlap, "\n")
cat("window_size:", window_size, "\n")
cat("sample_step_seconds:", sample_step, "\n")
cat("window_step_seconds:", window_step, "\n")
cat("expected_mode:", expected_mode, "\n")

parquet_files <- list.files(
  path = in_dir,
  pattern = "\\.parquet$",
  full.names = TRUE,
  recursive = TRUE,
  ignore.case = TRUE
)

parquet_files <- parquet_files[
  grepl("^Horse_dataset_2_.*\\.parquet$", basename(parquet_files)) &
    !grepl("export_summary|mapping_check", basename(parquet_files), ignore.case = TRUE)
]

if (length(parquet_files) == 0) stop("No horse parquet files found in: ", in_dir)

results <- purrr::map_dfr(parquet_files, function(file) {
  cat("\n==================================================\n")
  cat("Checking:", basename(file), "\n")
  cat("==================================================\n")
  
  df <- arrow::read_parquet(file) %>% tibble::as_tibble()
  
  has_datetime <- "DateTime" %in% names(df)
  if (!has_datetime) {
    cat("Missing DateTime column\n")
    return(tibble::tibble(
      file = basename(file),
      folder = dirname(file),
      n_rows = nrow(df),
      has_datetime = FALSE,
      datetime_parsed_pct = 0,
      na_datetime_n = NA_integer_,
      first_datetime = NA_character_,
      last_datetime = NA_character_,
      starts_at_reference_time = NA,
      duration_seconds = NA_real_,
      dt_diff_n = NA_integer_,
      duplicate_timestamps_n = NA_integer_,
      negative_steps_n = NA_integer_,
      zero_steps_n = NA_integer_,
      min_step_seconds = NA_real_,
      median_step_seconds = NA_real_,
      max_step_seconds = NA_real_,
      expected_sample_step = sample_step,
      expected_window_step = window_step,
      sample_within_tol_pct = NA_real_,
      window_within_tol_pct = NA_real_,
      sample_mean_abs_dev = NA_real_,
      window_mean_abs_dev = NA_real_,
      inferred_time_model = "missing_datetime",
      pass_structure = FALSE,
      pass_expected_mode = FALSE,
      overall_status = "FAIL"
    ))
  }
  
  dt <- parse_datetime_col(df$DateTime)
  parsed_pct <- 100 * mean(!is.na(dt))
  dt_diff <- as.numeric(diff(dt), units = "secs")
  
  sample_fit <- check_against_step(dt_diff, sample_step, tolerance_seconds)
  window_fit <- check_against_step(dt_diff, window_step, tolerance_seconds)
  inferred_time_model <- classify_fit(sample_fit, window_fit, expected_mode)
  
  pass_structure <- (
    all(!is.na(dt)) &&
      sum(dt_diff < 0, na.rm = TRUE) == 0 &&
      sum(dt_diff == 0, na.rm = TRUE) == 0
  )
  
  pass_expected_mode <- if (expected_mode == "auto") {
    max(sample_fit$within_tol_pct, window_fit$within_tol_pct, na.rm = TRUE) == 100
  } else if (expected_mode == "sample") {
    isTRUE(sample_fit$within_tol_pct == 100)
  } else if (expected_mode == "window") {
    isTRUE(window_fit$within_tol_pct == 100)
  } else {
    FALSE
  }
  
  overall_status <- if (isTRUE(pass_structure) && isTRUE(pass_expected_mode)) "PASS" else "CHECK"
  
  first_dt <- if (length(dt) > 0) dt[1] else as.POSIXct(NA)
  last_dt <- if (length(dt) > 0) dt[length(dt)] else as.POSIXct(NA)
  
  cat("Rows:", nrow(df), "\n")
  cat("Parsed DateTime %:", round(parsed_pct, 2), "\n")
  cat("Inferred model:", inferred_time_model, "\n")
  cat("Sample match %:", round(sample_fit$within_tol_pct, 4), "\n")
  cat("Window match %:", round(window_fit$within_tol_pct, 4), "\n")
  cat("Status:", overall_status, "\n")
  
  tibble::tibble(
    file = basename(file),
    folder = dirname(file),
    n_rows = nrow(df),
    has_datetime = TRUE,
    datetime_parsed_pct = parsed_pct,
    na_datetime_n = sum(is.na(dt)),
    first_datetime = as.character(first_dt),
    last_datetime = as.character(last_dt),
    starts_at_reference_time = isTRUE(!is.na(first_dt) && first_dt == reference_start_time),
    duration_seconds = as.numeric(difftime(last_dt, first_dt, units = "secs")),
    dt_diff_n = length(dt_diff),
    duplicate_timestamps_n = sum(duplicated(dt), na.rm = TRUE),
    negative_steps_n = sum(dt_diff < 0, na.rm = TRUE),
    zero_steps_n = sum(dt_diff == 0, na.rm = TRUE),
    min_step_seconds = safe_stat(dt_diff, min),
    median_step_seconds = safe_stat(dt_diff, median),
    max_step_seconds = safe_stat(dt_diff, max),
    expected_sample_step = sample_fit$expected_step,
    expected_window_step = window_fit$expected_step,
    sample_within_tol_pct = sample_fit$within_tol_pct,
    window_within_tol_pct = window_fit$within_tol_pct,
    sample_mean_abs_dev = sample_fit$mean_abs_dev,
    window_mean_abs_dev = window_fit$mean_abs_dev,
    inferred_time_model = inferred_time_model,
    pass_structure = pass_structure,
    pass_expected_mode = pass_expected_mode,
    overall_status = overall_status
  )
})

results <- results %>%
  dplyr::arrange(overall_status, file)

summary_txt <- c(
  "DateTime / Hz QA summary",
  paste("Created:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste("Input folder:", in_dir),
  paste("Settings source:", settings_vals$source),
  paste("srs:", srs),
  paste("overlap:", overlap),
  paste("window_size:", window_size),
  paste("sample_step_seconds:", sample_step),
  paste("window_step_seconds:", window_step),
  paste("expected_mode:", expected_mode),
  paste("files_checked:", nrow(results)),
  paste("pass_n:", sum(results$overall_status == "PASS", na.rm = TRUE)),
  paste("check_n:", sum(results$overall_status == "CHECK", na.rm = TRUE)),
  "",
  "Note:",
  "This script can validate internal DateTime spacing, but not absolute real-world clock time.",
  "Without metadata timestamps, only structural consistency can be checked."
)

arrow::write_parquet(results, file.path(out_dir, "Horse_dataset_2_datetime_hz_QA.parquet"))
write.csv(results, file.path(out_dir, "Horse_dataset_2_datetime_hz_QA.csv"), row.names = FALSE)
writeLines(summary_txt, file.path(out_dir, "Horse_dataset_2_datetime_hz_QA_summary.txt"))

cat("\n==============================\n")
cat("QA result overview\n")
cat("==============================\n")
print(results)

cat("\nSaved to:\n")
cat(file.path(out_dir, "Horse_dataset_2_datetime_hz_QA.parquet"), "\n")
cat(file.path(out_dir, "Horse_dataset_2_datetime_hz_QA.csv"), "\n")
cat(file.path(out_dir, "Horse_dataset_2_datetime_hz_QA_summary.txt"), "\n")
