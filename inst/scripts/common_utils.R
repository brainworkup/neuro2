#!/usr/bin/env Rscript

#' Common Utilities for Neuropsychological Workflow Scripts
#'
#' This script provides shared utility functions used across multiple workflow scripts
#' to reduce redundancy and ensure consistency.

#' Load required packages with consistent error handling
#' @param packages Character vector of package names
#' @param verbose Logical, whether to print loading messages
load_packages <- function(packages, verbose = TRUE) {
  suppressPackageStartupMessages({
    for (pkg in packages) {
      if (!requireNamespace(pkg, quietly = TRUE)) {
        if (verbose) {
          message("📦 Installing package: ", pkg)
        }
        install.packages(pkg, quiet = TRUE)
      }
      library(pkg, character.only = TRUE, quietly = TRUE)
      if (verbose) {
        message("✅ Loaded package: ", pkg)
      }
    }
  })
}

#' Load configuration from YAML file with fallback
#' @param config_path Path to config file
#' @param fallback_path Path to fallback config file
#' @return Configuration list
load_config <- function(config_path = "config.yml", fallback_path = NULL) {
  if (file.exists(config_path)) {
    config <- yaml::read_yaml(config_path)
    message("⚙️ Loaded config from: ", config_path)
  } else if (!is.null(fallback_path) && file.exists(fallback_path)) {
    config <- yaml::read_yaml(fallback_path)
    message("⚙️ Loaded fallback config from: ", fallback_path)
  } else {
    stop("Configuration file not found at: ", config_path,
         if (!is.null(fallback_path)) paste(" or ", fallback_path))
  }
  return(config)
}

#' Consistent logging function
#' @param message Message to log
#' @param type Log level (INFO, ERROR, WARNING, etc.)
#' @param verbose Whether to print the message
log_message <- function(message, type = "INFO", verbose = TRUE) {
  if (verbose) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    formatted_message <- paste0("[", timestamp, "] [", type, "] ", message)
    cat(formatted_message, "\n")
  }
}

#' Check if file exists with informative message
#' @param file_path Path to check
#' @param verbose Whether to print messages
#' @return Logical indicating if file exists
check_file_exists <- function(file_path, verbose = TRUE) {
  exists <- file.exists(file_path)
  if (verbose) {
    if (exists) {
      message("✅ File found: ", file_path)
    } else {
      message("❌ File not found: ", file_path)
    }
  }
  return(exists)
}

#' Safe source function with error handling
#' @param file_path Path to R script to source
#' @param verbose Whether to print messages
#' @return Logical indicating success
safe_source <- function(file_path, verbose = TRUE) {
  tryCatch({
    source(file_path)
    if (verbose) {
      message("📁 Sourced: ", file_path)
    }
    return(TRUE)
  }, error = function(e) {
    if (verbose) {
      message("❌ Error sourcing ", file_path, ": ", e$message)
    }
    return(FALSE)
  })
}

#' Get data files with preference order
#' @param data_dir Data directory path
#' @param basenames Base names to look for
#' @param verbose Whether to print messages
#' @return Named list of found files
get_data_files <- function(data_dir = "data", basenames = c("neurocog", "neurobehav", "validity"), verbose = TRUE) {
  files <- list()

  for (basename in basenames) {
    # Try parquet first (best performance)
    parquet_file <- file.path(data_dir, paste0(basename, ".parquet"))
    if (file.exists(parquet_file)) {
      files[[basename]] <- parquet_file
      if (verbose) message("📊 Found parquet: ", parquet_file)
      next
    }

    # Try feather
    feather_file <- file.path(data_dir, paste0(basename, ".feather"))
    if (file.exists(feather_file)) {
      files[[basename]] <- feather_file
      if (verbose) message("📊 Found feather: ", feather_file)
      next
    }

    # Try CSV
    csv_file <- file.path(data_dir, paste0(basename, ".csv"))
    if (file.exists(csv_file)) {
      files[[basename]] <- csv_file
      if (verbose) message("📊 Found CSV: ", csv_file)
    }
  }

  return(files)
}