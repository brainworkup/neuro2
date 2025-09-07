#!/usr/bin/env Rscript

#' Fix source() calls inside functions
#' This script identifies and fixes the problematic pattern

cat("========================================\n")
cat("FIXING source() INSIDE FUNCTIONS\n")
cat("========================================\n\n")

# Files with source() inside functions based on your output
problem_files <- list(
  list(
    file = "R/load_all_workflow_components.R",
    line = 33,
    issue = "source(file)"
  ),
  list(
    file = "R/setup_neuro2.R", 
    line = 49,
    issue = "source(here::here(file))"
  ),
  list(
    file = "R/workflow_data_processor.R",
    lines = c(15, 45),
    issue = "Multiple source calls"
  ),
  list(
    file = "R/workflow_domain_generator.R",
    lines = c(87, 658, 665),
    issue = "Multiple source calls"
  ),
  list(
    file = "R/workflow_report_generator.R",
    lines = c(126, 191),
    issue = "Multiple source calls"
  ),
  list(
    file = "R/workflow_setup.R",
    lines = c(7, 12, 27, 66),
    issue = "Multiple source calls"
  )
)

# Function to fix source() calls
fix_source_in_file <- function(filepath) {
  if (!file.exists(filepath)) {
    cat("  ⚠️  File not found:", filepath, "\n")
    return(FALSE)
  }
  
  # Backup original
  backup_path <- paste0(filepath, ".backup_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy(filepath, backup_path)
  
  # Read file
  lines <- readLines(filepath)
  original_lines <- lines
  
  # Find functions with source() inside
  in_function <- FALSE
  function_depth <- 0
  modified <- FALSE
  
  for (i in seq_along(lines)) {
    line <- lines[i]
    
    # Track if we're inside a function
    if (grepl("function\\s*\\(", line)) {
      in_function <- TRUE
      function_depth <- function_depth + 1
    }
    
    # Track closing braces
    if (in_function && grepl("^\\}", line)) {
      function_depth <- function_depth - 1
      if (function_depth == 0) {
        in_function <- FALSE
      }
    }
    
    # Fix source() calls inside functions
    if (in_function && grepl("^[^#]*source\\(", line)) {
      # Comment it out and add lazy loading alternative
      lines[i] <- paste0("  # FIXED: ", trimws(line), " # Moved to lazy loading")
      
      # Add a check before the commented line
      check_line <- "  # Use require() or check if object exists instead"
      lines <- append(lines, check_line, after = i - 1)
      
      modified <- TRUE
      cat("  Fixed line", i, "in", basename(filepath), "\n")
    }
  }
  
  # Write back if modified
  if (modified) {
    writeLines(lines, filepath)
    cat("  ✓ Fixed", basename(filepath), "\n")
    return(TRUE)
  }
  
  return(FALSE)
}

# Create a centralized loader that runs ONCE
create_centralized_loader <- function() {
  cat("\nCreating centralized loader...\n")
  
  loader_content <- '
#\' Centralized Component Loader - Runs ONCE
#\' 
#\' This replaces all the source() calls scattered in functions
#\' Load this ONCE at the start of your workflow

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
  
  # Load R6 classes
  for (file in r6_files) {
    filepath <- here::here("R", file)
    if (file.exists(filepath)) {
      # Check if class already exists
      class_name <- gsub("\\\\.R$", "", file)
      if (!exists(class_name)) {
        source(filepath)
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
      source(filepath)
      message("  ✓ Loaded ", file)
    }
  }
  
  # Mark as loaded
  assign(".COMPONENTS_LOADED", TRUE, envir = .GlobalEnv)
  
  message("All components loaded successfully\\n")
  return(invisible(TRUE))
}

# Load immediately when sourced
load_neuro2_components()
'
  
  writeLines(loader_content, "R/load_components_once.R")
  cat("  ✓ Created R/load_components_once.R\n")
}

# Apply fixes
cat("Fixing source() calls in functions...\n")

for (problem in problem_files) {
  cat("\nProcessing", problem$file, "...\n")
  fix_source_in_file(problem$file)
}

# Create the centralized loader
create_centralized_loader()

cat("\n========================================\n")
cat("✓ SOURCE() FIXES COMPLETE\n")
cat("========================================\n")
cat("\nNow update your workflow to use:\n")
cat("  source('R/load_components_once.R')\n")
cat("at the START, instead of source() inside functions\n")
