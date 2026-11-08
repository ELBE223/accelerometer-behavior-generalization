# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(readxl, dplyr, stringr, arrow, cellranger, tibble)

# paths
file_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_1/Data_Horse_Raw/Horse.xlsx"
out_dir   <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_1/Data_Horse_Proccessed"
out_file  <- file.path(out_dir, "Horse_dataset_1.parquet")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# required columns
required_cols <- c("ID", "Datum", "Zeit", "X", "Y", "Z", "Code")

# 4-class mapping
behavior_map <- c(
  KKN = "Foraging",
  KKM = "Foraging",
  KKO = "Foraging",
  FVB = "Foraging",
  GRA = "Foraging",
  HFN = "Foraging",
  HFM = "Foraging",
  HFT = "Foraging",
  HFO = "Foraging",
  
  SKN = "Resting",
  SKM = "Resting",
  SKO = "Resting",
  SLN = "Resting",
  LIN = "Resting",
  LIO = "Resting",
  STL = "Resting",
  
  SCH = "Locomotion",
  TRB = "Locomotion",
  GAL = "Locomotion",
  
  PUT = "Other",
  SAB = "Other",
  GFP = "Other",
  KOS = "Other",
  TRK = "Other",
  WAL = "Other"
)

# find header row
find_header_skip <- function(path, sheet, max_check_rows = 10) {
  preview <- readxl::read_excel(
    path,
    sheet = sheet,
    range = cellranger::cell_cols("A:L"),
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
  x <- gsub("[^A-Z]", "", x)
  
  x[nchar(x) == 0] <- NA_character_
  x
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
    range = cellranger::cell_cols("A:L"),
    skip = skip_n,
    .name_repair = "minimal"
  )
  
  if (!all(required_cols %in% names(x))) {
    message("Skipping sheet (missing required columns): ", sheet)
    return(NULL)
  }
  
  date_part <- as.Date(x$Datum)
  time_part <- format(x$Zeit, "%H:%M:%S")
  
  datetime <- as.POSIXct(
    paste(date_part, time_part),
    format = "%Y-%m-%d %H:%M:%S",
    tz = "UTC"
  )
  
  code_raw  <- as.character(x$Code)
  code_norm <- normalize_code(code_raw)
  behavior  <- unname(behavior_map[code_norm])
  
  tibble::tibble(
    `Individual ID` = as.integer(x$ID),
    Species         = "Equus ferus przewalskii",
    Name            = stringr::str_trim(stringr::str_remove(sheet, "\\s+\\d+.*$")),
    DateTime        = datetime,
    X               = as.numeric(x$X),
    Y               = as.numeric(x$Y),
    Z               = as.numeric(x$Z),
    Behavior        = behavior,
    Code            = code_raw,
    Code_norm       = code_norm,
    Source_sheet    = sheet
  )
}

# read sheets
sheet_names <- readxl::excel_sheets(file_path)[2:5]
all_data <- dplyr::bind_rows(lapply(sheet_names, process_sheet, path = file_path))

if (nrow(all_data) == 0) {
  stop("No valid sheets were processed.")
}

# report unmapped codes
unmapped_codes <- all_data %>%
  dplyr::filter(is.na(Behavior), !is.na(Code_norm)) %>%
  dplyr::count(Code_norm, sort = TRUE)

cat("\n==============================\n")
cat("Unmapped codes before export\n")
cat("==============================\n")

if (nrow(unmapped_codes) > 0) {
  print(unmapped_codes)
} else {
  cat("All codes mapped successfully.\n")
}

# keep only mapped rows
parquet_data <- all_data %>%
  dplyr::filter(!is.na(Behavior)) %>%
  dplyr::select(`Individual ID`, Species, Name, DateTime, X, Y, Z, Behavior)

if (nrow(parquet_data) == 0) {
  stop("No mapped rows available for parquet export.")
}

# class summary
class_stats <- parquet_data %>%
  dplyr::count(Behavior, name = "n") %>%
  dplyr::mutate(percent = round(100 * n / sum(n), 2)) %>%
  dplyr::arrange(desc(n))

cat("\n==============================\n")
cat("Export summary\n")
cat("==============================\n")
cat("Rows total: ", nrow(all_data), "\n", sep = "")
cat("Rows exported: ", nrow(parquet_data), "\n", sep = "")
cat("Rows removed: ", nrow(all_data) - nrow(parquet_data), "\n", sep = "")

cat("\n==============================\n")
cat("Behavior class sizes\n")
cat("==============================\n")
print(class_stats)

# export parquet
arrow::write_parquet(parquet_data, out_file)

cat("\n==============================\n")
cat("Export finished\n")
cat("==============================\n")
cat("Saved to: ", out_file, "\n", sep = "")

# read back parquet
parquet_check <- arrow::read_parquet(out_file)

cat("\n==============================\n")
cat("First 5 rows of exported parquet\n")
cat("==============================\n")
print(head(parquet_check, 5))