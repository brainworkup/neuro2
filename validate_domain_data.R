#!/usr/bin/env Rscript

# DOMAIN DATA VALIDATION MODULE
# This module validates which domains have sufficient data before generation

# Function to validate domain data
validate_domain_data <- function(domain_name, data, pheno) {
  # Check if data exists and has minimum required rows
  if (is.null(data) || nrow(data) == 0) {
    return(list(valid = FALSE, reason = "No data available"))
  }
  
  # Check for required columns
  required_cols <- c("test", "scale", "score", "percentile")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    return(list(
      valid = FALSE, 
      reason = paste("Missing required columns:", paste(missing_cols, collapse = ", "))
    ))
  }
  
  # Check for minimum number of valid scores
  valid_scores <- sum(!is.na(data$score) & !is.na(data$percentile))
  if (valid_scores < 1) {
    return(list(valid = FALSE, reason = "No valid scores found"))
  }
  
  # Domain-specific validation
  if (pheno == "adaptive") {
    # Adaptive functioning requires specific tests
    adaptive_tests <- c("abas3", "vineland3", "srs2", "brief2")
    has_adaptive <- any(data$test %in% adaptive_tests)
    if (!has_adaptive) {
      return(list(
        valid = FALSE, 
        reason = "No adaptive functioning measures found"
      ))
    }
  }
  
  return(list(valid = TRUE, reason = "Data validation passed"))
}

# Function to check if supporting files exist for a domain
check_domain_dependencies <- function(pheno, patient_type = NULL) {
  dependencies <- list()
  
  # Check if scales exist in sysdata.rda
  sysdata_path <- here::here("R", "sysdata.rda")
  if (file.exists(sysdata_path)) {
    load(sysdata_path, envir = environment())
    
    # Check for scales
    scale_var <- paste0("scales_", pheno)
    if (patient_type %in% c("child", "adult") && pheno %in% c("emotion", "adhd")) {
      scale_var <- paste0(scale_var, "_", patient_type)
    }
    
    if (!exists(scale_var, envir = environment())) {
      dependencies$scales <- FALSE
    } else {
      dependencies$scales <- TRUE
    }
  } else {
    dependencies$scales <- FALSE
  }
  
  return(dependencies)
}

# Function to get domains that should be generated
get_valid_domains <- function(neurocog_data, neurobehav_data, patient_type = "child") {
  valid_domains <- list()
  
  # Define domain configurations
  domain_configs <- list(
    list(name = "General Cognitive Ability", pheno = "iq", data_source = "neurocog"),
    list(name = "Academic Skills", pheno = "academics", data_source = "neurocog"),
    list(name = "Verbal/Language", pheno = "verbal", data_source = "neurocog"),
    list(name = "Visual Perception/Construction", pheno = "spatial", data_source = "neurocog"),
    list(name = "Memory", pheno = "memory", data_source = "neurocog"),
    list(name = "Attention/Executive", pheno = "executive", data_source = "neurocog"),
    list(name = "Motor", pheno = "motor", data_source = "neurocog"),
    list(name = "Social Cognition", pheno = "social", data_source = "neurocog"),
    list(name = "ADHD", pheno = "adhd", data_source = "neurobehav"),
    list(name = "Adaptive Functioning", pheno = "adaptive", data_source = "neurobehav")
  )
  
  # Emotion domains (consolidated)
  emotion_domains <- c(
    "Behavioral/Emotional/Social",
    "Emotional/Behavioral/Personality",
    "Psychiatric Disorders",
    "Personality Disorders",
    "Substance Use",
    "Psychosocial Problems"
  )
  
  # Check each domain
  for (config in domain_configs) {
    # Get appropriate data
    if (config$data_source == "neurocog") {
      source_data <- neurocog_data
    } else {
      source_data <- neurobehav_data
    }
    
    if (!is.null(source_data) && "domain" %in% names(source_data)) {
      domain_data <- source_data[source_data$domain == config$name, ]
      
      # Validate the domain data
      validation <- validate_domain_data(config$name, domain_data, config$pheno)
      
      if (validation$valid) {
        # Check dependencies
        deps <- check_domain_dependencies(config$pheno, patient_type)
        
        if (all(unlist(deps) | length(deps) == 0)) {
          valid_domains[[config$name]] <- list(
            pheno = config$pheno,
            data_source = config$data_source,
            row_count = nrow(domain_data)
          )
        }
      }
    }
  }
  
  # Check emotion domains (consolidated)
  if (!is.null(neurobehav_data) && "domain" %in% names(neurobehav_data)) {
    emotion_data <- neurobehav_data[neurobehav_data$domain %in% emotion_domains, ]
    
    if (nrow(emotion_data) > 0) {
      validation <- validate_domain_data("Emotion", emotion_data, "emotion")
      
      if (validation$valid) {
        deps <- check_domain_dependencies("emotion", patient_type)
        
        if (all(unlist(deps) | length(deps) == 0)) {
          # Add all emotion domains that have data
          present_emotion_domains <- unique(emotion_data$domain)
          valid_domains[["Emotion_Consolidated"]] <- list(
            pheno = "emotion",
            data_source = "neurobehav",
            row_count = nrow(emotion_data),
            domains = present_emotion_domains
          )
        }
      }
    }
  }
  
  return(valid_domains)
}

# Export functions if running as a module
if (sys.nframe() == 0) {
  # Running as a script
  cat("Domain validation module loaded\n")
}