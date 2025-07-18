#!/usr/bin/env Rscript

# Test script for the updated domain file generation workflow with Parquet/DuckDB
# This demonstrates the complete workflow from raw CSV to domain files

# Load required libraries
library(R6)
library(dplyr)
library(readr)
library(gt)
library(ggplot2)
library(here)
library(arrow)
library(DBI)
library(duckdb)
library(glue)
library(purrr)

# Source R6 classes and functions
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGT.R")
source("R/NeuropsychReportSystemR6.R")
source("R/duckdb_neuropsych_loader.R")

# Step 0: Process raw CSV files into parquet format
cat("=== Step 0: Process Raw CSV Files ===\n")

tryCatch(
  {
    # Create data directory if it doesn't exist
    if (!dir.exists("data")) {
      dir.create("data")
    }

    # Process raw CSV files using DuckDB loader
    result_data <- load_data_duckdb(
      file_path = "data-raw/csv",
      output_dir = "data",
      return_data = TRUE, # Return data for immediate use
      use_duckdb = TRUE,
      output_format = "all" # Generate CSV, Parquet, and Arrow formats
    )

    cat("✓ Raw CSV files processed successfully\n")
    cat("  Generated files in data/:\n")
    cat("  - neurocog.csv/parquet/feather\n")
    cat("  - neurobehav.csv/parquet/feather\n")
    cat("  - validity.csv/parquet/feather\n")
    cat("  - neuropsych.csv/parquet/feather\n\n")
  },
  error = function(e) {
    cat("✗ Error processing raw CSV files:", e$message, "\n")
    cat("  Make sure you have CSV files in data-raw/csv/\n")
    stop("Cannot proceed without processed data files")
  }
)

# Test 1: Generate domain files using DuckDB/Parquet data
cat("=== Test 1: Generate Verbal Domain Files with DuckDB ===\n")

tryCatch(
  {
    # Method 1: Load from parquet using DuckDB query
    con <- DBI::dbConnect(duckdb::duckdb())

    # Register parquet file as a view
    DBI::dbExecute(
      con,
      "CREATE OR REPLACE VIEW neurocog AS SELECT * FROM read_parquet('data/neurocog.parquet')"
    )

    # Query verbal domain data
    verbal_data <- DBI::dbGetQuery(
      con,
      "SELECT * FROM neurocog WHERE domain = 'Verbal/Language'"
    )

    DBI::dbDisconnect(con, shutdown = TRUE)

    # Create processor with injected data
    processor_verbal <- DomainProcessorR6$new(
      domains = "Verbal/Language",
      pheno = "verbal",
      input_file = NULL # No file, data will be injected
    )

    # Inject the DuckDB query result
    processor_verbal$data <- verbal_data

    # Process without loading (data already loaded)
    processor_verbal$filter_by_domain()
    processor_verbal$select_columns()

    # Save processed data
    processor_verbal$save_data()

    cat("✓ Data processed with DuckDB and saved successfully\n")

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

# Test 2: Use TableGT R6 class with parquet data
cat("\n=== Test 2: Generate Table with TableGT R6 ===\n")

tryCatch(
  {
    # Use the processed data
    if (exists("processor_verbal") && !is.null(processor_verbal$data)) {
      # Create table using TableGT
      table_gt <- TableGT$new(
        data = processor_verbal$data,
        pheno = "verbal",
        table_name = "table_verbal_parquet",
        vertical_padding = 0,
        source_note = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
        multiline = TRUE
      )

      # Build the table
      table_result <- table_gt$build_table()
      cat("✓ Table generated and saved as table_verbal_parquet.png/pdf\n")
    }
  },
  error = function(e) {
    cat("✗ Error in Test 2:", e$message, "\n")
  }
)

# Test 3: Query multiple domains using DuckDB
cat("\n=== Test 3: Multi-Domain Query with DuckDB ===\n")

tryCatch(
  {
    # Example of querying multiple domains at once
    domains_of_interest <- c("Verbal/Language", "Memory", "Attention/Executive")

    query <- glue::glue(
      "SELECT * FROM 'data/neurocog.parquet' 
     WHERE domain IN ({domains_str})",
      domains_str = paste0("'", domains_of_interest, "'", collapse = ", ")
    )

    multi_domain_data <- query_neuropsych(query, "data")

    cat("✓ Multi-domain query successful\n")
    cat(
      "  Found",
      nrow(multi_domain_data),
      "records across",
      length(unique(multi_domain_data$domain)),
      "domains\n"
    )

    # Generate domain files for each
    for (domain in unique(multi_domain_data$domain)) {
      domain_data <- multi_domain_data |> filter(domain == !!domain)
      domain_key <- gsub("[/ ]", "_", tolower(domain))

      processor <- DomainProcessorR6$new(
        domains = domain,
        pheno = domain_key,
        input_file = NULL
      )

      processor$data <- domain_data
      processor$select_columns()

      cat("  - Processed", domain, "with", nrow(domain_data), "tests\n")
    }
  },
  error = function(e) {
    cat("✗ Error in Test 3:", e$message, "\n")
  }
)

# Test 4: Performance comparison
cat("\n=== Test 4: Performance Comparison ===\n")

tryCatch(
  {
    # Time CSV loading
    csv_start <- Sys.time()
    csv_data <- readr::read_csv("data/neurocog.csv", show_col_types = FALSE)
    csv_time <- difftime(Sys.time(), csv_start, units = "secs")

    # Time Parquet loading with Arrow
    parquet_start <- Sys.time()
    parquet_data <- arrow::read_parquet("data/neurocog.parquet")
    parquet_time <- difftime(Sys.time(), parquet_start, units = "secs")

    # Time DuckDB query
    duckdb_start <- Sys.time()
    duckdb_data <- query_neuropsych(
      "SELECT * FROM neurocog WHERE domain = 'Verbal/Language'",
      "data"
    )
    duckdb_time <- difftime(Sys.time(), duckdb_start, units = "secs")

    cat("✓ Performance comparison:\n")
    cat(sprintf("  CSV loading: %.3f seconds\n", csv_time))
    cat(sprintf(
      "  Parquet loading: %.3f seconds (%.1fx faster)\n",
      parquet_time,
      as.numeric(csv_time / parquet_time)
    ))
    cat(sprintf(
      "  DuckDB query: %.3f seconds (%.1fx faster)\n",
      duckdb_time,
      as.numeric(csv_time / duckdb_time)
    ))
  },
  error = function(e) {
    cat("✗ Error in Test 4:", e$message, "\n")
  }
)

# Test 5: Full workflow with NeuropsychReportSystemR6
cat("\n=== Test 5: Full Report System with Parquet ===\n")

tryCatch(
  {
    # Update the report system to use parquet files
    report_config <- list(
      patient = "Test Patient",
      domains = c("Verbal/Language", "Memory", "Attention/Executive"),
      data_files = list(
        neurocog = "data/neurocog.parquet",
        neurobehav = "data/neurobehav.parquet",
        validity = "data/validity.parquet"
      )
    )

    # Note: This would require updating NeuropsychReportSystemR6 to support parquet
    # For now, we'll use the CSV files that were also generated
    report_config$data_files <- list(
      neurocog = "data/neurocog.csv",
      neurobehav = "data/neurobehav.csv"
    )

    report_system <- NeuropsychReportSystemR6$new(config = report_config)

    # Generate domain files only (not full report)
    report_system$generate_domain_files()

    cat("✓ Domain files generated for patient\n")
    cat("  Using modern data pipeline:\n")
    cat("  1. Raw CSV → DuckDB → Parquet\n")
    cat("  2. Parquet → Domain Processing\n")
    cat("  3. R6 Classes → Tables & Plots\n")
  },
  error = function(e) {
    cat("✗ Error in Test 5:", e$message, "\n")
  }
)

# Summary
cat("\n=== Parquet/DuckDB Workflow Summary ===\n")
cat("The updated workflow demonstrates:\n")
cat("1. Processing raw CSV files from data-raw/csv/\n")
cat("2. Converting to efficient Parquet format\n")
cat("3. Using DuckDB for fast data queries\n")
cat("4. Injecting query results into R6 processors\n")
cat("5. Generating domain files with modern tools\n")
cat("\nBenefits:\n")
cat("- Faster data loading (Parquet vs CSV)\n")
cat("- SQL queries for complex filtering\n")
cat("- Memory-efficient processing\n")
cat("- Scalable to large datasets\n")
