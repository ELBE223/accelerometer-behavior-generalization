# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(dplyr, stringr, tibble, purrr, arrow)

# paths
raw_dir <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Fox/Dataset_2/Data_Fox_Raw"
out_dir <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Fox/Dataset_2/Data_Fox_Proccessed"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (!dir.exists(raw_dir)) stop("Raw folder not found: ", raw_dir)

# behavior mapping
behavior_map <- c(
  WALKING  = "Locomotion",
  TROTTING = "Locomotion",
  RESTING  = "Resting",
  EATING   = "Foraging",
  STOCKING = "Foraging",
  GROOMING = "Other",
  OTHER    = "Other"
)

# parse one ACC burst row to long format
parse_acc_row <- function(raw_string, burst_time, tag_id, freq, species, name, behavior) {
  values <- strsplit(raw_string, "\\s+")[[1]]
  values <- values[values != ""]
  values <- suppressWarnings(as.numeric(values))

  if (length(values) == 0 || any(is.na(values))) return(NULL)
  if (is.na(freq) || freq <= 0) return(NULL)
  if (length(values) %% 3 != 0) return(NULL)

  mat <- matrix(values, ncol = 3, byrow = TRUE)
  n <- nrow(mat)

  tibble::tibble(
    `Individual ID` = tag_id,
    Species         = species,
    Name            = name,
    DateTime        = burst_time + ((seq_len(n) - 1) / freq),
    X               = mat[, 1],
    Y               = mat[, 2],
    Z               = mat[, 3],
    Behavior        = behavior
  )
}

# helper: extract first integer from file name
extract_tag_id <- function(x) {
  out <- stringr::str_extract(basename(x), "\\d+")
  suppressWarnings(as.integer(out))
}

# helper: read ACC
read_acc <- function(acc_file, fox_name) {
  acc_data <- read.csv(acc_file, stringsAsFactors = FALSE)

  acc_data %>%
    dplyr::mutate(
      row_id          = dplyr::row_number(),
      burst_timestamp = as.POSIXct(timestamp, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"),
      sampling_freq   = suppressWarnings(as.numeric(eobs.acceleration.sampling.frequency.per.axis)),
      tag_id          = suppressWarnings(as.integer(tag.local.identifier)),
      Species         = "Vulpes vulpes",
      Name            = fox_name
    )
}

# helper: read behaviour
read_beh <- function(beh_file) {
  beh_data <- read.csv(beh_file, stringsAsFactors = FALSE)

  beh_data %>%
    dplyr::mutate(
      row_id          = dplyr::row_number(),
      burst_timestamp = as.POSIXct(timestamp, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      Behavior_raw    = stringr::str_trim(as.character(bev)),
      Behavior_key    = toupper(Behavior_raw),
      Behavior        = unname(behavior_map[Behavior_key]),
      source_file     = basename(beh_file)
    )
}

# helper: compare one ACC with one behaviour candidate
score_behaviour_candidate <- function(acc_data, beh_file) {
  beh_data <- read_beh(beh_file)

  timestamp_matches <- sum(acc_data$burst_timestamp %in% beh_data$burst_timestamp, na.rm = TRUE)
  row_overlap <- min(nrow(acc_data), nrow(beh_data))
  row_diff <- abs(nrow(acc_data) - nrow(beh_data))
  mapped_rows <- sum(!is.na(beh_data$Behavior))

  tibble::tibble(
    beh_file = beh_file,
    beh_name = basename(beh_file),
    beh_rows = nrow(beh_data),
    timestamp_matches = timestamp_matches,
    row_overlap = row_overlap,
    row_diff = row_diff,
    mapped_rows = mapped_rows
  )
}

# helper: choose best behaviour file
choose_best_behaviour_file <- function(acc_data, beh_files) {
  candidate_stats <- purrr::map_dfr(beh_files, ~score_behaviour_candidate(acc_data, .x)) %>%
    dplyr::arrange(dplyr::desc(timestamp_matches), row_diff, dplyr::desc(mapped_rows), beh_name)

  best_file <- candidate_stats$beh_file[1]

  list(
    best_file = best_file,
    stats = candidate_stats
  )
}

# helper: join ACC and behaviour
join_acc_behaviour <- function(acc_data, beh_data) {
  timestamp_matches <- sum(acc_data$burst_timestamp %in% beh_data$burst_timestamp, na.rm = TRUE)

  if (timestamp_matches > 0) {
    beh_join <- beh_data %>%
      dplyr::distinct(burst_timestamp, .keep_all = TRUE) %>%
      dplyr::select(burst_timestamp, Behavior_raw, Behavior)

    joined <- acc_data %>%
      dplyr::left_join(beh_join, by = "burst_timestamp")

    join_mode <- "timestamp"
  } else {
    beh_join <- beh_data %>%
      dplyr::select(row_id, Behavior_raw, Behavior)

    joined <- acc_data %>%
      dplyr::left_join(beh_join, by = "row_id")

    join_mode <- "row_id"
  }

  list(
    data = joined,
    join_mode = join_mode,
    timestamp_matches = timestamp_matches
  )
}

# find files
acc_files <- list.files(
  path = raw_dir,
  pattern = "_ACC_movebank\\.csv$",
  full.names = TRUE,
  ignore.case = TRUE
)

beh_files <- list.files(
  path = raw_dir,
  pattern = "_behaviour\\.csv$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(acc_files) == 0) stop("No ACC files found in: ", raw_dir)
if (length(beh_files) == 0) stop("No behaviour files found in: ", raw_dir)

acc_index <- tibble::tibble(
  acc_file = acc_files,
  tag_id = extract_tag_id(acc_files)
) %>%
  dplyr::arrange(tag_id)

beh_index <- tibble::tibble(
  beh_file = beh_files,
  tag_id = extract_tag_id(beh_files)
) %>%
  dplyr::arrange(tag_id, beh_file)

fox_map <- acc_index %>%
  dplyr::distinct(tag_id) %>%
  dplyr::arrange(tag_id) %>%
  dplyr::mutate(Name = sprintf("FOX%02d", dplyr::row_number()))

cat("\n==============================\n")
cat("FOX mapping\n")
cat("==============================\n")
print(fox_map)

export_summary <- list()

for (i in seq_len(nrow(acc_index))) {
  acc_file <- acc_index$acc_file[i]
  tag_id <- acc_index$tag_id[i]
  fox_name <- fox_map$Name[fox_map$tag_id == tag_id]

  cat("\n======================================================\n")
  cat("Processing:", fox_name, "| tag", tag_id, "\n")
  cat("ACC file:", basename(acc_file), "\n")
  cat("======================================================\n")

  acc_data <- read_acc(acc_file, fox_name)

  beh_candidates <- beh_index %>%
    dplyr::filter(tag_id == !!tag_id) %>%
    dplyr::pull(beh_file)

  if (length(beh_candidates) == 0) {
    cat("No behaviour file found for tag", tag_id, "- skipped.\n")
    next
  }

  choice <- choose_best_behaviour_file(acc_data, beh_candidates)
  best_beh_file <- choice$best_file

  cat("\nBehaviour candidate check\n")
  print(choice$stats %>% dplyr::select(beh_name, beh_rows, timestamp_matches, row_diff, mapped_rows))
  cat("Selected behaviour file:", basename(best_beh_file), "\n")

  beh_data <- read_beh(best_beh_file)
  join_result <- join_acc_behaviour(acc_data, beh_data)
  acc_with_behavior <- join_result$data

  acc_with_behavior <- acc_with_behavior %>%
    dplyr::filter(!is.na(Behavior))

  if (nrow(acc_with_behavior) == 0) {
    cat("No matched and mapped ACC bursts for", fox_name, "- skipped.\n")
    next
  }

  long_list <- lapply(seq_len(nrow(acc_with_behavior)), function(j) {
    parse_acc_row(
      raw_string = acc_with_behavior$eobs.accelerations.raw[j],
      burst_time = acc_with_behavior$burst_timestamp[j],
      tag_id     = acc_with_behavior$tag_id[j],
      freq       = acc_with_behavior$sampling_freq[j],
      species    = acc_with_behavior$Species[j],
      name       = acc_with_behavior$Name[j],
      behavior   = acc_with_behavior$Behavior[j]
    )
  })

  fox_long <- dplyr::bind_rows(long_list)

  if (nrow(fox_long) == 0) {
    cat("No long-format rows created for", fox_name, "- skipped.\n")
    next
  }

  parquet_data <- fox_long %>%
    dplyr::select(
      `Individual ID`,
      Species,
      Name,
      DateTime,
      X,
      Y,
      Z,
      Behavior
    )

  out_file <- file.path(out_dir, paste0("Fox_dataset_2_", fox_name, ".parquet"))
  arrow::write_parquet(parquet_data, out_file)

  class_stats <- parquet_data %>%
    dplyr::count(Behavior, name = "n") %>%
    dplyr::mutate(percent = round(100 * n / sum(n), 2)) %>%
    dplyr::arrange(desc(n))

  cat("\nJoin mode:", join_result$join_mode, "\n")
  cat("ACC rows:", nrow(acc_data), "\n")
  cat("Behaviour rows:", nrow(beh_data), "\n")
  cat("Timestamp matches:", join_result$timestamp_matches, "\n")
  cat("Exported sensor rows:", nrow(parquet_data), "\n")
  cat("Saved to:", out_file, "\n")

  print(class_stats)

  export_summary[[fox_name]] <- tibble::tibble(
    Name = fox_name,
    tag_id = tag_id,
    acc_file = basename(acc_file),
    beh_file = basename(best_beh_file),
    join_mode = join_result$join_mode,
    acc_rows = nrow(acc_data),
    beh_rows = nrow(beh_data),
    timestamp_matches = join_result$timestamp_matches,
    exported_rows = nrow(parquet_data),
    out_file = out_file
  )
}

summary_table <- dplyr::bind_rows(export_summary)

cat("\n==============================\n")
cat("Final export summary\n")
cat("==============================\n")
print(summary_table)
