# File: R/setup_neuro2.R
# Main loader for neuro2 functionality

#' Load neuro2 package functionality
#' @param verbose Whether to show loading messages
load_neuro2 <- function(verbose = TRUE) {
  
  if (verbose) message("🧠 Loading neuro2 neuropsychological assessment tools...")
  
  # Load required packages
  required_packages <- c(
    "dplyr", "readr", "ggplot2", "gt", "gtExtras", 
    "yaml", "here", "R6", "glue", "tidyr", "purrr", "stringr"
  )
  
  # Optional packages that enhance functionality
  optional_packages <- c("arrow", "quarto", "knitr")
  
  # Load required packages
  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      message("Installing required package: ", pkg)
      install.packages(pkg)
    }
    
    # Load the package
    if (verbose) message("  📦 Loading: ", pkg)
    library(pkg, character.only = TRUE, quietly = !verbose)
  }
  
  # Load optional packages if available
  for (pkg in optional_packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      if (verbose) message("  📦 Loading optional: ", pkg)
      library(pkg, character.only = TRUE, quietly = !verbose)
    } else if (verbose) {
      message("  ⚠️  Optional package not available: ", pkg)
    }
  }
  
  # Source all R6 classes and utilities
  r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
  
  # Exclude this setup file to avoid circular sourcing
  r_files <- r_files[!grepl("setup_neuro2.R", r_files)]
  
  for (file in r_files) {
    if (file.exists(file)) {
      if (verbose) message("  📜 Loading: ", basename(file))
      tryCatch({
        source(file)
      }, error = function(e) {
        if (verbose) message("    ⚠️  Warning loading ", basename(file), ": ", e$message)
      })
    }
  }
  
  if (verbose) message("✅ neuro2 loaded successfully!")
  
  invisible(TRUE)
}

#' Quick setup check for neuro2
#' @description Checks if all essential components are available
check_neuro2_setup <- function() {
  
  message("🔍 Checking neuro2 setup...")
  
  # Check for essential R files
  essential_files <- c(
    "R/DomainProcessorR6.R",
    "R/data_validation.R"
  )
  
  missing_files <- character()
  for (file in essential_files) {
    if (!file.exists(file)) {
      missing_files <- c(missing_files, file)
    }
  }
  
  if (length(missing_files) > 0) {
    message("❌ Missing essential files:")
    for (file in missing_files) {
      message("  - ", file)
    }
    return(FALSE)
  }
  
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
init_neuro2_workspace <- function(patient_name = NULL, verbose = TRUE) {
  
  if (verbose) message("🏗️  Initializing neuro2 workspace...")
  
  # Create essential directories
  dirs <- c("data", "figs", "output", "tmp")
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      if (verbose) message("  📁 Created: ", dir)
    }
  }
  
  # Load neuro2 functionality
  load_neuro2(verbose = verbose)
  
  # Create basic config if it doesn't exist
  if (!file.exists("config.yml") && !is.null(patient_name)) {
    basic_config <- list(
      patient = list(
        name = patient_name,
        age = NULL,
        assessment_date = as.character(Sys.Date())
      ),
      data = list(
        input_dir = "data",
        output_dir = "output"
      ),
      processing = list(
        verbose = TRUE
      )
    )
    
    yaml::write_yaml(basic_config, "config.yml")
    if (verbose) message("  ⚙️  Created basic config.yml")
  }
  
  if (verbose) message("✅ Workspace initialized!")
  invisible(TRUE)
}

# Auto-load when sourced (but allow override)
if (!exists(".neuro2_loaded")) {
  
  # Check if we should auto-load
  auto_load <- getOption("neuro2.auto_load", TRUE)
  
  if (auto_load) {
    # Load with minimal verbosity by default
    load_neuro2(verbose = getOption("neuro2.verbose", FALSE))
    .neuro2_loaded <- TRUE
  }
}