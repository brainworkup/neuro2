# File: R/setup_neuro2.R
# Main loader for neuro2 functionality

#' Setup neuro2 package environment
#' @export
setup_neuro2 <- function() {
  # Load required packages
  required_packages <- c("here", "tidyverse", "gt", "gtExtras", "R6")

  for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      stop(paste("Required package not found:", pkg))
    }
  }

  # Source R6 classes in correct order
  r_files <- c(
    "R/DomainProcessorR6.R",
    "R/NeuropsychResultsR6.R",
    "R/TableGTR6.R",
    "R/DotplotR6.R",
    "R/score_type_utils.R",
    "R/tidy_data.R"
  )

  for (file in r_files) {
    if (file.exists(here::here(file))) {
      source(here::here(file))
    } else {
      warning(paste("R file not found:", file))
    }
  }

  message("✅ neuro2 environment setup complete")
}

# Fix the setup chunk in QMD files to use this:
# Instead of:
#   library(neuro2)
# Use:
#   source(here::here("R", "setup_neuro2.R"))
#   setup_neuro2()

#' Quick setup check for neuro2
#' @description Checks if all essential components are available
#' @return TRUE if setup is valid, FALSE otherwise
#' @export
check_neuro2_setup <- function() {
  message("🔍 Checking neuro2 setup...")

  # Check for data directory
  if (!dir.exists("data")) {
    message("❌ Data directory not found")
    message("   Run: dir.create('data')")
    return(FALSE)
  }

  # Check for config file
  if (!file.exists("config.yml")) {
    message("⚠️  No config.yml found (this is optional)")
  }

  message("✅ neuro2 setup looks good!")
  return(TRUE)
}

#' Initialize neuro2 workspace
#' @description Sets up directories and loads functionality
#' @param patient_name Character string for patient name (optional)
#' @param verbose Logical, whether to show verbose output
#' @return TRUE if successful
#' @export
init_neuro2_workspace <- function(patient_name = NULL, verbose = TRUE) {
  if (verbose) {
    message("🏗️  Initializing neuro2 workspace...")
  }

  # Create essential directories
  dirs <- c("data", "figs", "output", "tmp")
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      if (verbose) message("  📁 Created: ", dir)
    }
  }

  # Setup neuro2 functionality
  setup_neuro2(verbose = verbose)

  # Create basic config if it doesn't exist
  if (!file.exists("config.yml") && !is.null(patient_name)) {
    basic_config <- list(
      patient = list(
        name = patient_name,
        age = NULL,
        assessment_date = as.character(Sys.Date())
      ),
      data = list(input_dir = "data", output_dir = "output"),
      processing = list(verbose = TRUE)
    )

    yaml::write_yaml(basic_config, "config.yml")
    if (verbose) message("  ⚙️  Created basic config.yml")
  }

  if (verbose) {
    message("✅ Workspace initialized!")
  }
  invisible(TRUE)
}
