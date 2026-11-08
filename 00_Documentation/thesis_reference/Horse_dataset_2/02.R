if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(dplyr, stringr, tibble, purrr, arrow, tidyr, readxl)

raw_dir <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_2/Data_Horse_Raw"
out_dir <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_2/Data_Horse_Proccessed"
settings_file <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_2/settings.xlsx"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(raw_dir)) stop("Raw folder not found: ", raw_dir)

required_behaviors <- c("Foraging", "Locomotion", "Resting")
allowed_behaviors <- c(required_behaviors, "Other")

default_start_time <- as.POSIXct("2017-01-01 09:00:00", tz = "UTC")
fallback_sampling_rate_hz <- 100
time_mode <- "sample"

# "identity" = copy Ax/Ay/Az
# "ms2_to_g" = divide by 9.80665
# "g_to_ms2" = multiply by 9.80665
axis_conversion <- "identity"

mapping_reference <- list(
  Locomotion = c("SCH", "TRB", "GAL"),
  Resting    = c("SKO", "SKM", "LIO", "STL"),
  Foraging   = c("KKO", "KKM", "TRK", "FvB", "GRA", "HFO", "HFM", "HFT"),
  Other      = c("PUT", "SaB", "KOS", "GFP", "WAL")
)

mapping_reference_df <- tibble::enframe(mapping_reference, name = "Behavior", value = "Code") %>%
  tidyr::unnest_longer(Code)

read_settings_value <- function(settings_file, col_name, fallback = NA_real_) {
  if (!file.exists(settings_file)) return(fallback)
  x <- tryCatch(readxl::read_excel(settings_file, sheet = 1), error = function(e) NULL)
  if (is.null(x) || nrow(x) == 0 || !col_name %in% names(x)) return(fallback)
  suppressWarnings(as.numeric(x[[col_name]][1]))
}

sampling_rate_hz <- read_settings_value(settings_file, "srs", fallback_sampling_rate_hz)
window_size <- read_settings_value(settings_file, "window_size", NA_real_)
overlap <- read_settings_value(settings_file, "overlap", NA_real_)

get_step_seconds <- function(time_mode = "sample", sampling_rate_hz, window_size = NA_real_, overlap = NA_real_) {
  if (is.na(sampling_rate_hz) || sampling_rate_hz <= 0) {
    stop("Invalid sampling_rate_hz: ", sampling_rate_hz)
  }
  
  if (time_mode == "sample") {
    return(1 / sampling_rate_hz)
  }
  
  if (time_mode == "window") {
    if (is.na(window_size) || window_size <= 0) stop("Invalid window_size: ", window_size)
    if (is.na(overlap) || overlap < 0 || overlap >= 1) stop("Invalid overlap: ", overlap)
    return((window_size * (1 - overlap)) / sampling_rate_hz)
  }
  
  stop("Unknown time_mode: ", time_mode)
}

convert_axis <- function(x, mode = axis_conversion) {
  x <- suppressWarnings(as.numeric(x))
  
  if (mode == "identity") return(x)
  if (mode == "ms2_to_g") return(x / 9.80665)
  if (mode == "g_to_ms2") return(x * 9.80665)
  
  stop("Unknown axis_conversion: ", mode)
}

make_datetime <- function(df,
                          start_time = default_start_time,
                          time_mode = time_mode,
                          sampling_rate_hz = sampling_rate_hz,
                          window_size = window_size,
                          overlap = overlap) {
  candidate_cols <- c("DateTime", "datetime", "timestamp", "Timestamp", "date_time", "DATE_TIME")
  existing_cols <- intersect(candidate_cols, names(df))
  
  if (length(existing_cols) > 0) {
    col_name <- existing_cols[1]
    
    dt <- suppressWarnings(as.POSIXct(
      df[[col_name]],
      tz = "UTC",
      tryFormats = c(
        "%Y-%m-%d %H:%M:%OS",
        "%Y-%m-%d %H:%M:%S",
        "%d.%m.%Y %H:%M:%S",
        "%d.%m.%Y %H:%M"
      )
    ))
    
    if (sum(!is.na(dt)) == nrow(df)) return(dt)
    warning("Timestamp column found but not fully parsed: ", col_name, ". Using generated DateTime.")
  }
  
  step_seconds <- get_step_seconds(
    time_mode = time_mode,
    sampling_rate_hz = sampling_rate_hz,
    window_size = window_size,
    overlap = overlap
  )
  
  start_time + ((seq_len(nrow(df)) - 1) * step_seconds)
}

extract_first_value <- function(x, fallback = NA) {
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) return(fallback)
  x[1]
}

parquet_files <- list.files(
  path = raw_dir,
  pattern = "\\.parquet$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(parquet_files) == 0) stop("No .parquet files found in: ", raw_dir)

cat("\n==============================\n")
cat("Horse mapping reference\n")
cat("==============================\n")
print(mapping_reference_df)
cat("\nSampling rate (Hz):", sampling_rate_hz, "\n")
cat("Time mode:", time_mode, "\n")
cat("Step (seconds):", get_step_seconds(time_mode, sampling_rate_hz, window_size, overlap), "\n")

summary_list <- list()
mapping_check_list <- list()

for (file in parquet_files) {
  cat("\n======================================================\n")
  cat("Processing:", basename(file), "\n")
  cat("======================================================\n")
  
  df <- arrow::read_parquet(file) %>%
    tibble::as_tibble()
  
  needed_cols <- c("subject_id", "horse_name", "Ax", "Ay", "Az", "behavior_4cat", "label_clean")
  missing_cols <- setdiff(needed_cols, names(df))
  
  if (length(missing_cols) > 0) {
    cat("Skipped - missing columns:", paste(missing_cols, collapse = ", "), "\n")
    
    summary_list[[basename(file)]] <- tibble::tibble(
      file = basename(file),
      horse_name = NA_character_,
      subject_id = NA_integer_,
      include = FALSE,
      reason = paste("missing columns:", paste(missing_cols, collapse = ", ")),
      behaviors_found = NA_character_,
      input_rows = nrow(df),
      exported_rows = 0,
      out_file = NA_character_
    )
    next
  }
  
  horse_name <- as.character(extract_first_value(df$horse_name, tools::file_path_sans_ext(basename(file))))
  subject_id <- suppressWarnings(as.integer(extract_first_value(df$subject_id, NA_integer_)))
  
  df <- df %>%
    dplyr::mutate(
      Behavior = stringr::str_trim(as.character(behavior_4cat)),
      label_clean = stringr::str_trim(as.character(label_clean))
    )
  
  df$DateTime <- make_datetime(
    df = df,
    start_time = default_start_time,
    time_mode = time_mode,
    sampling_rate_hz = sampling_rate_hz,
    window_size = window_size,
    overlap = overlap
  )
  
  behaviors_found <- sort(unique(stats::na.omit(df$Behavior)))
  has_required <- all(required_behaviors %in% behaviors_found)
  has_unknown <- any(!behaviors_found %in% allowed_behaviors)
  
  mapping_check_list[[horse_name]] <- df %>%
    dplyr::count(horse_name, label_clean, Behavior, name = "n") %>%
    dplyr::arrange(Behavior, label_clean)
  
  if (!has_required || has_unknown) {
    reason <- c()
    if (!has_required) reason <- c(reason, "missing one or more required behaviors")
    if (has_unknown) reason <- c(reason, "contains unknown behavior values")
    
    cat("Skipped -", paste(reason, collapse = " | "), "\n")
    cat("Behaviors found:", paste(behaviors_found, collapse = ", "), "\n")
    
    summary_list[[horse_name]] <- tibble::tibble(
      file = basename(file),
      horse_name = horse_name,
      subject_id = subject_id,
      include = FALSE,
      reason = paste(reason, collapse = " | "),
      behaviors_found = paste(behaviors_found, collapse = ", "),
      input_rows = nrow(df),
      exported_rows = 0,
      out_file = NA_character_
    )
    next
  }
  
  export_df <- df %>%
    dplyr::filter(Behavior %in% required_behaviors) %>%
    dplyr::transmute(
      `Individual ID` = suppressWarnings(as.integer(subject_id)),
      Species = "Equus caballus",
      Name = horse_name,
      DateTime = DateTime,
      X = convert_axis(Ax),
      Y = convert_axis(Ay),
      Z = convert_axis(Az),
      Behavior = Behavior
    ) %>%
    dplyr::filter(!is.na(X), !is.na(Y), !is.na(Z), !is.na(Behavior))
  
  if (nrow(export_df) == 0) {
    cat("Skipped - no rows left after export filter\n")
    
    summary_list[[horse_name]] <- tibble::tibble(
      file = basename(file),
      horse_name = horse_name,
      subject_id = subject_id,
      include = FALSE,
      reason = "no rows left after export filter",
      behaviors_found = paste(behaviors_found, collapse = ", "),
      input_rows = nrow(df),
      exported_rows = 0,
      out_file = NA_character_
    )
    next
  }
  
  out_file <- file.path(out_dir, paste0("Horse_dataset_2_", horse_name, ".parquet"))
  arrow::write_parquet(export_df, out_file)
  
  class_stats <- export_df %>%
    dplyr::count(Behavior, name = "n") %>%
    dplyr::mutate(percent = round(100 * n / sum(n), 2)) %>%
    dplyr::arrange(desc(n))
  
  cat("Included\n")
  cat("Rows in:", nrow(df), "\n")
  cat("Rows out:", nrow(export_df), "\n")
  cat("Saved to:", out_file, "\n")
  print(class_stats)
  
  summary_list[[horse_name]] <- tibble::tibble(
    file = basename(file),
    horse_name = horse_name,
    subject_id = subject_id,
    include = TRUE,
    reason = "OK",
    behaviors_found = paste(behaviors_found, collapse = ", "),
    input_rows = nrow(df),
    exported_rows = nrow(export_df),
    out_file = out_file
  )
}

summary_table <- dplyr::bind_rows(summary_list) %>%
  dplyr::arrange(dplyr::desc(include), horse_name)

mapping_check_table <- dplyr::bind_rows(mapping_check_list) %>%
  dplyr::arrange(horse_name, Behavior, label_clean)

arrow::write_parquet(summary_table, file.path(out_dir, "Horse_dataset_2_export_summary.parquet"))
arrow::write_parquet(mapping_check_table, file.path(out_dir, "Horse_dataset_2_mapping_check.parquet"))

write.csv(mapping_reference_df, file.path(out_dir, "Horse_dataset_2_mapping_reference.csv"), row.names = FALSE)
write.csv(summary_table, file.path(out_dir, "Horse_dataset_2_export_summary.csv"), row.names = FALSE)
write.csv(mapping_check_table, file.path(out_dir, "Horse_dataset_2_mapping_check.csv"), row.names = FALSE)

cat("\n==============================\n")
cat("Final export summary\n")
cat("==============================\n")
print(summary_table)

cat("\n==============================\n")
cat("Observed label -> behavior check\n")
cat("==============================\n")
print(mapping_check_table)
