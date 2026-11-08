library(readxl)

folder_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Raccoon/Dataset_2/Data_Raccoon_Raw"

xlsx_files <- list.files(
  path = folder_path,
  pattern = "\\.xlsx$",
  full.names = TRUE
)

print(xlsx_files)

data_list <- lapply(xlsx_files, read_excel)

names(data_list) <- basename(xlsx_files)

for (i in seq_along(data_list)) {
  cat("\n==============================\n")
  cat("File:", names(data_list)[i], "\n")
  cat("==============================\n")
  
  cat("\nStructure:\n")
  str(data_list[[i]])
  
  cat("\nFirst 5 rows:\n")
  print(head(data_list[[i]], 5))
}