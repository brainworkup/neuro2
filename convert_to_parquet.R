#!/usr/bin/env Rscript

# Convert CSV files to Parquet format
library(arrow)
library(readr)
library(here)

cat("Converting CSV files to Parquet format...\n")

# List of expected data files
data_files <- c("neurocog", "neurobehav", "validity")
data_dir <- here::here("data")

for (basename in data_files) {
  csv_file <- file.path(data_dir, paste0(basename, ".csv"))
  parquet_file <- file.path(data_dir, paste0(basename, ".parquet"))
  
  if (file.exists(csv_file)) {
    cat("Converting", csv_file, "to parquet...\n")
    
    tryCatch({
      # Read CSV
      data <- read_csv(csv_file, show_col_types = FALSE)
      
      # Write as parquet
      write_parquet(data, parquet_file)
      
      cat("  ✅ Created", parquet_file, "\n")
    }, error = function(e) {
      cat("  ❌ Error:", e$message, "\n")
    })
  } else {
    cat("  ⚠️ No CSV file found:", csv_file, "\n")
  }
}

cat("\nConversion complete!\n")