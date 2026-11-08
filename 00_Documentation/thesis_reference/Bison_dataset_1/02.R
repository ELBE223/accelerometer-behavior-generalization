# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(readxl, dplyr, stringr, arrow, cellranger, tibble)

# paths
file_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Bison/Data_Bison_Raw/Wisent_Daten_gesamt.xlsx"
out_dir   <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Bison/Data_Bison_Proccessed"
out_file  <- file.path(out_dir, "Bison.parquet")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# behavior mapping
behavior_map <- c(
  SCH = "Locomotion",
  TRB = "Locomotion",
  GAL = "Locomotion",
  
  SKO = "Resting",
  SKM = "Resting",
  SKN = "Resting",
  SSA = "Resting",
  LIO = "Resting",
  LIN = "Resting",
  LWO = "Resting",
  LWN = "Resting",
  LSA = "Resting",
  LIT = "Resting",
  SWK = "Resting",
  STL = "Resting",
  LPN = "Resting",
  
  FSG = "Foraging",
  FSO = "Foraging",
  FSM = "Foraging",
  FST = "Foraging",
  FVB = "Foraging",
  KKO = "Foraging",
  KKM = "Foraging",
  KKN = "Foraging",
  TRK = "Foraging",
  GRA = "Foraging",
  RSG = "Foraging",
  RSH = "Foraging",
  HFO = "Foraging",
  HFM = "Foraging",
  HFT = "Foraging",
  HFN = "Foraging",
  FSN = "Foraging",
  FSH = "Foraging",
  
  KAM = "Other",
  PUT = "Other",
  SAB = "Other",
  WAL = "Other",
  SPU = "Other"
)

required_cols <- c("ID", "Datum", "Zeit", "X", "Y", "Z", "Code")

# find header row
find_header_skip <- function(path, sheet, max_check_rows = 10) {
  preview <- readxl::read_excel(
    path,
    sheet = sheet,
    range = cellranger::cell_cols("A:M"),
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
    range = cellranger::cell_cols("A:M"),
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
    Species         = "Bison bonasus",
    Name            = stringr::str_trim(stringr::str_remove(sheet, "\\s+\\d+$")),
    DateTime        = datetime,
    X               = as.numeric(x$X),
    Y               = as.numeric(x$Y),
    Z               = as.numeric(x$Z),
    Behavior        = behavior,
    Code            = code_raw,
    Code_norm       = code_norm
  )
}

# read sheets
sheet_names <- readxl::excel_sheets(file_path)
all_data <- dplyr::bind_rows(lapply(sheet_names, process_sheet, path = file_path))

if (nrow(all_data) == 0) {
  stop("No valid sheets were processed.")
}

# mapping summary
mapped_rows <- sum(!is.na(all_data$Behavior))
mapped_pct  <- round(100 * mapped_rows / nrow(all_data), 2)

unmapped_codes <- all_data %>%
  dplyr::filter(is.na(Behavior), !is.na(Code_norm)) %>%
  dplyr::count(Code_norm, sort = TRUE)

class_stats <- all_data %>%
  dplyr::filter(!is.na(Behavior)) %>%
  dplyr::count(Behavior, name = "n") %>%
  dplyr::mutate(percent = round(100 * n / sum(n), 2)) %>%
  dplyr::arrange(desc(n))

cat("\n==============================\n")
cat("Mapping summary\n")
cat("==============================\n")
cat("Rows total: ", nrow(all_data), "\n", sep = "")
cat("Mapped rows: ", mapped_rows, "\n", sep = "")
cat("Mapped percent: ", mapped_pct, "%\n", sep = "")

if (nrow(unmapped_codes) > 0) {
  cat("\nStill unmapped codes:\n")
  print(unmapped_codes)
} else {
  cat("\nAll codes mapped successfully.\n")
}

cat("\n==============================\n")
cat("Behavior class sizes\n")
cat("==============================\n")
print(class_stats)

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
cat("First 5 rows of exported parquet\n")
cat("==============================\n")
print(head(parquet_check, 5))