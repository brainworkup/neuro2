#!/usr/bin/env Rscript

#' Batch Domain Processor
#'
#' This script processes all domains with available data and generates
#' QMD files for each domain using DomainProcessorR6
#'
#' @description
#' 1. Scans data files to determine which domains have data
#' 2. Creates DomainProcessorR6 objects for each domain
#' 3. Generates QMD files following the memory template structure
#' 4. Creates an include list for the main template

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
  if (requireNamespace("arrow", quietly = TRUE)) {
    library(arrow)
  }
})

# Source the DomainProcessorR6 class
source(here::here("R", "DomainProcessorR6.R"))

#' Domain registry with mappings
get_domain_registry <- function() {
  list(
    # Cognitive domains
    iq = list(
      domains = "General Cognitive Ability",
      pheno = "iq",
      data_source = "neurocog",
      number = "01"
    ),
    academics = list(
      domains = "Academic Skills",
      pheno = "academics",
      data_source = "neurocog",
      number = "02"
    ),
    verbal = list(
      domains = "Verbal/Language",
      pheno = "verbal",
      data_source = "neurocog",
      number = "03"
    ),
    spatial = list(
      domains = "Visual Perception/Construction",
      pheno = "spatial",
      data_source = "neurocog",
      number = "04"
    ),
    memory = list(
      domains = "Memory",
      pheno = "memory",
      data_source = "neurocog",
      number = "05"
    ),
    executive = list(
      domains = "Attention/Executive",
      pheno = "executive",
      data_source = "neurocog",
      number = "06"
    ),
    motor = list(
      domains = "Motor",
      pheno = "motor",
      data_source = "neurocog",
      number = "07"
    ),
    social = list(
      domains = "Social Cognition",
      pheno = "social",
      data_source = "neurocog",
      number = "08"
    ),

    # Behavioral domains
    adhd = list(
      domains = "ADHD",
      pheno = "adhd",
      data_source = "neurobehav",
      number = "09"
    ),
    emotion_child = list(
      domains = c(
        "Behavioral/Emotional/Social",
        "Personality Disorders",
        "Psychiatric Disorders",
        "Psychosocial Problems",
        "Substance Use"
      ),
      pheno = "emotion",
      data_source = "neurobehav",
      number = "10"
    ),
    emotion_adult = list(
      domains = c(
        "Emotional/Behavioral/Personality",
        "Personality Disorders",
        "Psychiatric Disorders",
        "Psychosocial Problems",
        "Substance Use"
      ),
      pheno = "emotion",
      data_source = "neurobehav",
      number = "10"
    ),
    adaptive = list(
      domains = "Adaptive Functioning",
      pheno = "adaptive",
      data_source = "neurobehav",
      number = "11"
    ),
    daily_living = list(
      domains = "Daily Living",
      pheno = "daily_living",
      data_source = "neurocog",
      number = "12"
    ),

    # Validity
    validity = list(
      domains = c("Performance Validity", "Symptom Validity"),
      pheno = "validity",
      data_source = "validity",
      number = "13"
    )
  )
}

#' Check if a domain has data in the specified file
check_domain_has_data <- function(domain_names, data_file) {
  if (!file.exists(data_file)) {
    return(FALSE)
  }

  # Try to read the file
  data <- tryCatch(
    {
      file_ext <- tools::file_ext(data_file)
      if (file_ext == "parquet") {
        if (requireNamespace("arrow", quietly = TRUE)) {
          arrow::read_parquet(data_file)
        } else {
          return(FALSE)
        }
      } else if (file_ext == "feather") {
        if (requireNamespace("arrow", quietly = TRUE)) {
          arrow::read_feather(data_file)
        } else {
          return(FALSE)
        }
      } else {
        readr::read_csv(data_file, show_col_types = FALSE)
      }
    },
    error = function(e) {
      NULL
    }
  )

  if (is.null(data) || nrow(data) == 0) {
    return(FALSE)
  }

  if (!"domain" %in% names(data)) {
    return(FALSE)
  }

  # Check if any of the domain names exist in the data
  return(any(domain_names %in% data$domain))
}

#' Get available data files
get_data_files <- function() {
  data_dir <- here::here("data")

  # Look for different formats in order of preference
  files <- list()

  for (basename in c("neurocog", "neurobehav", "validity")) {
    # Try parquet first (best performance)
    parquet_file <- file.path(data_dir, paste0(basename, ".parquet"))
    if (file.exists(parquet_file)) {
      files[[basename]] <- parquet_file
      next
    }

    # Try feather
    feather_file <- file.path(data_dir, paste0(basename, ".feather"))
    if (file.exists(feather_file)) {
      files[[basename]] <- feather_file
      next
    }

    # Try CSV
    csv_file <- file.path(data_dir, paste0(basename, ".csv"))
    if (file.exists(csv_file)) {
      files[[basename]] <- csv_file
    }
  }

  files
}

#' Process all domains with available data
process_all_domains <- function(verbose = TRUE) {
  if (verbose) {
    cat("🚀 Starting batch domain processing...\n\n")
  }

  registry <- get_domain_registry()
  data_files <- get_data_files()

  if (length(data_files) == 0) {
    stop("No data files found in data/ directory")
  }

  if (verbose) {
    cat("📁 Found data files:\n")
    for (name in names(data_files)) {
      cat("  -", name, ":", data_files[[name]], "\n")
    }
    cat("\n")
  }

  # Track results
  generated_files <- character()
  failed_domains <- character()

  # Process each domain
  for (domain_key in names(registry)) {
    domain_info <- registry[[domain_key]]
    data_source <- domain_info$data_source

    if (verbose) {
      cat("🔍 Checking domain:", domain_key, "(", domain_info$domains[1], ")\n")
    }

    # Check if we have the required data file
    if (!data_source %in% names(data_files)) {
      if (verbose) {
        cat("  ❌ No data file for source:", data_source, "\n")
      }
      failed_domains <- c(failed_domains, domain_key)
      next
    }

    data_file <- data_files[[data_source]]

    # Check if domain has data
    has_data <- check_domain_has_data(domain_info$domains, data_file)

    if (!has_data) {
      if (verbose) {
        cat("  ❌ No data found for domain\n")
      }
      failed_domains <- c(failed_domains, domain_key)
      next
    }

    if (verbose) {
      cat("  ✅ Data found, creating processor...\n")
    }

    # Create and run processor
    tryCatch(
      {
        processor <- DomainProcessorR6$new(
          domains = domain_info$domains,
          pheno = domain_info$pheno,
          input_file = data_file,
          number = domain_info$number
        )

        # Generate the QMD file
        output_file <- processor$generate_domain_qmd()
        generated_files <- c(generated_files, output_file)

        if (verbose) {
          cat("  📄 Generated:", output_file, "\n")
        }
      },
      error = function(e) {
        if (verbose) {
          cat("  ❌ Error:", e$message, "\n")
        }
        failed_domains <- c(failed_domains, domain_key)
      }
    )

    if (verbose) {
      cat("\n")
    }
  }

  # Report results
  if (verbose) {
    cat("📊 Processing Summary:\n")
    cat("  ✅ Successfully generated:", length(generated_files), "files\n")
    cat("  ❌ Failed domains:", length(failed_domains), "\n")

    if (length(generated_files) > 0) {
      cat("\n📄 Generated files:\n")
      for (file in generated_files) {
        cat("  -", file, "\n")
      }
    }

    if (length(failed_domains) > 0) {
      cat("\n❌ Failed domains:\n")
      for (domain in failed_domains) {
        cat("  -", domain, "\n")
      }
    }
  }

  # Create include list for template
  create_include_list(generated_files, verbose = verbose)

  return(list(generated = generated_files, failed = failed_domains))
}

#' Create include list for main template
create_include_list <- function(generated_files, verbose = TRUE) {
  if (length(generated_files) == 0) {
    if (verbose) {
      cat("\n⚠️  No files to include in template\n")
    }
    return()
  }

  # Create include statements
  includes <- paste0("{{< include ", generated_files, " >}}")

  # Write to include file
  include_file <- here::here("_domain_includes.qmd")
  writeLines(includes, include_file)

  if (verbose) {
    cat("\n📝 Created include file:", include_file, "\n")
    cat("   Add this to your main template:\n")
    cat("   {{< include _domain_includes.qmd >}}\n")
  }

  # Also create a summary for manual inclusion
  summary_file <- here::here("_domain_summary.md")
  summary_content <- c(
    "# Generated Domain Files",
    "",
    "The following domain QMD files were generated:",
    "",
    paste("-", generated_files),
    "",
    "## Include in Template",
    "",
    "Add these includes to your main template file:",
    "",
    "```qmd",
    includes,
    "```"
  )

  writeLines(summary_content, summary_file)

  if (verbose) {
    cat("📋 Created summary file:", summary_file, "\n")
  }
}

#' Main execution function
main <- function() {
  cat("🧠 Neuropsychological Domain Processor\n")
  cat("=====================================\n\n")

  # Process all domains
  results <- process_all_domains(verbose = TRUE)

  cat("\n🎉 Batch processing complete!\n")

  if (length(results$generated) > 0) {
    cat("\nNext steps:\n")
    cat("1. Review generated QMD files\n")
    cat("2. Add domain includes to your main template\n")
    cat("3. Render your report\n")
  } else {
    cat("\n⚠️  No domain files were generated.\n")
    cat("   Check your data files and domain mappings.\n")
  }
}

# Run if called as script
if (!interactive()) {
  main()
}
