# File: R/setup_neuro2.R
# Main loader for neuro2 functionality

#' Setup neuro2 environment
#'
#' @description Sets up the neuro2 environment and loads required functionality
#' @param verbose Logical, whether to show verbose output
#' @return TRUE if successful
#' @export
setup_neuro2 <- function(verbose = TRUE) {
  if (verbose) {
    message("🏗️  Setting up neuro2...")
  }

  # Check if we're in a package development environment
  if (!"neuro2" %in% loadedNamespaces()) {
    if (verbose) {
      message("  📦 Loading neuro2 package...")
    }
  }

  # Create essential directories if they don't exist
  dirs <- c("data", "figs", "output", "tmp")
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      if (verbose) message("  📁 Created: ", dir)
    }
  }

  if (verbose) {
    message("✅ neuro2 setup complete!")
  }

  invisible(TRUE)
}

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

# Remove the problematic auto-loading code that was causing issues
# Package functions should not execute code when the package loads
