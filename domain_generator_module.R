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

# Load required packages
required_packages <- c("dplyr", "readr", "arrow", "yaml", "R6", "here", "gt", "ggplot2")
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
source("R/TableGT_ModifiedR6.R")
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
neurobehav_data <- read_data_file("neurobehav")

if (is.null(neurocog_data) && is.null(neurobehav_data)) {
  log_message("No data available for domain generation", "ERROR")
  stop("No data available for domain generation")
}

# Get unique domains
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
    input_file = "data/neurobehav.parquet"
  )
)

# Generate domain files using R6 class
for (domain in domains) {
  # Get config for this domain
  config <- domain_config[[domain]]
  
  if (is.null(config)) {
    log_message(paste("No configuration found for domain:", domain), "WARNING")
    
    # Try to map behavioral domains to emotion
    if (domain %in% c("Psychiatric Symptoms", "Substance Use", "Personality Disorders", "Psychosocial Problems")) {
      config <- list(
        pheno = "emotion",
        input_file = "data/neurobehav.parquet"
      )
    } else {
      next
    }
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
      log_message(paste("Input file not found for domain:", domain), "WARNING")
      next
    }
  }
  
  # Create processor
  tryCatch({
    log_message(paste("Processing domain:", domain), "DOMAINS")
    
    processor <- DomainProcessorR6$new(
      domains = domain,
      pheno = config$pheno,
      input_file = input_file
    )
    
    # Load and process data
    processor$load_data()
    processor$filter_by_domain()
    
    # Check if we have data for this domain
    if (is.null(processor$data) || nrow(processor$data) == 0) {
      log_message(paste("No data found for domain:", domain), "WARNING")
      next
    }
    
    # Generate domain QMD file
    generated_file <- processor$generate_domain_qmd()
    log_message(paste("Generated:", generated_file), "DOMAINS")
    
    # Also generate text file
    processor$generate_domain_text_qmd()
    
  }, error = function(e) {
    log_message(paste("Error processing domain", domain, ":", e$message), "ERROR")
  })
}

# Special handling for multi-rater domains (emotion and ADHD)
# Generate child-specific files if patient is a child
if (patient_type == "child") {
  # Generate emotion child files
  if ("Behavioral/Emotional/Social" %in% domains) {
    tryCatch({
      log_message("Processing emotion domain for child", "DOMAINS")
      
      processor <- DomainProcessorR6$new(
        domains = "Behavioral/Emotional/Social",
        pheno = "emotion",
        input_file = "data/neurobehav.parquet"
      )
      
      processor$load_data()
      processor$filter_by_domain()
      
      if (!is.null(processor$data) && nrow(processor$data) > 0) {
        # Generate child-specific emotion file
        generated_file <- processor$generate_domain_qmd(is_child = TRUE)
        log_message(paste("Generated:", generated_file), "DOMAINS")
        
        # Generate rater-specific text files
        processor$generate_domain_text_qmd(report_type = "self")
        processor$generate_domain_text_qmd(report_type = "parent")
        processor$generate_domain_text_qmd(report_type = "teacher")
      }
    }, error = function(e) {
      log_message(paste("Error processing emotion child domain:", e$message), "ERROR")
    })
  }
  
  # Generate ADHD child files
  if ("ADHD" %in% domains) {
    tryCatch({
      log_message("Processing ADHD domain for child", "DOMAINS")
      
      processor <- DomainProcessorR6$new(
        domains = "ADHD",
        pheno = "adhd",
        input_file = "data/neurobehav.parquet"
      )
      
      processor$load_data()
      processor$filter_by_domain()
      
      if (!is.null(processor$data) && nrow(processor$data) > 0) {
        # Generate child-specific ADHD file
        generated_file <- processor$generate_domain_qmd(is_child = TRUE)
        log_message(paste("Generated:", generated_file), "DOMAINS")
      }
    }, error = function(e) {
      log_message(paste("Error processing ADHD child domain:", e$message), "ERROR")
    })
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