#!/usr/bin/env Rscript

# DATA PROCESSOR MODULE
# This module handles data processing for the neuropsychological workflow
# It loads raw data from CSV files and processes them into the required format

# Load the DuckDB processor
if (file.exists("R/duckdb_neuropsych_loader.R")) {
  source("R/duckdb_neuropsych_loader.R")
} else {
  stop("Required file R/duckdb_neuropsych_loader.R not found")
}

# Get configuration from the parent environment
# This assumes this script is sourced from the WorkflowRunner
if (exists("self") && inherits(self, "R6")) {
  config <- self$config
} else {
  # Fallback if not called from WorkflowRunner
  if (file.exists("config.yml")) {
    if (!requireNamespace("yaml", quietly = TRUE)) {
      install.packages("yaml")
      library(yaml)
    }
    config <- yaml::read_yaml("config.yml")
  } else {
    stop("Configuration not available")
  }
}

# Log the data processing start
if (exists("log_message")) {
  log_message("Starting data processing with DuckDB", "DATA")
} else {
  cat("[DATA] Starting data processing with DuckDB\n")
}

# Process the data using DuckDB
load_data_duckdb(
  file_path = config$data$input_dir,
  output_dir = config$data$output_dir,
  output_format = config$data$format
)

# Log completion
if (exists("log_message")) {
  log_message("Data processing completed successfully", "DATA")
} else {
  cat("[DATA] Data processing completed successfully\n")
}
