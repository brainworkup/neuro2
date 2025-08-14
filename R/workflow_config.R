# Configuration Management Module
# Handles loading and validating workflow configuration

load_workflow_config <- function(config_file = "config.yml") {
  source("R/workflow_utils.R")

  log_message(paste0("Loading configuration from: ", config_file), "CONFIG")

  if (!file.exists(config_file)) {
    config_file <- create_default_config(config_file)
  }

  config <- yaml::read_yaml(config_file)

  # Validate configuration
  validate_config(config)

  # Display configuration
  log_message("Configuration loaded successfully", "CONFIG")
  log_message(paste0("Patient: ", config$patient$name), "CONFIG")
  log_message(paste0("Age: ", config$patient$age), "CONFIG")
  log_message(paste0("DOE: ", config$patient$doe), "CONFIG")

  return(config)
}

create_default_config <- function(config_file) {
  source("R/workflow_utils.R")

  # Check if config.yml exists in template directory before creating default
  template_dir <- "inst/quarto/templates/typst-report"
  template_config_file <- file.path(template_dir, "config.yml")

  if (file.exists(template_config_file)) {
    log_message(
      "Configuration file not found. Copying from template directory.",
      "CONFIG"
    )
    file.copy(template_config_file, config_file)
    log_message(
      paste0("Copied template configuration file: ", config_file),
      "CONFIG"
    )
  } else {
    # Create default configuration if template doesn't exist
    log_message(
      "Configuration file not found. Creating default configuration.",
      "CONFIG"
    )

    default_config <- list(
      patient = list(
        name = "Biggie",
        age = 21,
        doe = format(Sys.Date(), "%Y-%m-%d")
      ),
      data = list(
        input_dir = "data-raw/csv",
        output_dir = "data",
        format = "all"
      ),
      processing = list(
        use_duckdb = TRUE,
        parallel = TRUE
      ),
      report = list(
        template = "template.qmd",
        format = "neurotyp-adult-typst",
        output_dir = "output"
      )
    )

    yaml::write_yaml(default_config, config_file)
    log_message(
      paste0("Created default configuration file: ", config_file),
      "CONFIG"
    )
  }

  return(config_file)
}

validate_config <- function(config) {
  # Validate required fields
  required_fields <- list(
    patient = c("name", "age", "doe"),
    data = c("input_dir", "output_dir"),
    report = c("template", "format")
  )

  for (section in names(required_fields)) {
    if (!section %in% names(config)) {
      stop(paste0("Missing required configuration section: ", section))
    }

    for (field in required_fields[[section]]) {
      if (!field %in% names(config[[section]])) {
        stop(paste0("Missing required configuration field: ", section, "$", field))
      }
    }
  }

  # Set defaults for optional fields
  if (is.null(config$data$format)) {
    config$data$format <- "all"
  }

  if (is.null(config$processing$use_duckdb)) {
    config$processing$use_duckdb <- TRUE
  }

  if (is.null(config$processing$parallel)) {
    config$processing$parallel <- TRUE
  }

  if (is.null(config$report$output_dir)) {
    config$report$output_dir <- "output"
  }

  return(config)
}

parse_config_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  config_file <- "config.yml"

  if (length(args) > 0) {
    if (args[1] == "--config" && length(args) > 1) {
      config_file <- args[2]
    } else {
      config_file <- args[1]
    }
  }

  return(config_file)
}
