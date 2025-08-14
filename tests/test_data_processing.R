#!/usr/bin/env Rscript

# Simple test to verify data processing works

library(here)
library(neuro2)

cat("Testing data processing from raw CSV files...\n")
cat("============================================\n\n")

# Check if we're running in a test environment
is_test_env <- function() {
  # During R CMD check, the working directory is different
  # and data-raw might not be accessible
  !file.exists("data-raw/csv")
}

# Check raw CSV files
cat("Checking raw CSV files in data-raw/csv/:\n")
if (is_test_env()) {
  cat("  [SKIPPED] Running in test environment, skipping CSV file check\n")
} else {
  csv_files <- list.files("data-raw/csv", pattern = "\\.csv$", full.names = TRUE)
  if (length(csv_files) > 0) {
    for (f in csv_files) {
      cat("  ✓", basename(f), "\n")
    }
  } else {
    warning("No CSV files found in data-raw/csv/")
  }
}

cat("\nProcessing files...\n")

if (is_test_env()) {
  cat("  [SKIPPED] Running in test environment, skipping data processing\n")
} else {
  # Process files and WRITE them (return_data = FALSE)
  tryCatch(
    {
      # Create a temporary directory for test output
      temp_dir <- tempfile("neuro2_test_")
      dir.create(temp_dir, recursive = TRUE)

      # Process files to temporary directory
      load_data_duckdb(
        file_path = "data-raw/csv",
        output_dir = temp_dir,
        return_data = FALSE, # This will write files
        use_duckdb = TRUE,
        output_format = "all" # Generate CSV, Parquet, and Arrow formats
      )

      cat("\n✓ Processing complete!\n")

      # Check what was created
      cat("\nChecking created files in temporary directory:\n")
      created_files <- list.files(
        temp_dir,
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

      # Clean up temporary directory
      unlink(temp_dir, recursive = TRUE)
    },
    error = function(e) {
      cat("\n✗ Error:", e$message, "\n")
      warning("Failed to process files")
    }
  )
}

cat("\nDone!\n")
