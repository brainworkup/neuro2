#' Centralized Component Loader - Runs ONCE
#'
#' This replaces all the source() calls scattered in functions
#' Load this ONCE at the start of your workflow
#'
#' @name load_components_once

# Prevent multiple loads
if (exists(".COMPONENTS_LOADED") && .COMPONENTS_LOADED) {
  message("Components already loaded")
  return(invisible(TRUE))
}

# Load all R6 classes and utilities ONCE
load_neuro2_components <- function() {
  message("Loading neuro2 components...")

  # Core R6 classes
  r6_files <- c(
    "DomainProcessorR6.R",
    "DomainProcessorFactoryR6.R",
    "TableGTR6.R",
    "DotplotR6.R",
    "NeuropsychResultsR6.R",
    "DuckDBProcessorR6.R"
  )

  # Utility files
  util_files <- c(
    "tidy_data.R",
    "pluck_neuropsych_test_results.R",
    "domain_processing_utils.R"
  )

  # Create a new environment for loading components
  # This prevents polluting the global environment
  component_env <- new.env(parent = parent.frame())

  # Load R6 classes
  for (file in r6_files) {
    filepath <- here::here("R", file)
    if (file.exists(filepath)) {
      # Check if class already exists
      class_name <- gsub("\\.R$", "", file)
      if (!exists(class_name)) {
        sys.source(filepath, envir = component_env)
        message("  ✓ Loaded ", file)
      } else {
        message("  ⚠ ", class_name, " already exists, skipping")
      }
    }
  }

  # Load utilities
  for (file in util_files) {
    filepath <- here::here("R", file)
    if (file.exists(filepath)) {
      sys.source(filepath, envir = component_env)
      message("  ✓ Loaded ", file)
    }
  }

  # Mark as loaded
  assign(".COMPONENTS_LOADED", TRUE, envir = .GlobalEnv)

  message("All components loaded successfully\n")
  return(invisible(TRUE))
}

# Load immediately when sourced
load_neuro2_components()
