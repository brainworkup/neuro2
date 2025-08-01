#!/usr/bin/env Rscript

# TEST UNIFIED WORKFLOW
# This script tests the basic functionality of the unified workflow

# Set up logging
log_file <- "test_workflow.log"
cat("NEURO2 UNIFIED WORKFLOW TEST LOG\n", file = log_file)
cat(paste("Date:", Sys.time(), "\n\n"), file = log_file, append = TRUE)

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry, file = log_file, append = TRUE)
  cat(log_entry)
}

# Function to run tests
run_test <- function(test_name, test_function) {
  log_message(paste("Running test:", test_name), "TEST")

  result <- tryCatch(
    {
      test_function()
      TRUE
    },
    error = function(e) {
      log_message(paste("Test failed:", e$message), "ERROR")
      FALSE
    }
  )

  if (result) {
    log_message(paste("Test passed:", test_name), "SUCCESS")
  }

  return(result)
}

# Test 1: Check if required files exist
test_files_exist <- function() {
  required_files <- c(
    "unified_workflow_runner.R",
    "unified_neuropsych_workflow.sh",
    "unified_workflow_architecture.md",
    "UNIFIED_WORKFLOW_README.md"
  )

  for (file in required_files) {
    if (!file.exists(file)) {
      stop(paste("Required file not found:", file))
    }
  }

  log_message("All required files exist")
  return(TRUE)
}

# Test 2: Check if R packages can be loaded
test_packages <- function() {
  required_packages <- c("yaml", "R6", "dplyr", "readr", "here")

  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(paste("Required package not installed:", pkg))
    }
  }

  log_message("All required packages can be loaded")
  return(TRUE)
}

# Test 3: Check if R6 class files exist
test_r6_classes <- function() {
  r6_files <- c(
    "R/ReportTemplateR6.R",
    "R/NeuropsychResultsR6.R",
    "R/NeuropsychReportSystemR6.R",
    "R/DomainProcessorR6.R",
    "R/DotplotR6.R",
    "R/DrilldownR6.R",
    "R/DuckDBProcessorR6.R",
    "R/TableGT_ModifiedR6.R",
    "R/ReportUtilitiesR6.R",
    "R/TemplateContentManagerR6.R"
  )

  missing_files <- r6_files[!file.exists(r6_files)]
  if (length(missing_files) > 0) {
    log_message("Some R6 class files are missing:", "WARNING")
    for (file in missing_files) {
      log_message(paste("  -", file), "WARNING")
    }
    log_message(
      "Tests will continue but workflow may not function correctly",
      "WARNING"
    )
  } else {
    log_message("All R6 class files exist")
  }

  return(TRUE)
}

# Test 4: Create test directories
test_directories <- function() {
  test_dirs <- c("data-raw/csv", "data", "output")

  for (dir in test_dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      log_message(paste("Created directory:", dir))
    } else {
      log_message(paste("Directory exists:", dir))
    }
  }

  return(TRUE)
}

# Test 5: Create test configuration
test_configuration <- function() {
  config_file <- "test_config.yml"

  test_config <- list(
    patient = list(
      name = "Test Patient",
      age = 35,
      doe = format(Sys.Date(), "%Y-%m-%d")
    ),
    data = list(
      input_dir = "data-raw/csv",
      output_dir = "data",
      format = "csv"
    ),
    processing = list(use_duckdb = TRUE, parallel = FALSE),
    report = list(
      template = "template.qmd",
      format = "html",
      output_dir = "output"
    )
  )

  yaml::write_yaml(test_config, config_file)
  log_message(paste("Created test configuration file:", config_file))

  # Verify the file was created
  if (!file.exists(config_file)) {
    stop("Failed to create test configuration file")
  }

  return(TRUE)
}

# Test 6: Create sample CSV data
test_sample_data <- function() {
  # Create a simple test CSV file
  test_csv <- file.path("data-raw", "csv", "test_data.csv")

  test_data <- data.frame(
    test = c("WISC-V", "WISC-V", "WISC-V", "WISC-V"),
    test_name = c(
      "Wechsler Intelligence Scale for Children",
      "Wechsler Intelligence Scale for Children",
      "Wechsler Intelligence Scale for Children",
      "Wechsler Intelligence Scale for Children"
    ),
    scale = c(
      "Full Scale (FSIQ)",
      "Verbal Comprehension (VCI)",
      "Perceptual Reasoning (PRI)",
      "Working Memory (WMI)"
    ),
    raw_score = c(NA, NA, NA, NA),
    score = c(105, 110, 100, 95),
    ci_95 = c("100-110", "105-115", "95-105", "90-100"),
    percentile = c(63, 75, 50, 37),
    range = c("Average", "High Average", "Average", "Average"),
    domain = c(
      "General Cognitive Ability",
      "General Cognitive Ability",
      "General Cognitive Ability",
      "General Cognitive Ability"
    ),
    subdomain = c("Overall", "Verbal", "Nonverbal", "Working Memory"),
    narrow = c(NA, NA, NA, NA),
    pass = c(NA, NA, NA, NA),
    verbal = c(NA, "Yes", "No", NA),
    timed = c(NA, "No", "No", "Yes"),
    result = c(NA, NA, NA, NA),
    z = c(0.33, 0.67, 0, -0.33)
  )

  write.csv(test_data, test_csv, row.names = FALSE)
  log_message(paste("Created test CSV file:", test_csv))

  # Verify the file was created
  if (!file.exists(test_csv)) {
    stop("Failed to create test CSV file")
  }

  return(TRUE)
}

# Test 7: Test workflow runner script syntax
test_workflow_runner_syntax <- function() {
  # Check if the script has syntax errors
  result <- system(
    "Rscript -e 'source(\"unified_workflow_runner.R\", echo = TRUE, max.deparse.length = 10000, keep.source = TRUE)'",
    intern = TRUE
  )

  # Check for error messages
  errors <- grep("Error", result, value = TRUE)
  if (length(errors) > 0) {
    for (error in errors) {
      log_message(paste("Syntax error:", error), "ERROR")
    }
    stop("Syntax errors found in unified_workflow_runner.R")
  }

  log_message("No syntax errors found in unified_workflow_runner.R")
  return(TRUE)
}

# Test 8: Test shell script syntax
test_shell_script_syntax <- function() {
  # Check if the script has syntax errors
  result <- system(
    "bash -n unified_neuropsych_workflow.sh",
    ignore.stdout = TRUE,
    ignore.stderr = TRUE
  )

  if (result != 0) {
    stop("Syntax errors found in unified_neuropsych_workflow.sh")
  }

  log_message("No syntax errors found in unified_neuropsych_workflow.sh")
  return(TRUE)
}

# Run all tests
log_message("Starting unified workflow tests", "TEST")

tests <- list(
  "Required files exist" = test_files_exist,
  "Required packages can be loaded" = test_packages,
  "R6 class files exist" = test_r6_classes,
  "Test directories" = test_directories,
  "Test configuration" = test_configuration,
  "Sample data creation" = test_sample_data,
  "Workflow runner syntax" = test_workflow_runner_syntax,
  "Shell script syntax" = test_shell_script_syntax
)

results <- sapply(names(tests), function(test_name) {
  run_test(test_name, tests[[test_name]])
})

# Print summary
log_message("\nTest Summary:", "SUMMARY")
log_message(paste("Total tests:", length(tests)), "SUMMARY")
log_message(paste("Passed:", sum(results)), "SUMMARY")
log_message(paste("Failed:", sum(!results)), "SUMMARY")

if (all(results)) {
  log_message(
    "\nAll tests passed! The unified workflow is ready to use.",
    "SUCCESS"
  )
  log_message("To run the workflow, use:", "INFO")
  log_message("  ./unified_neuropsych_workflow.sh", "INFO")
  log_message("  or", "INFO")
  log_message("  Rscript unified_workflow_runner.R", "INFO")
} else {
  log_message(
    "\nSome tests failed. Please fix the issues before using the workflow.",
    "WARNING"
  )
}

# Make the scripts executable
system("chmod +x unified_workflow_runner.R")
system("chmod +x unified_neuropsych_workflow.sh")
log_message("Made workflow scripts executable", "INFO")

log_message("Test script completed", "INFO")
