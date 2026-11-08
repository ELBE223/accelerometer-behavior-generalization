# Folder path
data_dir <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Fox/Dataset_2/Data_Fox_Raw"

# Check folder
if (!dir.exists(data_dir)) stop("Folder not found: ", data_dir)

# Find all CSV files
csv_files <- list.files(
  path = data_dir,
  pattern = "\\.csv$",
  full.names = TRUE,
  ignore.case = TRUE
)

# Check files
if (length(csv_files) == 0) stop("No CSV files found in: ", data_dir)

# Load all CSV files into a list
data_list <- lapply(csv_files, function(f) {
  read.csv(f, stringsAsFactors = FALSE)
})

# Use file names as list names
names(data_list) <- tools::file_path_sans_ext(basename(csv_files))

# Show overview
cat("\n==================== FILE OVERVIEW ====================\n")
cat("Number of CSV files loaded:", length(data_list), "\n\n")
print(basename(csv_files))

# Show structure and first 3 rows for each file
for (i in seq_along(data_list)) {
  cat("\n======================================================\n")
  cat("FILE:", basename(csv_files[i]), "\n")
  cat("======================================================\n")
  
  str(data_list[[i]])
  
  cat("\nFirst 3 rows:\n")
  print(head(data_list[[i]], 3))
}