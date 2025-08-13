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
r6_files <- c(
  "R/DomainProcessorR6.R",
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
  "Memory" = list(
    pheno = "memory",
    input_file = "data/neurocog.parquet"
  ),
  "Attention/Executive" = list(
    pheno = "executive",
    input_file = "data/neurocog.parquet"
  ),
  "Motor" = list(
    pheno = "motor",
    input_file = "data/neurocog.parquet"
  ),
  "Social Cognition" = list(
    pheno = "social",
    input_file = "data/neurocog.parquet"
  ),
  "ADHD" = list(
    pheno = "adhd",
    input_file = "data/neurobehav.parquet"
  ),
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

# Function to process a single domain
process_single_domain <- function(domain_name, config) {
  log_message(paste("Processing domain:", domain_name), "DOMAINS")
  
  # Determine input file with fallback options
  input_file <- config$input_file
  
  if (!file.exists(input_file)) {
    base_name <- gsub("\\.(parquet|feather|csv)$", "", input_file)
    
    if (file.exists(paste0(base_name, ".parquet"))) {
      input_file <- paste0(base_name, ".parquet")
    } else if (file.exists(paste0(base_name, ".feather"))) {
      input_file <- paste0(base_name, ".feather")  
    } else if (file.exists(paste0(base_name, ".csv"))) {
      input_file <- paste0(base_name, ".csv")
    } else {
      log_message(paste("Input file not found for domain:", domain_name), "WARNING")
      return(FALSE)
    }
  }
  
  # Check if domain has data
  data_source <- if (grepl("neurocog", input_file)) neurocog_data else neurobehav_data
  if (!check_domain_has_data(domain_name, data_source)) {
    log_message(paste("No data found for domain:", domain_name, "- skipping"), "WARNING")
    return(FALSE)
  }
  
  # Create processor
  tryCatch({
    processor <- DomainProcessorR6$new(
      domains = domain_name,
      pheno = config$pheno,
      input_file = input_file
    )
    
    # Load and process data
    processor$load_data()
    processor$filter_by_domain()
    
    if (is.null(processor$data) || nrow(processor$data) == 0) {
      log_message(paste("No data found for domain:", domain_name), "WARNING")
      return(FALSE)
    }
    
    # Generate domain QMD file
    generated_file <- processor$generate_domain_qmd()
    log_message(paste("Generated:", generated_file), "DOMAINS")
    
    # Generate text file
    processor$generate_domain_text_qmd()
    
    # Generate rater-specific text files if applicable
    if (domain_name %in% c("ADHD", emotion_domains)) {
      raters <- c("self", "parent", "teacher")
      for (rater in raters) {
        if (processor$check_rater_data_exists(rater)) {
          processor$generate_domain_text_qmd(report_type = rater)
        }
      }
    }
    
    return(TRUE)
  }, error = function(e) {
    log_message(paste("Error processing domain", domain_name, ":", e$message), "ERROR")
    return(FALSE)
  })
}

# Function to process emotion domains (consolidated)
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
  
  tryCatch({
    age_type <- if (is_child) "child" else "adult"
    log_message(paste("Processing consolidated emotion domains for", age_type), "DOMAINS")
    
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
  }, error = function(e) {
    log_message(paste("Error processing emotion domains:", e$message), "ERROR")
    return(FALSE)
  })
}

# Function to process ADHD domain
process_adhd_domain <- function(is_child = TRUE) {
  if (!"ADHD" %in% domains) {
    return(FALSE)
  }
  
  if (!check_domain_has_data("ADHD", neurobehav_data)) {
    return(FALSE)
  }
  
  tryCatch({
    age_type <- if (is_child) "child" else "adult"
    log_message(paste("Processing ADHD domain for", age_type), "DOMAINS")
    
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
      
      # Generate age-specific ADHD file
      generated_file <- processor$generate_domain_qmd(is_child = is_child)
      log_message(paste("Generated:", generated_file), "DOMAINS")
      
      return(TRUE)
    }
    
    return(FALSE)
  }, error = function(e) {
    log_message(paste("Error processing ADHD domain:", e$message), "ERROR")
    return(FALSE)
  })
}

# Main processing logic
main_processing <- function() {
  # Process domains based on validation results if available
  if (exists("valid_domains") && is.list(valid_domains)) {
    log_message("Using validated domains", "DOMAINS")
    
    for (domain_name in names(valid_domains)) {
      # Skip consolidated emotion domain - handled separately
      if (domain_name == "Emotion_Consolidated") {
        next
      }
      
      # Skip individual emotion domains - processed together
      if (domain_name %in% emotion_domains) {
        log_message(paste("Skipping individual emotion domain:", domain_name), "DOMAINS")
        next
      }
      
      config <- domain_config[[domain_name]]
      if (!is.null(config)) {
        process_single_domain(domain_name, config)
      }
    }
  } else {
    log_message("Processing all available domains", "DOMAINS")
    
    for (domain in domains) {
      # Skip individual emotion domains - processed together
      if (domain %in% emotion_domains) {
        log_message(paste("Skipping individual emotion domain:", domain), "DOMAINS")
        next
      }
      
      config <- domain_config[[domain]]
      if (!is.null(config)) {
        process_single_domain(domain, config)
      }
    }
  }
  
  # Handle multi-rater domains based on patient type
  is_child <- (patient_type == "child")
  
  # Process consolidated emotion domains
  process_emotion_domains(is_child = is_child)
  
  # Process ADHD domain
  process_adhd_domain(is_child = is_child)
}

# Execute main processing
main_processing()

# List generated files
log_message("Listing generated domain files:", "DOMAINS")
domain_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$")

if (length(domain_files) > 0) {
  for (file in domain_files) {
    log_message(paste("  -", file), "DOMAINS")
  }
} else {
  log_message("  No domain files generated", "WARNING")
}

log_message("Domain generation complete", "DOMAINS")