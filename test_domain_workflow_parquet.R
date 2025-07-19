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
source("R/ReportTemplateR6.R") # Add missing R6 class
source("R/NeuropsychReportSystemR6.R")
source("R/duckdb_neuropsych_loader.R")

# Define domain constants (needed for NeuropsychReportSystemR6)
domain_iq <- "General Cognitive Ability"
domain_academics <- "Academic Skills"
domain_verbal <- "Verbal/Language"
domain_spatial <- "Visual Perception/Construction"
domain_memory <- "Memory"
domain_executive <- "Attention/Executive"
domain_motor <- "Motor"
domain_social <- "Social Cognition"
domain_adhd_child <- "ADHD"
domain_adhd_adult <- "ADHD"
domain_emotion_child <- "Emotional/Behavioral/Personality"
domain_emotion_adult <- "Emotional/Behavioral/Personality"

# Step 0: Process raw CSV files into parquet format
cat("=== Step 0: Process Raw CSV Files ===\n")

tryCatch(
  {
    # Create data directory if it doesn't exist
    if (!dir.exists("data")) {
      dir.create("data")
    }

    # First, process and WRITE files (return_data = FALSE)
    load_data_duckdb(
      file_path = "data-raw/csv",
      output_dir = "data",
      return_data = FALSE, # This will write files
      use_duckdb = TRUE,
      output_format = "all" # Generate CSV, Parquet, and Arrow formats
    )

    # Then load the data for immediate use
    result_data <- load_data_duckdb(
      file_path = "data-raw/csv",
      output_dir = "data",
      return_data = TRUE, # This will return data
      use_duckdb = TRUE,
      output_format = "all"
    )

    cat("✓ Raw CSV files processed successfully\n")

    # Check what files were actually created
    files_created <- list.files("data", pattern = "\\.(csv|parquet|feather)$")
    if (length(files_created) > 0) {
      cat("  Actually created files:\n")
      for (f in files_created) {
        cat("  -", f, "\n")
      }
    } else {
      cat("  WARNING: No files were created in data/\n")
    }
    cat("\n")
  },
  error = function(e) {
    cat("✗ Error processing raw CSV files:", e$message, "\n")
    cat("  Make sure you have CSV files in data-raw/csv/\n")
    stop("Cannot proceed without processed data files")
  }
)

# Helper function to get test filters for each domain
get_domain_test_filters <- function(domain) {
  # Define test filters for each domain based on actual test names in the data
  # The 'test' column in your CSV files contains: rbans, pegboard, tmt, pai, basc3, wisc5
  filters <- list(
    verbal = list(
      self = c("rbans"), # RBANS has verbal/language subtests
      observer = character(0),
      performance = c("rbans") # RBANS Language Index
    ),
    memory = list(
      self = c("rbans"), # RBANS has memory subtests
      observer = character(0),
      performance = c("rbans") # RBANS Memory indices
    ),
    executive = list(
      self = c("rbans", "tmt"), # RBANS Attention Index, TMT Part B
      observer = character(0), # Could add basc3 if it has executive measures
      performance = c("rbans", "tmt")
    ),
    # Add additional domains to prevent warnings
    iq = list(
      self = c("wisc5", "rbans"), # WISC-5 for IQ, RBANS Total Index
      observer = character(0),
      performance = c("wisc5", "rbans")
    ),
    spatial = list(
      self = c("rbans"), # RBANS Visuospatial/Constructional Index
      observer = character(0),
      performance = c("rbans")
    ),
    motor = list(
      self = c("pegboard"), # Grooved Pegboard test
      observer = character(0),
      performance = c("pegboard")
    ),
    emotion = list(
      self = c("pai"), # PAI for emotional/personality
      observer = c("basc3"), # BASC-3 for behavioral observations
      performance = character(0)
    ),
    validity = list(
      self = character(0), # No validity tests in current data
      observer = character(0),
      performance = character(0)
    )
  )

  return(filters[[tolower(domain)]])
}

# Test 1: Generate domain files for Verbal, Memory, and Executive (and optionally IQ)
cat("=== Test 1: Generate Domain Files for Multiple Domains ===\n\n")

# Note: Add IQ domain if you want to generate iq.csv
# Uncomment the line below to include IQ processing:
# list(domain = "General Cognitive Ability", pheno = "iq"),

domains_to_test <- list(
  list(domain = "Verbal/Language", pheno = "verbal"),
  list(domain = "Memory", pheno = "memory"),
  list(domain = "Attention/Executive", pheno = "executive")
)

cat(
  "Note: Domain-specific CSV files (e.g., verbal.csv, memory.csv) are created\n"
)
cat("      by processor$save_data() for each processed domain.\n\n")

# Process each domain
for (domain_info in domains_to_test) {
  cat(paste0("--- Processing ", domain_info$domain, " domain ---\n"))

  tryCatch(
    {
      # Use the properly processed data with z-scores from Step 0
      if (exists("result_data") && !is.null(result_data$neurocog)) {
        # Get domain data from the processed result that includes z-scores
        domain_data <- result_data$neurocog |>
          filter(domain == domain_info$domain)
        cat("  Using processed data with z-scores\n")
      } else {
        # Fallback: load from file if result_data not available
        if (!file.exists("data/neurocog.parquet")) {
          # Try CSV as fallback
          if (file.exists("data/neurocog.csv")) {
            cat("  Note: Using CSV file as parquet not found\n")
            domain_data <- readr::read_csv(
              "data/neurocog.csv",
              show_col_types = FALSE
            ) |>
              filter(domain == domain_info$domain)
          } else {
            stop("Neither neurocog.parquet nor neurocog.csv found in data/")
          }
        } else {
          # Load from parquet using DuckDB query
          con <- DBI::dbConnect(duckdb::duckdb())

          # Register parquet file as a view
          DBI::dbExecute(
            con,
            "CREATE OR REPLACE VIEW neurocog AS SELECT * FROM read_parquet('data/neurocog.parquet')"
          )

          # Query domain data
          domain_data <- DBI::dbGetQuery(
            con,
            paste0(
              "SELECT * FROM neurocog WHERE domain = '",
              domain_info$domain,
              "'"
            )
          )

          DBI::dbDisconnect(con, shutdown = TRUE)
        }
      }

      # Create processor with proper test filters
      processor <- DomainProcessorR6$new(
        domains = domain_info$domain,
        pheno = domain_info$pheno,
        input_file = "data/neurocog.csv", # Needed for generate_domain_qmd
        test_filters = get_domain_test_filters(domain_info$pheno)
      )

      # Inject the processed data
      processor$data <- domain_data

      # Process without loading (data already loaded)
      processor$filter_by_domain()
      processor$select_columns()

      # Save processed data
      processor$save_data()
      cat("  ✓ Data processed and saved successfully\n")

      # Generate domain QMD file
      processor$generate_domain_qmd()
      cat("  ✓ Domain QMD file generated\n")

      # Generate domain text file
      processor$generate_domain_text_qmd()
      cat("  ✓ Domain text file generated\n")

      # Store processor for later use
      if (domain_info$pheno == "verbal") {
        processor_verbal <- processor
      } else if (domain_info$pheno == "memory") {
        processor_memory <- processor
      } else if (domain_info$pheno == "executive") {
        processor_executive <- processor
      }

      cat("\n")
    },
    error = function(e) {
      cat("  ✗ Error processing", domain_info$domain, ":", e$message, "\n")
      cat("    Full error details:\n")
      print(e)
      cat("\n")
    }
  )
}

# Test 2: Generate tables and plots for all domains
cat("\n=== Test 2: Generate Tables and Plots for All Domains ===\n")

# List of domains to process
domains_with_processors <- list(
  list(name = "verbal", processor_var = "processor_verbal"),
  list(name = "memory", processor_var = "processor_memory"),
  list(name = "executive", processor_var = "processor_executive")
)

for (domain_info in domains_with_processors) {
  cat(paste0(
    "\n--- Generating visualizations for ",
    domain_info$name,
    " ---\n"
  ))

  tryCatch(
    {
      # Check if processor exists
      if (exists(domain_info$processor_var)) {
        processor <- get(domain_info$processor_var)

        if (!is.null(processor$data)) {
          # Create table using TableGT
          table_gt <- TableGT$new(
            data = processor$data,
            pheno = domain_info$name,
            table_name = paste0("table_", domain_info$name, "_parquet"),
            vertical_padding = 0,
            source_note = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
            multiline = TRUE
          )

          # Build the table
          table_result <- table_gt$build_table()
          cat(
            "  ✓ Table generated and saved as table_",
            domain_info$name,
            "_parquet.png/pdf\n",
            sep = ""
          )

          # Create dotplot using DotplotR6
          dotplot <- DotplotR6$new(
            data = processor$data,
            filename = paste0("test_", domain_info$name, "_dotplot"),
            aspect_ratio = 1.5
          )

          # Build the plot
          plot_result <- dotplot$build_plot()
          cat(
            "  ✓ Dotplot generated and saved as test_",
            domain_info$name,
            "_dotplot.svg\n",
            sep = ""
          )
        } else {
          cat(
            "  Skipped: No data available for ",
            domain_info$name,
            "\n",
            sep = ""
          )
        }
      } else {
        cat(
          "  Skipped: No processor found for ",
          domain_info$name,
          "\n",
          sep = ""
        )
      }
    },
    error = function(e) {
      cat(
        "  ✗ Error generating visualizations for ",
        domain_info$name,
        ": ",
        e$message,
        "\n",
        sep = ""
      )
      cat("    Full error details:\n")
      print(e)
      cat("\n")
    }
  )
}

# Test 3: Query multiple domains using DuckDB
cat("\n=== Test 3: Multi-Domain Query with DuckDB ===\n")

tryCatch(
  {
    # Check if we have any data files
    data_files <- list.files(
      "data",
      pattern = "\\.(csv|parquet|feather)$",
      full.names = TRUE
    )

    if (length(data_files) == 0) {
      cat("  Skipped: No data files found in data/\n")
    } else {
      # Example of querying multiple domains at once
      domains_of_interest <- c(
        "Verbal/Language",
        "Memory",
        "Attention/Executive"
      )

      # Find a neurocog file
      neurocog_file <- data_files[grepl("neurocog", data_files)][1]

      if (!is.na(neurocog_file)) {
        query <- glue::glue(
          "SELECT * FROM '{file}'
         WHERE domain IN ({domains_str})",
          file = neurocog_file,
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
      } else {
        cat("  Skipped: No neurocog file found\n")
      }
    }
  },
  error = function(e) {
    cat("✗ Error in Test 3:", e$message, "\n")
    cat("  Full error details:\n")
    print(e)
    cat("\n")
  }
)

# Test 4: Performance comparison
cat("\n=== Test 4: Performance Comparison ===\n")

tryCatch(
  {
    # Check if files exist before testing
    csv_exists <- file.exists("data/neurocog.csv")
    parquet_exists <- file.exists("data/neurocog.parquet")

    if (!csv_exists && !parquet_exists) {
      cat("  Skipped: No data files available for comparison\n")
    } else {
      if (csv_exists) {
        # Time CSV loading
        csv_start <- Sys.time()
        csv_data <- readr::read_csv("data/neurocog.csv", show_col_types = FALSE)
        csv_time <- difftime(Sys.time(), csv_start, units = "secs")
        cat(sprintf("  CSV loading: %.3f seconds\n", csv_time))
      }

      if (parquet_exists) {
        # Time Parquet loading with Arrow
        parquet_start <- Sys.time()
        parquet_data <- arrow::read_parquet("data/neurocog.parquet")
        parquet_time <- difftime(Sys.time(), parquet_start, units = "secs")
        cat(sprintf("  Parquet loading: %.3f seconds", parquet_time))

        if (exists("csv_time")) {
          cat(sprintf(
            " (%.1fx faster)\n",
            as.numeric(csv_time) / as.numeric(parquet_time)
          ))
        } else {
          cat("\n")
        }
      }

      # Time DuckDB query if we have any file
      if (csv_exists || parquet_exists) {
        duckdb_start <- Sys.time()
        duckdb_data <- query_neuropsych(
          "SELECT * FROM neurocog WHERE domain = 'Verbal/Language'",
          "data"
        )
        duckdb_time <- difftime(Sys.time(), duckdb_start, units = "secs")
        cat(sprintf("  DuckDB query: %.3f seconds", duckdb_time))

        if (exists("csv_time")) {
          cat(sprintf(
            " (%.1fx faster)\n",
            as.numeric(csv_time) / as.numeric(duckdb_time)
          ))
        } else {
          cat("\n")
        }
      }

      cat("✓ Performance comparison complete\n")
    }
  },
  error = function(e) {
    cat("✗ Error in Test 4:", e$message, "\n")
    cat("  Full error details:\n")
    print(e)
    cat("\n")
  }
)

# Test 5: Full workflow with NeuropsychReportSystemR6
cat("\n=== Test 5: Full Report System with Parquet ===\n")

tryCatch(
  {
    # First ensure we have properly processed data with z-scores
    # The NeuropsychReportSystemR6 expects these columns to exist

    # Check if the processed data from Step 0 is available
    if (exists("result_data") && !is.null(result_data)) {
      # Use the data that was processed with z-scores
      neurocog_data <- result_data$neurocog
      neurobehav_data <- result_data$neurobehav
      validity_data <- result_data$validity

      # Verify z-score columns exist
      z_cols <- grep("^z", names(neurocog_data), value = TRUE)
      if (length(z_cols) > 0) {
        cat("  Found z-score columns:", paste(z_cols, collapse = ", "), "\n\n")
      } else {
        cat("  WARNING: No z-score columns found in data\n")
      }
    }

    # Update the report system to use parquet files
    report_config <- list(
      patient = "Biggie",
      domains = c("Verbal/Language", "Memory", "Attention/Executive"),
      data_files = list(
        neurocog = "data/neurocog.parquet",
        neurobehav = "data/neurobehav.parquet",
        validity = "data/validity.parquet"
      )
    )

    # Check if parquet files exist, otherwise use CSV
    if (
      !file.exists("data/neurocog.parquet") && file.exists("data/neurocog.csv")
    ) {
      report_config$data_files <- list(
        neurocog = "data/neurocog.csv",
        neurobehav = "data/neurobehav.csv",
        validity = "data/validity.csv"
      )
      cat("  Note: Using CSV files as parquet not available\n")
    }

    # Create report system
    report_system <- NeuropsychReportSystemR6$new(config = report_config)

    # Inject the properly processed data with z-scores if available
    if (exists("result_data") && !is.null(result_data)) {
      # Override the domain processors to use our processed data
      for (domain_info in domains_to_test) {
        pheno <- domain_info$pheno
        if (pheno %in% names(report_system$domain_processors)) {
          # Get domain data with z-scores
          domain_data <- result_data$neurocog |>
            filter(domain == domain_info$domain)

          # Inject the processed data
          report_system$domain_processors[[pheno]]$data <- domain_data
        }
      }
    }

    # Generate domain files only for the configured domains (not full report)
    # This prevents warnings about missing processors for other domains
    report_system$generate_domain_files(domains = report_config$domains)

    cat("✓ Domain files generated for patient\n")
    cat("  Using modern data pipeline:\n")
    cat("  1. Raw CSV → DuckDB → Parquet (with z-score calculation)\n")
    cat("  2. Parquet → Domain Processing\n")
    cat("  3. R6 Classes → Tables & Plots\n")
  },
  error = function(e) {
    cat("✗ Error in Test 5:", e$message, "\n")
    cat("  Full error details:\n")
    print(e)
    cat("\n")
  }
)

# Test 6: Render domain files to typst format
cat("\n=== Test 6: Render Domain Files to Typst ===\n")

tryCatch(
  {
    # Find all generated domain QMD files
    domain_files <- list.files(
      pattern = "^_02-0[356]_(verbal|memory|executive)\\.qmd$",
      full.names = FALSE
    )

    if (length(domain_files) > 0) {
      cat("Found domain files to render:\n")
      for (f in domain_files) {
        cat("  -", f, "\n")
      }
      cat("\n")

      # Render each file to typst
      for (domain_file in domain_files) {
        cat(paste0("Rendering ", domain_file, " to typst format...\n"))

        # Get output name
        output_name <- gsub("\\.qmd$", ".typ", domain_file)

        # Render using quarto
        tryCatch(
          {
            system2(
              "quarto",
              args = c("render", domain_file, "--to", "typst"),
              stdout = TRUE,
              stderr = TRUE
            )
            cat("  ✓ Successfully rendered to", output_name, "\n")
          },
          error = function(e) {
            cat("  ✗ Error rendering", domain_file, ":", e$message, "\n")
          }
        )
      }
      cat("\n✓ Typst rendering complete\n")
    } else {
      cat("  No domain QMD files found to render\n")
    }
  },
  error = function(e) {
    cat("✗ Error in Test 6:", e$message, "\n")
    cat("  Full error details:\n")
    print(e)
    cat("\n")
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
cat("6. Rendering domain files to typst format\n")
cat("\nBenefits:\n")
cat("- Faster data loading (Parquet vs CSV)\n")
cat("- SQL queries for complex filtering\n")
cat("- Memory-efficient processing\n")
cat("- Scalable to large datasets\n")
cat("- Modern typesetting with typst\n")

# Final check
cat("\n=== Final Status Check ===\n")
data_files <- list.files("data", pattern = "\\.(csv|parquet|feather)$")
if (length(data_files) > 0) {
  cat("✓ Data files created in data/:\n")
  for (f in data_files) {
    size <- file.info(file.path("data", f))$size
    cat(sprintf("  - %s (%.1f KB)\n", f, size / 1024))
  }
} else {
  cat("✗ WARNING: No data files were created\n")
}
