library(arrow)

# Set folder path
folder_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Horse/Dataset_2/Data_Horse_Raw"

# List all parquet files
parquet_files <- list.files(
  path = folder_path,
  pattern = "\\.parquet$",
  full.names = TRUE
)

# Check if files exist
if (length(parquet_files) == 0) {
  stop("No .parquet files found in the folder.")
}

# Read, inspect, and print first 3 rows
data_list <- list()

for (file in parquet_files) {
  cat("\n==============================\n")
  cat("File:", basename(file), "\n")
  cat("==============================\n")
  
  df <- read_parquet(file)
  data_list[[basename(file)]] <- df
  
  cat("\nStructure:\n")
  str(df)
  
  cat("\nFirst 3 rows:\n")
  print(head(df, 3))
}