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
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGT.R")

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

# Test 2: Create processor with injected data
cat("2. Processing with DomainProcessorR6...\n")

processor_verbal <- DomainProcessorR6$new(
  domains = "Verbal/Language",
  pheno = "verbal",
  input_file = NULL # No file, data injected
)

# Inject the queried data
processor_verbal$data <- verbal_data
processor_verbal$select_columns()

cat("   ✓ Data processed\n\n")

# Test 3: Generate table
cat("3. Generating table with TableGT...\n")

table_gt <- TableGT$new(
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
cat("  - test_verbal_dotplot.svg\n")
cat("  - test_verbal_text.qmd\n")
cat("  - data/verbal.csv\n")
cat("\nThe workflow successfully:\n")
cat("  1. Loaded data from parquet using DuckDB\n")
cat("  2. Processed data with R6 classes\n")
cat("  3. Generated tables and visualizations\n")
cat("  4. Created text summaries\n")
