# Environment Setup Module
# Handles setting up the workflow environment, directories, and template files

# Workflow Setup Functions

.setup_workflow_environment <- function(config) {
  # Removed: source("R/workflow_utils.R") - functions available from package

  tryCatch(
    {
      if (file.exists("setup_environment.R")) {
        source("setup_environment.R") # External script, so kept
      }

      log_message("Environment setup complete", "SETUP")
      return(TRUE)
    },
    error = function(e) {
      log_message(paste("Failed to setup environment:", e$message), "ERROR")
      return(FALSE)
    }
  )
}

# Load required libraries for the workflow
.load_workflow_libraries <- function() {
  # Removed: source("R/workflow_utils.R") - functions available from package

  required_packages <- c(
    "dplyr",
    "readr",
    "here",
    "yaml",
    "purrr",
    "DBI",
    "duckdb",
    "arrow",
    "gt",
    "ggplot2"
  )

  missing_packages <- setdiff(
    required_packages,
    installed.packages()[, "Package"]
  )

  if (length(missing_packages) > 0) {
    log_message(
      paste("Missing packages:", paste(missing_packages, collapse = ", ")),
      "WARNING"
    )
    return(FALSE)
  }

  # Load all required packages
  for (pkg in required_packages) {
    suppressMessages(library(pkg, character.only = TRUE))
  }

  log_message("All workflow libraries loaded", "INFO")
  return(TRUE)
}

# Setup project directories
.setup_project_directories <- function(base_dir = ".") {
  # Removed: source("R/workflow_utils.R") - functions available from package

  required_dirs <- c("data", "figs", "output", "tmp")

  for (dir in required_dirs) {
    full_path <- file.path(base_dir, dir)
    if (!dir.exists(full_path)) {
      dir.create(full_path, recursive = TRUE)
      log_message(paste("Created directory:", full_path), "SETUP")
    }
  }

  log_message("Project directories verified", "SETUP")
  return(TRUE)
}

.copy_template_files <- function() {
  # workflow_utils functions are available through neuro2 package

  log_message("Copying template files to working directory...", "SETUP")

  # Find template directory
  template_dir <- .find_template_directory()

  if (is.null(template_dir)) {
    log_message("Could not find template directory in any location", "ERROR")
    return(FALSE)
  }

  # List files in the template directory
  log_message(
    paste0("Listing files in template directory: ", template_dir),
    "SETUP"
  )
  dir_contents <- list.files(template_dir)
  log_message(
    paste0("Directory contents: ", paste(dir_contents, collapse = ", ")),
    "SETUP"
  )

  # Get list of template files
  template_files <- list.files(
    template_dir,
    pattern = "\\.(qmd|yml|typ)$",
    full.names = TRUE
  )

  if (length(template_files) == 0) {
    log_message(paste0("No template files found in: ", template_dir), "ERROR")
    return(FALSE)
  }

  log_message(
    paste0("Found ", length(template_files), " template files"),
    "SETUP"
  )

  # Copy each file to working directory
  for (file in template_files) {
    dest_file <- basename(file)

    log_message(
      paste0("Processing template file: ", file, " -> ", dest_file),
      "SETUP"
    )

    if (!file.exists(file)) {
      log_message(paste0("Source file does not exist: ", file), "ERROR")
      next
    }

    # Determine if we should backup this file
    should_backup <- dest_file %in%
      c("template.qmd", "_quarto.yml", "_variables.yml", "config.yml")

    # Back up existing files before overwriting (only for main template files)
    if (file.exists(dest_file) && should_backup) {
      backup_file <- paste0(
        dest_file,
        ".",
        format(Sys.time(), "%Y%m%d_%H%M%S"),
        ".bak"
      )
      file.copy(dest_file, backup_file)
      log_message(paste0("Backed up existing file to: ", backup_file), "SETUP")
    }

    # Copy the latest version from inst
    copy_result <- file.copy(file, dest_file, overwrite = TRUE)
    if (copy_result) {
      log_message(paste0("Updated template file: ", dest_file), "SETUP")
    } else {
      log_message(
        paste0("Failed to update template file: ", dest_file),
        "ERROR"
      )
    }
  }

  # Verify essential files exist after copying
  .verify_essential_files(template_dir)

  return(TRUE)
}

.find_template_directory <- function() {
  # workflow_utils functions are available through neuro2 package

  # First try using system.file (for installed package)
  template_dir <- system.file(
    "quarto/templates/typst-report",
    package = "neuro2"
  )

  # If running from development environment, use local path
  if (template_dir == "") {
    template_dir <- "inst/quarto/templates/typst-report"
    log_message(
      paste0("Using development template directory: ", template_dir),
      "SETUP"
    )
  }

  # Check if template directory exists using helper function
  template_dir <- .find_directory(
    template_dir,
    c(
      "inst/quarto/templates/typst-report",
      "../inst/quarto/templates/typst-report",
      "../../inst/quarto/templates/typst-report"
    ),
    "template"
  )

  return(template_dir)
}

.verify_essential_files <- function(template_dir) {
  # workflow_utils functions are available through neuro2 package

  essential_files <- c(
    "template.qmd",
    "_quarto.yml",
    "_variables.yml",
    "config.yml"
  )

  missing_files <- character()
  for (file in essential_files) {
    if (!file.exists(file)) {
      missing_files <- c(missing_files, file)
    }
  }

  if (length(missing_files) > 0) {
    log_message(
      paste0(
        "Essential files still missing after copy: ",
        paste(missing_files, collapse = ", ")
      ),
      "ERROR"
    )

    # Last resort: try direct copy for each missing file
    for (file in missing_files) {
      source_file <- file.path(template_dir, file)
      if (file.exists(source_file)) {
        file.copy(source_file, file, overwrite = TRUE)
        log_message(paste0("Direct copy attempt for: ", file), "SETUP")
      }
    }
  }
}

.setup_quarto_extensions <- function(report_format) {
  # workflow_utils functions are available through neuro2 package

  log_message("Setting up Quarto extensions...", "SETUP")

  # Find extensions directory
  extensions_dir <- .find_extensions_directory()

  if (is.null(extensions_dir)) {
    log_message(
      "Could not find extensions directory in any location",
      "WARNING"
    )
    return(FALSE)
  }

  if (!dir.exists(extensions_dir)) {
    return(FALSE)
  }

  # Create _extensions directory in working directory
  if (!dir.exists("_extensions")) {
    dir.create("_extensions", recursive = TRUE, showWarnings = FALSE)
    log_message("Created _extensions directory", "SETUP")
  }

  # Copy brainworkup directory with all extensions
  brainworkup_dir <- file.path(extensions_dir, "brainworkup")
  if (dir.exists(brainworkup_dir)) {
    .copy_extensions(brainworkup_dir)

    # Verify required extension exists
    required_extension <- gsub("-typst$", "", report_format)
    if (!dir.exists(file.path("_extensions/brainworkup", required_extension))) {
      log_message(
        paste0("Required extension not found: ", required_extension),
        "WARNING"
      )
    } else {
      log_message(
        paste0("Required extension found: ", required_extension),
        "SETUP"
      )
    }
  } else {
    log_message(
      paste0("Brainworkup extensions directory not found: ", brainworkup_dir),
      "WARNING"
    )
  }

  return(TRUE)
}

.find_extensions_directory <- function() {
  # workflow_utils functions are available through neuro2 package

  # First try using system.file (for installed package)
  extensions_dir <- system.file("quarto/_extensions", package = "neuro2")

  # If running from development environment, use local path
  if (extensions_dir == "") {
    extensions_dir <- "inst/quarto/_extensions"
    log_message(
      paste0("Using development extensions directory: ", extensions_dir),
      "SETUP"
    )
  }

  # Check if extensions directory exists using helper function
  extensions_dir <- .find_directory(
    extensions_dir,
    c(
      "inst/quarto/_extensions",
      "../inst/quarto/_extensions",
      "../../inst/quarto/_extensions"
    ),
    "extensions"
  )

  return(extensions_dir)
}

.copy_extensions <- function(brainworkup_dir) {
  # workflow_utils functions are available through neuro2 package

  # Create brainworkup directory in _extensions
  if (!dir.exists("_extensions/brainworkup")) {
    dir.create(
      "_extensions/brainworkup",
      recursive = TRUE,
      showWarnings = FALSE
    )
    log_message("Created _extensions/brainworkup directory", "SETUP")
  }

  # List all extension directories
  extension_dirs <- list.dirs(
    brainworkup_dir,
    full.names = FALSE,
    recursive = FALSE
  )
  log_message(
    paste0("Found extensions: ", paste(extension_dirs, collapse = ", ")),
    "SETUP"
  )

  # Copy each extension directory
  for (ext_dir in extension_dirs) {
    src_dir <- file.path(brainworkup_dir, ext_dir)
    dest_dir <- file.path("_extensions/brainworkup", ext_dir)

    # Remove existing extension directory to ensure fresh copy
    if (dir.exists(dest_dir)) {
      log_message(
        paste0("Removing existing extension directory: ", ext_dir),
        "SETUP"
      )
      unlink(dest_dir, recursive = TRUE)
    }

    # Create the directory
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

    # Copy all files from the extension directory
    ext_files <- list.files(src_dir, full.names = TRUE)
    for (file in ext_files) {
      file.copy(file, dest_dir, recursive = TRUE)
    }
    log_message(paste0("Copied fresh extension: ", ext_dir), "SETUP")
  }
}

.check_r6_files <- function() {
  # workflow_utils functions are available through neuro2 package

  r6_files <- c(
    "R/ReportTemplateR6.R",
    "R/NeuropsychResultsR6.R",
    "R/NeuropsychReportSystemR6.R",
    "R/DomainProcessorR6.R",
    "R/DotplotR6.R",
    "R/DrilldownR6.R",
    "R/TableGTR6.R",
    "R/ReportUtilitiesR6.R",
    "R/TemplateContentManagerR6.R"
  )

  missing_files <- r6_files[!file.exists(r6_files)]
  if (length(missing_files) > 0) {
    log_message("Some R6 class files are missing:", "WARNING")
    for (file in missing_files) {
      log_message(paste0("  - ", file), "WARNING")
    }
  } else {
    log_message("All required R6 class files are present", "SETUP")
  }
}

.check_input_files <- function(input_dir) {
  # workflow_utils functions are available through neuro2 package

  csv_files <- list.files(input_dir, pattern = "\\.csv$")
  if (length(csv_files) == 0) {
    log_message(paste0("No CSV files found in ", input_dir), "WARNING")
  } else {
    log_message(
      paste0("Found ", length(csv_files), " CSV files in ", input_dir),
      "SETUP"
    )
  }
}
