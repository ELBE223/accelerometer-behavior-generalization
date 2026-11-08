# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(readxl, dplyr, stringr, arrow, cellranger, tibble)

# paths
file_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Giraffe/Data_Giraffe_Raw/Giraffe.xlsx"
out_dir   <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Giraffe/Data_Giraffe_Proccessed"
out_file  <- file.path(out_dir, "Giraffe.parquet")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# coarse mapping from cat_code
behavior_map_cat <- c(
  "WAL" = "Locomotion",
  "RUN" = "Locomotion",
  
  "FEA" = "Foraging",
  "FTM" = "Foraging",
  "FED" = "Foraging",
  "FEG" = "Foraging",
  "DRI" = "Foraging",
  
  "LIE" = "Resting",
  "RUM" = "Resting",
  "SLE" = "Resting",
  
  "GRO" = "Other",
  "SOC" = "Other",
  "FIG" = "Other"
)

# STA split by beh_code
standing_override <- c(
  "1ST"     = "Resting",
  "1STMI"   = "Resting",
  "1STGU"   = "Other",
  "1STGUMI" = "Other",
  "1STGUTI" = "Other"
)

required_cols <- c("tag_day", "date", "time_ss", "x", "y", "z", "beh_code", "cat_code", "animal")

# find header row
find_header_skip <- function(path, sheet, max_check_rows = 10) {
  preview <- readxl::read_excel(
    path,
    sheet = sheet,
    range = cellranger::cell_cols("A:J"),
    col_names = FALSE,
    n_max = max_check_rows,
    .name_repair = "minimal"
  )
  
  for (i in seq_len(nrow(preview))) {
    candidate <- as.character(unlist(preview[i, ], use.names = FALSE))
    candidate <- trimws(candidate)
    
    if (all(required_cols %in% candidate)) {
      return(i - 1)
    }
  }
  
  NA_integer_
}

# normalize codes
normalize_code <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x[x == ""] <- NA_character_
  
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
  x <- toupper(x)
  x <- gsub("[^A-Z0-9]", "", x)
  
  x[nchar(x) == 0] <- NA_character_
  x
}

# combine date + time_ss
make_datetime <- function(date_vec, time_vec) {
  date_part <- as.Date(date_vec)
  time_part <- as.character(time_vec)
  time_part <- trimws(time_part)
  time_part <- gsub(",", ".", time_part)
  time_part[time_part == ""] <- NA_character_
  
  as.POSIXct(
    paste(date_part, time_part),
    format = "%Y-%m-%d %H:%M:%OS",
    tz = "UTC"
  )
}

# process one sheet
process_sheet <- function(sheet, path) {
  skip_n <- find_header_skip(path, sheet)
  
  if (is.na(skip_n)) {
    message("Skipping sheet: ", sheet)
    return(NULL)
  }
  
  x <- readxl::read_excel(
    path,
    sheet = sheet,
    range = cellranger::cell_cols("A:J"),
    skip = skip_n,
    .name_repair = "minimal"
  )
  
  names(x) <- trimws(names(x))
  
  if (!all(required_cols %in% names(x))) {
    message("Skipping sheet (missing required columns): ", sheet)
    return(NULL)
  }
  
  cat_raw  <- as.character(x$cat_code)
  cat_norm <- normalize_code(cat_raw)
  
  beh_raw  <- as.character(x$beh_code)
  beh_norm <- normalize_code(beh_raw)
  
  behavior <- unname(behavior_map_cat[cat_norm])
  
  is_sta <- !is.na(cat_norm) & cat_norm == "STA"
  behavior[is_sta] <- unname(standing_override[beh_norm[is_sta]])
  
  tibble::tibble(
    Name        = stringr::str_trim(as.character(x$animal)),
    DateTime    = make_datetime(x$date, x$time_ss),
    X           = as.numeric(x$x),
    Y           = as.numeric(x$y),
    Z           = as.numeric(x$z),
    Behavior    = behavior,
    Cat_Code    = cat_raw,
    Cat_norm    = cat_norm,
    Beh_Code    = beh_raw,
    Beh_norm    = beh_norm,
    Tag_Day     = as.numeric(x$tag_day),
    Species     = "Giraffa camelopardalis",
    Sheet       = sheet
  )
}

# read sheets
sheet_names <- readxl::excel_sheets(file_path)
all_data <- dplyr::bind_rows(lapply(sheet_names, process_sheet, path = file_path))

if (nrow(all_data) == 0) {
  stop("No valid sheets were processed.")
}

# create individual ids from Name
valid_names <- unique(all_data$Name[!is.na(all_data$Name) & all_data$Name != ""])

id_lookup <- tibble::tibble(
  Name = valid_names,
  `Individual ID` = seq_along(valid_names)
)

all_data <- all_data %>%
  dplyr::left_join(id_lookup, by = "Name") %>%
  dplyr::select(
    `Individual ID`, Species, Name, DateTime, X, Y, Z, Behavior,
    Cat_Code, Cat_norm, Beh_Code, Beh_norm, Tag_Day, Sheet
  ) %>%
  dplyr::arrange(Name, DateTime)

# qa: mapping summary
mapped_rows <- sum(!is.na(all_data$Behavior))
mapped_pct  <- round(100 * mapped_rows / nrow(all_data), 2)
missing_dt  <- sum(is.na(all_data$DateTime))

unmapped_cat <- all_data %>%
  dplyr::filter(is.na(Behavior), !is.na(Cat_norm)) %>%
  dplyr::count(Cat_norm, sort = TRUE)

unmapped_beh <- all_data %>%
  dplyr::filter(is.na(Behavior), !is.na(Beh_norm)) %>%
  dplyr::count(Beh_norm, sort = TRUE)

class_stats <- all_data %>%
  dplyr::filter(!is.na(Behavior)) %>%
  dplyr::count(Behavior, name = "n") %>%
  dplyr::mutate(percent = round(100 * n / sum(n), 2)) %>%
  dplyr::arrange(desc(n))

cat_summary <- all_data %>%
  dplyr::count(Cat_norm, Behavior, sort = TRUE)

sta_detail_summary <- all_data %>%
  dplyr::filter(Cat_norm == "STA") %>%
  dplyr::count(Beh_norm, Behavior, sort = TRUE)

name_summary <- all_data %>%
  dplyr::count(Name, Behavior, sort = TRUE)

cat("\n==============================\n")
cat("Mapping summary\n")
cat("==============================\n")
cat("Rows total: ", nrow(all_data), "\n", sep = "")
cat("Mapped rows: ", mapped_rows, "\n", sep = "")
cat("Mapped percent: ", mapped_pct, "%\n", sep = "")
cat("Missing DateTime: ", missing_dt, "\n", sep = "")

if (nrow(unmapped_cat) > 0) {
  cat("\nStill unmapped cat_codes:\n")
  print(unmapped_cat)
} else {
  cat("\nAll cat_codes mapped successfully.\n")
}

if (nrow(unmapped_beh) > 0) {
  cat("\nStill unmapped beh_codes:\n")
  print(unmapped_beh)
} else {
  cat("\nAll relevant beh_codes mapped successfully.\n")
}

cat("\n==============================\n")
cat("Behavior class sizes\n")
cat("==============================\n")
print(class_stats)

cat("\n==============================\n")
cat("cat_code -> Behavior check\n")
cat("==============================\n")
print(cat_summary)

cat("\n==============================\n")
cat("STA split by beh_code\n")
cat("==============================\n")
print(sta_detail_summary)

cat("\n==============================\n")
cat("Name x Behavior check\n")
cat("==============================\n")
print(name_summary)

# export
parquet_data <- all_data %>%
  dplyr::select(`Individual ID`, Species, Name, DateTime, X, Y, Z, Behavior)

arrow::write_parquet(parquet_data, out_file)

cat("\n==============================\n")
cat("Export finished\n")
cat("==============================\n")
cat("Saved to: ", out_file, "\n", sep = "")

# read back parquet
parquet_check <- arrow::read_parquet(out_file)

cat("\n==============================\n")
cat("Parquet check\n")
cat("==============================\n")
cat("Rows parquet: ", nrow(parquet_check), "\n", sep = "")
cat("Cols parquet: ", ncol(parquet_check), "\n", sep = "")
cat("Missing Behavior parquet: ", sum(is.na(parquet_check$Behavior)), "\n", sep = "")
cat("Missing DateTime parquet: ", sum(is.na(parquet_check$DateTime)), "\n", sep = "")

cat("\n==============================\n")
cat("First 5 rows of exported parquet\n")
cat("==============================\n")
print(head(parquet_check, 5))

cat("\n==============================\n")
cat("Behavior counts in parquet\n")
cat("==============================\n")
print(parquet_check %>% dplyr::count(Behavior, sort = TRUE))