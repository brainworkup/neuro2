#!/usr/bin/env Rscript

# joey_startup_clean.R - FIXED VERSION
# Pure R code only - no external dependencies

patient_name <- "Ethan"

# Load the workflow function
source("inst/scripts/00_complete_neuropsych_workflow_FIXED.R")

# Create a simple wrapper
run_workflow <- function(patient = patient_name) {
  # Now run_neuropsych_workflow() actually exists!
  run_neuropsych_workflow(
    patient = patient,
    generate_qmd = TRUE,
    render_report = TRUE
  )
}

cat("========================================\n")
cat("Neuropsych Workflow Ready\n")
cat("========================================\n")
cat("Patient set to:", patient_name, "\n")
cat("\nCommands:\n")
cat("  run_workflow()              - Run full workflow\n")
cat("  run_workflow('Name')        - Run with different patient\n")
cat("\nAdvanced options:\n")
cat("  run_neuropsych_workflow(\n")
cat("    patient = 'Name',\n")
cat("    generate_qmd = TRUE,      - Generate domain QMD files\n")
cat("    render_report = TRUE,     - Render PDF report\n")
cat("    force_reprocess = FALSE   - Force data reprocessing\n")
cat("  )\n")
cat("========================================\n")
