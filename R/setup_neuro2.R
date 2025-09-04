#' Setup neuro2 package environment
#'
#' Loads required packages and sources the R6 classes/utilities used by
#' neuro2 reporting. Intended to be called from Quarto documents or
#' interactive sessions to ensure needed helpers are available.
#'
#' For Quarto, prefer sourcing this file and calling `setup_neuro2()`
#' instead of attaching the package with `library(neuro2)` to avoid
#' polluting the search path during document rendering.
#'
#' @param verbose logical; whether to print progress messages. Default `TRUE`.
#' @return Invisibly returns `NULL`.
#' @examples
#' \dontrun{
#' # In a Quarto setup chunk
#' source(here::here("R", "setup_neuro2.R"))
#' setup_neuro2()
#' }
#' @export
#' @importFrom here here
setup_neuro2 <- function(verbose = TRUE) {
  # Load required packages
  required_packages <- c("here", "tidyverse", "gt", "gtExtras", "R6")

  for (pkg in required_packages) {
    if (isTRUE(verbose)) {
      message("• Loading package: ", pkg)
    }
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
      if (isTRUE(verbose)) {
        message("• Sourcing: ", file)
      }
      source(here::here(file))
    } else {
      warning(paste("R file not found:", file))
    }
  }

  if (isTRUE(verbose)) {
    message("✅ neuro2 environment setup complete")
  }
  invisible(NULL)
}

#' Quick setup check for neuro2
#'
#' Checks for common prerequisites used by the neuro2 workflow
#' (e.g., a `data/` directory and an optional `config.yml`).
#'
#' @return Logical: `TRUE` if basic setup looks valid; otherwise `FALSE`.
#' @examples
#' \dontrun{
#' ok <- check_neuro2_setup()
#' if (!ok) message("Please create missing folders/files and retry.")
#' }
#' @seealso [init_neuro2_workspace()] to create the expected folders.
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
#'
#' Creates commonly used directories (`data/`, `figs/`, `output/`, `tmp/`),
#' loads neuro2 helpers via [setup_neuro2()], and optionally writes a minimal
#' `config.yml` seeded with `patient_name`.
#'
#' @param patient_name character; optional patient name to include in a
#'   generated `config.yml` if it does not already exist.
#' @param verbose logical; whether to print progress messages. Default `TRUE`.
#' @return Invisibly returns `TRUE` on success.
#' @examples
#' \dontrun{
#' init_neuro2_workspace(patient_name = "Jane Doe")
#' }
#' @seealso [setup_neuro2()], [check_neuro2_setup()]
#' @export
#' @importFrom yaml write_yaml
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
