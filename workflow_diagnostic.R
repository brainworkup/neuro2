#!/usr/bin/env Rscript

# WORKFLOW DIAGNOSTIC SCRIPT
# This script helps diagnose the relationships and dependencies between workflow scripts

# Initialize log file
log_file <- "workflow_diagnostic.log"
cat("NEURO2 WORKFLOW DIAGNOSTIC LOG\n", file = log_file)
cat(paste("Date:", Sys.time(), "\n\n"), file = log_file, append = TRUE)

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry, file = log_file, append = TRUE)
  cat(log_entry)
}

# Check which workflow scripts exist
log_message("Checking for workflow scripts...")
workflow_scripts <- c(
  "setup_environment.R",
  "neuropsych_workflow.sh",
  "new_patient_workflow.R",
  "run_test_workflow.sh",
  "neuro2_R6_update_workflow.R",
  "neuro2_duckdb_workflow.R"
)

for (script in workflow_scripts) {
  if (file.exists(script)) {
    log_message(paste("Found:", script))
  } else {
    log_message(paste("Missing:", script), "WARNING")
  }
}

# Check for R6 classes
log_message("\nChecking for R6 class files...")
r6_files <- c(
  "R/ReportTemplateR6.R",
  "R/NeuropsychResultsR6.R",
  "R/NeuropsychReportSystemR6.R",
  "R/IQReportGeneratorR6.R",
  "R/DomainProcessorR6.R",
  "R/DotplotR6.R",
  "R/DuckDBProcessorR6.R"
)

for (file in r6_files) {
  if (file.exists(file)) {
    log_message(paste("Found:", file))
  } else {
    log_message(paste("Missing:", file), "WARNING")
  }
}

# Check for data directories and files
log_message("\nChecking for data directories...")
data_dirs <- c("data-raw", "data", "data-raw/csv", "output")

for (dir in data_dirs) {
  if (dir.exists(dir)) {
    log_message(paste("Found directory:", dir))
    # Count files in directory
    files <- list.files(dir, pattern = "\\.(csv|parquet|feather|arrow)$")
    if (length(files) > 0) {
      log_message(paste("  Contains", length(files), "data files"))
    } else {
      log_message(
        paste("  Directory is empty or contains no data files"),
        "WARNING"
      )
    }
  } else {
    log_message(paste("Missing directory:", dir), "WARNING")
  }
}

# Check for template files
log_message("\nChecking for template files...")
template_files <- list.files(pattern = "^_.*\\.(qmd|Rmd)$")
if (length(template_files) > 0) {
  log_message(paste("Found", length(template_files), "template files"))
} else {
  log_message("No template files found", "WARNING")
}

# Check for package dependencies
log_message("\nChecking for package dependencies...")
required_packages <- c(
  "R6",
  "dplyr",
  "readr",
  "purrr",
  "stringr",
  "tidyr",
  "here",
  "quarto",
  "duckdb",
  "arrow"
)

for (pkg in required_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    log_message(paste("Package installed:", pkg))
  } else {
    log_message(paste("Package missing:", pkg), "WARNING")
  }
}

# Analyze script dependencies
log_message("\nAnalyzing script dependencies...")

# Function to check if a script sources or calls another script
check_dependency <- function(script, potential_dependency) {
  if (!file.exists(script)) {
    return(FALSE)
  }

  content <- readLines(script, warn = FALSE)

  # Check for source() calls
  source_pattern <- paste0("source\\(['\"]", potential_dependency, "['\"]\\)")
  source_match <- any(grepl(source_pattern, content, fixed = FALSE))

  # Check for system() or shell script calls
  system_pattern <- paste0(
    "system\\(['\"].*",
    potential_dependency,
    ".*['\"]\\)"
  )
  system_match <- any(grepl(system_pattern, content, fixed = FALSE))

  # For shell scripts, check for direct execution
  exec_pattern <- paste0("\\./", potential_dependency)
  exec_match <- any(grepl(exec_pattern, content, fixed = FALSE))

  # Check for Rscript calls
  rscript_pattern <- paste0("Rscript.*", potential_dependency)
  rscript_match <- any(grepl(rscript_pattern, content, fixed = FALSE))

  return(source_match || system_match || exec_match || rscript_match)
}

# Create dependency matrix
dependency_matrix <- matrix(
  FALSE,
  nrow = length(workflow_scripts),
  ncol = length(workflow_scripts),
  dimnames = list(workflow_scripts, workflow_scripts)
)

for (i in 1:length(workflow_scripts)) {
  for (j in 1:length(workflow_scripts)) {
    if (i != j) {
      dependency_matrix[i, j] <- check_dependency(
        workflow_scripts[i],
        workflow_scripts[j]
      )
    }
  }
}

# Log dependencies
for (i in 1:length(workflow_scripts)) {
  script <- workflow_scripts[i]
  dependencies <- workflow_scripts[dependency_matrix[i, ]]

  if (length(dependencies) > 0) {
    log_message(paste0(
      script,
      " depends on: ",
      paste(dependencies, collapse = ", ")
    ))
  } else {
    log_message(paste0(
      script,
      " has no dependencies on other workflow scripts"
    ))
  }

  dependents <- workflow_scripts[dependency_matrix[, i]]
  if (length(dependents) > 0) {
    log_message(paste0(
      script,
      " is used by: ",
      paste(dependents, collapse = ", ")
    ))
  } else {
    log_message(paste0(script, " is not used by other workflow scripts"))
  }
}

log_message("\nDiagnostic complete. See workflow_diagnostic.log for details.")
