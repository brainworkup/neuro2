#!/usr/bin/env Rscript

# IMPROVED DOMAIN GENERATOR MODULE
# This module generates domain-specific files only for domains with actual data

# Source the validation functions
source("R/domain_validation_utils.R") # Contains the validation functions from above

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry)
}

log_message("Starting domain generation module", "DOMAINS")

# Function to check if domain has data
check_domain_has_data <- function(domain_name, data) {
  if (is.null(data) || nrow(data) == 0) {
    return(FALSE)
  }
  if (!"domain" %in% names(data)) {
    return(FALSE)
  }
  return(domain_name %in% data$domain)
}

# Source validation module
if (file.exists("validate_domain_data.R")) {
  source("validate_domain_data.R")
} else {
  log_message(
    "Warning: validate_domain_data.R not found, proceeding without validation",
    "WARNING"
  )
}

# Load required packages
required_packages <- c(
  "dplyr",
  "readr",
  "arrow",
  "yaml",
  "R6",
  "here",
  "gt",
  "ggplot2"
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    log_message(paste("Installing package:", pkg), "DOMAINS")
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE, quietly = TRUE)
}

# Source R6 classes
r6_files <- c(
  "R/DomainProcessorR6Combo.R",
  "R/NeuropsychResultsR6.R",
  "R/DotplotR6.R",
  "R/TableGTR6.R",
  "R/score_type_utils.R"
)

for (file in r6_files) {
  if (file.exists(file)) {
    source(file)
  } else {
    log_message(paste("Warning: Required file not found:", file), "WARNING")
  }
}

# Load configuration
config <- yaml::read_yaml("config.yml")
data_dir <- config$data$output_dir
data_format <- config$data$format

# Function to read data based on format
read_data_file <- function(base_name, format = data_format) {
  # Try parquet first
  if (format %in% c("all", "parquet")) {
    file_path <- file.path(data_dir, paste0(base_name, ".parquet"))
    if (file.exists(file_path)) {
      log_message(paste("Reading", file_path), "DOMAINS")
      return(arrow::read_parquet(file_path))
    }
  }

  # Try feather
  if (format %in% c("all", "feather")) {
    file_path <- file.path(data_dir, paste0(base_name, ".feather"))
    if (file.exists(file_path)) {
      log_message(paste("Reading", file_path), "DOMAINS")
      return(arrow::read_feather(file_path))
    }
  }

  # Try CSV
  if (format %in% c("all", "csv")) {
    file_path <- file.path(data_dir, paste0(base_name, ".csv"))
    if (file.exists(file_path)) {
      log_message(paste("Reading", file_path), "DOMAINS")
      return(readr::read_csv(file_path, show_col_types = FALSE))
    }
  }

  log_message(paste("Could not find data file for", base_name), "ERROR")
  return(NULL)
}

# Read the neurocog and neurobehav data
neurocog_data <- read_data_file("neurocog")
neurobehav_data <- read_data_file("neurobehav")

# Get unique domains from both datasets
domains <- character()

if (!is.null(neurocog_data) && "domain" %in% names(neurocog_data)) {
  cog_domains <- unique(neurocog_data$domain)
  cog_domains <- cog_domains[!is.na(cog_domains)]
  domains <- c(domains, cog_domains)
}

if (!is.null(neurobehav_data) && "domain" %in% names(neurobehav_data)) {
  behav_domains <- unique(neurobehav_data$domain)
  behav_domains <- behav_domains[!is.na(behav_domains)]
  domains <- c(domains, behav_domains)
}

domains <- unique(domains)
log_message(paste("Found", length(domains), "unique domains"), "DOMAINS")

# Function to determine patient type (adult or child) based on age
determine_patient_type <- function() {
  config <- yaml::read_yaml("config.yml")
  age <- config$patient$age

  # Default to child if age is not specified
  if (is.null(age)) {
    return("child")
  }

  # Determine type based on age
  if (age >= 18) {
    return("adult")
  } else {
    return("child")
  }
}

# Get patient type
patient_type <- determine_patient_type()
log_message(paste("Determined patient type:", patient_type), "DOMAINS")

# Map domains to phenotypes and file names
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
    input_file = "data/neurocog.parquet"
  ),
  "Psychiatric Disorders" = list(
    pheno = "emotion",
    input_file = "data/neurobehav.parquet"
  ),
  "Personality Disorders" = list(
    pheno = "emotion",
    input_file = "data/neurobehav.parquet"
  ),
  "Substance Use" = list(
    pheno = "emotion",
    input_file = "data/neurobehav.parquet"
  ),
  "Psychosocial Problems" = list(
    pheno = "emotion",
    input_file = "data/neurobehav.parquet"
  )
)

# Define emotion-related domains that should be processed together
emotion_domains <- c(
  "Behavioral/Emotional/Social",
  "Emotional/Behavioral/Personality",
  "Psychiatric Disorders",
  "Personality Disorders",
  "Substance Use",
  "Psychosocial Problems"
)

# Function to process a single domain with proper validation
process_single_domain_validated <- function(
  domain_name,
  config,
  neurocog_data,
  neurobehav_data
) {
  log_message(paste("Validating domain:", domain_name), "DOMAINS")

  # Determine data source
  data_source <- if (grepl("neurocog", config$input_file)) {
    neurocog_data
  } else {
    neurobehav_data
  }

  # Validate data exists BEFORE processing
  validation <- validate_domain_data_exists(domain_name, data_source)

  if (!validation$has_data) {
    log_message(
      paste("Skipping", domain_name, "-", validation$message),
      "DOMAINS"
    )
    return(FALSE)
  }

  log_message(
    paste(
      "Processing domain:",
      domain_name,
      "- has",
      validation$row_count,
      "rows"
    ),
    "DOMAINS"
  )

  # Proceed with processing only if data exists
  tryCatch(
    {
      processor <- DomainProcessorR6Combo$new(
        domains = domain_name,
        pheno = config$pheno,
        input_file = config$input_file
      )

      # Load and validate data again in processor
      processor$load_data()
      processor$filter_by_domain()

      if (is.null(processor$data) || nrow(processor$data) == 0) {
        log_message(
          paste("No valid data after filtering for:", domain_name),
          "WARNING"
        )
        return(FALSE)
      }

      # Generate domain files
      generated_file <- processor$generate_domain_qmd()
      log_message(paste("Generated:", generated_file), "DOMAINS")

      # Generate text files
      processor$generate_domain_text_qmd()

      # Generate rater-specific text files if applicable
      if (domain_name %in% c("ADHD", emotion_domains)) {
        raters <- c("self", "parent", "teacher")
        for (rater in raters) {
          if (
            processor$check_rater_data_exists &&
              processor$check_rater_data_exists(rater)
          ) {
            processor$generate_domain_text_qmd(report_type = rater)
          }
        }
      }

      return(TRUE)
    },
    error = function(e) {
      log_message(
        paste("Error processing domain", domain_name, ":", e$message),
        "ERROR"
      )
      return(FALSE)
    }
  )
}

# # Function to process emotion domains (consolidated)
process_emotion_domains <- function(is_child = TRUE) {
  emotion_domains_present <- intersect(domains, emotion_domains)

  if (length(emotion_domains_present) == 0) {
    return(FALSE)
  }

  # Check if any emotion domains have data
  emotion_has_data <- any(sapply(emotion_domains_present, function(d) {
    check_domain_has_data(d, neurobehav_data)
  }))

  if (!emotion_has_data) {
    return(FALSE)
  }

  tryCatch(
    {
      age_type <- if (is_child) "child" else "adult"
      log_message(
        paste("Processing consolidated emotion domains for", age_type),
        "DOMAINS"
      )

      processor <- DomainProcessorR6Combo$new(
        domains = emotion_domains_present,
        pheno = "emotion",
        input_file = "data/neurobehav.parquet"
      )

      processor$load_data()
      processor$filter_by_domain()

      if (!is.null(processor$data) && nrow(processor$data) > 0) {
        # Process and save data
        processor$select_columns()
        processor$save_data()

        # Generate age-specific emotion file
        generated_file <- processor$generate_domain_qmd(is_child = is_child)
        log_message(paste("Generated:", generated_file), "DOMAINS")

        # Generate rater-specific text files
        raters <- if (is_child) c("self", "parent", "teacher") else c("self")
        for (rater in raters) {
          processor$generate_domain_text_qmd(report_type = rater)
        }

        return(TRUE)
      }

      return(FALSE)
    },
    error = function(e) {
      log_message(
        paste("Error processing emotion domains:", e$message),
        "ERROR"
      )
      return(FALSE)
    }
  )
}

# Function to process ADHD domain
process_adhd_domain <- function(is_child = TRUE) {
  if (!"ADHD" %in% domains) {
    return(FALSE)
  }

  if (!check_domain_has_data("ADHD", neurobehav_data)) {
    return(FALSE)
  }

  tryCatch(
    {
      age_type <- if (is_child) "child" else "adult"
      log_message(paste("Processing ADHD domain for", age_type), "DOMAINS")

      processor <- DomainProcessorR6Combo$new(
        domains = "ADHD",
        pheno = "adhd",
        input_file = "data/neurobehav.parquet"
      )

      processor$load_data()
      processor$filter_by_domain()

      if (!is.null(processor$data) && nrow(processor$data) > 0) {
        # Process and save data
        processor$select_columns()
        processor$save_data()

        # Generate age-specific ADHD file
        generated_file <- processor$generate_domain_qmd(is_child = is_child)
        log_message(paste("Generated:", generated_file), "DOMAINS")

        return(TRUE)
      }

      return(FALSE)
    },
    error = function(e) {
      log_message(paste("Error processing ADHD domain:", e$message), "ERROR")
      return(FALSE)
    }
  )
}

# Improved main processing logic
main_processing_improved <- function() {
  log_message("Starting improved domain processing with validation", "DOMAINS")

  # Get only domains with actual data
  domains_with_data <- get_domains_with_data(
    neurocog_data,
    neurobehav_data,
    domain_config
  )

  if (length(domains_with_data) == 0) {
    log_message("No domains found with valid data", "WARNING")
    return()
  }

  log_message(
    paste("Found", length(domains_with_data), "domains with data:"),
    "DOMAINS"
  )
  for (name in names(domains_with_data)) {
    log_message(paste("  -", name), "DOMAINS")
  }

  # Process only domains with data
  processed_count <- 0

  for (domain_name in names(domains_with_data)) {
    # Skip consolidated emotion domain - handled separately
    if (domain_name == "Emotion_Consolidated") {
      next
    }

    # Skip individual emotion domains - processed together
    if (domain_name %in% emotion_domains) {
      log_message(
        paste("Will process", domain_name, "as part of emotion consolidation"),
        "DOMAINS"
      )
      next
    }

    config <- domains_with_data[[domain_name]]$config
    success <- process_single_domain_validated(
      domain_name,
      config,
      neurocog_data,
      neurobehav_data
    )

    if (success) {
      processed_count <- processed_count + 1
    }
  }

  # Handle multi-rater domains with validation
  is_child <- (patient_type == "child")

  # Process consolidated emotion domains only if any emotion domain has data
  emotion_domains_with_data <- intersect(
    names(domains_with_data),
    emotion_domains
  )
  if (length(emotion_domains_with_data) > 0) {
    log_message("Processing consolidated emotion domains", "DOMAINS")
    emotion_success <- process_emotion_domains_validated(
      is_child,
      emotion_domains_with_data,
      neurobehav_data
    )
    if (emotion_success) processed_count <- processed_count + 1
  }

  # Process ADHD domain only if it has data
  if ("ADHD" %in% names(domains_with_data)) {
    log_message("Processing ADHD domain", "DOMAINS")
    adhd_success <- process_adhd_domain_validated(is_child, neurobehav_data)
    if (adhd_success) processed_count <- processed_count + 1
  }

  log_message(
    paste("Successfully processed", processed_count, "domains"),
    "DOMAINS"
  )
}

# Validated emotion domain processing
process_emotion_domains_validated <- function(
  is_child,
  emotion_domains_present,
  neurobehav_data
) {
  # Validate that emotion domains actually have data
  combined_validation <- validate_domain_data_exists(
    paste(emotion_domains_present, collapse = " OR "),
    neurobehav_data %>% filter(domain %in% emotion_domains_present)
  )

  if (!combined_validation$has_data) {
    log_message("No data found for any emotion domains - skipping", "DOMAINS")
    return(FALSE)
  }

  tryCatch(
    {
      age_type <- if (is_child) "child" else "adult"
      log_message(
        paste(
          "Processing",
          combined_validation$row_count,
          "emotion records for",
          age_type
        ),
        "DOMAINS"
      )

      processor <- DomainProcessorR6Combo$new(
        domains = emotion_domains_present,
        pheno = "emotion",
        input_file = "data/neurobehav.parquet"
      )

      processor$load_data()
      processor$filter_by_domain()

      if (!is.null(processor$data) && nrow(processor$data) > 0) {
        processor$select_columns()
        processor$save_data()

        # FIXED: Use the updated generate_domain_qmd method without is_child parameter
        # The method automatically detects child vs adult emotion type
        generated_file <- processor$generate_domain_qmd(
          domain_name = emotion_domains_present[1] # Use first domain as name
        )
        log_message(paste("Generated:", generated_file), "DOMAINS")

        return(TRUE)
      }

      return(FALSE)
    },
    error = function(e) {
      log_message(
        paste("Error processing emotion domains:", e$message),
        "ERROR"
      )
      return(FALSE)
    }
  )
}

# Validated ADHD domain processing
process_adhd_domain_validated <- function(is_child, neurobehav_data) {
  validation <- validate_domain_data_exists("ADHD", neurobehav_data)

  if (!validation$has_data) {
    log_message("No ADHD data found - skipping", "DOMAINS")
    return(FALSE)
  }

  tryCatch(
    {
      age_type <- if (is_child) "child" else "adult"
      log_message(
        paste("Processing", validation$row_count, "ADHD records for", age_type),
        "DOMAINS"
      )

      processor <- DomainProcessorR6Combo$new(
        domains = "ADHD",
        pheno = "adhd",
        input_file = "data/neurobehav.parquet"
      )

      processor$load_data()
      processor$filter_by_domain()

      if (!is.null(processor$data) && nrow(processor$data) > 0) {
        processor$select_columns()
        processor$save_data()

        # FIXED: Use the updated generate_domain_qmd method
        # The method automatically detects child vs adult ADHD type
        generated_file <- processor$generate_domain_qmd(domain_name = "ADHD")
        log_message(paste("Generated:", generated_file), "DOMAINS")

        return(TRUE)
      }

      return(FALSE)
    },
    error = function(e) {
      log_message(paste("Error processing ADHD domain:", e$message), "ERROR")
      return(FALSE)
    }
  )
}
