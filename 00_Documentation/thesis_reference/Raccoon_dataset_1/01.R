library(readxl)

file_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Raccoon/Dataset_1/Data_Raccoon_Raw/Raccoon_dataset_1.xlsx"

sheet_names <- excel_sheets(file_path)[1]

data_list <- lapply(sheet_names, function(sheet) {
  read_excel(file_path, sheet = sheet, range = cell_cols("A:K"))
})

names(data_list) <- sheet_names

for (sheet in sheet_names) {
  cat("\n==============================\n")
  cat("Sheet:", sheet, "\n")
  cat("==============================\n")
  
  str(data_list[[sheet]])
  cat("\nFirst 5 rows:\n")
  print(head(data_list[[sheet]], 5))
}