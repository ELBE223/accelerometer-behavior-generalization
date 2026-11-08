dir_path <- "/Volumes/Z Slim/07_04_2026_Data_Analysis/Datasets_raw/Dog/Dataset_2/Data_Dog_Raw"

all_files <- list.files(
  path = dir_path,
  full.names = TRUE,
  recursive = FALSE,
  all.files = FALSE,
  no.. = TRUE
)

all_files <- all_files[!file.info(all_files)$isdir]

cat("Files found:", length(all_files), "\n")
print(basename(all_files))

read_txt_auto <- function(file) {
  seps <- c("\t", ";", ",", " ")
  
  for (sep in seps) {
    df <- tryCatch(
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
    
    if (!is.null(df) && ncol(df) > 1) {
      return(df)
    }
  }
  
  tryCatch(
    readLines(file, n = 3, warn = FALSE),
    error = function(e) paste("Could not read file as text:", basename(file))
  )
}

all_data <- list()

for (file in all_files) {
  file_name <- basename(file)
  all_data[[file_name]] <- read_txt_auto(file)
}

for (file_name in names(all_data)) {
  cat("\n############################################\n")
  cat("File:", file_name, "\n")
  cat("############################################\n")
  
  obj <- all_data[[file_name]]
  
  if (is.data.frame(obj)) {
    str(obj)
    cat("\nFirst 3 rows:\n")
    print(head(obj, 3))
  } else {
    cat("\nNo table detected. First 3 lines:\n")
    print(obj)
  }
}