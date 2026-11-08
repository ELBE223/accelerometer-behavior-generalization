# 01_harmonize_model_ready_v2.R
# Prepare exactly 12 input parquet files, harmonize them, and write model-ready outputs.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
})

# ---------- settings ----------

datasets_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Datasets_raw"
processing_root <- "/Volumes/Z Slim/11_05_2026_Data_Analysis/Data_Processing"

# Canonical input: exactly 12 parquet files, one per dataset.
input_dir <- file.path(processing_root, "00_input", "01_raw_parquet")

# Script 01 output structure.
output_root <- file.path(processing_root, "01")
out_parquet_dir <- file.path(output_root, "01_parquet")
out_csv_dir <- file.path(output_root, "01_csv")
out_txt_dir <- file.path(output_root, "01_txt")

expected_n_files <- 12
write_outputs <- TRUE
overwrite_outputs <- TRUE

# Input refresh: "auto", "always", or "never".
input_refresh_mode <- "auto"
overwrite_input_files <- TRUE

# Keep only these classes for modelling.
target_main_classes <- c("foraging", "locomotion", "resting")
drop_non_target_classes <- TRUE
drop_missing_xyz_rows <- TRUE
drop_missing_datetime_rows <- TRUE

# Hedgehog needs the more detailed animal name as ID.
fix_hedgehog_individual_id_from_name <- TRUE

# Dataset-specific raw xyz conversion.
xyz_divisor_lookup <- c(
  Bison_dataset_1 = 512,
  Dog_dataset_1 = 512,
  Dog_dataset_2 = 512,
  Fox_dataset_1 = 512,
  Fox_dataset_2 = 512,
  Giraffe_dataset_1 = 512,
  Hedgehog_dataset_1 = 512,
  Horse_dataset_1 = 512,
  Horse_dataset_2 = 256,
  Raccoon_dataset_1 = 512,
  Raccoon_dataset_2 = 512
)

# Output files.
input_report_path <- file.path(out_csv_dir, "01_input_files.csv")
input_selection_report_path <- file.path(out_csv_dir, "01_input_selection.csv")
report_csv_path <- file.path(out_csv_dir, "01_harmonization_report.csv")
filter_report_csv_path <- file.path(out_csv_dir, "01_filter_report.csv")
report_txt_path <- file.path(out_txt_dir, "01_report.txt")

# ---------- folders ----------

create_output_dirs <- function() {
  dirs <- c(output_root, out_parquet_dir, out_csv_dir, out_txt_dir)
  purrr::walk(dirs, ~ dir.create(.x, recursive = TRUE, showWarnings = FALSE))
}

# ---------- input discovery ----------

find_parquet_dirs <- function(root_dir) {
  if (!dir.exists(root_dir)) {
    stop("Raw datasets folder does not exist: ", root_dir)
  }
  
  dirs <- list.dirs(root_dir, recursive = TRUE, full.names = TRUE)
  dirs[basename(dirs) == "parquet" & grepl("Data_.*_Processed", dirname(dirs))]
}

make_dataset_name_from_dir <- function(parquet_dir) {
  parts <- strsplit(parquet_dir, .Platform$file.sep, fixed = TRUE)[[1]]
  
  species_idx <- which(parts == "Datasets_raw") + 1
  species_name <- parts[species_idx]
  
  dataset_idx <- grep("^Dataset_[0-9]+$", parts)
  dataset_number <- if (length(dataset_idx) > 0) {
    stringr::str_extract(parts[dataset_idx[1]], "[0-9]+")
  } else {
    "1"
  }
  
  paste0(species_name, "_dataset_", dataset_number)
}

find_candidate_files <- function(parquet_dir) {
  files <- list.files(parquet_dir, pattern = "\\.parquet$", full.names = TRUE)
  base <- basename(files)
  
  exclude_pattern <- paste(
    c("summary", "report", "manifest", "diagnostic", "diagnostics",
      "qa", "columns", "mapping", "metadata", "labels"),
    collapse = "|"
  )
  
  preferred <- files[
    grepl("model_ready", base, ignore.case = TRUE) &
      !grepl(exclude_pattern, base, ignore.case = TRUE)
  ]
  if (length(preferred) > 0) return(preferred)
  
  mapped <- files[
    grepl("mapped", base, ignore.case = TRUE) &
      !grepl(exclude_pattern, base, ignore.case = TRUE)
  ]
  if (length(mapped) > 0) return(mapped)
  
  files[!grepl(exclude_pattern, base, ignore.case = TRUE)]
}

get_parquet_nrows <- function(file) {
  tryCatch({
    ds <- arrow::open_dataset(file, format = "parquet")
    out <- ds %>%
      dplyr::summarise(n = dplyr::n()) %>%
      dplyr::collect()
    as.integer(out$n[[1]])
  }, error = function(e) {
    warning("Could not count rows for: ", file, " | ", conditionMessage(e))
    NA_integer_
  })
}

select_input_files <- function(files) {
  if (length(files) == 0) {
    return(list(files = character(), mode = "no_files", file_info = tibble()))
  }
  
  file_info <- tibble(
    file = files,
    file_name = basename(files),
    rows = purrr::map_int(files, get_parquet_nrows)
  )
  
  if (length(files) == 1) {
    return(list(files = files, mode = "single_file", file_info = file_info))
  }
  
  if (any(is.na(file_info$rows))) {
    return(list(files = files, mode = "combined_files_no_row_count", file_info = file_info))
  }
  
  max_i <- which.max(file_info$rows)
  max_rows <- file_info$rows[max_i]
  other_rows <- sum(file_info$rows[-max_i])
  
  has_aggregate <- other_rows > 0 &&
    max_rows >= 0.95 * other_rows &&
    max_rows <= 1.05 * other_rows
  
  if (has_aggregate) {
    selected <- file_info$file[max_i]
    mode <- "aggregate_file_selected"
  } else {
    selected <- file_info$file
    mode <- "combined_files"
  }
  
  list(files = selected, mode = mode, file_info = file_info)
}

discover_raw_jobs <- function(root_dir) {
  parquet_dirs <- find_parquet_dirs(root_dir)
  
  if (length(parquet_dirs) == 0) {
    stop("No processed parquet folders found below: ", root_dir)
  }
  
  jobs <- tibble(
    parquet_dir = parquet_dirs,
    dataset_name = purrr::map_chr(parquet_dirs, make_dataset_name_from_dir),
    candidate_files = purrr::map(parquet_dirs, find_candidate_files)
  ) %>%
    filter(purrr::map_int(candidate_files, length) > 0)
  
  if (nrow(jobs) == 0) {
    stop("No usable parquet files found in processed parquet folders.")
  }
  
  jobs$dataset_name <- make.unique(jobs$dataset_name, sep = "_")
  
  selections <- purrr::map(jobs$candidate_files, select_input_files)
  jobs$selected_files <- purrr::map(selections, "files")
  jobs$selection_mode <- purrr::map_chr(selections, "mode")
  
  jobs
}

read_raw_files_for_input <- function(dataset_name, selected_files) {
  dfs <- vector("list", length(selected_files))
  
  for (i in seq_along(selected_files)) {
    file <- selected_files[[i]]
    message("  Loading source ", i, "/", length(selected_files), ": ", basename(file))
    
    df <- arrow::read_parquet(file, as_data_frame = TRUE)
    df$source_parquet_file <- basename(file)
    df$dataset_name <- dataset_name
    dfs[[i]] <- df
  }
  
  dplyr::bind_rows(dfs)
}

build_input_files_from_raw <- function(root_dir, input_dir) {
  dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
  
  jobs <- discover_raw_jobs(root_dir) %>%
    arrange(dataset_name)
  
  if (nrow(jobs) != expected_n_files) {
    stop(
      "Expected ", expected_n_files,
      " datasets from raw folders, but found ", nrow(jobs), ".\n",
      "Raw folder: ", root_dir
    )
  }
  
  if (isTRUE(overwrite_input_files)) {
    old_files <- list.files(input_dir, pattern = "\\.parquet$", full.names = TRUE)
    if (length(old_files) > 0) unlink(old_files)
  }
  
  output_files <- character(nrow(jobs))
  
  for (i in seq_len(nrow(jobs))) {
    dataset_name <- jobs$dataset_name[[i]]
    selected_files <- jobs$selected_files[[i]]
    output_file <- file.path(input_dir, paste0(dataset_name, ".parquet"))
    
    message("\nPreparing input: ", dataset_name)
    
    if (file.exists(output_file) && !isTRUE(overwrite_input_files)) {
      message("  Keeping existing input file: ", basename(output_file))
    } else {
      df <- read_raw_files_for_input(dataset_name, selected_files)
      arrow::write_parquet(df, output_file)
      message("  Written input file: ", basename(output_file))
      rm(df)
      invisible(gc())
    }
    
    output_files[[i]] <- output_file
  }
  
  jobs %>%
    mutate(
      input_file = output_files,
      input_file_name = basename(output_files),
      n_candidate_files = purrr::map_int(candidate_files, length),
      n_selected_files = purrr::map_int(selected_files, length),
      candidate_file_names = purrr::map_chr(candidate_files, ~ paste(basename(.x), collapse = "; ")),
      selected_file_names = purrr::map_chr(selected_files, ~ paste(basename(.x), collapse = "; "))
    ) %>%
    select(
      dataset_name,
      input_file_name,
      selection_mode,
      n_candidate_files,
      n_selected_files,
      selected_file_names,
      candidate_file_names,
      parquet_dir,
      input_file
    )
}

prepare_input_folder <- function() {
  dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
  
  current_files <- list.files(input_dir, pattern = "\\.parquet$", full.names = TRUE)
  
  if (input_refresh_mode == "always") {
    refresh <- TRUE
  } else if (input_refresh_mode == "never") {
    refresh <- FALSE
  } else if (input_refresh_mode == "auto") {
    refresh <- length(current_files) != expected_n_files
  } else {
    stop("input_refresh_mode must be 'auto', 'always', or 'never'.")
  }
  
  if (isTRUE(refresh)) {
    message("Preparing canonical 12-file input folder from raw datasets...")
    selection_report <- build_input_files_from_raw(datasets_root, input_dir)
    readr::write_csv(selection_report, input_selection_report_path)
    return(invisible(selection_report))
  }
  
  message("Using existing canonical input folder: ", input_dir)
  invisible(NULL)
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
  
  parquet_files <- visible_files[str_detect(basename(visible_files), "\\.parquet$")]
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
  
  sort(parquet_files)
}

make_dataset_name <- function(file) {
  tools::file_path_sans_ext(basename(file))
}

make_jobs <- function(input_dir) {
  files <- list_input_files(input_dir)
  dataset_names <- purrr::map_chr(files, make_dataset_name)
  
  if (anyDuplicated(dataset_names) > 0) {
    stop("Duplicate dataset names found after removing .parquet extension.")
  }
  
  tibble(
    dataset_name = dataset_names,
    input_file = files,
    input_file_name = basename(files),
    input_size_mb = round(file.size(files) / 1024^2, 2)
  ) %>%
    arrange(dataset_name)
}

read_dataset <- function(dataset_name, input_file) {
  message("  Reading: ", basename(input_file))
  
  df <- arrow::read_parquet(input_file, as_data_frame = TRUE)
  
  if (!("source_parquet_file" %in% names(df))) {
    df$source_parquet_file <- basename(input_file)
  }
  
  if (!("dataset_name" %in% names(df))) {
    df$dataset_name <- dataset_name
  }
  
  df %>%
    dplyr::select(dataset_name, source_parquet_file, dplyr::everything())
}

# ---------- type helpers ----------

get_vec <- function(df, candidates, default = NA) {
  hit <- candidates[candidates %in% names(df)][1]
  
  if (is.na(hit)) {
    return(rep(default, nrow(df)))
  }
  
  df[[hit]]
}

to_chr <- function(x) {
  if (inherits(x, "factor")) x <- as.character(x)
  as.character(x)
}

to_num <- function(x) {
  suppressWarnings(as.numeric(x))
}

to_lgl <- function(x) {
  if (is.logical(x)) return(x)
  if (is.numeric(x)) return(x != 0)
  
  x_chr <- tolower(trimws(as.character(x)))
  dplyr::case_when(
    x_chr %in% c("true", "t", "yes", "y", "1") ~ TRUE,
    x_chr %in% c("false", "f", "no", "n", "0") ~ FALSE,
    TRUE ~ NA
  )
}

to_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXct") || inherits(x, "POSIXt")) return(as.Date(x))
  
  out <- suppressWarnings(as.Date(as.character(x)))
  
  numeric_x <- suppressWarnings(as.numeric(x))
  excel_like <- is.na(out) & is.finite(numeric_x) & numeric_x > 20000
  out[excel_like] <- as.Date(numeric_x[excel_like], origin = "1899-12-30")
  
  out
}

to_datetime <- function(x) {
  if (inherits(x, "POSIXct")) return(x)
  if (inherits(x, "POSIXt")) return(as.POSIXct(x, tz = "UTC"))
  
  x_chr <- as.character(x)
  out <- suppressWarnings(as.POSIXct(x_chr, tz = "UTC"))
  
  missing <- is.na(out) & !is.na(x_chr) & x_chr != ""
  if (any(missing)) {
    out[missing] <- suppressWarnings(as.POSIXct(
      x_chr[missing],
      format = "%Y-%m-%d %H:%M:%OS",
      tz = "UTC"
    ))
  }
  
  numeric_x <- suppressWarnings(as.numeric(x))
  excel_like <- is.na(out) & is.finite(numeric_x) & numeric_x > 20000
  out[excel_like] <- as.POSIXct(
    numeric_x[excel_like] * 86400,
    origin = "1899-12-30",
    tz = "UTC"
  )
  
  out
}

safe_time_from_datetime <- function(datetime_vec) {
  out <- rep(NA_character_, length(datetime_vec))
  ok <- !is.na(datetime_vec)
  out[ok] <- format(datetime_vec[ok], "%H:%M:%OS3")
  out
}

first_non_missing_chr <- function(...) {
  values <- list(...)
  out <- to_chr(values[[1]])
  
  if (length(values) == 1) {
    return(out)
  }
  
  for (i in seq_along(values)[-1]) {
    candidate <- to_chr(values[[i]])
    replace_i <- is.na(out) | out == "" | out == "NA"
    out[replace_i] <- candidate[replace_i]
  }
  
  out
}

clean_id <- function(x) {
  x <- to_chr(x)
  x <- trimws(x)
  x[x == "" | x == "NA"] <- NA_character_
  x
}

standardize_main_class <- function(x) {
  x <- to_chr(x)
  x <- str_to_lower(trimws(x))
  x[x == "" | x == "na"] <- NA_character_
  x
}

# ---------- xyz helpers ----------

infer_xyz_scale <- function(x, y, z) {
  vals <- c(to_num(x), to_num(y), to_num(z))
  vals <- vals[is.finite(vals)]
  
  if (length(vals) == 0) return("missing_xyz")
  
  val_min <- min(vals)
  val_max <- max(vals)
  max_abs <- max(abs(vals))
  
  if (max_abs <= 16) return("already_g")
  if (val_min >= -250 && val_max <= 5000) return("raw_12bit_candidate")
  
  "unknown_xyz_scale"
}

best_divisor_by_magnitude <- function(x, y, z) {
  divisors <- c(128, 256, 512, 1024)
  
  scores <- purrr::map_dbl(divisors, function(divisor) {
    x_g <- (to_num(x) - 2048) / divisor
    y_g <- (to_num(y) - 2048) / divisor
    z_g <- (to_num(z) - 2048) / divisor
    mag <- sqrt(x_g^2 + y_g^2 + z_g^2)
    abs(stats::median(mag, na.rm = TRUE) - 1)
  })
  
  divisors[which.min(scores)]
}

get_xyz_divisor <- function(dataset_name, x, y, z) {
  if (dataset_name %in% names(xyz_divisor_lookup)) {
    return(unname(xyz_divisor_lookup[[dataset_name]]))
  }
  
  best_divisor_by_magnitude(x, y, z)
}

convert_raw_to_g <- function(x, divisor) {
  (to_num(x) - 2048) / divisor
}

# ---------- ID helpers ----------

make_individual_id <- function(df) {
  n <- nrow(df)
  
  id <- first_non_missing_chr(
    get_vec(df, c("individual_id", "Individual ID", "tag_id")),
    get_vec(df, c("record_id")),
    get_vec(df, c("animal")),
    get_vec(df, c("individual_name", "name", "Name")),
    get_vec(df, c("individual_label")),
    rep(NA_character_, n)
  )
  
  clean_id(id)
}

make_individual_name <- function(df) {
  n <- nrow(df)
  
  name <- first_non_missing_chr(
    get_vec(df, c("individual_name", "name", "Name")),
    get_vec(df, c("animal")),
    get_vec(df, c("individual_label")),
    get_vec(df, c("individual_id", "Individual ID", "tag_id")),
    rep(NA_character_, n)
  )
  
  clean_id(name)
}

# ---------- harmonization ----------

harmonize_dataset <- function(df, dataset_name) {
  n <- nrow(df)
  original_col_count <- ncol(df)
  
  x_candidate <- get_vec(df, c("x_raw", "x", "X"))
  y_candidate <- get_vec(df, c("y_raw", "y", "Y"))
  z_candidate <- get_vec(df, c("z_raw", "z", "Z"))
  
  x_g_explicit <- get_vec(df, c("x_g"))
  y_g_explicit <- get_vec(df, c("y_g"))
  z_g_explicit <- get_vec(df, c("z_g"))
  
  xyz_scale <- infer_xyz_scale(x_candidate, y_candidate, z_candidate)
  
  has_explicit_g <- any(!is.na(to_num(x_g_explicit))) ||
    any(!is.na(to_num(y_g_explicit))) ||
    any(!is.na(to_num(z_g_explicit)))
  
  if (has_explicit_g) {
    x_raw <- if (xyz_scale == "raw_12bit_candidate") to_num(x_candidate) else rep(NA_real_, n)
    y_raw <- if (xyz_scale == "raw_12bit_candidate") to_num(y_candidate) else rep(NA_real_, n)
    z_raw <- if (xyz_scale == "raw_12bit_candidate") to_num(z_candidate) else rep(NA_real_, n)
    
    x_g <- to_num(x_g_explicit)
    y_g <- to_num(y_g_explicit)
    z_g <- to_num(z_g_explicit)
    
    xyz_divisor <- NA_real_
    xyz_conversion <- "used_existing_g_columns"
  } else if (xyz_scale == "already_g") {
    x_raw <- rep(NA_real_, n)
    y_raw <- rep(NA_real_, n)
    z_raw <- rep(NA_real_, n)
    
    x_g <- to_num(x_candidate)
    y_g <- to_num(y_candidate)
    z_g <- to_num(z_candidate)
    
    xyz_divisor <- NA_real_
    xyz_conversion <- "already_g"
  } else if (xyz_scale == "raw_12bit_candidate") {
    xyz_divisor <- get_xyz_divisor(dataset_name, x_candidate, y_candidate, z_candidate)
    
    x_raw <- to_num(x_candidate)
    y_raw <- to_num(y_candidate)
    z_raw <- to_num(z_candidate)
    
    x_g <- convert_raw_to_g(x_candidate, xyz_divisor)
    y_g <- convert_raw_to_g(y_candidate, xyz_divisor)
    z_g <- convert_raw_to_g(z_candidate, xyz_divisor)
    
    xyz_conversion <- paste0("converted_raw_center2048_div", xyz_divisor)
  } else {
    x_raw <- rep(NA_real_, n)
    y_raw <- rep(NA_real_, n)
    z_raw <- rep(NA_real_, n)
    
    x_g <- rep(NA_real_, n)
    y_g <- rep(NA_real_, n)
    z_g <- rep(NA_real_, n)
    
    xyz_divisor <- NA_real_
    xyz_conversion <- xyz_scale
  }
  
  datetime_raw <- get_vec(df, c("datetime", "DateTime", "behavior_datetime", "datetime_jst", "datetime_utc"))
  datetime <- to_datetime(datetime_raw)
  
  date_raw <- get_vec(df, c("date", "Date"))
  date <- to_date(date_raw)
  date[is.na(date)] <- as.Date(datetime[is.na(date)])
  
  time_raw <- get_vec(df, c("time", "Time", "behavior_timestamp"))
  time <- to_chr(time_raw)
  time_missing <- is.na(time) | time == "" | time == "NA"
  time[time_missing] <- safe_time_from_datetime(datetime)[time_missing]
  
  species <- first_non_missing_chr(
    get_vec(df, c("species", "Species")),
    rep(NA_character_, n)
  )
  
  individual_id <- make_individual_id(df)
  individual_name <- make_individual_name(df)
  
  if (isTRUE(fix_hedgehog_individual_id_from_name) && dataset_name == "Hedgehog_dataset_1") {
    use_name <- !is.na(individual_name) & individual_name != ""
    individual_id[use_name] <- individual_name[use_name]
  }
  
  source_file <- first_non_missing_chr(
    get_vec(df, c("source_file", "source_sheet", "behavior_file")),
    get_vec(df, c("source_parquet_file")),
    rep(NA_character_, n)
  )
  
  row_nr <- suppressWarnings(as.integer(to_num(get_vec(df, c("row_nr", "row_id", "behavior_row_id")))))
  
  behavior_raw <- first_non_missing_chr(
    get_vec(df, c("behavior_raw", "Behavior", "behavior_raw_de", "behavior_raw_code", "bev")),
    get_vec(df, c("code_raw")),
    rep(NA_character_, n)
  )
  
  code_raw <- first_non_missing_chr(
    get_vec(df, c("code_raw")),
    behavior_raw,
    rep(NA_character_, n)
  )
  
  code_norm <- first_non_missing_chr(
    get_vec(df, c("code_norm")),
    toupper(code_raw),
    rep(NA_character_, n)
  )
  
  code_ma <- first_non_missing_chr(
    get_vec(df, c("code_ma")),
    code_norm,
    rep(NA_character_, n)
  )
  
  behavior_en <- first_non_missing_chr(
    get_vec(df, c("behavior_en")),
    behavior_raw,
    rep(NA_character_, n)
  )
  
  main_class <- first_non_missing_chr(
    get_vec(df, c("main_class")),
    behavior_en,
    rep(NA_character_, n)
  )
  main_class <- standardize_main_class(main_class)
  
  acc_magnitude_g <- to_num(get_vec(df, c("acc_magnitude_g")))
  missing_acc <- is.na(acc_magnitude_g)
  acc_magnitude_g[missing_acc] <- sqrt(
    x_g[missing_acc]^2 + y_g[missing_acc]^2 + z_g[missing_acc]^2
  )
  
  tibble(
    dataset_name = to_chr(get_vec(df, c("dataset_name"), dataset_name)),
    species = species,
    individual_id = individual_id,
    individual_name = individual_name,
    source_file = source_file,
    source_parquet_file = to_chr(get_vec(df, c("source_parquet_file"))),
    date = date,
    time = time,
    datetime = datetime,
    row_nr = row_nr,
    
    x_raw = x_raw,
    y_raw = y_raw,
    z_raw = z_raw,
    x_g = x_g,
    y_g = y_g,
    z_g = z_g,
    acc_magnitude_g = acc_magnitude_g,
    
    behavior_raw = behavior_raw,
    code_raw = code_raw,
    code_norm = code_norm,
    code_ma = code_ma,
    behavior_en = behavior_en,
    main_class = main_class,
    ma_category_code = to_chr(get_vec(df, c("ma_category_code"))),
    ma_category_de = to_chr(get_vec(df, c("ma_category_de"))),
    model_use_ma = to_lgl(get_vec(df, c("model_use_ma"))),
    is_mapped = to_lgl(get_vec(df, c("is_mapped"))),
    burst_uid = to_chr(get_vec(df, c("burst_uid", "burst_uid_behavior", "sample_uid"))),
    
    xyz_scale_inferred = rep(xyz_scale, n),
    xyz_conversion = rep(xyz_conversion, n),
    xyz_divisor = rep(xyz_divisor, n),
    original_columns_count = rep(original_col_count, n)
  )
}

# ---------- filtering ----------

filter_model_ready_dataset <- function(df) {
  out <- df
  
  if (isTRUE(drop_non_target_classes)) {
    out <- out %>% filter(main_class %in% target_main_classes)
  }
  
  if (isTRUE(drop_missing_xyz_rows)) {
    out <- out %>% filter(!is.na(x_g), !is.na(y_g), !is.na(z_g))
  }
  
  if (isTRUE(drop_missing_datetime_rows)) {
    out <- out %>% filter(!is.na(datetime))
  }
  
  out
}

summarise_filtering <- function(before_df, after_df, dataset_name) {
  target_before <- before_df %>% filter(main_class %in% target_main_classes)
  target_xyz_before <- target_before %>% filter(!is.na(x_g), !is.na(y_g), !is.na(z_g))
  
  tibble(
    dataset_name = dataset_name,
    rows_before_filter = nrow(before_df),
    rows_after_filter = nrow(after_df),
    removed_total = nrow(before_df) - nrow(after_df),
    removed_non_target_or_missing_class = nrow(before_df) - nrow(target_before),
    removed_missing_xyz_after_class_filter = nrow(target_before) - nrow(target_xyz_before),
    removed_missing_datetime_after_class_xyz_filter = nrow(target_xyz_before) - nrow(after_df),
    retained_prop = ifelse(nrow(before_df) == 0, NA_real_, nrow(after_df) / nrow(before_df)),
    n_classes_after = dplyr::n_distinct(after_df$main_class, na.rm = TRUE),
    classes_after = paste(sort(unique(na.omit(after_df$main_class))), collapse = "; "),
    n_individuals_after = dplyr::n_distinct(after_df$individual_id, na.rm = TRUE)
  )
}

# ---------- reports ----------

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

summarise_harmonized <- function(df) {
  tibble(
    dataset_name = unique(df$dataset_name)[1],
    n_rows = nrow(df),
    n_columns = ncol(df),
    species = paste(sort(unique(na.omit(df$species))), collapse = "; "),
    n_individuals = n_distinct(df$individual_id, na.rm = TRUE),
    n_individual_names = n_distinct(df$individual_name, na.rm = TRUE),
    n_behaviors_raw = n_distinct(df$behavior_raw, na.rm = TRUE),
    n_main_classes = n_distinct(df$main_class, na.rm = TRUE),
    xyz_scale_inferred = unique(df$xyz_scale_inferred)[1],
    xyz_conversion = unique(df$xyz_conversion)[1],
    xyz_divisor = unique(df$xyz_divisor)[1],
    x_raw_min = safe_min(df$x_raw),
    x_raw_max = safe_max(df$x_raw),
    x_g_min = safe_min(df$x_g),
    x_g_max = safe_max(df$x_g),
    y_g_min = safe_min(df$y_g),
    y_g_max = safe_max(df$y_g),
    z_g_min = safe_min(df$z_g),
    z_g_max = safe_max(df$z_g),
    acc_magnitude_g_median = safe_median(df$acc_magnitude_g),
    missing_xyz_rows = sum(is.na(df$x_g) | is.na(df$y_g) | is.na(df$z_g)),
    missing_datetime_rows = sum(is.na(df$datetime)),
    missing_individual_id_rows = sum(is.na(df$individual_id) | df$individual_id == ""),
    missing_behavior_rows = sum(is.na(df$behavior_raw) | df$behavior_raw == "")
  )
}

make_txt_report <- function(report_tbl, filter_report_tbl, input_report, output_files, schema_cols) {
  lines <- c(
    "01 Harmonize Model-ready Report",
    paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "Goal:",
    "- Prepare one canonical input parquet per dataset if needed.",
    "- Load exactly 12 direct parquet files from one input folder.",
    "- Harmonize all datasets to one shared schema.",
    "- Write model-ready parquet outputs and compact reports.",
    "",
    "Folders:",
    paste0("- raw source: ", datasets_root),
    paste0("- canonical input: ", input_dir),
    paste0("- parquet: ", out_parquet_dir),
    paste0("- csv: ", out_csv_dir),
    paste0("- txt: ", out_txt_dir),
    "",
    paste0("Input files: ", nrow(input_report)),
    paste0("Datasets processed: ", nrow(report_tbl)),
    paste0("Rows after filtering: ", format(sum(report_tbl$n_rows), big.mark = ",")),
    paste0("Common columns: ", length(schema_cols)),
    "",
    "Model-ready filter:",
    paste0("- retained classes: ", paste(target_main_classes, collapse = ", ")),
    paste0("- drop non-target classes: ", drop_non_target_classes),
    paste0("- drop missing xyz rows: ", drop_missing_xyz_rows),
    paste0("- drop missing datetime rows: ", drop_missing_datetime_rows),
    "",
    "Common schema:",
    paste0("- ", schema_cols),
    "",
    "Dataset summary:"
  )
  
  for (i in seq_len(nrow(report_tbl))) {
    r <- report_tbl[i, ]
    f <- filter_report_tbl %>% filter(dataset_name == r$dataset_name)
    
    lines <- c(
      lines,
      "",
      paste0("Dataset: ", r$dataset_name),
      paste0("- rows before filter: ", format(f$rows_before_filter, big.mark = ",")),
      paste0("- rows after filter: ", format(r$n_rows, big.mark = ",")),
      paste0("- retained proportion: ", round(f$retained_prop, 4)),
      paste0("- species: ", r$species),
      paste0("- individual ids: ", r$n_individuals),
      paste0("- main classes: ", r$n_main_classes),
      paste0("- xyz conversion: ", r$xyz_conversion),
      paste0("- xyz divisor: ", ifelse(is.na(r$xyz_divisor), "NA", r$xyz_divisor)),
      paste0("- missing datetime rows: ", r$missing_datetime_rows),
      paste0("- output: ", basename(output_files[[r$dataset_name]]))
    )
  }
  
  c(
    lines,
    "",
    "Notes:",
    "- Output is model-ready at row level, not yet window level.",
    "- Use x_g, y_g, and z_g for windowing and feature extraction.",
    "- Re-run diagnostics before model training."
  )
}

# ---------- processing ----------

process_one_dataset <- function(dataset_name, input_file) {
  output_file <- file.path(out_parquet_dir, paste0(dataset_name, "_mr.parquet"))
  
  if (file.exists(output_file) && !isTRUE(overwrite_outputs)) {
    message("Skipping existing output: ", output_file)
    existing <- arrow::read_parquet(output_file, as_data_frame = TRUE)
    
    return(list(
      output_file = output_file,
      report = summarise_harmonized(existing),
      filter_report = tibble(
        dataset_name = dataset_name,
        rows_before_filter = NA_integer_,
        rows_after_filter = nrow(existing),
        removed_total = NA_integer_,
        removed_non_target_or_missing_class = NA_integer_,
        removed_missing_xyz_after_class_filter = NA_integer_,
        removed_missing_datetime_after_class_xyz_filter = NA_integer_,
        retained_prop = NA_real_,
        n_classes_after = dplyr::n_distinct(existing$main_class, na.rm = TRUE),
        classes_after = paste(sort(unique(na.omit(existing$main_class))), collapse = "; "),
        n_individuals_after = dplyr::n_distinct(existing$individual_id, na.rm = TRUE)
      ),
      schema_cols = names(existing)
    ))
  }
  
  message("\nProcessing: ", dataset_name)
  
  raw_df <- read_dataset(dataset_name, input_file)
  message("  Rows loaded: ", format(nrow(raw_df), big.mark = ","))
  
  harmonized_all <- harmonize_dataset(raw_df, dataset_name)
  rm(raw_df)
  invisible(gc())
  
  harmonized_mr <- filter_model_ready_dataset(harmonized_all)
  
  filter_report <- summarise_filtering(
    before_df = harmonized_all,
    after_df = harmonized_mr,
    dataset_name = dataset_name
  )
  
  rm(harmonized_all)
  invisible(gc())
  
  report <- summarise_harmonized(harmonized_mr)
  schema_cols <- names(harmonized_mr)
  
  if (isTRUE(write_outputs)) {
    arrow::write_parquet(harmonized_mr, output_file)
    message("  Written: ", output_file)
  }
  
  rm(harmonized_mr)
  invisible(gc())
  
  list(
    output_file = output_file,
    report = report,
    filter_report = filter_report,
    schema_cols = schema_cols
  )
}

# ---------- run ----------

create_output_dirs()
prepare_input_folder()

jobs <- make_jobs(input_dir)
readr::write_csv(jobs, input_report_path)

message("Processing 12 datasets sequentially...")

results <- vector("list", nrow(jobs))
names(results) <- jobs$dataset_name

schema_cols <- NULL
schema_ok <- TRUE
output_files <- setNames(rep(NA_character_, nrow(jobs)), jobs$dataset_name)

for (i in seq_len(nrow(jobs))) {
  dataset_name <- jobs$dataset_name[[i]]
  input_file <- jobs$input_file[[i]]
  
  result <- process_one_dataset(dataset_name, input_file)
  results[[dataset_name]] <- result
  output_files[[dataset_name]] <- result$output_file
  
  if (is.null(schema_cols)) {
    schema_cols <- result$schema_cols
  } else if (!identical(schema_cols, result$schema_cols)) {
    schema_ok <- FALSE
    warning("Schema mismatch for dataset: ", dataset_name)
  }
  
  invisible(gc())
}

report_tbl <- purrr::map_dfr(results, "report")
filter_report_tbl <- purrr::map_dfr(results, "filter_report")

if (!schema_ok) {
  warning("At least one schema mismatch occurred. Check harmonize_dataset().")
}

if (isTRUE(write_outputs)) {
  readr::write_csv(report_tbl, report_csv_path)
  readr::write_csv(filter_report_tbl, filter_report_csv_path)
  
  txt_lines <- make_txt_report(
    report_tbl = report_tbl,
    filter_report_tbl = filter_report_tbl,
    input_report = jobs,
    output_files = output_files,
    schema_cols = schema_cols
  )
  writeLines(txt_lines, report_txt_path)
}

assign("script01_input_files", jobs, envir = .GlobalEnv)
assign("script01_harmonization_report", report_tbl, envir = .GlobalEnv)
assign("script01_filter_report", filter_report_tbl, envir = .GlobalEnv)
assign("script01_output_files", output_files, envir = .GlobalEnv)

cat("\nFinished Script 01.\n")
cat("Input files: ", nrow(jobs), "\n", sep = "")
cat("Same schema: ", schema_ok, "\n", sep = "")
cat("Parquet folder: ", out_parquet_dir, "\n", sep = "")
cat("CSV folder: ", out_csv_dir, "\n", sep = "")
cat("TXT folder: ", out_txt_dir, "\n", sep = "")
cat("TXT report: ", report_txt_path, "\n", sep = "")

print(report_tbl, width = Inf)
print(filter_report_tbl, width = Inf)
