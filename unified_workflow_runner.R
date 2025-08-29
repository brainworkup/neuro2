#!/usr/bin/env Rscript

# UNIFIED NEUROPSYCHOLOGICAL WORKFLOW RUNNER
# Refactored main controller script for the neuropsychological report generation workflow
# This script orchestrates the entire workflow using modular components

# Load required packages
required_packages <- c("yaml", "R6", "dplyr", "readr", "here", "quarto")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE, quietly = TRUE)
}

# Source utility modules
source("R/workflow_utils.R")
source("R/workflow_config.R")
source("R/workflow_data_processor.R")
source("R/workflow_domain_generator.R")
source("R/workflow_report_generator.R")
source("R/duckdb_neuropsych_loader.R")
source("R/ScoreTypeCacheR6.R")
source("R/DomainProcessorFactoryR6.R")
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/TableGTR6.R")
source("R/DotplotR6.R")
source("R/domain_validation_utils.R")
source("R/WorkflowRunnerR6.R")

# Initialize logging
log_file <- setup_logging()

# Print header
.print_header()

# Check for essential template files before starting
.print_colored("Checking for essential template files...", "blue")
essential_files <- c(
  "template.qmd",
  "_quarto.yml",
  "_variables.yml",
  "config.yml"
)

missing_files <- .check_essential_files(essential_files)

if (length(missing_files) > 0) {
  .print_colored(
    "Some essential template files are missing. Would you like to copy them from the template directory? (y/n)",
    "yellow"
  )
  answer <- readline(prompt = "")

  if (tolower(answer) == "y") {
    template_dir <- "inst/quarto/templates/typst-report"
    for (file in missing_files) {
      source_file <- file.path(template_dir, file)
      if (file.exists(source_file)) {
        # Only copy if destination doesn't exist
        if (!file.exists(file)) {
          file.copy(source_file, file, overwrite = FALSE)
          .print_colored(
            paste0("✓ Copied ", file, " from template directory"),
            "green"
          )
        } else {
          .print_colored(
            paste0("⚠️ ", file, " already exists, skipping copy"),
            "yellow"
          )
        }
      } else {
        .print_colored(
          paste0("⚠️ Could not find ", file, " in template directory"),
          "red"
        )
      }
    }
  }
}

# Parse command line arguments and load configuration
config_file <- .parse_config_args()
config <- .load_workflow_config(config_file)

# Create and run the workflow
workflow <- WorkflowRunnerR6$new(config)
result <- workflow$run()

# Print summary
workflow$print_summary(result)

# Exit with appropriate status code
if (result) {
  quit(status = 0)
} else {
  quit(status = 1)
}
