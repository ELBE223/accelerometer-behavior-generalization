library(arrow)

file_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Bison/Data_Bison_Proccessed/Bison.parquet"
backup_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Bison/Data_Bison_Proccessed/Bison_backup.parquet"

bison_df <- read_parquet(file_path)

# Backup
#file.copy(file_path, backup_path, overwrite = TRUE)

# Keep only valid names
bison_clean <- bison_df[bison_df$Name %in% c("Arena", "Döschi", "Flake"), ]

# Overwrite parquet
write_parquet(bison_clean, file_path)

# Check
bison_check <- read_parquet(file_path)
print(sort(unique(bison_check$Name)))
print(sort(table(bison_check$Name), decreasing = TRUE))