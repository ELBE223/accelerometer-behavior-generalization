# 04_make_native_windows.R
# Builds fixed 62-sample x/y/z windows from model-ready data.
# Uses sequential processing to keep RAM usage low.

Sys.setenv(ARROW_NUM_THREADS = "2")

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(dplyr)
})

# ---------- settings ----------

processing_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processing"
script_id <- "04"
expected_file_count <- 12L

input_dir <- file.path(processing_root, "01", "01_parquet")
output_root <- file.path(processing_root, script_id)
out_parquet_dir <- file.path(output_root, "04_parquet")
out_csv_dir <- file.path(output_root, "04_csv")
out_txt_dir <- file.path(output_root, "04_txt")

# Keep old variable names for the writer functions.
output_data_dir <- out_parquet_dir
output_meta_dir <- out_csv_dir

report_txt_path <- file.path(out_txt_dir, "04_windowing_report.txt")
summary_csv_path <- file.path(out_csv_dir, "04_windowing_summary.csv")
summary_parquet_path <- file.path(out_csv_dir, "04_windowing_summary.parquet")
route_csv_path <- file.path(out_csv_dir, "04_dataset_routes.csv")

write_outputs <- TRUE
run_validation <- TRUE

# Keep output chunks small enough for low-RAM machines.
windows_per_part <- 25000L
clip_groups_per_chunk <- 2500L

# Target representation.
target_hz <- 25L
native_clip_sec <- 2.46
target_window_sec <- native_clip_sec
target_n <- as.integer(round(target_hz * target_window_sec))

target_main_classes <- c("foraging", "locomotion", "resting")

# For sample-based time series, short homogeneous segments are excluded.
# For clip-based data, each native clip is resampled to 62 samples.
keep_short_sample_segments <- FALSE
min_input_samples_per_window <- 10L

# Gap threshold for sample-based data.
# A new segment starts after behavior changes, source changes, non-increasing time, or large gaps.
gap_multiplier <- 3
gap_threshold_min_sec <- 0.25

# Manual routes based on 03 preflight diagnostics.
dataset_route_lookup <- c(
  Bison_dataset_1 = "clip",
  Cattle_dataset_1 = "sample",
  Dog_dataset_1 = "clip",
  Dog_dataset_2 = "clip",
  Fox_dataset_1 = "clip",
  Fox_dataset_2 = "sample",
  Giraffe_dataset_1 = "sample_sequence",
  Hedgehog_dataset_1 = "clip",
  Horse_dataset_1 = "clip",
  Horse_dataset_2 = "sample",
  Raccoon_dataset_1 = "clip",
  Raccoon_dataset_2 = "clip"
)

# Approximate original clip Hz for repeated-timestamp clip datasets.
# Used only to estimate source duration for clip data.
clip_hz_lookup <- c(
  Bison_dataset_1 = 33.333,
  Dog_dataset_1 = 33.333,
  Dog_dataset_2 = 20.000,
  Fox_dataset_1 = 33.333,
  Hedgehog_dataset_1 = 100.000,
  Horse_dataset_1 = 33.333,
  Raccoon_dataset_1 = 33.333,
  Raccoon_dataset_2 = 33.333
)

# Expected sample Hz for continuous sample-level datasets.
# Used as fallback if datetime spacing cannot be estimated.
sample_hz_lookup <- c(
  Cattle_dataset_1 = 25.000,
  Fox_dataset_2 = 33.333,
  Giraffe_dataset_1 = 33.333,
  Horse_dataset_2 = 100.000
)

# Special sequence route settings.
# Giraffe has continuous sample-level data, but rapid class changes can split
# homogeneous segments into pieces shorter than 2.46 s. The sequence route windows
# first and assigns the label by majority vote within each 2.46-s window.
sequence_gap_threshold_lookup <- c(
  Giraffe_dataset_1 = 0.100
)

# For Giraffe, gap-separated sequences are often shorter than 2.46 s,
# but still contain enough samples for a fixed 62-value representation.
# These short sequence units are interpolated by position instead of being dropped.
keep_short_sequence_segments <- TRUE

# ---------- setup ----------

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
dir.create(out_parquet_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_txt_dir, recursive = TRUE, showWarnings = FALSE)

x_cols <- sprintf("x_%03d", seq_len(target_n))
y_cols <- sprintf("y_%03d", seq_len(target_n))
z_cols <- sprintf("z_%03d", seq_len(target_n))

base_cols <- c(
  "dataset_name", "species", "individual_id", "individual_name",
  "source_file", "source_parquet_file", "datetime", "row_nr",
  "x_g", "y_g", "z_g", "main_class", "burst_uid"
)

# ---------- helpers ----------

clean_dataset_name <- function(file) {
  x <- tools::file_path_sans_ext(basename(file))
  sub("_mr$", "", x)
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
  for (nm in missing_cols) {
    dt[, (nm) := NA]
  }
  
  setcolorder(dt, cols)
  dt
}

standardize_dt <- function(dt, dataset_label) {
  setDT(dt)
  
  if (!inherits(dt$datetime, "POSIXct")) {
    if (is.numeric(dt$datetime)) {
      dt[, datetime := as.POSIXct(datetime, origin = "1970-01-01", tz = "UTC")]
    } else {
      dt[, datetime := as.POSIXct(as.character(datetime), tz = "UTC")]
    }
  }
  
  chr_cols <- c(
    "dataset_name", "species", "individual_id", "individual_name",
    "source_file", "source_parquet_file", "main_class", "burst_uid"
  )
  for (nm in chr_cols) {
    dt[, (nm) := as.character(get(nm))]
  }
  
  dt[is.na(dataset_name) | dataset_name == "", dataset_name := dataset_label]
  dt[, main_class := tolower(trimws(main_class))]
  dt <- dt[main_class %in% target_main_classes]
  dt <- dt[!is.na(x_g) & !is.na(y_g) & !is.na(z_g)]
  dt <- dt[!is.na(datetime)]
  
  if (!"row_nr" %in% names(dt)) dt[, row_nr := NA_integer_]
  dt[, input_order := .I]
  
  dt
}

first_value <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (!length(x)) return(NA_character_)
  as.character(x[1])
}

majority_value <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & x != ""]
  if (!length(x)) return(NA_character_)
  
  tab <- sort(table(x), decreasing = TRUE)
  names(tab)[1]
}

safe_numeric_median <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  stats::median(x)
}

get_lookup_value <- function(lookup, key, default = NA_real_) {
  if (key %in% names(lookup)) return(unname(lookup[[key]]))
  default
}

make_target_times <- function(start_sec = 0) {
  start_sec + seq(0, target_window_sec, length.out = target_n)
}

get_sequence_gap_threshold <- function(dataset_name, base_dt) {
  custom_gap <- get_lookup_value(sequence_gap_threshold_lookup, dataset_name, NA_real_)
  if (is.finite(custom_gap) && custom_gap > 0) return(custom_gap)
  
  max(gap_multiplier * base_dt, gap_threshold_min_sec)
}

resample_by_position <- function(v, n_out = target_n) {
  v <- as.numeric(v)
  ok <- is.finite(v)
  
  if (!any(ok)) return(rep(NA_real_, n_out))
  if (sum(ok) == 1L) return(rep(v[which(ok)[1]], n_out))
  
  t_in <- seq(0, 1, length.out = length(v))
  t_out <- seq(0, 1, length.out = n_out)
  
  approx(
    x = t_in[ok],
    y = v[ok],
    xout = t_out,
    method = "linear",
    rule = 2,
    ties = "ordered"
  )$y
}

resample_by_time <- function(v, t_in, t_out) {
  v <- as.numeric(v)
  t_in <- as.numeric(t_in)
  t_out <- as.numeric(t_out)
  
  ok <- is.finite(v) & is.finite(t_in)
  
  if (!any(ok)) return(rep(NA_real_, length(t_out)))
  if (sum(ok) == 1L) return(rep(v[which(ok)[1]], length(t_out)))
  
  ord <- order(t_in[ok])
  x <- t_in[ok][ord]
  y <- v[ok][ord]
  
  keep <- !duplicated(x)
  x <- x[keep]
  y <- y[keep]
  
  if (length(x) == 1L) return(rep(y[1], length(t_out)))
  
  approx(
    x = x,
    y = y,
    xout = t_out,
    method = "linear",
    rule = 2,
    ties = "ordered"
  )$y
}

make_window_dt <- function(meta_dt, x_mat, y_mat, z_mat) {
  setDT(meta_dt)
  
  x_dt <- as.data.table(x_mat)
  y_dt <- as.data.table(y_mat)
  z_dt <- as.data.table(z_mat)
  
  setnames(x_dt, x_cols)
  setnames(y_dt, y_cols)
  setnames(z_dt, z_cols)
  
  cbind(meta_dt, x_dt, y_dt, z_dt)
}

prepare_dataset_output_dir <- function(dataset_name) {
  out_dir <- file.path(output_data_dir, dataset_name)
  if (dir.exists(out_dir)) unlink(out_dir, recursive = TRUE, force = TRUE)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir
}

make_part_writer <- function(dataset_out_dir) {
  part_id <- 1L
  total_windows <- 0L
  buffer <- list()
  buffer_n <- 0L
  
  flush <- function() {
    if (!buffer_n) return(invisible(NULL))
    
    out <- rbindlist(buffer, fill = TRUE, use.names = TRUE)
    out_path <- file.path(dataset_out_dir, sprintf("part_%05d.parquet", part_id))
    
    if (isTRUE(write_outputs)) {
      arrow::write_parquet(out, out_path, compression = "zstd")
    }
    
    total_windows <<- total_windows + nrow(out)
    part_id <<- part_id + 1L
    buffer <<- list()
    buffer_n <<- 0L
    
    rm(out)
    gc(FALSE)
    invisible(NULL)
  }
  
  add <- function(dt) {
    if (is.null(dt) || !nrow(dt)) return(invisible(NULL))
    
    buffer[[length(buffer) + 1L]] <<- dt
    buffer_n <<- buffer_n + nrow(dt)
    
    if (buffer_n >= windows_per_part) flush()
    invisible(NULL)
  }
  
  close <- function() {
    flush()
    list(
      total_windows = total_windows,
      part_files = part_id - 1L
    )
  }
  
  list(add = add, close = close)
}

# ---------- builders: clip route ----------

build_clip_group_windows <- function(sd, dataset_name) {
  n_in <- nrow(sd)
  if (!n_in) return(NULL)
  
  setorderv(sd, c("row_nr", "input_order"), na.last = TRUE)
  
  clip_hz <- get_lookup_value(clip_hz_lookup, dataset_name, NA_real_)
  duration_est <- if (is.finite(clip_hz) && clip_hz > 0) n_in / clip_hz else NA_real_
  
  can_split_full_native <- is.finite(duration_est) && duration_est >= target_window_sec
  n_windows <- if (can_split_full_native) floor(duration_est / target_window_sec) else 1L
  n_windows <- max(1L, as.integer(n_windows))
  
  x_mat <- matrix(NA_real_, nrow = n_windows, ncol = target_n)
  y_mat <- matrix(NA_real_, nrow = n_windows, ncol = target_n)
  z_mat <- matrix(NA_real_, nrow = n_windows, ncol = target_n)
  
  short_fixed <- !can_split_full_native
  
  if (can_split_full_native) {
    t_in <- seq(0, by = 1 / clip_hz, length.out = n_in)
    
    for (k in seq_len(n_windows)) {
      start_sec <- (k - 1L) * target_window_sec
      t_out <- make_target_times(start_sec)
      
      x_mat[k, ] <- resample_by_time(sd$x_g, t_in, t_out)
      y_mat[k, ] <- resample_by_time(sd$y_g, t_in, t_out)
      z_mat[k, ] <- resample_by_time(sd$z_g, t_in, t_out)
    }
  } else {
    x_mat[1, ] <- resample_by_position(sd$x_g)
    y_mat[1, ] <- resample_by_position(sd$y_g)
    z_mat[1, ] <- resample_by_position(sd$z_g)
  }
  
  start_time <- sd$datetime[1]
  
  meta_dt <- data.table(
    dataset_name = rep(dataset_name, n_windows),
    species = rep(first_value(sd$species), n_windows),
    individual_id = rep(first_value(sd$individual_id), n_windows),
    individual_name = rep(first_value(sd$individual_name), n_windows),
    source_file = rep(first_value(sd$source_file), n_windows),
    source_parquet_file = rep(first_value(sd$source_parquet_file), n_windows),
    main_class = rep(first_value(sd$main_class), n_windows),
    route = rep("clip_repeated_timestamp", n_windows),
    window_id_in_source = seq_len(n_windows),
    source_start_datetime = rep(start_time, n_windows),
    window_start_datetime = start_time + ((seq_len(n_windows) - 1L) * target_window_sec),
    target_hz = rep(target_hz, n_windows),
    target_window_sec = rep(target_window_sec, n_windows),
    target_n_samples = rep(target_n, n_windows),
    source_n_samples = rep(n_in, n_windows),
    source_duration_sec_est = rep(duration_est, n_windows),
    original_hz_est = rep(clip_hz, n_windows),
    short_clip_fixed_length = rep(short_fixed, n_windows),
    full_native_from_source = rep(can_split_full_native, n_windows),
    min_input_samples_ok = rep(n_in >= 1L, n_windows)
  )
  
  make_window_dt(meta_dt, x_mat, y_mat, z_mat)
}

process_clip_dataset <- function(file, dataset_name, writer) {
  dt <- read_selected_parquet(file, base_cols)
  input_rows <- nrow(dt)
  dt <- standardize_dt(dt, dataset_name)
  rows_after_basic_filter <- nrow(dt)
  
  if (!rows_after_basic_filter) {
    return(list(
      input_rows = input_rows,
      rows_after_basic_filter = 0L,
      output_windows = 0L,
      part_files = 0L,
      short_clip_windows = 0L,
      full_native_windows = 0L
    ))
  }
  
  setorderv(
    dt,
    c("individual_id", "source_file", "source_parquet_file", "datetime", "main_class", "row_nr", "input_order"),
    na.last = TRUE
  )
  
  dt[, group_id := .GRP, by = .(
    individual_id, individual_name, source_file, source_parquet_file, datetime, main_class
  )]
  
  group_ids <- unique(dt$group_id)
  short_clip_windows <- 0L
  full_native_windows <- 0L
  
  for (start_i in seq(1L, length(group_ids), by = clip_groups_per_chunk)) {
    ids <- group_ids[start_i:min(start_i + clip_groups_per_chunk - 1L, length(group_ids))]
    chunk <- dt[group_id %in% ids]
    
    out_list <- vector("list", length(ids))
    for (j in seq_along(ids)) {
      sd <- chunk[group_id == ids[j]]
      out_list[[j]] <- build_clip_group_windows(sd, dataset_name)
    }
    
    out_dt <- rbindlist(out_list, fill = TRUE, use.names = TRUE)
    
    if (nrow(out_dt)) {
      short_clip_windows <- short_clip_windows + sum(out_dt$short_clip_fixed_length, na.rm = TRUE)
      full_native_windows <- full_native_windows + sum(out_dt$full_native_from_source, na.rm = TRUE)
      writer$add(out_dt)
    }
    
    rm(chunk, out_list, out_dt)
    gc(FALSE)
  }
  
  writer_res <- writer$close()
  
  rm(dt)
  gc(FALSE)
  
  list(
    input_rows = input_rows,
    rows_after_basic_filter = rows_after_basic_filter,
    output_windows = writer_res$total_windows,
    part_files = writer_res$part_files,
    short_clip_windows = short_clip_windows,
    full_native_windows = full_native_windows
  )
}

# ---------- builders: sample route ----------

build_sample_segment_windows <- function(sd, dataset_name, base_dt) {
  n_in <- nrow(sd)
  if (n_in < 2L) return(NULL)
  
  setorderv(sd, c("datetime", "row_nr", "input_order"), na.last = TRUE)
  
  t_in <- as.numeric(sd$datetime - sd$datetime[1], units = "secs")
  t_in <- t_in - min(t_in, na.rm = TRUE)
  
  local_diff <- diff(t_in)
  local_diff <- local_diff[is.finite(local_diff) & local_diff > 0]
  local_dt <- if (length(local_diff)) stats::median(local_diff) else base_dt
  
  duration_sec <- max(t_in, na.rm = TRUE) + local_dt
  
  if (!is.finite(duration_sec) || duration_sec <= 0) return(NULL)
  
  short_fixed <- duration_sec < target_window_sec
  
  if (short_fixed) {
    if (!isTRUE(keep_short_sequence_segments) && !isTRUE(keep_short_sample_segments)) {
      return(NULL)
    }
    if (n_in < min_input_samples_per_window) return(NULL)
    
    label <- majority_value(sd$main_class)
    if (is.na(label) || !(label %in% target_main_classes)) return(NULL)
    
    x_mat <- matrix(resample_by_position(sd$x_g), nrow = 1L)
    y_mat <- matrix(resample_by_position(sd$y_g), nrow = 1L)
    z_mat <- matrix(resample_by_position(sd$z_g), nrow = 1L)
    
    sample_hz <- get_lookup_value(
      sample_hz_lookup,
      dataset_name,
      ifelse(is.finite(base_dt) && base_dt > 0, 1 / base_dt, NA_real_)
    )
    
    meta_dt <- data.table(
      dataset_name = dataset_name,
      species = first_value(sd$species),
      individual_id = first_value(sd$individual_id),
      individual_name = first_value(sd$individual_name),
      source_file = first_value(sd$source_file),
      source_parquet_file = first_value(sd$source_parquet_file),
      main_class = label,
      route = "sample_sequence_short_fixed_length",
      window_id_in_source = 1L,
      source_start_datetime = sd$datetime[1],
      window_start_datetime = sd$datetime[1],
      target_hz = target_hz,
      target_window_sec = target_window_sec,
      target_n_samples = target_n,
      source_n_samples = n_in,
      source_duration_sec_est = duration_sec,
      original_hz_est = sample_hz,
      short_clip_fixed_length = TRUE,
      full_native_from_source = FALSE,
      min_input_samples_ok = TRUE
    )
    
    return(make_window_dt(meta_dt, x_mat, y_mat, z_mat))
  }
  
  n_windows <- if (duration_sec >= target_window_sec) {
    floor(duration_sec / target_window_sec)
  } else {
    1L
  }
  n_windows <- max(1L, as.integer(n_windows))
  
  x_mat <- matrix(NA_real_, nrow = n_windows, ncol = target_n)
  y_mat <- matrix(NA_real_, nrow = n_windows, ncol = target_n)
  z_mat <- matrix(NA_real_, nrow = n_windows, ncol = target_n)
  
  min_ok <- logical(n_windows)
  short_fixed <- duration_sec < target_window_sec
  
  for (k in seq_len(n_windows)) {
    start_sec <- (k - 1L) * target_window_sec
    end_sec <- start_sec + target_window_sec
    t_out <- make_target_times(start_sec)
    
    in_window <- t_in >= start_sec & t_in < end_sec
    min_ok[k] <- sum(in_window, na.rm = TRUE) >= min_input_samples_per_window
    
    if (!min_ok[k]) next
    
    x_mat[k, ] <- resample_by_time(sd$x_g, t_in, t_out)
    y_mat[k, ] <- resample_by_time(sd$y_g, t_in, t_out)
    z_mat[k, ] <- resample_by_time(sd$z_g, t_in, t_out)
  }
  
  keep <- min_ok
  if (!any(keep)) return(NULL)
  
  x_mat <- x_mat[keep, , drop = FALSE]
  y_mat <- y_mat[keep, , drop = FALSE]
  z_mat <- z_mat[keep, , drop = FALSE]
  kept_ids <- which(keep)
  n_keep <- length(kept_ids)
  
  sample_hz <- get_lookup_value(sample_hz_lookup, dataset_name, ifelse(is.finite(base_dt) && base_dt > 0, 1 / base_dt, NA_real_))
  
  meta_dt <- data.table(
    dataset_name = rep(dataset_name, n_keep),
    species = rep(first_value(sd$species), n_keep),
    individual_id = rep(first_value(sd$individual_id), n_keep),
    individual_name = rep(first_value(sd$individual_name), n_keep),
    source_file = rep(first_value(sd$source_file), n_keep),
    source_parquet_file = rep(first_value(sd$source_parquet_file), n_keep),
    main_class = rep(first_value(sd$main_class), n_keep),
    route = rep("sample_based_segment", n_keep),
    window_id_in_source = kept_ids,
    source_start_datetime = rep(sd$datetime[1], n_keep),
    window_start_datetime = sd$datetime[1] + ((kept_ids - 1L) * target_window_sec),
    target_hz = rep(target_hz, n_keep),
    target_window_sec = rep(target_window_sec, n_keep),
    target_n_samples = rep(target_n, n_keep),
    source_n_samples = rep(n_in, n_keep),
    source_duration_sec_est = rep(duration_sec, n_keep),
    original_hz_est = rep(sample_hz, n_keep),
    short_clip_fixed_length = rep(short_fixed, n_keep),
    full_native_from_source = rep(!short_fixed, n_keep),
    min_input_samples_ok = rep(TRUE, n_keep)
  )
  
  make_window_dt(meta_dt, x_mat, y_mat, z_mat)
}

process_sample_dt <- function(dt, dataset_name, writer) {
  if (!nrow(dt)) {
    return(list(
      rows_after_basic_filter = 0L,
      output_windows = 0L,
      part_files = 0L,
      skipped_short_segments = 0L,
      short_clip_windows = 0L,
      full_native_windows = 0L
    ))
  }
  
  setorderv(
    dt,
    c("individual_id", "source_file", "source_parquet_file", "datetime", "row_nr", "input_order"),
    na.last = TRUE
  )
  
  dt[, source_unit := paste(source_file, source_parquet_file, sep = "__")]
  dt[, diff_sec := as.numeric(datetime - shift(datetime), units = "secs"), by = .(individual_id, source_unit)]
  dt[, prev_class := shift(main_class), by = .(individual_id, source_unit)]
  
  pos_diff <- dt[is.finite(diff_sec) & diff_sec > 0 & diff_sec < 5, diff_sec]
  base_dt <- safe_numeric_median(pos_diff)
  
  if (!is.finite(base_dt) || base_dt <= 0) {
    fallback_hz <- get_lookup_value(sample_hz_lookup, dataset_name, 25)
    base_dt <- 1 / fallback_hz
  }
  
  gap_threshold <- max(gap_multiplier * base_dt, gap_threshold_min_sec)
  
  dt[, new_segment := FALSE]
  dt[
    is.na(diff_sec) |
      diff_sec <= 0 |
      diff_sec > gap_threshold |
      main_class != prev_class,
    new_segment := TRUE
  ]
  
  dt[, segment_id := cumsum(new_segment), by = .(individual_id, source_unit)]
  dt[, group_id := .GRP, by = .(individual_id, source_unit, segment_id, main_class)]
  
  group_ids <- unique(dt$group_id)
  
  skipped_short_segments <- 0L
  short_clip_windows <- 0L
  full_native_windows <- 0L
  
  for (gid in group_ids) {
    sd <- dt[group_id == gid]
    duration_est <- as.numeric(max(sd$datetime) - min(sd$datetime), units = "secs") + base_dt
    
    if (is.finite(duration_est) && duration_est < target_window_sec && !isTRUE(keep_short_sample_segments)) {
      skipped_short_segments <- skipped_short_segments + 1L
      next
    }
    
    out_dt <- build_sample_segment_windows(sd, dataset_name, base_dt)
    
    if (!is.null(out_dt) && nrow(out_dt)) {
      short_clip_windows <- short_clip_windows + sum(out_dt$short_clip_fixed_length, na.rm = TRUE)
      full_native_windows <- full_native_windows + sum(out_dt$full_native_from_source, na.rm = TRUE)
      writer$add(out_dt)
    }
    
    rm(sd, out_dt)
  }
  
  writer_res <- writer$close()
  
  list(
    rows_after_basic_filter = nrow(dt),
    output_windows = writer_res$total_windows,
    part_files = writer_res$part_files,
    skipped_short_segments = skipped_short_segments,
    short_clip_windows = short_clip_windows,
    full_native_windows = full_native_windows
  )
}

get_dataset_ids <- function(file) {
  ds <- arrow::open_dataset(file, format = "parquet")
  ids <- ds %>%
    dplyr::select(individual_id) %>%
    dplyr::distinct() %>%
    dplyr::collect()
  
  ids <- as.character(ids$individual_id)
  ids[is.na(ids) | ids == ""] <- NA_character_
  ids
}

read_sample_id <- function(file, id, cols) {
  ds <- arrow::open_dataset(file, format = "parquet")
  schema_names <- names(ds$schema)
  cols_existing <- intersect(cols, schema_names)
  
  if (is.na(id)) {
    out <- ds %>%
      dplyr::filter(is.na(individual_id) | individual_id == "") %>%
      dplyr::select(dplyr::all_of(cols_existing)) %>%
      dplyr::collect()
  } else {
    out <- ds %>%
      dplyr::filter(individual_id == !!id) %>%
      dplyr::select(dplyr::all_of(cols_existing)) %>%
      dplyr::collect()
  }
  
  dt <- as.data.table(out)
  
  missing_cols <- setdiff(cols, names(dt))
  for (nm in missing_cols) {
    dt[, (nm) := NA]
  }
  
  setcolorder(dt, cols)
  dt
}

process_sample_dataset <- function(file, dataset_name, writer) {
  input_rows <- as.integer(arrow::open_dataset(file, format = "parquet") %>%
                             dplyr::summarise(n = dplyr::n()) %>%
                             dplyr::collect() %>%
                             dplyr::pull(n))
  
  ids <- get_dataset_ids(file)
  
  rows_after_basic_filter_total <- 0L
  skipped_short_segments_total <- 0L
  short_clip_windows_total <- 0L
  full_native_windows_total <- 0L
  
  for (id in ids) {
    message("  individual_id: ", ifelse(is.na(id), "<NA>", id))
    
    dt <- read_sample_id(file, id, base_cols)
    dt <- standardize_dt(dt, dataset_name)
    
    rows_after_basic_filter_total <- rows_after_basic_filter_total + nrow(dt)
    
    res <- process_sample_dt(dt, dataset_name, writer)
    
    skipped_short_segments_total <- skipped_short_segments_total + res$skipped_short_segments
    short_clip_windows_total <- short_clip_windows_total + res$short_clip_windows
    full_native_windows_total <- full_native_windows_total + res$full_native_windows
    
    rm(dt, res)
    gc(FALSE)
  }
  
  writer_res <- writer$close()
  
  list(
    input_rows = input_rows,
    rows_after_basic_filter = rows_after_basic_filter_total,
    output_windows = writer_res$total_windows,
    part_files = writer_res$part_files,
    skipped_short_segments = skipped_short_segments_total,
    short_clip_windows = short_clip_windows_total,
    full_native_windows = full_native_windows_total
  )
}


# ---------- builders: sample sequence route ----------

build_sample_sequence_segment_windows <- function(sd, dataset_name, base_dt) {
  n_in <- nrow(sd)
  if (n_in < 2L) return(NULL)
  
  setorderv(sd, c("datetime", "row_nr", "input_order"), na.last = TRUE)
  
  t_in <- as.numeric(sd$datetime - sd$datetime[1], units = "secs")
  t_in <- t_in - min(t_in, na.rm = TRUE)
  
  local_diff <- diff(t_in)
  local_diff <- local_diff[is.finite(local_diff) & local_diff > 0]
  local_dt <- if (length(local_diff)) stats::median(local_diff) else base_dt
  
  duration_sec <- max(t_in, na.rm = TRUE) + local_dt
  
  if (!is.finite(duration_sec) || duration_sec <= 0) return(NULL)
  
  short_fixed <- duration_sec < target_window_sec
  
  if (short_fixed) {
    if (!isTRUE(keep_short_sequence_segments) && !isTRUE(keep_short_sample_segments)) {
      return(NULL)
    }
    if (n_in < min_input_samples_per_window) return(NULL)
    
    label <- majority_value(sd$main_class)
    if (is.na(label) || !(label %in% target_main_classes)) return(NULL)
    
    x_mat <- matrix(resample_by_position(sd$x_g), nrow = 1L)
    y_mat <- matrix(resample_by_position(sd$y_g), nrow = 1L)
    z_mat <- matrix(resample_by_position(sd$z_g), nrow = 1L)
    
    sample_hz <- get_lookup_value(
      sample_hz_lookup,
      dataset_name,
      ifelse(is.finite(base_dt) && base_dt > 0, 1 / base_dt, NA_real_)
    )
    
    meta_dt <- data.table(
      dataset_name = dataset_name,
      species = first_value(sd$species),
      individual_id = first_value(sd$individual_id),
      individual_name = first_value(sd$individual_name),
      source_file = first_value(sd$source_file),
      source_parquet_file = first_value(sd$source_parquet_file),
      main_class = label,
      route = "sample_sequence_short_fixed_length",
      window_id_in_source = 1L,
      source_start_datetime = sd$datetime[1],
      window_start_datetime = sd$datetime[1],
      target_hz = target_hz,
      target_window_sec = target_window_sec,
      target_n_samples = target_n,
      source_n_samples = n_in,
      source_duration_sec_est = duration_sec,
      original_hz_est = sample_hz,
      short_clip_fixed_length = TRUE,
      full_native_from_source = FALSE,
      min_input_samples_ok = TRUE
    )
    
    return(make_window_dt(meta_dt, x_mat, y_mat, z_mat))
  }
  
  n_windows <- if (duration_sec >= target_window_sec) {
    floor(duration_sec / target_window_sec)
  } else {
    1L
  }
  n_windows <- max(1L, as.integer(n_windows))
  
  raw_window_id <- as.integer(floor(t_in / target_window_sec) + 1L)
  valid_window <- is.finite(raw_window_id) & raw_window_id >= 1L & raw_window_id <= n_windows
  
  if (!any(valid_window)) return(NULL)
  
  count_dt <- data.table(window_id = raw_window_id[valid_window])[, .N, by = window_id]
  keep_ids <- count_dt[N >= min_input_samples_per_window, window_id]
  
  if (!length(keep_ids)) return(NULL)
  
  keep_ids <- sort(as.integer(keep_ids))
  idx_by_window <- split(which(valid_window), raw_window_id[valid_window])
  
  n_keep <- length(keep_ids)
  
  x_mat <- matrix(NA_real_, nrow = n_keep, ncol = target_n)
  y_mat <- matrix(NA_real_, nrow = n_keep, ncol = target_n)
  z_mat <- matrix(NA_real_, nrow = n_keep, ncol = target_n)
  
  label_vec <- rep(NA_character_, n_keep)
  source_samples_vec <- integer(n_keep)
  
  for (ii in seq_along(keep_ids)) {
    k <- keep_ids[ii]
    idx <- idx_by_window[[as.character(k)]]
    
    if (is.null(idx) || length(idx) < min_input_samples_per_window) next
    
    start_sec <- (k - 1L) * target_window_sec
    t_out <- make_target_times(start_sec)
    
    x_mat[ii, ] <- resample_by_time(sd$x_g[idx], t_in[idx], t_out)
    y_mat[ii, ] <- resample_by_time(sd$y_g[idx], t_in[idx], t_out)
    z_mat[ii, ] <- resample_by_time(sd$z_g[idx], t_in[idx], t_out)
    
    label_vec[ii] <- majority_value(sd$main_class[idx])
    source_samples_vec[ii] <- length(idx)
  }
  
  keep <- !is.na(label_vec) & label_vec %in% target_main_classes & source_samples_vec >= min_input_samples_per_window
  if (!any(keep)) return(NULL)
  
  x_mat <- x_mat[keep, , drop = FALSE]
  y_mat <- y_mat[keep, , drop = FALSE]
  z_mat <- z_mat[keep, , drop = FALSE]
  kept_ids <- keep_ids[keep]
  label_vec <- label_vec[keep]
  source_samples_vec <- source_samples_vec[keep]
  n_keep <- length(kept_ids)
  
  sample_hz <- get_lookup_value(
    sample_hz_lookup,
    dataset_name,
    ifelse(is.finite(base_dt) && base_dt > 0, 1 / base_dt, NA_real_)
  )
  
  meta_dt <- data.table(
    dataset_name = rep(dataset_name, n_keep),
    species = rep(first_value(sd$species), n_keep),
    individual_id = rep(first_value(sd$individual_id), n_keep),
    individual_name = rep(first_value(sd$individual_name), n_keep),
    source_file = rep(first_value(sd$source_file), n_keep),
    source_parquet_file = rep(first_value(sd$source_parquet_file), n_keep),
    main_class = label_vec,
    route = rep("sample_sequence_majority_label", n_keep),
    window_id_in_source = kept_ids,
    source_start_datetime = rep(sd$datetime[1], n_keep),
    window_start_datetime = sd$datetime[1] + ((kept_ids - 1L) * target_window_sec),
    target_hz = rep(target_hz, n_keep),
    target_window_sec = rep(target_window_sec, n_keep),
    target_n_samples = rep(target_n, n_keep),
    source_n_samples = source_samples_vec,
    source_duration_sec_est = rep(duration_sec, n_keep),
    original_hz_est = rep(sample_hz, n_keep),
    short_clip_fixed_length = rep(FALSE, n_keep),
    full_native_from_source = rep(TRUE, n_keep),
    min_input_samples_ok = rep(TRUE, n_keep)
  )
  
  make_window_dt(meta_dt, x_mat, y_mat, z_mat)
}

process_sample_sequence_dt <- function(dt, dataset_name, writer) {
  if (!nrow(dt)) {
    return(list(
      rows_after_basic_filter = 0L,
      output_windows = 0L,
      part_files = 0L,
      skipped_short_segments = 0L,
      short_clip_windows = 0L,
      full_native_windows = 0L
    ))
  }
  
  setorderv(
    dt,
    c("individual_id", "source_file", "source_parquet_file", "datetime", "row_nr", "input_order"),
    na.last = TRUE
  )
  
  dt[, source_unit := paste(source_file, source_parquet_file, sep = "__")]
  dt[, diff_sec := as.numeric(datetime - shift(datetime), units = "secs"), by = .(individual_id, source_unit)]
  
  pos_diff <- dt[is.finite(diff_sec) & diff_sec > 0 & diff_sec < 5, diff_sec]
  base_dt <- safe_numeric_median(pos_diff)
  
  if (!is.finite(base_dt) || base_dt <= 0) {
    fallback_hz <- get_lookup_value(sample_hz_lookup, dataset_name, 25)
    base_dt <- 1 / fallback_hz
  }
  
  gap_threshold <- get_sequence_gap_threshold(dataset_name, base_dt)
  
  dt[, new_segment := FALSE]
  dt[
    is.na(diff_sec) |
      diff_sec <= 0 |
      diff_sec > gap_threshold,
    new_segment := TRUE
  ]
  
  dt[, segment_id := cumsum(new_segment), by = .(individual_id, source_unit)]
  dt[, group_id := .GRP, by = .(individual_id, source_unit, segment_id)]
  
  group_ids <- unique(dt$group_id)
  
  skipped_short_segments <- 0L
  short_clip_windows <- 0L
  full_native_windows <- 0L
  
  for (gid in group_ids) {
    sd <- dt[group_id == gid]
    duration_est <- as.numeric(max(sd$datetime) - min(sd$datetime), units = "secs") + base_dt
    
    if (
      is.finite(duration_est) &&
      duration_est < target_window_sec &&
      !isTRUE(keep_short_sequence_segments) &&
      !isTRUE(keep_short_sample_segments)
    ) {
      skipped_short_segments <- skipped_short_segments + 1L
      next
    }
    
    out_dt <- build_sample_sequence_segment_windows(sd, dataset_name, base_dt)
    
    if (is.null(out_dt) && is.finite(duration_est) && duration_est < target_window_sec) {
      skipped_short_segments <- skipped_short_segments + 1L
    }
    
    if (!is.null(out_dt) && nrow(out_dt)) {
      short_clip_windows <- short_clip_windows + sum(out_dt$short_clip_fixed_length, na.rm = TRUE)
      full_native_windows <- full_native_windows + sum(out_dt$full_native_from_source, na.rm = TRUE)
      writer$add(out_dt)
    }
    
    rm(sd, out_dt)
  }
  
  writer_res <- writer$close()
  
  list(
    rows_after_basic_filter = nrow(dt),
    output_windows = writer_res$total_windows,
    part_files = writer_res$part_files,
    skipped_short_segments = skipped_short_segments,
    short_clip_windows = short_clip_windows,
    full_native_windows = full_native_windows
  )
}

process_sample_sequence_dataset <- function(file, dataset_name, writer) {
  input_rows <- as.integer(arrow::open_dataset(file, format = "parquet") %>%
                             dplyr::summarise(n = dplyr::n()) %>%
                             dplyr::collect() %>%
                             dplyr::pull(n))
  
  ids <- get_dataset_ids(file)
  
  rows_after_basic_filter_total <- 0L
  skipped_short_segments_total <- 0L
  short_clip_windows_total <- 0L
  full_native_windows_total <- 0L
  
  for (id in ids) {
    message("  individual_id: ", ifelse(is.na(id), "<NA>", id))
    
    dt <- read_sample_id(file, id, base_cols)
    dt <- standardize_dt(dt, dataset_name)
    
    rows_after_basic_filter_total <- rows_after_basic_filter_total + nrow(dt)
    
    res <- process_sample_sequence_dt(dt, dataset_name, writer)
    
    skipped_short_segments_total <- skipped_short_segments_total + res$skipped_short_segments
    short_clip_windows_total <- short_clip_windows_total + res$short_clip_windows
    full_native_windows_total <- full_native_windows_total + res$full_native_windows
    
    rm(dt, res)
    gc(FALSE)
  }
  
  writer_res <- writer$close()
  
  list(
    input_rows = input_rows,
    rows_after_basic_filter = rows_after_basic_filter_total,
    output_windows = writer_res$total_windows,
    part_files = writer_res$part_files,
    skipped_short_segments = skipped_short_segments_total,
    short_clip_windows = short_clip_windows_total,
    full_native_windows = full_native_windows_total
  )
}

# ---------- validation ----------

validate_dataset_output <- function(dataset_name) {
  dir_path <- file.path(output_data_dir, dataset_name)
  part_files <- list.files(dir_path, pattern = "\\.parquet$", full.names = TRUE)
  
  if (!dir.exists(dir_path) || !length(part_files)) {
    return(data.table(
      dataset_name = dataset_name,
      export_exists = FALSE,
      n_parts = 0L,
      x_cols = NA_integer_,
      y_cols = NA_integer_,
      z_cols = NA_integer_,
      width_ok = NA,
      labels_ok = NA,
      labels_found = NA_character_
    ))
  }
  
  ds <- arrow::open_dataset(dir_path, format = "parquet")
  nm <- names(ds$schema)
  
  labels <- ds %>%
    dplyr::select(main_class) %>%
    dplyr::distinct() %>%
    dplyr::collect()
  
  labels_found <- sort(unique(as.character(labels$main_class)))
  
  data.table(
    dataset_name = dataset_name,
    export_exists = TRUE,
    n_parts = length(part_files),
    x_cols = sum(x_cols %in% nm),
    y_cols = sum(y_cols %in% nm),
    z_cols = sum(z_cols %in% nm),
    width_ok = all(x_cols %in% nm) && all(y_cols %in% nm) && all(z_cols %in% nm),
    labels_ok = all(labels_found %in% target_main_classes),
    labels_found = paste(labels_found, collapse = "; ")
  )
}

make_txt_report <- function(summary_dt, route_dt, validation_dt = NULL) {
  lines <- c(
    "04 Windowing Report",
    paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "Goal:",
    "- Convert model-ready sample/clip-level data into fixed-length windows.",
    "- Target representation: 25 Hz, 2.46 s, 62 samples per axis.",
    "- Process one dataset at a time to reduce RAM usage.",
    "",
    "Input:",
    paste0("- input directory: ", input_dir),
    paste0("- parquet output: ", out_parquet_dir),
    paste0("- csv output: ", out_csv_dir),
    paste0("- txt output: ", out_txt_dir),
    paste0("- datasets processed: ", nrow(summary_dt)),
    paste0("- total input rows: ", format(sum(summary_dt$input_rows, na.rm = TRUE), big.mark = ",")),
    paste0("- total output windows: ", format(sum(summary_dt$output_windows, na.rm = TRUE), big.mark = ",")),
    "",
    "Routes:",
    "- clip: repeated-timestamp clips are converted to fixed 62-sample windows.",
    "- sample: continuous homogeneous segments are split into non-overlapping 2.46-s windows and resampled to 25 Hz.",
    "- sample_sequence: continuous segments are windowed first, then main_class is assigned by majority vote within each 2.46-s window.",
    "",
    "Important method note:",
    "- 2.46 s at 25 Hz gives 61.5 samples; this script uses the rounded fixed length of 62.",
    "- Clip-based sequences are resampled to the same fixed 62-sample representation.",
    "- Short sample-based homogeneous segments below 2.46 s are excluded unless keep_short_sample_segments is TRUE.",
    "- Giraffe uses sample_sequence to avoid class-change splitting; short gap-separated sequence units are kept as fixed 62-sample windows.",
    "",
    "Dataset routes:"
  )
  
  for (i in seq_len(nrow(route_dt))) {
    r <- route_dt[i]
    lines <- c(lines, paste0("- ", r$dataset_name, ": ", r$route))
  }
  
  lines <- c(lines, "", "Dataset summary:")
  
  for (i in seq_len(nrow(summary_dt))) {
    r <- summary_dt[i]
    lines <- c(
      lines,
      "",
      paste0("Dataset: ", r$dataset_name),
      paste0("- route: ", r$route),
      paste0("- input rows: ", format(r$input_rows, big.mark = ",")),
      paste0("- rows after basic filter: ", format(r$rows_after_basic_filter, big.mark = ",")),
      paste0("- output windows: ", format(r$output_windows, big.mark = ",")),
      paste0("- part files: ", r$part_files),
      paste0("- short fixed-length clip/sequence windows: ", format(r$short_clip_windows, big.mark = ",")),
      paste0("- full native windows: ", format(r$full_native_windows, big.mark = ",")),
      paste0("- skipped short sample segments: ", r$skipped_short_sample_segments),
      paste0("- output directory: ", r$output_dir)
    )
  }
  
  if (!is.null(validation_dt)) {
    lines <- c(lines, "", "Validation summary:")
    for (i in seq_len(nrow(validation_dt))) {
      v <- validation_dt[i]
      lines <- c(
        lines,
        paste0(
          "- ", v$dataset_name,
          ": width_ok=", v$width_ok,
          ", labels_ok=", v$labels_ok,
          ", parts=", v$n_parts
        )
      )
    }
  }
  
  c(
    lines,
    "",
    "Next step:",
    "- Use the window parquet files for feature extraction and raw time-series model input.",
    "- Downstream code should use x_001..x_062, y_001..y_062, and z_001..z_062."
  )
}

# ---------- run ----------

if (!dir.exists(input_dir)) stop("Input folder does not exist: ", input_dir)

input_files <- sort(list.files(input_dir, pattern = "_mr\\.parquet$", full.names = TRUE))

if (length(input_files) != expected_file_count) {
  stop(
    "Expected ", expected_file_count, " '*_mr.parquet' files, but found ",
    length(input_files), " in: ", input_dir
  )
}

input_names <- vapply(input_files, clean_dataset_name, character(1))
input_files <- input_files[order(input_names)]
input_names <- input_names[order(input_names)]

route_dt <- data.table(
  dataset_name = input_names,
  input_file = input_files,
  route = unname(dataset_route_lookup[input_names])
)
route_dt[is.na(route), route := "sample"]

write.csv(route_dt, route_csv_path, row.names = FALSE)

cat("\n==============================\n")
cat("04 WINDOWING START\n")
cat("==============================\n")

summary_list <- vector("list", nrow(route_dt))

for (i in seq_len(nrow(route_dt))) {
  dataset_name <- route_dt$dataset_name[i]
  file <- route_dt$input_file[i]
  route <- route_dt$route[i]
  
  cat("\n----------------------------------------\n")
  cat("DATASET:", dataset_name, "\n")
  cat("ROUTE  :", route, "\n")
  cat("----------------------------------------\n")
  
  dataset_out_dir <- prepare_dataset_output_dir(dataset_name)
  writer <- make_part_writer(dataset_out_dir)
  
  res <- tryCatch(
    {
      if (route == "clip") {
        process_clip_dataset(file, dataset_name, writer)
      } else if (route == "sample_sequence") {
        process_sample_sequence_dataset(file, dataset_name, writer)
      } else {
        process_sample_dataset(file, dataset_name, writer)
      }
    },
    error = function(e) {
      message("ERROR in ", dataset_name, ": ", e$message)
      list(
        input_rows = NA_integer_,
        rows_after_basic_filter = NA_integer_,
        output_windows = NA_integer_,
        part_files = NA_integer_,
        skipped_short_segments = NA_integer_,
        short_clip_windows = NA_integer_,
        full_native_windows = NA_integer_,
        error_message = e$message
      )
    }
  )
  
  summary_list[[i]] <- data.table(
    dataset_name = dataset_name,
    route = route,
    input_file = file,
    input_rows = res$input_rows,
    rows_after_basic_filter = res$rows_after_basic_filter,
    output_windows = res$output_windows,
    part_files = res$part_files,
    short_clip_windows = ifelse(is.null(res$short_clip_windows), 0L, res$short_clip_windows),
    full_native_windows = ifelse(is.null(res$full_native_windows), 0L, res$full_native_windows),
    skipped_short_sample_segments = ifelse(is.null(res$skipped_short_segments), 0L, res$skipped_short_segments),
    error_message = ifelse(is.null(res$error_message), NA_character_, res$error_message),
    output_dir = dataset_out_dir
  )
  
  cat("Input rows        :", format(res$input_rows, big.mark = ","), "\n")
  cat("Rows after filter :", format(res$rows_after_basic_filter, big.mark = ","), "\n")
  cat("Output windows    :", format(res$output_windows, big.mark = ","), "\n")
  cat("Part files        :", format(res$part_files, big.mark = ","), "\n")
  
  rm(writer, res)
  gc(FALSE)
}

summary_dt <- rbindlist(summary_list, fill = TRUE)

write.csv(summary_dt, summary_csv_path, row.names = FALSE)
arrow::write_parquet(summary_dt, summary_parquet_path, compression = "zstd")

validation_dt <- NULL
if (isTRUE(run_validation)) {
  validation_dt <- rbindlist(lapply(summary_dt$dataset_name, validate_dataset_output), fill = TRUE)
  write.csv(validation_dt, file.path(output_meta_dir, "04_windowing_validation.csv"), row.names = FALSE)
  arrow::write_parquet(validation_dt, file.path(output_meta_dir, "04_windowing_validation.parquet"), compression = "zstd")
}

writeLines(make_txt_report(summary_dt, route_dt, validation_dt), report_txt_path)

cat("\n==============================\n")
cat("04 WINDOWING SUMMARY\n")
cat("==============================\n")
print(summary_dt[, .(
  dataset_name,
  route,
  input_rows,
  rows_after_basic_filter,
  output_windows,
  part_files,
  error_message
)])

if (!is.null(validation_dt)) {
  cat("\n==============================\n")
  cat("VALIDATION SUMMARY\n")
  cat("==============================\n")
  print(validation_dt)
}

cat("\n==============================\n")
cat("DONE\n")
cat("==============================\n")
cat("Output root:\n")
cat(output_root, "\n")
