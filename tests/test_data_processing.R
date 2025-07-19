#!/usr/bin/env Rscript

# Simple test to verify data processing works

library(here)
source("R/duckdb_neuropsych_loader.R")

cat("Testing data processing from raw CSV files...\n")
cat("============================================\n\n")

# Check raw CSV files
cat("Checking raw CSV files in data-raw/csv/:\n")
csv_files <- list.files("data-raw/csv", pattern = "\\.csv$", full.names = TRUE)
if (length(csv_files) > 0) {
  for (f in csv_files) {
    cat("  ✓", basename(f), "\n")
  }
} else {
  stop("No CSV files found in data-raw/csv/")
}

cat("\nProcessing files...\n")

# Process files and WRITE them (return_data = FALSE)
tryCatch(
  {
    load_data_duckdb(
      file_path = "data-raw/csv",
      output_dir = "data",
      return_data = FALSE, # This will write files
      use_duckdb = TRUE,
      output_format = "all" # Generate CSV, Parquet, and Arrow formats
    )

    cat("\n✓ Processing complete!\n")
  },
  error = function(e) {
    cat("\n✗ Error:", e$message, "\n")
    stop("Failed to process files")
  }
)

# Check what was created
cat("\nChecking created files in data/:\n")
created_files <- list.files(
  "data",
  pattern = "\\.(csv|parquet|feather)$",
  full.names = TRUE
)
if (length(created_files) > 0) {
  for (f in created_files) {
    size_kb <- file.info(f)$size / 1024
    cat(sprintf("  ✓ %s (%.1f KB)\n", basename(f), size_kb))
  }
} else {
  cat("  ✗ No files were created!\n")
}

cat("\nDone!\n")
