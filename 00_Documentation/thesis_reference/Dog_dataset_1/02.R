# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(dplyr, stringr, arrow, tibble)

# paths
dir_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Dog/Dataset_1/Data_Dog_Raw"
out_dir  <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Dog/Dataset_1/Data_Dog_Proccessed"
out_file <- file.path(out_dir, "Dog_dataset_1.parquet")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# behavior mapping
behavior_map <- c(
  SIT = "Resting",
  LIG = "Resting",
  STE = "Resting",
  GEH = "Locomotion",
  REN = "Locomotion",
  SPR = "Locomotion",
  KNA = "Foraging",
  SCH = "Foraging",
  BUD = "Other"
)

# read txt with auto separator
read_txt_auto <- function(file) {
  seps <- c("\t", ";", ",", "")
  
  for (sep in seps) {
    x <- tryCatch(
      read.table(
        file,
        header = TRUE,
        sep = sep,
        stringsAsFactors = FALSE,
        fill = TRUE,
        quote = "",
        comment.char = "",
        check.names = FALSE
      ),
      error = function(e) NULL
    )
    
    if (!is.null(x) && ncol(x) >= 8) {
      return(x)
    }
  }
  
  return(NULL)
}

# normalize dates
normalize_date <- function(x) {
  x <- stringr::str_trim(as.character(x))
  as.Date(x, format = "%d.%m.%Y")
}

# process one txt file
process_data_file <- function(df, file_name) {
  id_col <- dplyr::case_when(
    "Nummer" %in% names(df) ~ "Nummer",
    "Burst"  %in% names(df) ~ "Burst",
    TRUE ~ NA_character_
  )
  
  required_cols <- c(id_col, "Datum", "Zeit", "x", "y", "z", "Tier", "Verhalten")
  
  if (is.na(id_col) || !all(required_cols %in% names(df))) {
    message("Skipping file with missing columns: ", file_name)
    return(NULL)
  }
  
  df <- df %>%
    dplyr::select(
      dplyr::all_of(id_col),
      Datum,
      Zeit,
      x,
      y,
      z,
      Tier,
      Verhalten
    ) %>%
    dplyr::rename(
      ID = dplyr::all_of(id_col),
      Behavior_raw = Verhalten
    )
  
  date_part <- normalize_date(df$Datum)
  time_part <- stringr::str_trim(as.character(df$Zeit))
  
  datetime <- as.POSIXct(
    paste(date_part, time_part),
    format = "%Y-%m-%d %H:%M:%S",
    tz = "UTC"
  )
  
  behavior_norm <- toupper(stringr::str_trim(as.character(df$Behavior_raw)))
  behavior <- unname(behavior_map[behavior_norm])
  
  tibble::tibble(
    `Individual ID` = suppressWarnings(as.integer(df$ID)),
    Species         = "Canis lupus familiaris",
    Name            = stringr::str_trim(as.character(df$Tier)),
    DateTime        = datetime,
    X               = suppressWarnings(as.numeric(df$x)),
    Y               = suppressWarnings(as.numeric(df$y)),
    Z               = suppressWarnings(as.numeric(df$z)),
    Behavior        = behavior,
    Behavior_raw    = df$Behavior_raw,
    Source_file     = file_name
  )
}

# read files
txt_files <- list.files(dir_path, pattern = "\\.txt$", full.names = TRUE)

all_data <- lapply(txt_files, function(file) {
  file_name <- basename(file)
  x <- read_txt_auto(file)
  
  if (is.null(x)) {
    message("Skipping unreadable file: ", file_name)
    return(NULL)
  }
  
  process_data_file(x, file_name)
})

all_data <- dplyr::bind_rows(all_data)

if (nrow(all_data) == 0) {
  stop("No valid txt files were processed.")
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