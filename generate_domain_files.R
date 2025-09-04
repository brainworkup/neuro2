#!/usr/bin/env Rscript
# Validation-aware script to generate domain files using DomainProcessorR6
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
library(arrow)
# Prefer loading local package source first for consistency with development
load_neuro2_dev <- function() {
  if (file.exists(here::here("DESCRIPTION"))) {
    if (requireNamespace("devtools", quietly = TRUE)) {
      try(devtools::load_all(here::here(), quiet = TRUE), silent = TRUE)
      return(TRUE)
    }
    if (requireNamespace("pkgload", quietly = TRUE)) {
      try(pkgload::load_all(here::here(), quiet = TRUE), silent = TRUE)
      return(TRUE)
    }
  }
  FALSE
}

if (!load_neuro2_dev()) {
  # Fallback to installed package; if that fails, source minimal classes directly
  ok <- FALSE
  try(
    {
      suppressPackageStartupMessages(library(neuro2))
      ok <- TRUE
    },
    silent = TRUE
  )
  if (!ok) {
    classes <- c(
      "R/ScoreTypeCacheR6.R",
      "R/score_type_utils.R",
      "R/DomainProcessorR6.R",
      "R/NeuropsychResultsR6.R",
      "R/TableGTR6.R",
      "R/DotplotR6.R"
    )
    for (cls in classes) {
      fp <- here::here(cls)
      if (file.exists(fp)) source(fp)
    }
  }
}

# Always override DotplotR6 with local source if available to ensure
# robust SVG handling on systems where svglite may segfault
local_dotplot <- here::here("R", "DotplotR6.R")
if (file.exists(local_dotplot)) {
  source(local_dotplot)
}

# Defensive: ask svglite not to embed fonts if it gets used indirectly
Sys.setenv(SVGLITE_NO_FONTS = "true")


# Function to generate placeholder text files
generate_text_files <- function(generated_files, verbose = TRUE) {
  if (verbose) {
    cat("\nGenerating placeholder text files...\n")
  }

  text_files_created <- character(0)

  for (qmd_file in generated_files) {
    if (file.exists(qmd_file)) {
      # Read the QMD file to find text file references
      content <- readLines(qmd_file, warn = FALSE)

      # Find lines with Quarto include; use fixed matching to avoid escaping '{'
      include_lines <- grep("{{< include", content, value = TRUE, fixed = TRUE)
      include_lines <- include_lines[grepl(
        "_text.qmd",
        include_lines,
        fixed = TRUE
      )]

      for (include_line in include_lines) {
        # Extract the text filename appearing after `include`
        # Example: {{< include _02-01_iq_text.qmd >}}
        # Extract the text filename token after '{{< include '
        start_idx <- regexpr("{{< include ", include_line, fixed = TRUE)
        text_file <- NA_character_
        if (start_idx > 0) {
          start <- start_idx + nchar("{{< include ")
          rest <- substring(include_line, start)
          # Take characters until first space or '>'
          text_file <- sub("[ >].*$", "", rest, perl = TRUE)
        }

        if (!is.na(text_file) && nchar(text_file) > 0) {
          if (!file.exists(text_file)) {
            # Extract domain name from the text file name
            domain_name <- gsub("_[0-9]+-[0-9]+-([^_]+)_.*", "\\1", text_file)
            domain_name <- tools::toTitleCase(gsub("_", " ", domain_name))

            # Create placeholder content
            placeholder_content <- paste0(
              "# ",
              domain_name,
              " Assessment\n\n",
              "The ",
              tolower(domain_name),
              " assessment results will be generated here.\n\n",
              "This section will include:\n\n",
              "- Overview of test results\n",
              "- Clinical interpretation\n",
              "- Relevant observations\n"
            )

            # Only write if file doesn't exist
            if (!file.exists(text_file)) {
              writeLines(placeholder_content, text_file)
              text_files_created <- c(text_files_created, text_file)

              if (verbose) cat("  ✓ Created placeholder:", text_file, "\n")
            } else {
              if (verbose) cat("  - Skipped existing file:", text_file, "\n")
            }
          }
        }
      }
    }
  }

  return(text_files_created)
}

cat("Generating domain files using R6 classes with validation...\n\n")

# Load data for validation
tryCatch(
  {
    neurocog_data <- NULL
    neurobehav_data <- NULL
    validity_data <- NULL

    if (file.exists("data/neurocog.parquet")) {
      neurocog_data <- arrow::read_parquet(
        "data/neurocog.parquet",
        show_col_types = FALSE
      )
    }

    if (file.exists("data/neurobehav.parquet")) {
      neurobehav_data <- arrow::read_parquet(
        "data/neurobehav.parquet",
        show_col_types = FALSE
      )
    }

    if (file.exists("data/validity.parquet")) {
      validity_data <- arrow::read_parquet(
        "data/validity.parquet",
        show_col_types = FALSE
      )
    }

    if (is.null(neurocog_data) && is.null(neurobehav_data)) {
      cat("⚠ No data files found - skipping domain generation\n")
      quit(save = "no")
    }

    # Load domain configuration
    domain_config <- list(
      "General Cognitive Ability" = list(
        pheno = "iq",
        input_file = "data/neurocog.parquet"
      ),
      "Academic Skills" = list(
        pheno = "academics",
        input_file = "data/neurocog.parquet"
      ),
      "Verbal/Language" = list(
        pheno = "verbal",
        input_file = "data/neurocog.parquet"
      ),
      "Visual Perception/Construction" = list(
        pheno = "spatial",
        input_file = "data/neurocog.parquet"
      ),
      "Memory" = list(pheno = "memory", input_file = "data/neurocog.parquet"),
      "Attention/Executive" = list(
        pheno = "executive",
        input_file = "data/neurocog.parquet"
      ),
      "Motor" = list(pheno = "motor", input_file = "data/neurocog.parquet"),
      "Social Cognition" = list(
        pheno = "social",
        input_file = "data/neurocog.parquet"
      ),
      "ADHD" = list(pheno = "adhd", input_file = "data/neurobehav.parquet"),
      "Behavioral/Emotional/Social" = list(
        pheno = "emotion",
        input_file = "data/neurobehav.parquet"
      ),
      # "Psychiatric Disorders" = list(
      #   pheno = "emotion",
      #   input_file = "data/neurobehav.parquet"
      # ),
      # "Personality Disorders" = list(
      #   pheno = "emotion",
      #   input_file = "data/neurobehav.parquet"
      # ),
      # "Psychosocial Problems" = list(
      #   pheno = "emotion",
      #   input_file = "data/neurobehav.parquet"
      # ),
      # "Substance Use" = list(
      #   pheno = "emotion",
      #   input_file = "data/neurobehav.parquet"
      # ),
      "Emotional/Behavioral/Personality" = list(
        pheno = "emotion",
        input_file = "data/neurobehav.parquet"
      ),
      "Adaptive Functioning" = list(
        pheno = "adaptive",
        input_file = "data/neurobehav.parquet"
      ),
      "Daily Living" = list(
        pheno = "daily_living",
        input_file = "data/neurobehav.parquet"
      )
    )

    # Get domains with data using validation
    valid_domains_only <- .get_domains_with_data(
      neurocog_data,
      neurobehav_data,
      domain_config
    )

    if (length(valid_domains_only) == 0) {
      cat("⚠ No domains found with sufficient data\n")
      quit(save = "no")
    }

    cat("Found", length(valid_domains_only), "domains with data\n")

    # Track generated files for text file creation
    generated_qmd_files <- character(0)

    # Only generate files for domains that have data
    for (domain_name in names(valid_domains_only)) {
      domain_info <- valid_domains_only[[domain_name]]
      config <- domain_info$config

      cat("Generating files for", domain_name, "(", config$pheno, ")...\n")

      tryCatch(
        {
          processor <- DomainProcessorR6$new(
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
              generated_qmd_files <- c(generated_qmd_files, generated_file)
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

    # Generate placeholder text files for all created QMD files
    if (length(generated_qmd_files) > 0) {
      text_files <- generate_text_files(generated_qmd_files, verbose = TRUE)
      if (length(text_files) > 0) {
        cat("\n✓ Created", length(text_files), "placeholder text files\n")
      }
    }

    cat("\nValidated domain file generation complete!\n")
  },
  error = function(e) {
    cat("✗ Error in domain generation:", e$message, "\n")
  }
)

# Restore warning level
options(warn = old_warn)
