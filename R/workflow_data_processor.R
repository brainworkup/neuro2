# Data Processing Module
# Handles data loading and processing for the workflow

process_workflow_data <- function(config) {
  source("R/workflow_utils.R")
  
  log_message("Processing data...", "WORKFLOW")
  
  # Source the data processor module if it exists
  if (file.exists("data_processor_module.R")) {
    log_message("Running data_processor_module.R", "DATA")
    source("data_processor_module.R")
    return(TRUE)
  }
  
  # Fallback to using existing scripts
  if (config$processing$use_duckdb && file.exists("R/duckdb_neuropsych_loader.R")) {
    log_message("Using DuckDB data processor", "DATA")
    source("R/duckdb_neuropsych_loader.R")
    
    # Process the data
    load_data_duckdb(
      file_path = config$data$input_dir,
      output_dir = config$data$output_dir,
      output_format = config$data$format
    )
  } else if (file.exists("neuro2_duckdb_workflow.R")) {
    log_message("Using neuro2_duckdb_workflow.R", "DATA")
    source("neuro2_duckdb_workflow.R")
  } else {
    log_message("No suitable data processor found", "ERROR")
    return(FALSE)
  }
  
  log_message("Data processing complete", "DATA")
  return(TRUE)
}

# Query function for neuropsych data
query_neuropsych <- function(query, data_dir) {
  source("R/workflow_utils.R")
  
  # Try to load the data
  neurocog_data <- load_neuropsych_data(data_dir)
  
  if (is.null(neurocog_data)) {
    return(data.frame())
  }
  
  # Parse the query to extract what we need
  if (grepl("SELECT DISTINCT domain", query, ignore.case = TRUE)) {
    if (grepl("FROM neurocog", query, ignore.case = TRUE)) {
      if ("domain" %in% names(neurocog_data)) {
        unique_domains <- unique(neurocog_data$domain)
        unique_domains <- unique_domains[!is.na(unique_domains)]
        return(data.frame(domain = unique_domains))
      }
    } else if (grepl("FROM neurobehav", query, ignore.case = TRUE)) {
      # Load neurobehav data
      neurobehav_data <- load_neurobehav_data(data_dir)
      if (!is.null(neurobehav_data) && "domain" %in% names(neurobehav_data)) {
        unique_domains <- unique(neurobehav_data$domain)
        unique_domains <- unique_domains[!is.na(unique_domains)]
        return(data.frame(domain = unique_domains))
      }
    }
  }
  
  return(data.frame())
}

# Load neurobehav data
load_neurobehav_data <- function(data_dir) {
  parquet_file <- file.path(data_dir, "neurobehav.parquet")
  csv_file <- file.path(data_dir, "neurobehav.csv")
  feather_file <- file.path(data_dir, "neurobehav.feather")
  
  if (file.exists(parquet_file) && requireNamespace("arrow", quietly = TRUE)) {
    return(arrow::read_parquet(parquet_file))
  } else if (file.exists(feather_file) && requireNamespace("arrow", quietly = TRUE)) {
    return(arrow::read_feather(feather_file))
  } else if (file.exists(csv_file)) {
    return(readr::read_csv(csv_file, show_col_types = FALSE))
  } else {
    return(NULL)
  }
}

# Check if data exists
check_data_exists <- function(config) {
  neurocog_exists <- file.exists(file.path(config$data$output_dir, "neurocog.csv")) ||
    file.exists(file.path(config$data$output_dir, "neurocog.parquet")) ||
    file.exists(file.path(config$data$output_dir, "neurocog.feather"))
  
  neurobehav_exists <- file.exists(file.path(config$data$output_dir, "neurobehav.csv")) ||
    file.exists(file.path(config$data$output_dir, "neurobehav.parquet")) ||
    file.exists(file.path(config$data$output_dir, "neurobehav.feather"))
  
  return(list(
    neurocog = neurocog_exists,
    neurobehav = neurobehav_exists
  ))
}

# Get data format
get_data_format <- function(config, data_type = "neurocog") {
  input_format <- config$data$format
  
  if (is.null(input_format) || input_format == "all") {
    # If format is "all", check which format exists
    if (file.exists(file.path(config$data$output_dir, paste0(data_type, ".parquet")))) {
      input_format <- "parquet"
    } else if (file.exists(file.path(config$data$output_dir, paste0(data_type, ".csv")))) {
      input_format <- "csv"
    } else if (file.exists(file.path(config$data$output_dir, paste0(data_type, ".feather")))) {
      input_format <- "feather"
    } else {
      input_format <- "parquet" # fallback
    }
  }
  
  return(input_format)
}