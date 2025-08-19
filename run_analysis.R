# Neuropsychological Assessment Analysis for Isabella
# Generated on: 2025-08-19

# Load required packages
library(here)
library(yaml)

# Source neuro2 functions
source("R/setup_neuro2.R")

# Load configuration
config <- yaml::read_yaml("config.yml")

# Run complete assessment pipeline
main_analysis <- function() {
  message("🚀 Starting neuropsychological assessment pipeline")

  # Step 1: Load and validate data
  message("📊 Loading and validating data...")
  data_success <- process_workflow_data(config)

  if (!data_success) {
    stop("❌ Data processing failed. Please check your data files and config.")
  }

  # Step 2: Process all domains
  message("🧠 Processing cognitive and behavioral domains...")

  # Determine patient type
  patient_type <- determine_patient_type(config$patient$age)

  # Check data status
  data_status <- check_data_exists(config)

  # Process domains using workflow function
  results <- process_all_domains(config, patient_type, data_status)

  if (!results) {
    warning("⚠️ Domain processing had issues, but continuing...")
  }

  # Step 3: Generate report using workflow function
  message("📄 Generating assessment report...")
  report_success <- generate_workflow_report(config)

  if (report_success) {
    message("✅ Assessment complete!")
  } else {
    message("⚠️ Assessment completed with warnings")
  }

  return(TRUE)
}

# Run if called directly
if (!interactive()) {
  main_analysis()
}
