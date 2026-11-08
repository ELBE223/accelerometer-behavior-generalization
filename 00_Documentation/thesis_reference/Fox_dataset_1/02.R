# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(readxl, dplyr, stringr, arrow, tibble)

# paths
dir_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Fox/Dataset_1/Data_Fox_Raw"
out_dir  <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Fox/Dataset_1/Data_Fox_Proccessed"
out_file <- file.path(out_dir, "Fox_dataset_1.parquet")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# behavior mapping
behavior_map <- c(
  WALKING  = "Locomotion",
  TROTTING = "Locomotion",
  RESTING  = "Resting",
  FORAGING = "Foraging",
  DIGGING  = "Foraging",
  STOCKING = "Foraging",
  DRINKING = "Foraging",
  GROOMING = "Other"
)

# normalize dates
normalize_date <- function(x) {
  if (inherits(x, "POSIXt")) return(as.Date(x))
  if (inherits(x, "Date")) return(x)
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))
  as.Date(x)
}

# process one data sheet
process_data_sheet <- function(df, file_name) {
  df <- df %>%
    dplyr::select(
      ID,
      Datum,
      Uhrzeit,
      X,
      Y,
      Z,
      Tier,
      Verhalten_ueberkategorie
    ) %>%
    dplyr::rename(Behavior_raw = Verhalten_ueberkategorie)
  
  date_part <- normalize_date(df$Datum)
  time_part <- stringr::str_trim(as.character(df$Uhrzeit))
  
  datetime <- as.POSIXct(
    paste(date_part, time_part),
    format = "%Y-%m-%d %H:%M:%S",
    tz = "UTC"
  )
  
  behavior_norm <- toupper(stringr::str_trim(as.character(df$Behavior_raw)))
  behavior <- unname(behavior_map[behavior_norm])
  
  tibble::tibble(
    `Individual ID` = suppressWarnings(as.integer(df$ID)),
    Species         = "Vulpes vulpes",
    Name            = stringr::str_trim(as.character(df$Tier)),
    DateTime        = datetime,
    X               = suppressWarnings(as.numeric(df$X)),
    Y               = suppressWarnings(as.numeric(df$Y)),
    Z               = suppressWarnings(as.numeric(df$Z)),
    Behavior        = behavior,
    Behavior_raw    = df$Behavior_raw,
    Source_file     = file_name
  )
}

# read files
xlsx_files <- list.files(dir_path, pattern = "\\.xlsx$", full.names = TRUE)

all_data <- lapply(xlsx_files, function(file) {
  file_name <- basename(file)
  sheet_names <- readxl::excel_sheets(file)
  
  if (!"data" %in% sheet_names) {
    message("Skipping file without 'data' sheet: ", file_name)
    return(NULL)
  }
  
  x <- readxl::read_excel(
    file,
    sheet = "data",
    range = readxl::cell_cols("A:M")
  )
  
  required_cols <- c(
    "ID", "Datum", "Uhrzeit", "X", "Y", "Z", "Tier", "Verhalten_ueberkategorie"
  )
  
  if (!all(required_cols %in% names(x))) {
    message("Skipping file with missing columns: ", file_name)
    return(NULL)
  }
  
  process_data_sheet(x, file_name)
})

all_data <- dplyr::bind_rows(all_data)

if (nrow(all_data) == 0) {
  stop("No valid data sheets were processed.")
}

# mapping summary
mapped_rows <- sum(!is.na(all_data$Behavior))
mapped_pct  <- round(100 * mapped_rows / nrow(all_data), 2)

unmapped_behaviors <- all_data %>%
  dplyr::filter(is.na(Behavior), !is.na(Behavior_raw)) %>%
  dplyr::count(Behavior_raw, sort = TRUE)

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

if (nrow(unmapped_behaviors) > 0) {
  cat("\nStill unmapped behaviors:\n")
  print(unmapped_behaviors)
} else {
  cat("\nAll behaviors mapped successfully.\n")
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