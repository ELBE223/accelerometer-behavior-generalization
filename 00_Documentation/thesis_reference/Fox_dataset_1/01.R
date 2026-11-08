library(readxl)

dir_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Fox/Dataset_1/Data_Fox_Raw"

xlsx_files <- list.files(dir_path, pattern = "\\.xlsx$", full.names = TRUE)

all_data <- list()

for (file in xlsx_files) {
  file_name <- basename(file)
  sheet_names <- excel_sheets(file)
  
  all_data[[file_name]] <- lapply(sheet_names, function(sheet) {
    read_excel(file, sheet = sheet, range = cell_cols("A:M"))
  })
  
  names(all_data[[file_name]]) <- sheet_names
}

for (file_name in names(all_data)) {
  cat("\n############################################\n")
  cat("File:", file_name, "\n")
  cat("############################################\n")
  
  for (sheet in names(all_data[[file_name]])) {
    cat("\n==============================\n")
    cat("Sheet:", sheet, "\n")
    cat("==============================\n")
    
    str(all_data[[file_name]][[sheet]])
    cat("\nFirst 5 rows:\n")
    print(head(all_data[[file_name]][[sheet]], 5))
  }
}