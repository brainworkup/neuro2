#!/usr/bin/env Rscript

# Simple test of Verbal domain processing with the new workflow

library(R6)
library(dplyr)
library(readr)
library(gt)
library(ggplot2)
library(here)
library(arrow)
library(DBI)
library(duckdb)

# Source R6 classes
source("R/DomainProcessor.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGTR6.R")

cat("Testing Verbal/Language Domain Processing\n")
cat("=========================================\n\n")

# Test 1: Load data from Parquet using DuckDB
cat("1. Loading Verbal/Language data from parquet...\n")

con <- DBI::dbConnect(duckdb::duckdb())

# Query verbal domain data directly from parquet
verbal_data <- DBI::dbGetQuery(
  con,
  "SELECT * FROM read_parquet('data/neurocog.parquet')
   WHERE domain = 'Verbal/Language'"
)

DBI::dbDisconnect(con, shutdown = TRUE)

cat("   ✓ Loaded", nrow(verbal_data), "rows for Verbal/Language domain\n")
cat(
  "   Tests found:",
  paste(unique(verbal_data$test_name), collapse = ", "),
  "\n\n"
)

# Check if z column exists, if not calculate it
if (!"z" %in% names(verbal_data)) {
  cat("   Calculating z-scores from percentiles...\n")
  verbal_data <- verbal_data %>%
    mutate(
      z = case_when(
        !is.na(percentile) & percentile > 0 & percentile < 100 ~
          qnorm(percentile / 100),
        TRUE ~ NA_real_
      )
    )
}

# Test 2: Create processor with injected data
cat("2. Processing with DomainProcessor...\n")

processor_verbal <- DomainProcessor$new(
  domains = "Verbal/Language",
  pheno = "verbal",
  input_file = NULL # No file, data injected
)

# Inject the queried data
processor_verbal$data <- verbal_data

# Check which columns exist before selecting
available_cols <- names(processor_verbal$data)
cat("   Available columns:", length(available_cols), "\n")

# Use filter_by_domain instead of select_columns to avoid column selection issues
processor_verbal$filter_by_domain()

# Manually select only the columns that exist
required_cols <- c(
  "test",
  "test_name",
  "scale",
  "raw_score",
  "score",
  "ci_95",
  "percentile",
  "range",
  "domain",
  "subdomain",
  "narrow",
  "pass",
  "verbal",
  "timed",
  "result",
  "z"
)

# Add z_mean columns if they exist
z_cols <- grep("^z_", names(processor_verbal$data), value = TRUE)
required_cols <- c(required_cols, z_cols)

# Select only existing columns
existing_cols <- intersect(required_cols, names(processor_verbal$data))
processor_verbal$data <- processor_verbal$data %>% select(all_of(existing_cols))

cat("   ✓ Data processed with", ncol(processor_verbal$data), "columns\n\n")

# Test 3: Generate table
cat("3. Generating table with TableGTR6...\n")

table_gt <- TableGTR6$new(
  data = processor_verbal$data,
  pheno = "verbal",
  table_name = "test_verbal_table",
  vertical_padding = 0,
  source_note = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
  multiline = TRUE
)

table_result <- table_gt$build_table()
cat("   ✓ Table generated: test_verbal_table.png/pdf\n\n")

# Test 4: Generate dotplot
cat("4. Generating dotplot with DotplotR6...\n")

# Check if we have subdomain data
if (
  "subdomain" %in%
    names(processor_verbal$data) &&
    any(!is.na(processor_verbal$data$subdomain))
) {
  # Calculate z_mean_subdomain if not present
  if (!"z_mean_subdomain" %in% names(processor_verbal$data)) {
    processor_verbal$data <- processor_verbal$data %>%
      group_by(subdomain) %>%
      mutate(z_mean_subdomain = mean(z, na.rm = TRUE)) %>%
      ungroup()
  }

  # Prepare data for dotplot
  plot_data <- processor_verbal$data %>%
    filter(!is.na(subdomain), !is.na(z_mean_subdomain)) %>%
    select(subdomain, z_mean_subdomain) %>%
    distinct()

  if (nrow(plot_data) > 0) {
    dotplot <- DotplotR6$new(
      data = plot_data,
      x = "z_mean_subdomain",
      y = "subdomain",
      filename = "test_verbal_dotplot.svg"
    )

    plot_result <- dotplot$create_plot()
    cat("   ✓ Dotplot generated: test_verbal_dotplot.svg\n")
  } else {
    cat("   ⚠ No subdomain data available for plotting\n")
  }
} else {
  cat("   ⚠ No subdomain column in data\n")
}

# Test 5: Generate text summary
cat("\n5. Generating text summary...\n")

# Save some data for text generation
if (!dir.exists("data")) {
  dir.create("data")
}
write_csv(processor_verbal$data, "data/verbal.csv")

results_processor <- NeuropsychResultsR6$new(
  data = processor_verbal$data,
  file = "test_verbal_text.qmd"
)

results_processor$process()
cat("   ✓ Text summary generated: test_verbal_text.qmd\n")

# Summary
cat("\n=========================================\n")
cat("✓ Verbal domain processing complete!\n")
cat("\nFiles created:\n")
cat("  - test_verbal_table.png/pdf\n")
cat("  - test_verbal_dotplot.svg (if subdomain data available)\n")
cat("  - test_verbal_text.qmd\n")
cat("  - data/verbal.csv\n")
cat("\nThe workflow successfully:\n")
cat("  1. Loaded data from parquet using DuckDB\n")
cat("  2. Processed data with R6 classes\n")
cat("  3. Generated tables and visualizations\n")
cat("  4. Created text summaries\n")
