#' Enhanced Domain Data Validation
#' 
#' @description Validates if a domain has sufficient data before processing
#' @param domain_name Domain to check
#' @param data_source Data frame to check
#' @param min_rows Minimum number of rows required (default: 1)
#' @return List with validation results
validate_domain_data_exists <- function(domain_name, data_source, min_rows = 1) {
  validation <- list(
    has_data = FALSE,
    row_count = 0,
    domain_name = domain_name,
    message = ""
  )
  
  # Check if data source exists and has domain column
  if (is.null(data_source) || nrow(data_source) == 0) {
    validation$message <- "Data source is empty or null"
    return(validation)
  }
  
  if (!"domain" %in% names(data_source)) {
    validation$message <- "Domain column not found in data"
    return(validation)
  }
  
  # Filter for the specific domain
  domain_data <- data_source %>%
    dplyr::filter(domain == domain_name) %>%
    dplyr::filter(!is.na(percentile) | !is.na(score)) # Must have some scoreable data
  
  validation$row_count <- nrow(domain_data)
  validation$has_data <- validation$row_count >= min_rows
  
  if (validation$has_data) {
    validation$message <- paste("Found", validation$row_count, "rows for", domain_name)
  } else {
    validation$message <- paste("Insufficient data for", domain_name, "- found", validation$row_count, "rows")
  }
  
  return(validation)
}

#' Get Domains With Data
#' 
#' @description Returns only domains that have actual data
#' @param neurocog_data Neurocognitive data
#' @param neurobehav_data Neurobehavioral data  
#' @param domain_config Domain configuration list
#' @return List of domains with data
get_domains_with_data <- function(neurocog_data, neurobehav_data, domain_config) {
  domains_with_data <- list()
  
  for (domain_name in names(domain_config)) {
    config <- domain_config[[domain_name]]
    
    # Determine which data source to use
    data_source <- if (grepl("neurocog", config$input_file)) {
      neurocog_data
    } else {
      neurobehav_data
    }
    
    # Validate data exists
    validation <- validate_domain_data_exists(domain_name, data_source)
    
    if (validation$has_data) {
      domains_with_data[[domain_name]] <- list(
        config = config,
        validation = validation
      )
      message(paste("✓", validation$message))
    } else {
      message(paste("✗", validation$message, "- skipping"))
    }
  }
  
  return(domains_with_data)
}