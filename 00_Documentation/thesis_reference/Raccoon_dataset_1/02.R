# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(readxl, dplyr, stringr, arrow, tibble)

# paths
file_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Raccoon/Dataset_1/Data_Raccoon_Raw/R-Daten_3.xlsx"
out_dir   <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Raccoon/Dataset_1/Data_Raccoon_Proccessed"
out_file  <- file.path(out_dir, "Raccoon_dataset_1.parquet")

# timezone
tz_out <- "UTC"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# behavior mapping
behavior_codes <- list(
  Locomotion = c(
    "KlHoH", "KlRuH", "KlRuN", "KlKÜ", "HaVP", "HaAP", "GaW", "GaG",
    "LaW", "LaG", "WGeH", "WGeN", "WGeT", "MGeT", "GGeH", "GGeN", "GGeT"
  ),
  Resting = c(
    "StH", "StN", "StT", "StB",
    "SiH", "SiN", "SiB",
    "LiABH", "LiLSH", "LiLSN", "LiRSH", "LiRSN",
    "LiLGH", "LiLGN", "LiRGH", "LiRGN", "LiAR"
  ),
  Foraging = c(
    "Su", "SuG", "SuHG", "SuM", "SuW",
    "StKH", "StKN", "StKB",
    "StFrBoT", "StFr", "StAHFrAPT", "StAHFr",
    "SiKH", "SiKN", "SiFr", "SiFrBoT", "SiFrAPT",
    "StHBWa", "SiWa"
  ),
  Other = c(
    "StKrHO", "StAHKr", "StAHKrT",
    "StAHPu", "SiPu", "LiPu",
    "StAHSteilH", "StHo",
    "Tob", "Schütt"
  )
)

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

# build lookup
behavior_map <- unlist(lapply(names(behavior_codes), function(class_name) {
  codes <- behavior_codes[[class_name]]
  stats::setNames(rep(class_name, length(codes)), normalize_code(codes))
}), use.names = TRUE)

# find matching column
find_col <- function(df, candidates) {
  nm <- names(df)
  idx <- match(tolower(candidates), tolower(nm))
  idx <- idx[!is.na(idx)]
  if (length(idx) == 0) return(NA_character_)
  nm[idx[1]]
}

# parse date
parse_date_col <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  
  if (is.numeric(x)) {
    return(as.Date(x, origin = "1899-12-30"))
  }
  
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  x <- sub("\\s+.*$", "", x)
  
  as.Date(x, tryFormats = c(
    "%d/%m/%y",
    "%d/%m/%Y",
    "%Y-%m-%d",
    "%d.%m.%Y",
    "%m/%d/%Y"
  ))
}

# parse time
parse_time_col <- function(x) {
  if (inherits(x, "POSIXt")) {
    return(format(x, "%H:%M:%S"))
  }
  
  if (is.numeric(x)) {
    secs <- round((x %% 1) * 86400)
    return(format(as.POSIXct(secs, origin = "1970-01-01", tz = "UTC"), "%H:%M:%S"))
  }
  
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  
  out <- stringr::str_extract(x, "\\b\\d{1,2}:\\d{2}:\\d{2}\\b")
  out
}

# build datetime
build_datetime <- function(date_vec, time_vec, tz = "UTC") {
  as.POSIXct(
    paste(date_vec, time_vec),
    format = "%Y-%m-%d %H:%M:%S",
    tz = tz
  )
}

# read first sheet
sheet_name <- readxl::excel_sheets(file_path)[1]

x <- readxl::read_excel(
  file_path,
  sheet = sheet_name,
  .name_repair = "minimal"
)

# detect columns
col_id   <- find_col(x, c("ID", "Nummer", "Number"))
col_tier <- find_col(x, c("Tier", "Name"))
col_date <- find_col(x, c("Datum", "Date"))
col_time <- find_col(x, c("Zeit", "Zeit_raw", "Time"))
col_x    <- find_col(x, c("X", "x"))
col_y    <- find_col(x, c("Y", "y"))
col_z    <- find_col(x, c("Z", "z"))
col_code <- find_col(x, c("Verhalten_Code", "Verhalten", "Code"))

required_found <- c(col_id, col_tier, col_date, col_time, col_x, col_y, col_z, col_code)
if (any(is.na(required_found))) {
  stop("Missing required columns after detection.")
}

# standardize input
raw_data <- tibble::tibble(
  ID   = x[[col_id]],
  Tier = x[[col_tier]],
  Date = x[[col_date]],
  Time = x[[col_time]],
  X    = x[[col_x]],
  Y    = x[[col_y]],
  Z    = x[[col_z]],
  Code = x[[col_code]]
)

# process data
date_only <- parse_date_col(raw_data$Date)
time_only <- parse_time_col(raw_data$Time)
datetime  <- build_datetime(date_only, time_only, tz = tz_out)

code_raw  <- as.character(raw_data$Code)
code_norm <- normalize_code(code_raw)
behavior  <- unname(behavior_map[code_norm])

all_data <- tibble::tibble(
  `Individual ID` = suppressWarnings(as.integer(raw_data$ID)),
  Species         = "Procyon lotor",
  Name            = stringr::str_trim(as.character(raw_data$Tier)),
  DateTime        = datetime,
  X               = as.numeric(raw_data$X),
  Y               = as.numeric(raw_data$Y),
  Z               = as.numeric(raw_data$Z),
  Behavior        = behavior,
  Code            = code_raw,
  Code_norm       = code_norm
)

if (nrow(all_data) == 0) {
  stop("No valid rows were processed.")
}

# mapping summary
mapped_rows <- sum(!is.na(all_data$Behavior))
mapped_pct  <- round(100 * mapped_rows / nrow(all_data), 2)

unmapped_codes <- all_data %>%
  dplyr::filter(is.na(Behavior), !is.na(Code_norm)) %>%
  dplyr::count(Code, Code_norm, sort = TRUE)

class_stats <- all_data %>%
  dplyr::filter(!is.na(Behavior)) %>%
  dplyr::count(Behavior, name = "n") %>%
  dplyr::mutate(percent = round(100 * n / sum(n), 2)) %>%
  dplyr::arrange(desc(n))

cat("\n==============================\n")
cat("Input check\n")
cat("==============================\n")
cat("Sheet: ", sheet_name, "\n", sep = "")
cat("ID column: ", col_id, "\n", sep = "")
cat("Tier column: ", col_tier, "\n", sep = "")
cat("Date column: ", col_date, "\n", sep = "")
cat("Time column: ", col_time, "\n", sep = "")
cat("X column: ", col_x, "\n", sep = "")
cat("Y column: ", col_y, "\n", sep = "")
cat("Z column: ", col_z, "\n", sep = "")
cat("Code column: ", col_code, "\n", sep = "")

cat("\n==============================\n")
cat("DateTime check\n")
cat("==============================\n")
print(head(all_data %>% dplyr::select(`Individual ID`, Name, DateTime, Code), 10))

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