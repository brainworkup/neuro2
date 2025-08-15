# FIXED DOMAIN WORKFLOW MODULE
# This replaces/updates your domain generation workflow to add validation BEFORE processing

#' Enhanced Domain Validation and Processing
#'
#' @description This module validates domains BEFORE generating files, preventing
#' the creation of empty domain files and fixing the workflow logic.

# Load required libraries
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

# Enhanced logging function
log_domain_message <- function(message, type = "DOMAINS") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message)
  cat(log_entry, "\n")
}

log_domain_message(
  "Starting enhanced domain workflow with validation",
  "WORKFLOW"
)

# STEP 1: Load and validate data files
load_and_validate_data <- function() {
  log_domain_message("Loading and validating data files", "DATA")

  # Function to safely read data
  safe_read_data <- function(file_paths) {
    for (path in file_paths) {
      if (file.exists(path)) {
        tryCatch(
          {
            if (grepl("\\.parquet$", path)) {
              if (requireNamespace("arrow", quietly = TRUE)) {
                data <- arrow::read_parquet(path)
                log_domain_message(
                  paste("✓ Loaded", path, "-", nrow(data), "rows"),
                  "DATA"
                )
                return(data)
              }
            } else if (grepl("\\.csv$", path)) {
              data <- readr::read_csv(path, show_col_types = FALSE)
              log_domain_message(
                paste("✓ Loaded", path, "-", nrow(data), "rows"),
                "DATA"
              )
              return(data)
            }
          },
          error = function(e) {
            log_domain_message(
              paste("✗ Failed to read", path, ":", e$message),
              "ERROR"
            )
          }
        )
      }
    }
    return(NULL)
  }

  # Load neurocog data
  neurocog_paths <- c("data/neurocog.parquet", "data/neurocog.csv")
  neurocog_data <- safe_read_data(neurocog_paths)

  # Load neurobehav data
  neurobehav_paths <- c("data/neurobehav.parquet", "data/neurobehav.csv")
  neurobehav_data <- safe_read_data(neurobehav_paths)

  if (is.null(neurocog_data) && is.null(neurobehav_data)) {
    log_domain_message("No data files found - cannot proceed", "ERROR")
    return(NULL)
  }

  return(list(neurocog = neurocog_data, neurobehav = neurobehav_data))
}

# STEP 2: Define domain configuration
get_domain_configuration <- function() {
  list(
    "General Cognitive Ability" = list(
      pheno = "iq",
      number = "01",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    ),
    "Academic Skills" = list(
      pheno = "academics",
      number = "02",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    ),
    "Verbal/Language" = list(
      pheno = "verbal",
      number = "03",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    ),
    "Visual Perception/Construction" = list(
      pheno = "spatial",
      number = "04",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    ),
    "Memory" = list(
      pheno = "memory",
      number = "05",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    ),
    "Attention/Executive" = list(
      pheno = "executive",
      number = "06",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    ),
    "Motor" = list(
      pheno = "motor",
      number = "07",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    ),
    "Social Cognition" = list(
      pheno = "social",
      number = "08",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    ),
    "ADHD" = list(
      pheno = "adhd",
      number = "09",
      data_source = "neurobehav",
      input_file = "data/neurobehav.csv"
    ),
    "Behavioral/Emotional/Social" = list(
      pheno = "emotion",
      number = "10",
      data_source = "neurobehav",
      input_file = "data/neurobehav.csv"
    ),
    "Emotional/Behavioral/Personality" = list(
      pheno = "emotion",
      number = "10",
      data_source = "neurobehav",
      input_file = "data/neurobehav.csv"
    ),
    "Psychiatric Disorders" = list(
      pheno = "emotion",
      number = "10",
      data_source = "neurobehav",
      input_file = "data/neurobehav.csv"
    ),
    "Personality Disorders" = list(
      pheno = "emotion",
      number = "10",
      data_source = "neurobehav",
      input_file = "data/neurobehav.csv"
    ),
    "Substance Use" = list(
      pheno = "emotion",
      number = "10",
      data_source = "neurobehav",
      input_file = "data/neurobehav.csv"
    ),
    "Psychosocial Problems" = list(
      pheno = "emotion",
      number = "10",
      data_source = "neurobehav",
      input_file = "data/neurobehav.csv"
    ),
    "Adaptive Functioning" = list(
      pheno = "adaptive",
      number = "11",
      data_source = "neurobehav",
      input_file = "data/neurobehav.csv"
    ),
    "Daily Living" = list(
      pheno = "daily_living",
      number = "12",
      data_source = "neurocog",
      input_file = "data/neurocog.csv"
    )
  )
}

# STEP 3: Validate domains have data
validate_domain_has_data <- function(domain_name, data_source, min_rows = 1) {
  if (is.null(data_source) || nrow(data_source) == 0) {
    return(list(
      has_data = FALSE,
      row_count = 0,
      message = "No data source available"
    ))
  }

  if (!"domain" %in% names(data_source)) {
    return(list(
      has_data = FALSE,
      row_count = 0,
      message = "No domain column found"
    ))
  }

  # Filter for specific domain and ensure it has scoreable data
  domain_data <- data_source %>%
    filter(domain == domain_name) %>%
    filter(!is.na(percentile) | !is.na(score))

  row_count <- nrow(domain_data)

  return(list(
    has_data = row_count >= min_rows,
    row_count = row_count,
    message = if (row_count >= min_rows) {
      paste("✓ Found", row_count, "valid rows for", domain_name)
    } else {
      paste(
        "✗ Only",
        row_count,
        "rows found for",
        domain_name,
        "(minimum:",
        min_rows,
        ")"
      )
    }
  ))
}

# STEP 4: Get only domains with actual data
get_validated_domains <- function(data_list, domain_config) {
  log_domain_message("Validating domains for data availability", "VALIDATION")

  validated_domains <- list()

  for (domain_name in names(domain_config)) {
    config <- domain_config[[domain_name]]

    # Get the appropriate data source
    data_source <- if (config$data_source == "neurocog") {
      data_list$neurocog
    } else {
      data_list$neurobehav
    }

    # Validate this domain has data
    validation <- validate_domain_has_data(domain_name, data_source)

    log_domain_message(validation$message, "VALIDATION")

    if (validation$has_data) {
      validated_domains[[domain_name]] <- list(
        config = config,
        validation = validation,
        data_source = data_source
      )
    }
  }

  log_domain_message(
    paste(
      "Validation complete:",
      length(validated_domains),
      "out of",
      length(domain_config),
      "domains have data"
    ),
    "VALIDATION"
  )

  return(validated_domains)
}

# STEP 5: Safe domain processing with error handling
process_domain_safely <- function(domain_name, domain_info) {
  log_domain_message(paste("Processing domain:", domain_name), "PROCESSING")

  tryCatch(
    {
      config <- domain_info$config

      # Check if DomainProcessor class exists
      if (!exists("DomainProcessor")) {
        # Try to load it
        if (file.exists("R/DomainProcessor.R")) {
          source("R/DomainProcessor.R")
        } else {
          log_domain_message("DomainProcessor class not found", "ERROR")
          return(FALSE)
        }
      }

      # Create processor with error handling
      processor <- DomainProcessor$new(
        domains = domain_name,
        pheno = config$pheno,
        input_file = config$input_file,
        number = config$number
      )

      # Set the data directly to avoid reloading
      processor$data <- domain_info$data_source %>%
        filter(domain == domain_name) %>%
        filter(!is.na(percentile) | !is.na(score))

      if (nrow(processor$data) == 0) {
        log_domain_message(
          paste("No valid data after filtering for", domain_name),
          "WARNING"
        )
        return(FALSE)
      }

      # Generate domain file
      result <- processor$generate_domain_qmd()

      if (!is.null(result)) {
        log_domain_message(
          paste("✓ Generated domain file for", domain_name),
          "PROCESSING"
        )
        return(TRUE)
      } else {
        log_domain_message(
          paste("✗ Failed to generate domain file for", domain_name),
          "ERROR"
        )
        return(FALSE)
      }
    },
    error = function(e) {
      log_domain_message(
        paste("✗ Error processing", domain_name, ":", e$message),
        "ERROR"
      )
      return(FALSE)
    }
  )
}

# STEP 6: Main workflow function
run_validated_domain_workflow <- function() {
  log_domain_message("Starting validated domain workflow", "WORKFLOW")

  # Load and validate data
  data_list <- load_and_validate_data()
  if (is.null(data_list)) {
    log_domain_message("Cannot proceed without data", "ERROR")
    return(FALSE)
  }

  # Get domain configuration
  domain_config <- get_domain_configuration()

  # Get only domains with data
  validated_domains <- get_validated_domains(data_list, domain_config)

  if (length(validated_domains) == 0) {
    log_domain_message(
      "No domains have valid data - no files will be generated",
      "WARNING"
    )
    return(FALSE)
  }

  # Process only validated domains
  success_count <- 0
  total_count <- length(validated_domains)

  for (domain_name in names(validated_domains)) {
    success <- process_domain_safely(
      domain_name,
      validated_domains[[domain_name]]
    )
    if (success) {
      success_count <- success_count + 1
    }
  }

  log_domain_message(
    paste(
      "Workflow complete:",
      success_count,
      "out of",
      total_count,
      "domains processed successfully"
    ),
    "WORKFLOW"
  )

  return(success_count > 0)
}

# STEP 7: Execute the workflow
main <- function() {
  # Check if this is being called from within another script
  if (exists(".domain_workflow_running")) {
    log_domain_message("Domain workflow already running, skipping", "INFO")
    return(TRUE)
  }

  # Set flag to prevent recursive calls
  .domain_workflow_running <<- TRUE

  on.exit({
    rm(.domain_workflow_running, envir = .GlobalEnv)
  })

  # Run the validated workflow
  result <- run_validated_domain_workflow()

  # List generated files
  domain_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$")
  if (length(domain_files) > 0) {
    log_domain_message("Generated domain files:", "RESULTS")
    for (file in domain_files) {
      log_domain_message(paste("  -", file), "RESULTS")
    }
  } else {
    log_domain_message("No domain files were generated", "RESULTS")
  }

  return(result)
}

# Execute if running as script
if (!interactive()) {
  main()
}
