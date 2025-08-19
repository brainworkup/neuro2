#!/usr/bin/env Rscript

#' Batch Domain Processor
#' 
#' Processes all domains that have data using DomainProcessorR6Combo
#' and generates QMD files for the neuropsychological report.

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

# Source the combo processor
source(here::here("R", "DomainProcessorR6Combo.R"))

#' Check if a domain has data in the specified file
#' @param domain_name Domain name to check
#' @param data_file Path to data file
#' @param min_rows Minimum number of rows required
#' @return List with validation results
check_domain_data <- function(domain_name, data_file, min_rows = 1) {
  result <- list(
    has_data = FALSE,
    row_count = 0,
    domain_name = domain_name,
    file_path = data_file
  )
  
  if (!file.exists(data_file)) {
    return(result)
  }
  
  # Read and check data
  tryCatch({
    # Determine file type and read appropriately
    file_ext <- tools::file_ext(data_file)
    
    if (file_ext == "parquet") {
      if (requireNamespace("arrow", quietly = TRUE)) {
        data <- arrow::read_parquet(data_file)
      } else {
        return(result)
      }
    } else {
      data <- readr::read_csv(data_file, show_col_types = FALSE)
    }
    
    if ("domain" %in% names(data)) {
      domain_data <- data %>%
        dplyr::filter(domain == domain_name) %>%
        dplyr::filter(!is.na(percentile) | !is.na(score))
      
      result$row_count <- nrow(domain_data)
      result$has_data <- result$row_count >= min_rows
    }
  }, error = function(e) {
    # Silent failure, result stays FALSE
  })
  
  return(result)
}

#' Get all domains with data
#' @param domain_config Domain configuration list
#' @return List of domains that have sufficient data
get_domains_with_data <- function(domain_config) {
  domains_with_data <- list()
  
  for (domain_key in names(domain_config)) {
    config <- domain_config[[domain_key]]
    
    # Check each domain name for this phenotype
    for (domain_name in config$domains) {
      validation <- check_domain_data(domain_name, config$input_file)
      
      if (validation$has_data) {
        domains_with_data[[domain_key]] <- config
        cat("✅", domain_name, "- found", validation$row_count, "rows\n")
        break  # Found data for this phenotype, move to next
      }
    }
    
    if (!domain_key %in% names(domains_with_data)) {
      cat("❌", paste(config$domains, collapse = "/"), "- no data found\n")
    }
  }
  
  return(domains_with_data)
}

#' Process a single domain
#' @param domain_key Domain key (e.g., "memory", "iq")
#' @param config Domain configuration
#' @return Success status
process_single_domain <- function(domain_key, config) {
  cat("\n📊 Processing", domain_key, "domain...\n")
  
  tryCatch({
    # Create processor
    processor <- DomainProcessorR6Combo$new(
      domains = config$domains,
      pheno = config$pheno,
      input_file = config$input_file,
      number = config$number
    )
    
    # Generate domain QMD
    generated_file <- processor$generate_domain_qmd()
    cat("✅ Generated:", generated_file, "\n")
    
    return(TRUE)
  }, error = function(e) {
    cat("❌ Error processing", domain_key, ":", e$message, "\n")
    return(FALSE)
  })
}

#' Main batch processing function
#' @param verbose Whether to show detailed output
#' @return List of processing results
process_all_domains <- function(verbose = TRUE) {
  if (verbose) {
    cat("🧠 Neuropsychological Domain Batch Processor\n")
    cat("===========================================\n\n")
  }
  
  # Define domain configuration
  domain_config <- list(
    # Cognitive domains
    iq = list(
      domains = "General Cognitive Ability",
      pheno = "iq",
      input_file = "data/neurocog.csv",
      number = "01"
    ),
    
    academics = list(
      domains = "Academic Skills", 
      pheno = "academics",
      input_file = "data/neurocog.csv",
      number = "02"
    ),
    
    verbal = list(
      domains = "Verbal/Language",
      pheno = "verbal",
      input_file = "data/neurocog.csv",
      number = "03"
    ),
    
    spatial = list(
      domains = "Visual Perception/Construction",
      pheno = "spatial",
      input_file = "data/neurocog.csv",
      number = "04"
    ),
    
    memory = list(
      domains = "Memory",
      pheno = "memory",
      input_file = "data/neurocog.csv",
      number = "05"
    ),
    
    executive = list(
      domains = "Attention/Executive",
      pheno = "executive", 
      input_file = "data/neurocog.csv",
      number = "06"
    ),
    
    motor = list(
      domains = "Motor",
      pheno = "motor",
      input_file = "data/neurocog.csv",
      number = "07"
    ),
    
    social = list(
      domains = "Social Cognition",
      pheno = "social",
      input_file = "data/neurocog.csv", 
      number = "08"
    ),
    
    # Behavioral domains  
    adhd = list(
      domains = "ADHD",
      pheno = "adhd",
      input_file = "data/neurobehav.csv",
      number = "09"
    ),
    
    emotion = list(
      domains = c(
        "Behavioral/Emotional/Social",
        "Emotional/Behavioral/Personality",
        "Psychiatric Disorders", 
        "Personality Disorders",
        "Substance Use",
        "Psychosocial Problems"
      ),
      pheno = "emotion",
      input_file = "data/neurobehav.csv",
      number = "10"
    ),
    
    adaptive = list(
      domains = "Adaptive Functioning",
      pheno = "adaptive",
      input_file = "data/neurobehav.csv",
      number = "11"
    ),
    
    daily_living = list(
      domains = "Daily Living",
      pheno = "daily_living",
      input_file = "data/neurocog.csv",
      number = "12"
    ),
    
    # Validity
    validity = list(
      domains = c("Performance Validity", "Symptom Validity"),
      pheno = "validity",
      input_file = "data/validity.csv",
      number = "13"
    )
  )
  
  # Check which domains have data
  if (verbose) {
    cat("🔍 Checking for available domain data...\n")
  }
  
  domains_with_data <- get_domains_with_data(domain_config)
  
  if (length(domains_with_data) == 0) {
    cat("❌ No domains found with data. Please check your data files.\n")
    return(list())
  }
  
  if (verbose) {
    cat("\n📋 Found", length(domains_with_data), "domains with data\n")
    cat("🚀 Starting batch processing...\n")
  }
  
  # Process each domain
  results <- list()
  success_count <- 0
  
  for (domain_key in names(domains_with_data)) {
    config <- domains_with_data[[domain_key]]
    success <- process_single_domain(domain_key, config)
    
    results[[domain_key]] <- list(
      success = success,
      config = config
    )
    
    if (success) {
      success_count <- success_count + 1
    }
  }
  
  # Summary
  if (verbose) {
    cat("\n📊 Batch Processing Complete!\n")
    cat("============================\n")
    cat("✅ Success:", success_count, "/", length(domains_with_data), "domains\n")
    
    if (success_count < length(domains_with_data)) {
      failed <- names(domains_with_data)[!sapply(results, function(x) x$success)]
      cat("❌ Failed:", paste(failed, collapse = ", "), "\n")
    }
    
    # List generated files
    cat("\n📄 Generated QMD files:\n")
    qmd_files <- list.files(".", pattern = "^_02-[0-9]{2}_.*\\.qmd$")
    if (length(qmd_files) > 0) {
      for (file in sort(qmd_files)) {
        cat("  -", file, "\n")
      }
    } else {
      cat("  (No QMD files found)\n")
    }
  }
  
  return(results)
}

#' Quick test function for a single domain
#' @param domain_name Domain name to test
#' @param pheno Phenotype identifier
#' @param input_file Input data file
test_single_domain <- function(domain_name = "Memory", pheno = "memory", input_file = "data/neurocog.csv") {
  cat("🧪 Testing single domain:", domain_name, "\n")
  
  processor <- DomainProcessorR6Combo$new(
    domains = domain_name,
    pheno = pheno, 
    input_file = input_file
  )
  
  generated_file <- processor$generate_domain_qmd()
  cat("✅ Test complete! Generated:", generated_file, "\n")
  
  return(generated_file)
}

# If script is run directly, execute main function
if (!interactive()) {
  process_all_domains(verbose = TRUE)
} else {
  cat("🧠 Batch Domain Processor loaded!\n")
  cat("Usage:\n")
  cat("  process_all_domains()           - Process all domains with data\n") 
  cat("  test_single_domain()           - Test with memory domain\n")
  cat("  get_domains_with_data(config)  - Check which domains have data\n")
}