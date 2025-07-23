# Load required packages
library(dplyr)
library(readr)
library(tidyr)
library(stringr)
library(purrr)

# Source the file directly
source("R/process_rbans_unified.R")

# RBANS test parameters
input_file <- "EF2025_4_17_2025_scores.csv"
test_prefix <- "RBANS Update Form A "
output_file <- "data-raw/csv/rbans.csv"
summary_file <- "rbans_summary.csv"

manual_percentiles <- list(
  "Line Orientation" = 13,
  "Picture Naming" = 37,
  "List Recall" = 37,
  "List Recognition" = 63
)

manual_entries <- NULL
debug <- TRUE

# Run RBANS processing
process_rbans_unified(
  input_file = input_file,
  test_prefix = test_prefix,
  output_file = output_file,
  summary_file = summary_file,
  manual_percentiles = manual_percentiles,
  manual_entries = manual_entries,
  debug = debug
)

# Print confirmation
cat("RBANS processing completed. Check output files:\n")
cat("- Output file:", output_file, "\n")
cat("- Summary file:", summary_file, "\n")
