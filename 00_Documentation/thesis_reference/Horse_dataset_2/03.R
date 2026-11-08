if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(arrow, dplyr, tibble)

in_dir  <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_2/Data_Horse_Proccessed"
out_dir <- file.path(in_dir, "transformed_counts_12bit_pm8g")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

to_sensor_counts_12bit_pm8g <- function(x_ms2) {
  g <- as.numeric(x_ms2) / 9.80665
  y <- round(((g + 8) / 16) * 4095)
  y <- pmax(0L, pmin(4095L, y))
  as.integer(y)
}

parquet_files <- list.files(
  path = in_dir,
  pattern = "\\.parquet$",
  full.names = TRUE,
  ignore.case = TRUE
)

parquet_files <- parquet_files[
  grepl("^Horse_dataset_2_.*\\.parquet$", basename(parquet_files)) &
    !grepl("export_summary|mapping_check", basename(parquet_files), ignore.case = TRUE)
]

if (length(parquet_files) == 0) stop("No horse parquet files found.")

for (file in parquet_files) {
  cat("\n==================================================\n")
  cat("Processing:", basename(file), "\n")
  cat("==================================================\n")
  
  df <- arrow::read_parquet(file) %>%
    tibble::as_tibble()
  
  df_new <- df %>%
    dplyr::mutate(
      X = to_sensor_counts_12bit_pm8g(X),
      Y = to_sensor_counts_12bit_pm8g(Y),
      Z = to_sensor_counts_12bit_pm8g(Z)
    )
  
  out_file <- file.path(
    out_dir,
    sub("\\.parquet$", "_12bit_pm8g.parquet", basename(file), ignore.case = TRUE)
  )
  
  arrow::write_parquet(df_new, out_file)
  
  cat("\n--- SUMMARY ---\n")
  print(
    df_new %>%
      dplyr::summarise(
        X_min = min(X, na.rm = TRUE),
        X_max = max(X, na.rm = TRUE),
        Y_min = min(Y, na.rm = TRUE),
        Y_max = max(Y, na.rm = TRUE),
        Z_min = min(Z, na.rm = TRUE),
        Z_max = max(Z, na.rm = TRUE)
      )
  )
  
  cat("\n--- FIRST 5 ROWS ---\n")
  print(head(df_new, 5))
  
  cat("\nSaved to:", out_file, "\n")
}