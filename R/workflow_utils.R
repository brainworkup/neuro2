# Workflow Utility Functions
# Common utilities for the neuropsychological workflow

# Logging setup and functions
setup_logging <- function(log_file = "workflow.log") {
  cat("NEURO2 UNIFIED WORKFLOW LOG\n", file = log_file)
  cat(paste("Date:", Sys.time(), "\n\n"), file = log_file, append = TRUE)
  return(log_file)
}

log_message <- function(message, type = "INFO", log_file = "workflow.log") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry, file = log_file, append = TRUE)
  cat(log_entry)
}

# Console output functions
print_colored <- function(message, color = "blue") {
  colors <- list(
    red = "\033[0;31m",
    green = "\033[0;32m",
    yellow = "\033[1;33m",
    blue = "\033[0;34m",
    reset = "\033[0m"
  )
  
  cat(paste0(colors[[color]], message, colors$reset, "\n"))
}

print_header <- function() {
  print_colored(
    "🧠 NEUROPSYCHOLOGICAL REPORT GENERATION - UNIFIED WORKFLOW",
    "blue"
  )
  print_colored(
    "===========================================================",
    "blue"
  )
  print_colored("")
}

# File and directory utilities
find_directory <- function(primary_dir, alternative_dirs, dir_type = "directory") {
  if (dir.exists(primary_dir)) {
    return(primary_dir)
  }
  
  log_message(
    paste0(capitalize(dir_type), " directory not found: ", primary_dir),
    "WARNING"
  )
  
  for (alt_dir in alternative_dirs) {
    if (dir.exists(alt_dir)) {
      log_message(
        paste0("Found alternative ", dir_type, " directory: ", alt_dir),
        "SETUP"
      )
      return(alt_dir)
    }
  }
  
  return(NULL)
}

ensure_template_file <- function(template_file, log_type = "INFO") {
  log_message(
    paste0("Checking for template file: ", template_file),
    log_type
  )
  log_message(paste0("Current working directory: ", getwd()), log_type)
  
  if (file.exists(template_file)) {
    log_message(paste0("Template file found: ", template_file), log_type)
    file_info <- file.info(template_file)
    log_message(paste0("File size: ", file_info$size, " bytes"), log_type)
    log_message(paste0("Last modified: ", file_info$mtime), log_type)
    return(TRUE)
  }
  
  template_dir <- "inst/quarto/templates/typst-report"
  alt_template_path <- file.path(template_dir, template_file)
  
  if (file.exists(alt_template_path)) {
    log_message(
      paste0("Template found in template directory: ", alt_template_path),
      log_type
    )
    log_message("Copying template file to working directory...", log_type)
    file.copy(alt_template_path, template_file)
    
    if (file.exists(template_file)) {
      log_message("Template file copied successfully", log_type)
      return(TRUE)
    } else {
      log_message(
        paste0("Failed to copy template file from: ", alt_template_path),
        "ERROR"
      )
      return(FALSE)
    }
  } else {
    log_message(paste0("Template file not found: ", template_file), "ERROR")
    log_message(paste0("Also checked: ", alt_template_path), "ERROR")
    return(FALSE)
  }
}

create_directories <- function(dirs) {
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      log_message(paste0("Created directory: ", dir), "SETUP")
    }
  }
}

# Helper functions
capitalize <- function(str) {
  paste0(toupper(substring(str, 1, 1)), substring(str, 2))
}

# Package management
ensure_packages <- function(required_packages) {
  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      log_message(paste("Installing package:", pkg), "SETUP")
      install.packages(pkg)
    }
    library(pkg, character.only = TRUE, quietly = TRUE)
  }
}

# Template file checking
check_essential_files <- function(essential_files, template_dir = "inst/quarto/templates/typst-report") {
  missing_files <- character()
  
  for (file in essential_files) {
    if (!file.exists(file)) {
      if (file.exists(file.path(template_dir, file))) {
        print_colored(
          paste0("⚠️ Essential template file not found in working directory: ", file),
          "yellow"
        )
        print_colored(
          paste0("  This file exists in ", template_dir, " and will be copied during setup."),
          "yellow"
        )
      } else {
        print_colored(
          paste0("⚠️ Essential template file not found: ", file),
          "red"
        )
        print_colored(
          paste0("  This file is required and should be created before running the workflow."),
          "red"
        )
        missing_files <- c(missing_files, file)
      }
    }
  }
  
  return(missing_files)
}

# Data loading utilities
load_neuropsych_data <- function(data_dir) {
  parquet_file <- file.path(data_dir, "neurocog.parquet")
  csv_file <- file.path(data_dir, "neurocog.csv")
  feather_file <- file.path(data_dir, "neurocog.feather")
  
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

get_domains_from_data <- function(data_dir) {
  neurocog_data <- load_neuropsych_data(data_dir)
  if (is.null(neurocog_data)) {
    return(data.frame(domain = character(0)))
  }
  
  if ("domain" %in% names(neurocog_data)) {
    unique_domains <- unique(neurocog_data$domain)
    unique_domains <- unique_domains[!is.na(unique_domains)]
    return(data.frame(domain = unique_domains))
  }
  
  return(data.frame(domain = character(0)))
}

# Patient type determination
determine_patient_type <- function(age) {
  if (is.null(age)) {
    return("child")
  }
  
  if (age >= 18) {
    return("adult")
  } else {
    return("child")
  }
}