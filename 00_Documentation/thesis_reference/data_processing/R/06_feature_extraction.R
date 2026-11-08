# 06_feature_extraction.R
# Extracts 26 handcrafted features from native 62-sample windows.

Sys.setenv(ARROW_NUM_THREADS = "2")

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(matrixStats)
})

# ---------- settings ----------

processing_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processing"
script_id <- "06"
expected_dataset_count <- 12L

input_dir <- file.path(processing_root, "04", "04_parquet")
output_root <- file.path(processing_root, script_id)
out_parquet_dir <- file.path(output_root, "06_parquet")
out_csv_dir <- file.path(output_root, "06_csv")
out_txt_dir <- file.path(output_root, "06_txt")

report_txt_path <- file.path(out_txt_dir, "06_feature_report.txt")
input_csv_path <- file.path(out_csv_dir, "06_input_folders.csv")
summary_csv_path <- file.path(out_csv_dir, "06_feature_dataset_summary.csv")
part_csv_path <- file.path(out_csv_dir, "06_feature_part_summary.csv")
qc_csv_path <- file.path(out_csv_dir, "06_feature_qc.csv")
feature_cols_csv_path <- file.path(out_csv_dir, "06_feature_columns.csv")

# Native window settings from Script 04.
target_hz <- 25L
target_window_sec <- 2.46
target_n <- 62L

target_main_classes <- c("foraging", "locomotion", "resting")

# Keep this at 26 to match the manuscript feature set.
feature_set_id <- "dynamic_26_v1"

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

feature_cols <- c(
  "vedba_mean", "vedba_sd", "vedba_max",
  "odba_mean", "odba_sd",
  "sd_x", "sd_y", "sd_z",
  "rms_x", "rms_y", "rms_z",
  "iqr_x", "iqr_y", "iqr_z",
  "skew_x", "skew_y", "skew_z",
  "kurt_x", "kurt_y", "kurt_z",
  "zero_cross_x", "zero_cross_y", "zero_cross_z",
  "spec_dom_freq_mag", "spec_centroid_mag", "spec_entropy_mag"
)

# ---------- setup ----------

for (d in c(output_root, out_parquet_dir, out_csv_dir, out_txt_dir)) {
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

row_sds_fast <- function(mat) {
  sqrt(matrixStats::rowVars(mat, na.rm = TRUE))
}

row_rms_fast <- function(mat) {
  sqrt(rowMeans(mat^2, na.rm = TRUE))
}

row_iqr_fast <- function(mat) {
  qs <- matrixStats::rowQuantiles(mat, probs = c(0.25, 0.75), na.rm = TRUE)
  qs[, 2] - qs[, 1]
}

row_skew_fast <- function(mat) {
  mu <- rowMeans(mat, na.rm = TRUE)
  sdv <- row_sds_fast(mat)
  centered <- sweep(mat, 1L, mu, "-")
  m3 <- rowMeans(centered^3, na.rm = TRUE)
  out <- ifelse(sdv > 0, m3 / (sdv^3), 0)
  out[!is.finite(out)] <- 0
  out
}

row_kurt_fast <- function(mat) {
  mu <- rowMeans(mat, na.rm = TRUE)
  sdv <- row_sds_fast(mat)
  centered <- sweep(mat, 1L, mu, "-")
  m4 <- rowMeans(centered^4, na.rm = TRUE)
  out <- ifelse(sdv > 0, (m4 / (sdv^4)) - 3, 0)
  out[!is.finite(out)] <- 0
  out
}

zero_crossings_fast <- function(mat) {
  s <- sign(mat)
  a <- s[, -ncol(s), drop = FALSE]
  b <- s[, -1L, drop = FALSE]
  out <- rowSums((a * b) < 0, na.rm = TRUE)
  out[!is.finite(out)] <- 0
  out
}

spectral_features_mag <- function(mat, hz) {
  n <- ncol(mat)
  mat_centered <- sweep(mat, 1L, rowMeans(mat, na.rm = TRUE), "-")
  mat_centered[!is.finite(mat_centered)] <- 0

  fft_res <- mvfft(t(mat_centered))
  power <- Mod(fft_res)^2

  keep_idx <- 2L:(floor(n / 2) + 1L)
  power_pos <- power[keep_idx, , drop = FALSE]
  freqs <- (keep_idx - 1L) * hz / n

  power_sum <- colSums(power_pos, na.rm = TRUE)
  power_sum[power_sum <= 0] <- NA_real_

  dom_idx <- max.col(t(power_pos), ties.method = "first")
  dom_freq <- freqs[dom_idx]

  centroid_num <- colSums(sweep(power_pos, 1L, freqs, "*"), na.rm = TRUE)
  centroid <- centroid_num / power_sum

  p_norm <- sweep(power_pos, 2L, power_sum, "/")
  p_norm[!is.finite(p_norm)] <- NA_real_
  entropy <- -colSums(p_norm * log(pmax(p_norm, .Machine$double.eps)), na.rm = TRUE) / log(length(freqs))

  dom_freq[!is.finite(dom_freq)] <- 0
  centroid[!is.finite(centroid)] <- 0
  entropy[!is.finite(entropy)] <- 0

  data.table(
    spec_dom_freq_mag = dom_freq,
    spec_centroid_mag = centroid,
    spec_entropy_mag = entropy
  )
}

feature_qc <- function(dt, dataset_name, part_file) {
  data.table(
    dataset_name = dataset_name,
    part_file = basename(part_file),
    feature = feature_cols,
    n_rows = nrow(dt),
    n_missing = vapply(feature_cols, function(nm) sum(is.na(dt[[nm]])), integer(1)),
    n_nonfinite = vapply(feature_cols, function(nm) sum(!is.finite(dt[[nm]])), integer(1)),
    min_value = vapply(feature_cols, function(nm) suppressWarnings(min(dt[[nm]], na.rm = TRUE)), numeric(1)),
    max_value = vapply(feature_cols, function(nm) suppressWarnings(max(dt[[nm]], na.rm = TRUE)), numeric(1))
  )
}

# ---------- feature extraction ----------

make_features <- function(dt, dataset_name, part_file) {
  required_xyz <- c(x_cols, y_cols, z_cols)
  missing_xyz <- setdiff(required_xyz, names(dt))
  if (length(missing_xyz)) {
    stop("Missing xyz columns: ", paste(missing_xyz, collapse = ", "))
  }

  dt[, main_class := tolower(trimws(as.character(main_class)))]
  dt <- dt[main_class %in% target_main_classes]
  if (!nrow(dt)) return(data.table())

  x_mat <- as.matrix(dt[, ..x_cols]); storage.mode(x_mat) <- "double"
  y_mat <- as.matrix(dt[, ..y_cols]); storage.mode(y_mat) <- "double"
  z_mat <- as.matrix(dt[, ..z_cols]); storage.mode(z_mat) <- "double"

  x_static <- rowMeans(x_mat, na.rm = TRUE)
  y_static <- rowMeans(y_mat, na.rm = TRUE)
  z_static <- rowMeans(z_mat, na.rm = TRUE)

  x_dyn <- sweep(x_mat, 1L, x_static, "-")
  y_dyn <- sweep(y_mat, 1L, y_static, "-")
  z_dyn <- sweep(z_mat, 1L, z_static, "-")

  vedba_ts <- sqrt(x_dyn^2 + y_dyn^2 + z_dyn^2)
  odba_ts <- abs(x_dyn) + abs(y_dyn) + abs(z_dyn)

  spec_dt <- spectral_features_mag(vedba_ts, hz = target_hz)

  feat_dt <- data.table(
    dataset_name = safe_chr(dt$dataset_name, dataset_name),
    species = safe_chr(dt$species),
    individual_id = safe_chr(dt$individual_id),
    individual_name = safe_chr(dt$individual_name),
    name = safe_name(dt$individual_name, dt$individual_id),
    source_file = safe_chr(dt$source_file),
    source_parquet_file = safe_chr(dt$source_parquet_file),
    part_file = basename(part_file),
    main_class = dt$main_class,
    behavior = behavior_label(dt$main_class),
    route = safe_chr(dt$route),
    window_id_in_source = dt$window_id_in_source,
    source_start_datetime = dt$source_start_datetime,
    window_start_datetime = dt$window_start_datetime,
    target_hz = dt$target_hz,
    target_window_sec = dt$target_window_sec,
    target_n_samples = dt$target_n_samples,
    source_n_samples = dt$source_n_samples,
    source_duration_sec_est = dt$source_duration_sec_est,
    original_hz_est = dt$original_hz_est,
    short_clip_fixed_length = dt$short_clip_fixed_length,
    full_native_from_source = dt$full_native_from_source,
    min_input_samples_ok = dt$min_input_samples_ok,
    feature_set_id = feature_set_id,
    vedba_mean = rowMeans(vedba_ts, na.rm = TRUE),
    vedba_sd = row_sds_fast(vedba_ts),
    vedba_max = matrixStats::rowMaxs(vedba_ts, na.rm = TRUE),
    odba_mean = rowMeans(odba_ts, na.rm = TRUE),
    odba_sd = row_sds_fast(odba_ts),
    sd_x = row_sds_fast(x_dyn),
    sd_y = row_sds_fast(y_dyn),
    sd_z = row_sds_fast(z_dyn),
    rms_x = row_rms_fast(x_dyn),
    rms_y = row_rms_fast(y_dyn),
    rms_z = row_rms_fast(z_dyn),
    iqr_x = row_iqr_fast(x_dyn),
    iqr_y = row_iqr_fast(y_dyn),
    iqr_z = row_iqr_fast(z_dyn),
    skew_x = row_skew_fast(x_dyn),
    skew_y = row_skew_fast(y_dyn),
    skew_z = row_skew_fast(z_dyn),
    kurt_x = row_kurt_fast(x_dyn),
    kurt_y = row_kurt_fast(y_dyn),
    kurt_z = row_kurt_fast(z_dyn),
    zero_cross_x = zero_crossings_fast(x_dyn),
    zero_cross_y = zero_crossings_fast(y_dyn),
    zero_cross_z = zero_crossings_fast(z_dyn)
  )

  feat_dt <- cbind(feat_dt, spec_dt)

  for (nm in feature_cols) {
    feat_dt[[nm]][!is.finite(feat_dt[[nm]])] <- NA_real_
  }

  feat_dt
}

process_part <- function(part_file, dataset_name, dataset_out_dir) {
  cols <- c(meta_cols, x_cols, y_cols, z_cols)
  dt <- read_selected_parquet(part_file, cols)

  if (!nrow(dt)) {
    return(list(
      summary = data.table(
        dataset_name = dataset_name,
        part_file = basename(part_file),
        output_file = NA_character_,
        n_windows = 0L,
        n_individuals = 0L,
        behaviors = NA_character_,
        status = "empty_input"
      ),
      qc = data.table()
    ))
  }

  feat_dt <- make_features(dt, dataset_name, part_file)

  out_file <- file.path(
    dataset_out_dir,
    sub("\\.parquet$", "_features.parquet", basename(part_file))
  )

  if (nrow(feat_dt)) {
    arrow::write_parquet(feat_dt, out_file, compression = "zstd")
    qc_dt <- feature_qc(feat_dt, dataset_name, part_file)
    status <- "ok"
  } else {
    out_file <- NA_character_
    qc_dt <- data.table()
    status <- "no_target_classes"
  }

  part_summary <- data.table(
    dataset_name = dataset_name,
    part_file = basename(part_file),
    output_file = out_file,
    n_windows = nrow(feat_dt),
    n_individuals = ifelse(nrow(feat_dt), uniqueN(feat_dt$name), 0L),
    behaviors = ifelse(nrow(feat_dt), paste(sort(unique(feat_dt$behavior)), collapse = " | "), NA_character_),
    status = status
  )

  rm(dt, feat_dt)
  gc(FALSE)

  list(summary = part_summary, qc = qc_dt)
}

process_dataset <- function(dataset_dir) {
  dataset_name <- basename(dataset_dir)
  dataset_out_dir <- file.path(out_parquet_dir, dataset_name)

  if (dir.exists(dataset_out_dir)) unlink(dataset_out_dir, recursive = TRUE, force = TRUE)
  dir.create(dataset_out_dir, showWarnings = FALSE, recursive = TRUE)

  part_files <- sort(list.files(dataset_dir, pattern = "\\.parquet$", full.names = TRUE))

  cat("\n----------------------------------------\n")
  cat("DATASET:", dataset_name, "\n")
  cat("PARTS  :", length(part_files), "\n")
  cat("----------------------------------------\n")

  if (!length(part_files)) {
    return(list(
      part_summary = data.table(
        dataset_name = dataset_name,
        part_file = NA_character_,
        output_file = NA_character_,
        n_windows = 0L,
        n_individuals = 0L,
        behaviors = NA_character_,
        status = "no_part_files"
      ),
      qc = data.table()
    ))
  }

  part_list <- vector("list", length(part_files))
  qc_list <- vector("list", length(part_files))

  for (i in seq_along(part_files)) {
    cat("  part", i, "of", length(part_files), "\n")

    res <- tryCatch(
      process_part(part_files[i], dataset_name, dataset_out_dir),
      error = function(e) {
        message("ERROR in ", dataset_name, " / ", basename(part_files[i]), ": ", e$message)
        list(
          summary = data.table(
            dataset_name = dataset_name,
            part_file = basename(part_files[i]),
            output_file = NA_character_,
            n_windows = NA_integer_,
            n_individuals = NA_integer_,
            behaviors = NA_character_,
            status = paste0("error: ", e$message)
          ),
          qc = data.table()
        )
      }
    )

    part_list[[i]] <- res$summary
    qc_list[[i]] <- res$qc
  }

  list(
    part_summary = rbindlist(part_list, fill = TRUE, use.names = TRUE),
    qc = rbindlist(qc_list, fill = TRUE, use.names = TRUE)
  )
}

make_dataset_summary <- function(part_dt) {
  part_dt[, .(
    n_parts = .N,
    n_windows = sum(n_windows, na.rm = TRUE),
    n_individuals_max_per_part = suppressWarnings(max(n_individuals, na.rm = TRUE)),
    behaviors = paste(sort(unique(unlist(strsplit(paste(behaviors, collapse = " | "), " \\| ")))), collapse = " | "),
    failed_parts = sum(status != "ok", na.rm = TRUE),
    status = ifelse(all(status == "ok", na.rm = TRUE), "ok", "check")
  ), by = dataset_name][order(dataset_name)]
}

make_txt_report <- function(input_dt, dataset_dt, part_dt, qc_dt) {
  failed_parts <- part_dt[status != "ok"]
  qc_bad <- qc_dt[n_missing > 0 | n_nonfinite > 0]

  lines <- c(
    "06 Feature Extraction Report",
    paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "Goal:",
    "- Extract 26 dynamic handcrafted features from native windows.",
    "- Read exactly 12 dataset folders from Script 04 output.",
    "- Write feature parquet outputs and compact reports.",
    "",
    "Folders:",
    paste0("- input: ", input_dir),
    paste0("- parquet: ", out_parquet_dir),
    paste0("- csv: ", out_csv_dir),
    paste0("- txt: ", out_txt_dir),
    "",
    "Target representation:",
    paste0("- target_hz: ", target_hz),
    paste0("- target_window_sec: ", target_window_sec),
    paste0("- target_n_samples: ", target_n),
    paste0("- feature_set_id: ", feature_set_id),
    paste0("- feature_count: ", length(feature_cols)),
    "",
    paste0("Datasets found: ", nrow(input_dt)),
    paste0("Datasets processed: ", nrow(dataset_dt)),
    paste0("Total windows with features: ", format(sum(dataset_dt$n_windows, na.rm = TRUE), big.mark = ",")),
    paste0("Failed/check datasets: ", sum(dataset_dt$status != "ok", na.rm = TRUE)),
    "",
    "Features:",
    paste0("- ", feature_cols),
    "",
    "Dataset summary:"
  )

  for (i in seq_len(nrow(dataset_dt))) {
    r <- dataset_dt[i]
    lines <- c(
      lines,
      "",
      paste0("Dataset: ", r$dataset_name),
      paste0("- parts: ", r$n_parts),
      paste0("- windows: ", format(r$n_windows, big.mark = ",")),
      paste0("- behaviors: ", r$behaviors),
      paste0("- failed parts: ", r$failed_parts),
      paste0("- status: ", r$status)
    )
  }

  lines <- c(lines, "")

  if (nrow(failed_parts)) {
    lines <- c(lines, "Parts to check:")
    for (i in seq_len(nrow(failed_parts))) {
      r <- failed_parts[i]
      lines <- c(lines, paste0("- ", r$dataset_name, " / ", r$part_file, ": ", r$status))
    }
  } else {
    lines <- c(lines, "Parts to check: none")
  }

  lines <- c(lines, "")

  if (nrow(qc_bad)) {
    lines <- c(lines, "Feature QC warnings:")
    qc_short <- qc_bad[, .(
      n_warnings = .N,
      features = paste(sort(unique(feature)), collapse = " | ")
    ), by = dataset_name]
    for (i in seq_len(nrow(qc_short))) {
      r <- qc_short[i]
      lines <- c(lines, paste0("- ", r$dataset_name, ": ", r$n_warnings, " warnings; ", r$features))
    }
  } else {
    lines <- c(lines, "Feature QC warnings: none")
  }

  c(
    lines,
    "",
    "Next step:",
    "- Use 06 feature parquets for Random Forest and LightGBM.",
    "- Use 04 window parquets for CNN, ResNet, HYDRA, and MultiRocket."
  )
}

# ---------- run ----------

if (!dir.exists(input_dir)) stop("Input folder does not exist: ", input_dir)

dataset_dirs <- sort(list.dirs(input_dir, full.names = TRUE, recursive = FALSE))
dataset_dirs <- dataset_dirs[file.info(dataset_dirs)$isdir]

dataset_names <- basename(dataset_dirs)
dataset_dirs <- dataset_dirs[order(dataset_names)]
dataset_names <- dataset_names[order(dataset_names)]

if (length(dataset_dirs) != expected_dataset_count) {
  stop(
    "Expected ", expected_dataset_count, " dataset folders, but found ",
    length(dataset_dirs), " in: ", input_dir
  )
}

input_dt <- data.table(
  dataset_name = dataset_names,
  input_dir = dataset_dirs,
  n_part_files = vapply(dataset_dirs, function(d) length(list.files(d, pattern = "\\.parquet$", full.names = TRUE)), integer(1))
)

write.csv(input_dt, input_csv_path, row.names = FALSE)
write.csv(data.table(feature_id = seq_along(feature_cols), feature = feature_cols), feature_cols_csv_path, row.names = FALSE)

cat("\n==============================\n")
cat("06 FEATURE EXTRACTION START\n")
cat("==============================\n")

res_list <- vector("list", length(dataset_dirs))

for (i in seq_along(dataset_dirs)) {
  res_list[[i]] <- process_dataset(dataset_dirs[i])
}

part_dt <- rbindlist(lapply(res_list, `[[`, "part_summary"), fill = TRUE, use.names = TRUE)
qc_dt <- rbindlist(lapply(res_list, `[[`, "qc"), fill = TRUE, use.names = TRUE)
dataset_dt <- make_dataset_summary(part_dt)

write.csv(part_dt, part_csv_path, row.names = FALSE)
write.csv(dataset_dt, summary_csv_path, row.names = FALSE)
write.csv(qc_dt, qc_csv_path, row.names = FALSE)
writeLines(make_txt_report(input_dt, dataset_dt, part_dt, qc_dt), report_txt_path)

cat("\n==============================\n")
cat("06 FEATURE EXTRACTION DONE\n")
cat("Datasets:", nrow(dataset_dt), "\n")
cat("Windows :", format(sum(dataset_dt$n_windows, na.rm = TRUE), big.mark = ","), "\n")
cat("Report  :", report_txt_path, "\n")
cat("Output  :", out_parquet_dir, "\n")
cat("==============================\n")
