#!/usr/bin/env Rscript
# Validation-aware script to generate domain files using DomainProcessor
# Only generates files for domains that have data

# Ensure warnings are not converted to errors
old_warn <- getOption("warn")
options(warn = 1)

# Load required libraries
library(here)
library(R6)
library(dplyr)
library(readr)
library(yaml)

# Source required files
source("R/DomainProcessor.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGTR6.R")
source("R/score_type_utils.R")
source("R/domain_validation_utils.R")

cat("Generating domain files using R6 classes with validation...\n\n")

# Load data for validation
tryCatch(
  {
    neurocog_data <- NULL
    neurobehav_data <- NULL

    if (file.exists("data/neurocog.csv")) {
      neurocog_data <- read_csv("data/neurocog.csv", show_col_types = FALSE)
    }

    if (file.exists("data/neurobehav.csv")) {
      neurobehav_data <- read_csv("data/neurobehav.csv", show_col_types = FALSE)
    }

    if (is.null(neurocog_data) && is.null(neurobehav_data)) {
      cat("⚠ No data files found - skipping domain generation\n")
      quit(save = "no")
    }

    # Load domain configuration
    domain_config <- list(
      "General Cognitive Ability" = list(
        pheno = "iq",
        input_file = "data/neurocog.csv"
      ),
      "Academic Skills" = list(
        pheno = "academics",
        input_file = "data/neurocog.csv"
      ),
      "Verbal/Language" = list(
        pheno = "verbal",
        input_file = "data/neurocog.csv"
      ),
      "Visual Perception/Construction" = list(
        pheno = "spatial",
        input_file = "data/neurocog.csv"
      ),
      "Memory" = list(pheno = "memory", input_file = "data/neurocog.csv"),
      "Attention/Executive" = list(
        pheno = "executive",
        input_file = "data/neurocog.csv"
      ),
      "Motor" = list(pheno = "motor", input_file = "data/neurocog.csv"),
      "Social Cognition" = list(
        pheno = "social",
        input_file = "data/neurocog.csv"
      ),
      "ADHD" = list(pheno = "adhd", input_file = "data/neurobehav.csv"),
      "Behavioral/Emotional/Social" = list(
        pheno = "emotion",
        input_file = "data/neurobehav.csv"
      ),
      "Psychiatric Disorders" = list(
        pheno = "emotion",
        input_file = "data/neurobehav.csv"
      ),
      "Personality Disorders" = list(
        pheno = "emotion",
        input_file = "data/neurobehav.csv"
      ),
      "Psychosocial Problems" = list(
        pheno = "emotion",
        input_file = "data/neurobehav.csv"
      ),
      "Substance Use" = list(
        pheno = "emotion",
        input_file = "data/neurobehav.csv"
      ),
      "Emotional/Behavioral/Personality" = list(
        pheno = "emotion",
        input_file = "data/neurobehav.csv"
      ),
      "Adaptive Functioning" = list(
        pheno = "adaptive",
        input_file = "data/neurobehav.csv"
      ),
      "Daily Living" = list(
        pheno = "daily_living",
        input_file = "data/neurobehav.csv"
      )
    )

    # Get domains with data using validation
    valid_domains_only <- get_domains_with_data(
      neurocog_data,
      neurobehav_data,
      domain_config
    )

    if (length(valid_domains_only) == 0) {
      cat("⚠ No domains found with sufficient data\n")
      quit(save = "no")
    }

    cat("Found", length(valid_domains_only), "domains with data\n")

    # Only generate files for domains that have data
    for (domain_name in names(valid_domains_only)) {
      domain_info <- valid_domains_only[[domain_name]]
      config <- domain_info$config

      cat("Generating files for", domain_name, "(", config$pheno, ")...\n")

      tryCatch(
        {
          processor <- DomainProcessor$new(
            domains = domain_name,
            pheno = config$pheno,
            input_file = config$input_file
          )

          processor$load_data()
          processor$filter_by_domain()

          if (!is.null(processor$data) && nrow(processor$data) > 0) {
            processor$select_columns()
            processor$save_data()

            generated_file <- processor$generate_domain_qmd()
            if (!is.null(generated_file)) {
              cat("  ✓ Generated", generated_file, "\n")
            }
          } else {
            cat("  ⚠ No data after filtering\n")
          }
        },
        error = function(e) {
          cat("  ✗ Error generating", domain_name, ":", e$message, "\n")
        }
      )
    }

    cat("\nValidated domain file generation complete!\n")
  },
  error = function(e) {
    cat("✗ Error in domain generation:", e$message, "\n")
  }
)

# Restore warning level
options(warn = old_warn)
