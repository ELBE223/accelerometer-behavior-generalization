# install/load packages
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(readxl, dplyr, stringr, arrow, tibble)

# paths
in_dir   <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Raccoon/Dataset_2/Data_Raccoon_Raw"
out_dir  <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Raccoon/Dataset_2/Data_Raccoon_Proccessed"
out_file <- file.path(out_dir, "Raccoon_dataset_2.parquet")

# timezone
tz_out <- "UTC"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# 4 target classes
behavior_codes <- list(
  Locomotion = c(
    "L", "G", "K", "H",
    "Laufen", "Galopp", "Klettern Kopf oben", "Hängen"
  ),
  Resting = c(
    "S", "R", "ST", "SI",
    "Schlafen", "Ruhen", "Stehen", "Sitzen"
  ),
  Foraging = c(
    "E", "SCH", "SCHW",
    "Essen", "Schaben Land", "Schaben Wasser"
  ),
  Other = c(
    "P", "PG", "SU", "SUE",
    "Putzen", "Putzen Gegenseitig", "Schütteln", "Schuetteln",  
    "LT", "U", "EW", "KKU", "KS", "HD", "KR", "KAL", "AST",
    "Laufen Tür", "Urinieren", "Essen Wasser",
    "Klettern Kopf unten", "Klettern Seitlich",
    "Hängen Decke", "Kratzen", "Kratzen am Logger",
    "Auf zwei Beinen stehen"
  )
)

# official exclusions from the PDF # not used!
exclude_codes_official <- c(
 
)

# extra exclusions for your 4-class version
exclude_codes_extra <- c(
  "SWI", "Schwimmen",
  "L/St", "LST"
)

# normalize labels/codes
normalize_code <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x[x == ""] <- NA_character_
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
  x <- toupper(x)
  x <- gsub("[_\\-]+", " ", x)
  x <- gsub("[^A-Z0-9 /]", "", x)
  x <- gsub("/", "", x)
  x <- gsub("\\s+", " ", x)
  x <- trimws(x)
  x[nchar(x) == 0] <- NA_character_
  x
}

# normalize exclusion lists
exclude_codes_official <- normalize_code(exclude_codes_official)
exclude_codes_extra    <- normalize_code(exclude_codes_extra)

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

# helper for empty checks
is_empty_value <- function(x) {
  y <- trimws(as.character(x))
  is.na(x) | y == ""
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
  
  out <- stringr::str_extract(x, "\\b\\d{1,2}:\\d{2}(:\\d{2})?\\b")
  out <- ifelse(!is.na(out) & grepl("^\\d{1,2}:\\d{2}$", out), paste0(out, ":00"), out)
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

# read files
xlsx_files <- list.files(
  path = in_dir,
  pattern = "\\.xlsx$",
  full.names = TRUE
)

if (length(xlsx_files) == 0) {
  stop("No xlsx files found in input folder.")
}

# process one file
process_file <- function(file_path) {
  sheet_name <- readxl::excel_sheets(file_path)[1]
  
  x <- readxl::read_excel(
    file_path,
    sheet = sheet_name,
    .name_repair = "minimal"
  )
  
  n_excel_rows <- nrow(x)
  
  col_id   <- find_col(x, c("ID", "Nummer", "Number"))
  col_date <- find_col(x, c("Datum", "Date"))
  col_time <- find_col(x, c("Uhrzeit", "Zeit", "Time"))
  col_x    <- find_col(x, c("X", "x"))
  col_y    <- find_col(x, c("Y", "y"))
  col_z    <- find_col(x, c("Z", "z"))
  col_name <- find_col(x, c("Tiername", "Tier", "Name"))
  col_code <- find_col(x, c("Verhalten_Code", "Verhalten", "Code"))
  
  required_found <- c(col_id, col_date, col_time, col_x, col_y, col_z, col_name, col_code)
  if (any(is.na(required_found))) {
    stop(
      paste0(
        "Missing required columns in file: ", basename(file_path),
        " | Found: ",
        paste(required_found, collapse = ", ")
      )
    )
  }
  
  raw_data <- tibble::tibble(
    ID          = x[[col_id]],
    Date        = x[[col_date]],
    Time        = x[[col_time]],
    X           = x[[col_x]],
    Y           = x[[col_y]],
    Z           = x[[col_z]],
    Name        = x[[col_name]],
    Code        = x[[col_code]],
    Source_file = basename(file_path)
  )
  
  # drop pseudo-empty rows
  junk_row <- is_empty_value(raw_data$ID) &
    is_empty_value(raw_data$Date) &
    is_empty_value(raw_data$Time) &
    is_empty_value(raw_data$X) &
    is_empty_value(raw_data$Y) &
    is_empty_value(raw_data$Z) &
    is_empty_value(raw_data$Code)
  
  n_junk_rows <- sum(junk_row)
  raw_data <- raw_data[!junk_row, , drop = FALSE]
  
  date_only <- parse_date_col(raw_data$Date)
  time_only <- parse_time_col(raw_data$Time)
  datetime  <- build_datetime(date_only, time_only, tz = tz_out)
  
  code_raw  <- as.character(raw_data$Code)
  code_norm <- normalize_code(code_raw)
  behavior  <- unname(behavior_map[code_norm])
  
  removal_reason <- dplyr::case_when(
    is.na(code_norm) ~ "Missing_code",
    code_norm %in% exclude_codes_official ~ "Excluded_official",
    code_norm %in% exclude_codes_extra ~ "Excluded_extra",
    is.na(behavior) ~ "Unmapped_code",
    TRUE ~ "Kept"
  )
  
  out_data <- tibble::tibble(
    `Individual ID` = suppressWarnings(as.integer(as.character(raw_data$ID))),
    Species         = "Procyon lotor",
    Name            = stringr::str_trim(as.character(raw_data$Name)),
    DateTime        = datetime,
    X               = suppressWarnings(as.numeric(raw_data$X)),
    Y               = suppressWarnings(as.numeric(raw_data$Y)),
    Z               = suppressWarnings(as.numeric(raw_data$Z)),
    Behavior        = behavior,
    Code            = code_raw,
    Code_norm       = code_norm,
    Removal_reason  = removal_reason,
    Source_file     = raw_data$Source_file
  )
  
  out_stats <- tibble::tibble(
    Source_file           = basename(file_path),
    Excel_rows_read       = n_excel_rows,
    Junk_rows_removed     = n_junk_rows,
    Rows_after_junk_filter = nrow(raw_data)
  )
  
  list(data = out_data, stats = out_stats)
}

# process all files
results <- lapply(xlsx_files, process_file)

all_data <- dplyr::bind_rows(lapply(results, function(x) x$data))
file_import_stats <- dplyr::bind_rows(lapply(results, function(x) x$stats))

if (nrow(all_data) == 0) {
  stop("No valid rows were processed after junk-row filtering.")
}

# summaries
raw_behavior_values <- all_data %>%
  dplyr::count(Code, Code_norm, sort = TRUE)

removal_by_reason <- all_data %>%
  dplyr::count(Removal_reason, name = "n") %>%
  dplyr::mutate(percent_of_rows_after_junk = round(100 * n / sum(n), 2)) %>%
  dplyr::arrange(desc(n))

removed_code_values <- all_data %>%
  dplyr::filter(Removal_reason != "Kept") %>%
  dplyr::count(Removal_reason, Code, Code_norm, sort = TRUE)

mapped_data <- all_data %>%
  dplyr::filter(Removal_reason == "Kept")

if (nrow(mapped_data) == 0) {
  stop("No rows left after filtering.")
}

class_stats <- mapped_data %>%
  dplyr::count(Behavior, name = "n") %>%
  dplyr::mutate(percent_of_export = round(100 * n / sum(n), 2)) %>%
  dplyr::arrange(desc(n))

file_final_stats <- all_data %>%
  dplyr::group_by(Source_file) %>%
  dplyr::summarise(
    Exported_rows        = sum(Removal_reason == "Kept"),
    Removed_official     = sum(Removal_reason == "Excluded_official"),
    Removed_extra        = sum(Removal_reason == "Excluded_extra"),
    Removed_missing_code = sum(Removal_reason == "Missing_code"),
    Removed_unmapped     = sum(Removal_reason == "Unmapped_code"),
    .groups = "drop"
  ) %>%
  dplyr::left_join(file_import_stats, by = "Source_file") %>%
  dplyr::select(
    Source_file,
    Excel_rows_read,
    Junk_rows_removed,
    Rows_after_junk_filter,
    Exported_rows,
    Removed_official,
    Removed_extra,
    Removed_missing_code,
    Removed_unmapped
  ) %>%
  dplyr::mutate(
    Exported_pct_of_excel = round(100 * Exported_rows / Excel_rows_read, 2),
    Exported_pct_after_junk = round(100 * Exported_rows / Rows_after_junk_filter, 2)
  )

# total summary
total_excel_rows       <- sum(file_import_stats$Excel_rows_read)
total_junk_removed     <- sum(file_import_stats$Junk_rows_removed)
total_after_junk       <- nrow(all_data)
total_removed_official <- sum(all_data$Removal_reason == "Excluded_official")
total_removed_extra    <- sum(all_data$Removal_reason == "Excluded_extra")
total_removed_missing  <- sum(all_data$Removal_reason == "Missing_code")
total_removed_unmapped <- sum(all_data$Removal_reason == "Unmapped_code")
total_exported         <- nrow(mapped_data)
total_removed_all      <- total_excel_rows - total_exported

summary_table <- tibble::tibble(
  Step = c(
    "Excel rows read",
    "Junk rows removed",
    "Rows after junk filter",
    "Removed official exclusions",
    "Removed extra exclusions",
    "Removed missing code",
    "Removed unmapped code",
    "Rows exported",
    "Rows removed total"
  ),
  n = c(
    total_excel_rows,
    total_junk_removed,
    total_after_junk,
    total_removed_official,
    total_removed_extra,
    total_removed_missing,
    total_removed_unmapped,
    total_exported,
    total_removed_all
  )
) %>%
  dplyr::mutate(
    pct_of_excel = round(100 * n / total_excel_rows, 2)
  )

# console output
cat("\n==============================\n")
cat("Input files\n")
cat("==============================\n")
print(xlsx_files)

cat("\n==============================\n")
cat("Rows per file\n")
cat("==============================\n")
print(file_final_stats, n = Inf)

cat("\n==============================\n")
cat("DateTime check\n")
cat("==============================\n")
print(head(all_data %>% dplyr::select(`Individual ID`, Name, DateTime, Code, Behavior, Removal_reason, Source_file), 10))

cat("\n==============================\n")
cat("Removal summary by reason\n")
cat("==============================\n")
print(removal_by_reason, n = Inf)

cat("\n==============================\n")
cat("Raw behavior values after junk filter\n")
cat("==============================\n")
print(raw_behavior_values, n = Inf)

cat("\n==============================\n")
cat("Global summary\n")
cat("==============================\n")
print(summary_table, n = Inf)

cat("\n==============================\n")
cat("Removed code values\n")
cat("==============================\n")
print(removed_code_values, n = Inf)

cat("\n==============================\n")
cat("Behavior class sizes\n")
cat("==============================\n")
print(class_stats, n = Inf)

# export
parquet_data <- mapped_data %>%
  dplyr::select(`Individual ID`, Species, Name, DateTime, X, Y, Z, Behavior)

arrow::write_parquet(parquet_data, out_file)

cat("\n==============================\n")
cat("Export finished\n")
cat("==============================\n")
cat("Saved to: ", out_file, "\n", sep = "")
cat("Exported rows: ", total_exported, "\n", sep = "")
cat("Exported percent of Excel rows: ", round(100 * total_exported / total_excel_rows, 2), "%\n", sep = "")
cat("Exported percent after junk filter: ", round(100 * total_exported / total_after_junk, 2), "%\n", sep = "")

# read back parquet
parquet_check <- arrow::read_parquet(out_file)

cat("\n==============================\n")
cat("First 5 rows of exported parquet\n")
cat("==============================\n")
print(head(parquet_check, 5))