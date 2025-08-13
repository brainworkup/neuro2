#!/usr/bin/env Rscript

# Script to generate table PNG files before rendering the template

# Load required packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(gt)
  library(readr)
  library(arrow)
})

# Function to safely load sysdata
load_sysdata <- function() {
  sysdata_path <- "R/sysdata.rda"
  if (file.exists(sysdata_path)) {
    load(sysdata_path, envir = .GlobalEnv)
    message("✓ Loaded sysdata.rda")
  } else {
    message("⚠ Warning: R/sysdata.rda not found")
  }
}

# Load sysdata.rda to get domain objects
load_sysdata()

# Source the required R6 classes
source_required_files <- function() {
  required_files <- c("R/TableGTR6.R", "R/score_type_utils.R")

  for (file in required_files) {
    if (file.exists(file)) {
      source(file)
      message(paste("✓ Sourced", file))
    } else {
      warning(paste("⚠ Warning: Required file not found:", file))
    }
  }
}

source_required_files()

# Function to read data file with format fallback
read_data_file <- function(pheno) {
  # Try different file formats in order of preference
  formats <- list(
    list(ext = ".parquet", reader = arrow::read_parquet),
    list(ext = ".feather", reader = arrow::read_feather),
    list(ext = ".csv", reader = function(x) {
      readr::read_csv(x, show_col_types = FALSE)
    })
  )

  for (format in formats) {
    file_path <- paste0("data/", pheno, format$ext)
    if (file.exists(file_path)) {
      message(paste("  ✓ Reading", file_path))
      return(format$reader(file_path))
    }
  }

  message(paste("  ✗ No data file found for", pheno))
  return(NULL)
}

# Function to get score type footnotes
get_score_type_footnotes <- function(unique_score_types) {
  footnote_map <- list(
    "t_score" = "T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]",
    "scaled_score" = "Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]",
    "standard_score" = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
    "z_score" = "z-score: Mean = 0 [50th‰], SD ± 1 [16th‰, 84th‰]",
    "percentile" = "Percentile rank: Percentage scoring at or below this level",
    "raw_score" = "Raw score: Untransformed test score",
    "base_rate" = "Base rate: Percentage of normative sample at or below this score"
  )

  fn_list <- list()
  for (score_type in unique_score_types) {
    if (score_type %in% names(footnote_map)) {
      fn_list[[score_type]] <- footnote_map[[score_type]]
    }
  }

  return(fn_list)
}

# Function to determine default source note
get_default_source_note <- function(pheno, fn_list) {
  if (length(fn_list) > 0) {
    return(NULL) # Use footnotes instead of source note
  }

  # Default source notes based on domain type
  default_notes <- list(
    "iq" = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
    "academics" = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
    "verbal" = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
    "spatial" = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
    "memory" = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
    "executive" = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
    "motor" = "Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]",
    "emotion" = "T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]",
    "adaptive" = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]"
  )

  return(
    default_notes[[pheno]] %||%
      "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]"
  )
}

# Main function to generate table for a domain
generate_domain_table <- function(pheno, domain_name) {
  message(paste0(
    "\n📊 Generating table for ",
    domain_name,
    " (",
    pheno,
    ")..."
  ))

  # Read the data
  data <- read_data_file(pheno)

  if (is.null(data)) {
    message(paste0("  ✗ No data file found for ", pheno))
    return(NULL)
  }

  if (nrow(data) == 0) {
    message(paste0("  ✗ No data available for ", pheno))
    return(NULL)
  }

  # Validate required columns
  required_cols <- c("test_name", "scale", "score", "percentile", "range")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    message(paste0(
      "  ✗ Missing required columns: ",
      paste(missing_cols, collapse = ", ")
    ))
    return(NULL)
  }

  # Table parameters
  table_name <- paste0("table_", pheno)
  vertical_padding <- 0
  multiline <- TRUE

  # Get score types from the lookup table if available
  score_types_list <- list()

  if (exists("get_score_types_from_lookup")) {
    tryCatch(
      {
        score_type_map <- get_score_types_from_lookup(data)

        # Process the score type map to group tests by score type
        for (test_name in names(score_type_map)) {
          types <- score_type_map[[test_name]]
          for (type in types) {
            if (!type %in% names(score_types_list)) {
              score_types_list[[type]] <- character(0)
            }
            score_types_list[[type]] <- unique(c(
              score_types_list[[type]],
              test_name
            ))
          }
        }
      },
      error = function(e) {
        message(paste(
          "  ⚠ Warning: Could not get score types from lookup:",
          e$message
        ))
      }
    )
  }

  # Get unique score types present
  unique_score_types <- names(score_types_list)

  # Define the score type footnotes
  fn_list <- get_score_type_footnotes(unique_score_types)

  # Get source note
  source_note <- get_default_source_note(pheno, fn_list)

  # Create table using TableGTR6 R6 class
  tryCatch(
    {
      table_gt <- TableGTR6$new(
        data = data,
        pheno = pheno,
        table_name = table_name,
        vertical_padding = vertical_padding,
        source_note = source_note,
        multiline = multiline,
        fn_list = fn_list,
        grp_list = score_types_list,
        dynamic_grp = score_types_list
      )

      # Build the table
      tbl <- table_gt$build_table()

      # Save the table
      table_gt$save_table(tbl, dir = here::here())

      message(paste0("  ✓ Created ", table_name, ".png"))
      return(table_name)
    },
    error = function(e) {
      message(paste0("  ✗ Error creating table for ", pheno, ": ", e$message))
      return(NULL)
    }
  )
}

# Function to check if data exists for domain
check_data_exists <- function(pheno) {
  formats <- c(".parquet", ".feather", ".csv")
  for (format in formats) {
    file_path <- paste0("data/", pheno, format)
    if (file.exists(file_path)) {
      return(TRUE)
    }
  }
  return(FALSE)
}

# Main processing function
main_processing <- function() {
  message("🚀 Starting table generation process...")

  # Define domains to process
  domains_to_process <- list(
    list(pheno = "iq", domain = "General Cognitive Ability"),
    list(pheno = "academics", domain = "Academic Skills"),
    list(pheno = "verbal", domain = "Verbal/Language"),
    list(pheno = "spatial", domain = "Visual Perception/Construction"),
    list(pheno = "memory", domain = "Memory"),
    list(pheno = "executive", domain = "Attention/Executive"),
    list(pheno = "motor", domain = "Motor"),
    list(pheno = "social", domain = "Social Cognition"),
    list(pheno = "emotion", domain = "Behavioral/Emotional/Social"),
    list(pheno = "adaptive", domain = "Adaptive Functioning"),
    list(pheno = "adhd", domain = "ADHD"),
    list(pheno = "validity", domain = "Performance/Symptom Validity")
  )

  generated_tables <- list()
  skipped_domains <- character()

  # Process each domain
  for (domain_info in domains_to_process) {
    # Check if data file exists before attempting to generate tables
    if (check_data_exists(domain_info$pheno)) {
      table_name <- generate_domain_table(domain_info$pheno, domain_info$domain)
      if (!is.null(table_name)) {
        generated_tables[[domain_info$pheno]] <- table_name
      }
    } else {
      message(paste0(
        "\n⏭️  Skipping ",
        domain_info$domain,
        " - no data file exists"
      ))
      skipped_domains <- c(skipped_domains, domain_info$domain)
    }
  }

  # Report results
  report_results(generated_tables, skipped_domains)

  return(generated_tables)
}

# Function to report generation results
report_results <- function(generated_tables, skipped_domains) {
  message(paste0("\n", paste(rep("=", 50), collapse = "")))
  message("📈 TABLE GENERATION SUMMARY")
  message(paste(rep("=", 50), collapse = ""))

  if (length(generated_tables) > 0) {
    message(paste0(
      "✅ Successfully generated ",
      length(generated_tables),
      " tables:"
    ))

    # List generated files
    table_files <- list.files(pattern = "^table_.*\\.png$", full.names = FALSE)
    for (file in table_files) {
      message(paste0("   📋 ", file))
    }
  } else {
    message("❌ No tables were generated")
  }

  if (length(skipped_domains) > 0) {
    message(paste0(
      "\n⏭️  Skipped ",
      length(skipped_domains),
      " domains (no data):"
    ))
    for (domain in skipped_domains) {
      message(paste0("   ⚪ ", domain))
    }
  }

  message("\n🎯 Table generation complete!")
  if (length(generated_tables) > 0) {
    message("   ➡️  You can now run the template rendering.")
  } else {
    message("   ⚠️  No tables available for template rendering.")
  }
}

# Null coalesce operator if not defined
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Execute main processing
main_processing()
