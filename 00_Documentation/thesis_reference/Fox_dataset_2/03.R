# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(dplyr, stringr, tibble)

# paths
raw_dir <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Fox/Dataset_2/Data_Fox_Raw"

if (!dir.exists(raw_dir)) stop("Raw folder not found: ", raw_dir)

# helper
extract_tag_id <- function(x) {
  out <- stringr::str_extract(basename(x), "\\d+")
  suppressWarnings(as.integer(out))
}

count_tokens <- function(x) {
  x <- stringr::str_trim(as.character(x))
  x[x == ""] <- NA_character_
  out <- stringr::str_count(x, "\\S+")
  out[is.na(x)] <- NA_integer_
  out
}

# find ACC files
acc_files <- list.files(
  path = raw_dir,
  pattern = "_ACC_movebank\\.csv$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(acc_files) == 0) stop("No ACC files found in: ", raw_dir)

acc_index <- tibble::tibble(
  acc_file = acc_files,
  tag_id = extract_tag_id(acc_files)
) %>%
  dplyr::arrange(tag_id) %>%
  dplyr::mutate(Name = sprintf("FOX%02d", dplyr::row_number()))

qc_list <- lapply(seq_len(nrow(acc_index)), function(i) {
  acc_file <- acc_index$acc_file[i]
  tag_id   <- acc_index$tag_id[i]
  fox_name <- acc_index$Name[i]
  
  cat("\n==============================\n")
  cat("QC:", fox_name, "| tag", tag_id, "\n")
  cat("==============================\n")
  
  acc <- read.csv(acc_file, stringsAsFactors = FALSE)
  
  acc <- acc %>%
    dplyr::mutate(
      burst_timestamp = as.POSIXct(timestamp, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"),
      sampling_freq   = suppressWarnings(as.numeric(eobs.acceleration.sampling.frequency.per.axis)),
      n_values        = count_tokens(eobs.accelerations.raw),
      n_samples       = n_values / 3,
      burst_length_s  = n_samples / sampling_freq
    )
  
  dt_diff <- as.numeric(diff(acc$burst_timestamp), units = "secs")
  
  freq_values <- sort(unique(stats::na.omit(acc$sampling_freq)))
  sample_values <- sort(unique(stats::na.omit(acc$n_samples)))
  
  qc_row <- tibble::tibble(
    Name = fox_name,
    tag_id = tag_id,
    file = basename(acc_file),
    n_bursts = nrow(acc),
    first_timestamp = min(acc$burst_timestamp, na.rm = TRUE),
    last_timestamp = max(acc$burst_timestamp, na.rm = TRUE),
    n_unique_hz = length(freq_values),
    hz_values = paste(round(freq_values, 4), collapse = "; "),
    median_hz = round(stats::median(acc$sampling_freq, na.rm = TRUE), 4),
    n_unique_samples = length(sample_values),
    samples_values = paste(sample_values, collapse = "; "),
    median_samples = stats::median(acc$n_samples, na.rm = TRUE),
    median_burst_length_s = round(stats::median(acc$burst_length_s, na.rm = TRUE), 4),
    min_burst_length_s = round(min(acc$burst_length_s, na.rm = TRUE), 4),
    max_burst_length_s = round(max(acc$burst_length_s, na.rm = TRUE), 4),
    median_burst_interval_s = round(stats::median(dt_diff, na.rm = TRUE), 4),
    min_burst_interval_s = round(min(dt_diff, na.rm = TRUE), 4),
    max_burst_interval_s = round(max(dt_diff, na.rm = TRUE), 4),
    invalid_triplets = sum(!is.na(acc$n_values) & acc$n_values %% 3 != 0),
    missing_raw = sum(is.na(acc$eobs.accelerations.raw) | stringr::str_trim(acc$eobs.accelerations.raw) == ""),
    missing_timestamp = sum(is.na(acc$burst_timestamp)),
    missing_hz = sum(is.na(acc$sampling_freq))
  )
  
  print(qc_row)
  
  qc_row
})

qc_table <- dplyr::bind_rows(qc_list)

cat("\n==============================\n")
cat("ACC QC summary\n")
cat("==============================\n")
print(qc_table)

# optional export
qc_out <- file.path(raw_dir, "ACC_QC_summary.csv")
write.csv(qc_table, qc_out, row.names = FALSE)

cat("\nSaved QC summary to:\n")
cat(qc_out, "\n")

qc_seconds <- qc_table %>%
  dplyr::rowwise() %>%
  dplyr::mutate(
    burst_seconds = paste(
      round(as.numeric(strsplit(samples_values, ";\\s*")[[1]]) / median_hz, 3),
      "s",
      collapse = "; "
    )
  ) %>%
  dplyr::ungroup() %>%
  dplyr::select(Name, tag_id, hz_values, samples_values, burst_seconds)

print(qc_seconds)