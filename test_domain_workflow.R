#!/usr/bin/env Rscript

# Test script for the updated domain file generation workflow
# This demonstrates how to use the new R6 classes with modern tools

# Load required libraries
library(R6)
library(dplyr)
library(readr)
library(gt)
library(ggplot2)
library(here)
library(neuro2)

# Source R6 classes
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGT.R")
source("R/NeuropsychReportSystemR6.R")

# Test 1: Generate a single domain file using DomainProcessorR6
cat("=== Test 1: Generate Verbal Domain Files ===\n")

# Create processor for verbal domain
processor_verbal <- DomainProcessorR6$new(
  domains = "Verbal/Language",
  pheno = "verbal",
  input_file = "data/neurocog.csv"
)

# Process the data
tryCatch(
  {
    processor_verbal$load_data()
    processor_verbal$filter_by_domain()
    processor_verbal$select_columns()

    # Save processed data
    processor_verbal$save_data()

    cat("✓ Data processed and saved successfully\n")

    # Generate domain files
    processor_verbal$generate_domain_qmd()
    cat("✓ Domain QMD file generated\n")

    processor_verbal$generate_domain_text_qmd()
    cat("✓ Domain text file generated\n")
  },
  error = function(e) {
    cat("✗ Error in Test 1:", e$message, "\n")
  }
)

# Test 2: Use TableGT R6 class directly
cat("\n=== Test 2: Generate Table with TableGT R6 ===\n")

tryCatch(
  {
    # Use the processed data
    if (!is.null(processor_verbal$data)) {
      # Create table using TableGT
      table_gt <- TableGT$new(
        data = processor_verbal$data,
        pheno = "verbal",
        table_name = "table_verbal_test",
        vertical_padding = 0,
        source_note = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
        multiline = TRUE
      )

      # Build the table
      table_result <- table_gt$build_table()
      cat("✓ Table generated and saved as table_verbal_test.png/pdf\n")
    }
  },
  error = function(e) {
    cat("✗ Error in Test 2:", e$message, "\n")
  }
)

# Test 3: Use DotplotR6 class
cat("\n=== Test 3: Generate Dotplot with DotplotR6 ===\n")

tryCatch(
  {
    if (!is.null(processor_verbal$data)) {
      # Create dotplot
      dotplot <- DotplotR6$new(
        data = processor_verbal$data,
        x = "z_mean_subdomain",
        y = "subdomain",
        filename = "test_verbal_dotplot.svg"
      )

      plot_result <- dotplot$create_plot()
      cat("✓ Dotplot generated and saved as test_verbal_dotplot.svg\n")
    }
  },
  error = function(e) {
    cat("✗ Error in Test 3:", e$message, "\n")
  }
)

# Test 4: Full workflow with NeuropsychReportSystemR6
cat("\n=== Test 4: Full Report System Workflow ===\n")

tryCatch(
  {
    # Create report system for specific domains
    report_config <- list(
      patient = "Test Patient",
      domains = c("Verbal/Language", "Memory", "Executive"),
      data_files = list(
        neurocog = "data/neurocog.csv",
        neurobehav = "data/neurobehav.csv"
      )
    )

    report_system <- NeuropsychReportSystemR6$new(config = report_config)

    # Generate domain files only (not full report)
    report_system$generate_domain_files()

    cat("✓ Domain files generated for: Verbal/Language, Memory, Executive\n")
    cat("  Check for files:\n")
    cat("  - _02-03_verbal_language.qmd\n")
    cat("  - _02-04_memory.qmd\n")
    cat("  - _02-05_executive.qmd\n")
  },
  error = function(e) {
    cat("✗ Error in Test 4:", e$message, "\n")
  }
)

# Test 5: DuckDB/Parquet Integration Example
cat("\n=== Test 5: Modern Data Format Integration ===\n")

tryCatch(
  {
    # Simulate loading data from DuckDB
    cat("Example: Loading from DuckDB/Parquet\n")

    # Create a processor without file input
    processor_modern <- DomainProcessorR6$new(
      domains = "Memory",
      pheno = "memory",
      input_file = NULL # No file, data will be injected
    )

    # Simulate injecting data from DuckDB query
    # In real usage, this would come from:
    # processor_modern$data <- DBI::dbGetQuery(con, "SELECT * FROM neurocog WHERE domain = 'Memory'")

    # For this test, use existing data
    if (exists("processor_verbal") && !is.null(processor_verbal$data)) {
      processor_modern$data <- processor_verbal$data
      processor_modern$domains <- "Verbal/Language" # Use verbal data for test

      cat("✓ Data injection workflow demonstrated\n")
      cat("  In production: data <- duckdb_query_result\n")
    }
  },
  error = function(e) {
    cat("✗ Error in Test 5:", e$message, "\n")
  }
)

# Summary
cat("\n=== Workflow Test Summary ===\n")
cat("The updated workflow demonstrates:\n")
cat("1. R6 classes for modular, object-oriented design\n")
cat("2. TableGT for automatic table generation with footnotes\n")
cat("3. DotplotR6 for standardized visualizations\n")
cat("4. Dynamic domain file generation based on patient data\n")
cat("5. Support for modern data formats (DuckDB/Parquet)\n")
cat("\nCheck the generated files in your workspace.\n")
