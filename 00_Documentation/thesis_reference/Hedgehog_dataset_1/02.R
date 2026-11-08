# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(readxl, dplyr, stringr, arrow, cellranger, tibble)

# paths
file_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Hegehog/Data_Hegehog_Raw/Hedgehog.xlsx"
out_dir   <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Hegehog/Data_Hegehog_Proccessed"
out_file  <- file.path(out_dir, "Hedgehog.parquet")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# behavior groups
locomotion_labels <- c(
  "gehen", "laufend", "rennen", "rennend"
)

resting_labels <- c(
  "ruhend"
)

foraging_labels <- c(
  "schnuppert", "schnuppern", "fressen"
)

other_labels <- c(
  "eingekugelt",
  "zusammengekugelt",
  "kratzt sich",
  "schuttelt sich",
  "wird geschuttelt",
  "startshake",
  "endshake"
)

drop_labels <- c(
  "wird bewegt",
  "wird getragen"
)

required_cols <- c("ID", "Name", "Datum", "X", "Y", "Z", "Verhalten")

# find header row
find_header_skip <- function(path, sheet, max_check_rows = 10) {
  preview <- readxl::read_excel(
    path,
    sheet = sheet,
    range = cellranger::cell_cols("A:G"),
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

# normalize behavior text
normalize_behavior <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x[x == ""] <- NA_character_
  
  x <- tolower(x)
  
  # remove escape/backslash artifacts and quotes
  x <- gsub("\\\\", "", x)
  x <- gsub('"', "", x, fixed = TRUE)
  
  # transliterate umlauts etc.
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
  
  # normalize spaces
  x <- gsub("\\s+", " ", x)
  x <- trimws(x)
  
  x[nchar(x) == 0] <- NA_character_
  x
}

# convert datetime safely
normalize_datetime <- function(x) {
  if (inherits(x, "POSIXct")) return(x)
  
  if (inherits(x, "Date")) {
    return(as.POSIXct(x, tz = "UTC"))
  }
  
  if (is.numeric(x)) {
    return(as.POSIXct((x - 25569) * 86400, origin = "1970-01-01", tz = "UTC"))
  }
  
  as.POSIXct(x, tz = "UTC")
}

# map behavior
map_behavior <- function(x) {
  dplyr::case_when(
    x %in% locomotion_labels ~ "Locomotion",
    x %in% resting_labels    ~ "Resting",
    x %in% foraging_labels   ~ "Foraging",
    x %in% other_labels      ~ "Other",
    TRUE ~ NA_character_
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
    range = cellranger::cell_cols("A:G"),
    skip = skip_n,
    .name_repair = "minimal"
  )
  
  if (!all(required_cols %in% names(x))) {
    message("Skipping sheet (missing required columns): ", sheet)
    return(NULL)
  }
  
  x <- x %>%
    dplyr::select(dplyr::all_of(required_cols)) %>%
    dplyr::filter(!(is.na(ID) & is.na(Name) & is.na(Datum) & is.na(X) & is.na(Y) & is.na(Z) & is.na(Verhalten)))
  
  behavior_raw  <- as.character(x$Verhalten)
  behavior_norm <- normalize_behavior(behavior_raw)
  behavior_grp  <- map_behavior(behavior_norm)
  drop_flag     <- behavior_norm %in% drop_labels
  
  tibble::tibble(
    `Individual ID` = as.character(x$ID),
    Species         = "Erinaceus europaeus",
    Name            = as.character(x$Name),
    DateTime        = normalize_datetime(x$Datum),
    X               = as.numeric(x$X),
    Y               = as.numeric(x$Y),
    Z               = as.numeric(x$Z),
    Behavior        = behavior_grp,
    Behavior_raw    = behavior_raw,
    Behavior_norm   = behavior_norm,
    Drop_label      = drop_flag,
    Sheet           = sheet
  )
}

# read sheets
sheet_names <- readxl::excel_sheets(file_path)
all_data <- dplyr::bind_rows(lapply(sheet_names, process_sheet, path = file_path))

if (nrow(all_data) == 0) {
  stop("No valid sheets were processed.")
}

# summaries before filtering
drop_stats <- all_data %>%
  dplyr::filter(Drop_label, !is.na(Behavior_norm)) %>%
  dplyr::count(Behavior_norm, sort = TRUE)

unmapped_behaviors <- all_data %>%
  dplyr::filter(!Drop_label, is.na(Behavior), !is.na(Behavior_norm)) %>%
  dplyr::count(Behavior_norm, sort = TRUE)

# remove handling/artifact labels
all_data_clean <- all_data %>%
  dplyr::filter(!Drop_label)

mapped_rows <- sum(!is.na(all_data_clean$Behavior))
mapped_pct  <- round(100 * mapped_rows / nrow(all_data_clean), 2)

class_stats <- all_data_clean %>%
  dplyr::filter(!is.na(Behavior)) %>%
  dplyr::count(Behavior, name = "n") %>%
  dplyr::mutate(percent = round(100 * n / sum(n), 2)) %>%
  dplyr::arrange(desc(n))

cat("\n==============================\n")
cat("Data overview\n")
cat("==============================\n")
cat("Sheets processed: ", length(sheet_names), "\n", sep = "")
cat("Rows total (raw): ", nrow(all_data), "\n", sep = "")
cat("Rows after dropping handling labels: ", nrow(all_data_clean), "\n", sep = "")
cat("Unique IDs: ", dplyr::n_distinct(all_data_clean$`Individual ID`), "\n", sep = "")
cat("Unique names: ", dplyr::n_distinct(all_data_clean$Name), "\n", sep = "")
cat("Date range: ", format(min(all_data_clean$DateTime, na.rm = TRUE)), " -> ",
    format(max(all_data_clean$DateTime, na.rm = TRUE)), "\n", sep = "")

cat("\n==============================\n")
cat("Dropped labels\n")
cat("==============================\n")
if (nrow(drop_stats) > 0) {
  print(drop_stats)
} else {
  cat("No rows dropped.\n")
}

cat("\n==============================\n")
cat("Mapping summary\n")
cat("==============================\n")
cat("Mapped rows: ", mapped_rows, "\n", sep = "")
cat("Mapped percent: ", mapped_pct, "%\n", sep = "")

if (nrow(unmapped_behaviors) > 0) {
  cat("\nStill unmapped behaviors:\n")
  print(unmapped_behaviors)
} else {
  cat("\nAll remaining behaviors mapped successfully.\n")
}

cat("\n==============================\n")
cat("Behavior class sizes\n")
cat("==============================\n")
print(class_stats)

cat("\n==============================\n")
cat("First 5 rows\n")
cat("==============================\n")
print(head(all_data_clean, 5))

# export
parquet_data <- all_data_clean %>%
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