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

  # Special handling for emotion domains
  emotion_domains_processed <- FALSE

  # Process each domain
  for (domain_key in names(registry)) {
    domain_info <- registry[[domain_key]]
    data_source <- domain_info$data_source

    if (verbose) {
      cat("🔍 Checking domain:", domain_key, "(", domain_info$domains[1], ")\n")
    }

    # Skip individual emotion processing if we already processed them together
    if (domain_key %in% c("emotion_child", "emotion_adult")) {
      if (emotion_domains_processed) {
        if (verbose) {
          cat("  ⏭️  Emotion domains already processed together\n")
        }
        next
      }

      # Process emotion domains together
      emotion_result <- process_emotion_domains(data_files, registry, verbose)
      if (!is.null(emotion_result)) {
        generated_files <- c(generated_files, emotion_result)
        emotion_domains_processed <- TRUE
        if (verbose) {
          cat("  ✅ Generated:", emotion_result, "\n")
        }
      } else {
        failed_domains <- c(failed_domains, domain_key)
      }
      next
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

# New function to handle emotion domains intelligently
process_emotion_domains <- function(data_files, registry, verbose = TRUE) {
  # Check if we have neurobehav data
  if (!"neurobehav" %in% names(data_files)) {
    if (verbose) {
      cat("  ❌ No neurobehavioral data file found\n")
    }
    return(NULL)
  }

  data_file <- data_files[["neurobehav"]]

  # Get both child and adult emotion domain definitions
  child_domains <- registry[["emotion_child"]]$domains
  adult_domains <- registry[["emotion_adult"]]$domains

  # Check which emotion domains have data
  child_has_data <- check_domain_has_data(child_domains, data_file)
  adult_has_data <- check_domain_has_data(adult_domains, data_file)

  if (!child_has_data && !adult_has_data) {
    if (verbose) {
      cat("  ❌ No data found for any emotion domains\n")
    }
    return(NULL)
  }

  # Determine which type to process based on available data
  if (child_has_data) {
    emotion_info <- registry[["emotion_child"]]
    if (verbose) {
      cat("  🔍 Processing child emotion domains\n")
    }
  } else {
    emotion_info <- registry[["emotion_adult"]]
    if (verbose) {
      cat("  🔍 Processing adult emotion domains\n")
    }
  }

  # Create processor with the appropriate domains
  tryCatch(
    {
      processor <- DomainProcessorR6$new(
        domains = emotion_info$domains,
        pheno = emotion_info$pheno,
        input_file = data_file,
        number = emotion_info$number
      )

      # Load data to help with age detection
      processor$load_data()
      processor$filter_by_domain()

      # Generate the QMD file (this will automatically detect child vs adult)
      output_file <- processor$generate_domain_qmd()
      return(output_file)
    },
    error = function(e) {
      if (verbose) {
        cat("  ❌ Error processing emotion domains:", e$message, "\n")
      }
      return(NULL)
    }
  )
}


# Run if called as script
if (!interactive()) {
  main()
}
