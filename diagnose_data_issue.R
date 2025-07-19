#!/usr/bin/env Rscript

# Diagnostic script to check data processing issues

library(here)
library(duckdb)
library(DBI)
library(readr)
library(dplyr)

cat("=== Diagnostic Check for Data Processing ===\n\n")

# 1. Check raw CSV files
cat("1. Checking raw CSV files:\n")
csv_files <- list.files("data-raw/csv", pattern = "\\.csv$", full.names = TRUE)
if (length(csv_files) > 0) {
  for (f in csv_files) {
    # Try to read first few lines
    tryCatch(
      {
        df <- read_csv(f, n_max = 5, show_col_types = FALSE)
        cat(sprintf(
          "  ✓ %s (%d cols, %d rows sample)\n",
          basename(f),
          ncol(df),
          nrow(df)
        ))
      },
      error = function(e) {
        cat(sprintf("  ✗ %s - Error: %s\n", basename(f), e$message))
      }
    )
  }
} else {
  cat("  ✗ No CSV files found\n")
}

# 2. Test DuckDB processing manually
cat("\n2. Testing DuckDB processing:\n")

con <- DBI::dbConnect(duckdb::duckdb())

# Try to read one CSV file
if (length(csv_files) > 0) {
  test_file <- csv_files[1]
  cat("  Testing with:", basename(test_file), "\n")

  tryCatch(
    {
      # Read CSV
      query <- sprintf("SELECT * FROM read_csv_auto('%s')", test_file)
      df <- DBI::dbGetQuery(con, query)
      cat(sprintf("  ✓ Read %d rows, %d columns\n", nrow(df), ncol(df)))

      # Check column names
      cat("  Columns:", paste(head(names(df), 10), collapse = ", "))
      if (ncol(df) > 10) {
        cat("...")
      }
      cat("\n")

      # Check for test_type column
      if ("test_type" %in% names(df)) {
        test_types <- unique(df$test_type)
        cat("  Test types found:", paste(test_types, collapse = ", "), "\n")
      } else {
        cat("  ⚠ No 'test_type' column found - this might be the issue\n")
      }
    },
    error = function(e) {
      cat("  ✗ Error reading CSV:", e$message, "\n")
    }
  )
}

DBI::dbDisconnect(con, shutdown = TRUE)

# 3. Check if data directory exists
cat("\n3. Checking data directory:\n")
if (dir.exists("data")) {
  cat("  ✓ data/ directory exists\n")
  existing_files <- list.files("data")
  if (length(existing_files) > 0) {
    cat("  Existing files:", paste(existing_files, collapse = ", "), "\n")
  } else {
    cat("  Directory is empty\n")
  }
} else {
  cat("  ✗ data/ directory does not exist\n")
  cat("  Creating it now...\n")
  dir.create("data")
}

# 4. Try minimal processing
cat("\n4. Trying minimal data processing:\n")

# Read all CSVs and combine
all_data <- list()
for (i in seq_along(csv_files)) {
  file <- csv_files[i]
  tryCatch(
    {
      df <- read_csv(file, show_col_types = FALSE)
      df$filename <- basename(file)
      all_data[[i]] <- df
      cat("  ✓ Read", basename(file), "-", nrow(df), "rows\n")
    },
    error = function(e) {
      cat("  ✗ Error reading", basename(file), ":", e$message, "\n")
    }
  )
}

if (length(all_data) > 0) {
  # Combine all data
  combined_data <- bind_rows(all_data)
  cat(
    "\n  Combined data:",
    nrow(combined_data),
    "rows,",
    ncol(combined_data),
    "columns\n"
  )

  # Check what columns we have
  cat("  All columns:\n")
  cat("   ", paste(names(combined_data), collapse = ", "), "\n")

  # Try to save a simple CSV
  cat("\n  Trying to save combined data as CSV...\n")
  tryCatch(
    {
      write_csv(combined_data, "data/test_combined.csv")
      cat("  ✓ Successfully wrote test_combined.csv\n")
    },
    error = function(e) {
      cat("  ✗ Error writing CSV:", e$message, "\n")
    }
  )
}

cat("\n=== Diagnostic complete ===\n")
