#!/usr/bin/env Rscript

# DOMAIN GENERATOR MODULE
# This module generates domain-specific files for the neuropsychological report

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry)
}

log_message("Starting domain generation module", "DOMAINS")

# Source validation module
if (file.exists("validate_domain_data.R")) {
  source("validate_domain_data.R")
} else {
  log_message("Warning: validate_domain_data.R not found, proceeding without validation", "WARNING")
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
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGTR6.R")
source("R/score_type_utils.R")

# Load configuration
config <- yaml::read_yaml("config.yml")
data_dir <- config$data$output_dir
data_format <- config$data$format

# Function to read data based on format
read_data_file <- function(base_name, format = data_format) {
  if (format == "all" || format == "parquet") {
    file_path <- file.path(data_dir, paste0(base_name, ".parquet"))
    if (file.exists(file_path)) {
      log_message(paste("Reading", file_path), "DOMAINS")
      return(arrow::read_parquet(file_path))
    }
  }

  if (format == "all" || format == "feather") {
    file_path <- file.path(data_dir, paste0(base_name, ".feather"))
    if (file.exists(file_path)) {
      log_message(paste("Reading", file_path), "DOMAINS")
      return(arrow::read_feather(file_path))
    }
  }

  if (format == "all" || format == "csv") {
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
# Function to determine patient type (adult or child) based on age
determine_patient_type <- function() {
  # Read config to get patient age
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

  if (!is.null(neurobehav_data) && "domain" %in% names(neurobehav_data)) {
    behav_domains <- unique(neurobehav_data$domain)
    behav_domains <- behav_domains[!is.na(behav_domains)]
    domains <- c(domains, behav_domains)
  }

  domains <- unique(domains)
  log_message(paste("Found", length(domains), "unique domains"), "DOMAINS")
}
  behav_domains <- unique(neurobehav_data$domain)
  behav_domains <- behav_domains[!is.na(behav_domains)]
  domains <- c(domains, behav_domains)
}

domains <- unique(domains)
log_message(paste("Found", length(domains), "unique domains"), "DOMAINS")

# Function to determine patient type (adult or child) based on age
determine_patient_type <- function() {
  # Read config to get patient age
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
# Process domains based on validation results if available
if (exists("valid_domains") && is.list(valid_domains)) {
  # Use validated domains
  for (domain_name in names(valid_domains)) {
    # Skip consolidated emotion domain for now
    if (domain_name == "Emotion_Consolidated") {
      continue
    }
    
    domain_info <- valid_domains[[domain_name]]
    config <- domain_config[[domain_name]]
    
    if (is.null(config)) {
      log_message(paste("No configuration found for domain:", domain_name), "WARNING")
      next
    }
    
    # Skip emotion-related domains - they will be processed together
    if (domain_name %in% emotion_domains) {
      log_message(
        paste(
          "Skipping individual processing of emotion domain:",
          domain_name,
          "- will be processed in consolidated section"
        ),
        "DOMAINS"
      )
      next
    }
    
    # Determine input file
    input_file <- config$input_file
    
    # Check if the input file exists with different formats
    if (!file.exists(input_file)) {
      # Try other formats
      base_name <- gsub("\\.(parquet|feather|csv)$", "", input_file)
      
      if (file.exists(paste0(base_name, ".parquet"))) {
        input_file <- paste0(base_name, ".parquet")
      } else if (file.exists(paste0(base_name, ".feather"))) {
        input_file <- paste0(base_name, ".feather")
      } else if (file.exists(paste0(base_name, ".csv"))) {
        input_file <- paste0(base_name, ".csv")
      } else {
        log_message(paste("Input file not found for domain:", domain_name), "WARNING")
        next
      }
    }
    
    # Create processor
    tryCatch(
      {
        log_message(paste("Processing validated domain:", domain_name), "DOMAINS")
        
        processor <- DomainProcessorR6$new(
          domains = domain_name,
          pheno = config$pheno,
          input_file = input_file
        )
        
        # Load and process data
        processor$load_data()
        processor$filter_by_domain()
        
        # Check if we have data for this domain
        if (is.null(processor$data) || nrow(processor$data) == 0) {
          log_message(paste("No data found for domain:", domain_name), "WARNING")
          next
        }
        
        # Generate domain QMD file
        generated_file <- processor$generate_domain_qmd()
        log_message(paste("Generated:", generated_file), "DOMAINS")
        
        # Also generate text file
        processor$generate_domain_text_qmd()
      },
      error = function(e) {
        log_message(
          paste("Error processing domain", domain_name, ":", e$message),
          "ERROR"
        )
      }
    )
  }
} else {
  # Original logic (fallback)
  # Generate domain files using R6 class
  for (domain in domains) {
    # Skip emotion-related domains - they will be processed together in the special handling section
    if (domain %in% emotion_domains) {
      log_message(
# Special handling for multi-rater domains (emotion and ADHD)
# Check if we should process emotion domains
should_process_emotion <- FALSE
emotion_domains_to_process <- character()

if (exists("valid_domains") && "Emotion_Consolidated" %in% names(valid_domains)) {
  should_process_emotion <- TRUE
  emotion_domains_to_process <- valid_domains[["Emotion_Consolidated"]]$domains
} else {
  # Check the traditional way
  emotion_domains_present <- intersect(domains, emotion_domains)
  
  # Check if any emotion domains have data
  emotion_has_data <- FALSE
  for (emotion_domain in emotion_domains_present) {
    if (check_domain_has_data(emotion_domain, neurobehav_data)) {
      emotion_has_data <- TRUE
      emotion_domains_to_process <- c(emotion_domains_to_process, emotion_domain)
    }
  }
  
  should_process_emotion <- length(emotion_domains_to_process) > 0 && emotion_has_data
}
        processor <- DomainProcessorR6$new(
          domains = emotion_domains_to_process,
          pheno = "emotion",
          input_file = "data/neurobehav.parquet"
        )uld_process_emotion) {
    }

    # Determine input file
    input_file <- config$input_file

    # Check if the input file exists with different formats
    if (!file.exists(input_file)) {
      # Try other formats
      base_name <- gsub("\\.(parquet|feather|csv)$", "", input_file)

      if (file.exists(paste0(base_name, ".parquet"))) {
        input_file <- paste0(base_name, ".parquet")
      } else if (file.exists(paste0(base_name, ".feather"))) {
          # Generate rater-specific text files only if data exists
          if (processor$check_rater_data_exists("self")) {
            processor$generate_domain_text_qmd(report_type = "self")
          }
          if (processor$check_rater_data_exists("parent")) {
            processor$generate_domain_text_qmd(report_type = "parent")
          }
          if (processor$check_rater_data_exists("teacher")) {
            processor$generate_domain_text_qmd(report_type = "teacher")
          }
        log_message(paste("Input file not found for domain:", domain), "WARNING")
        next
      }
    }

  # Generate ADHD child files
  adhd_should_process <- FALSE
  if (exists("valid_domains") && "ADHD" %in% names(valid_domains)) {
    adhd_should_process <- TRUE
  } else {
    adhd_should_process <- "ADHD" %in% domains && check_domain_has_data("ADHD", neurobehav_data)
  }
  
  if (adhd_should_process) {
    if (grepl("neurocog", input_file)) {
      has_data <- check_domain_has_data(domain, neurocog_data)
    } else if (grepl("neurobehav", input_file)) {
      has_data <- check_domain_has_data(domain, neurobehav_data)
    }
    
    if (!has_data) {
      log_message(paste("No data found for domain:", domain, "- skipping file generation"), "WARNING")
      next
    }

    # Create processor
    tryCatch(
      {
        log_message(paste("Processing domain:", domain), "DOMAINS")

        processor <- DomainProcessorR6$new(
          domains = domain,
          pheno = config$pheno,
          input_file = input_file
        )

        # Load and process data
        processor$load_data()
} else {
  # Generate adult-specific files
  # Generate emotion adult files if emotion domains should be processed
  if (should_process_emotion) {
      error = function(e) {
        log_message(
          paste("Error processing domain", domain, ":", e$message),
          "ERROR"
        )
      }
    )
  }
}       log_message(paste("No data found for domain:", domain), "WARNING")
        next
      }

      # Generate domain QMD file
      generated_file <- processor$generate_domain_qmd()
      log_message(paste("Generated:", generated_file), "DOMAINS")

      # Also generate text file
      processor$generate_domain_text_qmd()
    },
    error = function(e) {
      log_message(
        paste("Error processing domain", domain, ":", e$message),
        "ERROR"
      )
    }
  )
}

# Special handling for multi-rater domains (emotion and ADHD)
# Generate child-specific files if patient is a child
if (patient_type == "child") {
  # Generate emotion child files if any emotion domains are present
  emotion_domains_present <- intersect(domains, emotion_domains)
  
  # Check if any emotion domains have data
  emotion_has_data <- FALSE
  for (emotion_domain in emotion_domains_present) {
    if (check_domain_has_data(emotion_domain, neurobehav_data)) {
      emotion_has_data <- TRUE
      break
    }
  }
  
  if (length(emotion_domains_present) > 0 && emotion_has_data) {
    tryCatch(
      {
  # Generate ADHD adult files
  adhd_should_process <- FALSE
  if (exists("valid_domains") && "ADHD" %in% names(valid_domains)) {
    adhd_should_process <- TRUE
  } else {
    adhd_should_process <- "ADHD" %in% domains && check_domain_has_data("ADHD", neurobehav_data)
  }
  
  if (adhd_should_process) {
          "DOMAINS"
        )

        processor <- DomainProcessorR6$new(
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

          # Generate child-specific emotion file
          generated_file <- processor$generate_domain_qmd(is_child = TRUE)
          log_message(paste("Generated:", generated_file), "DOMAINS")

          # Generate rater-specific text files
          processor$generate_domain_text_qmd(report_type = "self")
          processor$generate_domain_text_qmd(report_type = "parent")
          processor$generate_domain_text_qmd(report_type = "teacher")
        }
      },
      error = function(e) {
        log_message(
          paste("Error processing emotion child domain:", e$message),
          "ERROR"
        )
      }
    )
  }

  # Generate ADHD child files
  if ("ADHD" %in% domains && check_domain_has_data("ADHD", neurobehav_data)) {
    tryCatch(
      {
        log_message("Processing ADHD domain for child", "DOMAINS")

        processor <- DomainProcessorR6$new(
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

          # Generate child-specific ADHD file
          generated_file <- processor$generate_domain_qmd(is_child = TRUE)
          log_message(paste("Generated:", generated_file), "DOMAINS")
        }
      },
      error = function(e) {
        log_message(
          paste("Error processing ADHD child domain:", e$message),
          "ERROR"
        )
      }
    )
  }
} else {
  # Generate adult-specific files
  # Generate emotion adult files if any emotion domains are present
  emotion_domains_present <- intersect(domains, emotion_domains)
  
  # Check if any emotion domains have data
  emotion_has_data <- FALSE
  for (emotion_domain in emotion_domains_present) {
    if (check_domain_has_data(emotion_domain, neurobehav_data)) {
      emotion_has_data <- TRUE
      break
    }
  }
  
  if (length(emotion_domains_present) > 0 && emotion_has_data) {
    tryCatch(
      {
        log_message(
          "Processing consolidated emotion domain for adult",
          "DOMAINS"
        )

        processor <- DomainProcessorR6$new(
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

          # Generate adult-specific emotion file
          generated_file <- processor$generate_domain_qmd(is_child = FALSE)
          log_message(paste("Generated:", generated_file), "DOMAINS")
        }
      },
      error = function(e) {
        log_message(
          paste("Error processing emotion adult domain:", e$message),
          "ERROR"
        )
      }
    )
  }

  # Generate ADHD adult files
  if ("ADHD" %in% domains && check_domain_has_data("ADHD", neurobehav_data)) {
    tryCatch(
      {
        log_message("Processing ADHD domain for adult", "DOMAINS")

        processor <- DomainProcessorR6$new(
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

          # Generate adult-specific ADHD file
          generated_file <- processor$generate_domain_qmd(is_child = FALSE)
          log_message(paste("Generated:", generated_file), "DOMAINS")
        }
      },
      error = function(e) {
        log_message(
          paste("Error processing ADHD adult domain:", e$message),
          "ERROR"
        )
      }
    )
  }
}

# List generated files
log_message("Listing generated domain files:", "DOMAINS")
domain_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$")
for (file in domain_files) {
  log_message(paste("  -", file), "DOMAINS")
}

log_message("Domain generation complete", "DOMAINS")
# Script completed successfully
