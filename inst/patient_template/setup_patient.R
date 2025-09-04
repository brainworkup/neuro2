#!/usr/bin/env Rscript
# File: setup_patient.R
# Run this script to set up a new patient workspace

#' Set up patient workspace for neuropsychological assessment
#' @param patient_name Patient identifier (will be used in file names)
#' @param age Patient age in years
#' @param assessment_date Date of assessment
#' @param base_dir Base directory for workspace (default: current directory)
setup_patient_workspace <- function(
  patient_name,
  age = NULL,
  assessment_date = Sys.Date(),
  base_dir = "."
) {
  message(
    "🧠 Setting up neuropsychological assessment workspace for ",
    patient_name
  )

  # Create directories
  dirs <- c("data", "figs", "output", "tmp", "config")
  for (dir in dirs) {
    dir_path <- file.path(base_dir, dir)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      message("📁 Created: ", dir_path)
    }
  }

  # Load and update config
  config_path <- file.path(base_dir, "config.yml")
  if (file.exists(config_path)) {
    config <- yaml::read_yaml(config_path)
  } else {
    # Create default config
    config <- yaml::read_yaml("inst/patient_template/config.yml")
  }

  # Update patient-specific info
  config$patient$name <- patient_name
  if (!is.null(age)) {
    config$patient$age <- age
    config$processing$age_group <- if (age >= 18) "adult" else "child"
  }
  config$patient$assessment_date <- as.character(assessment_date)

  # Write updated config
  yaml::write_yaml(config, config_path)
  message("⚙️  Updated config: ", config_path)

  # Create main analysis script
  analysis_script <- sprintf(
    '
# Neuropsychological Assessment Analysis for %s
# Generated on: %s

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
  data_success <- .process_workflow_data(config)

  if (!data_success) {
    stop("❌ Data processing failed. Please check your data files and config.")
  }

  # Step 2: Process all domains
  message("🧠 Processing cognitive and behavioral domains...")
  results <- process_all_domains(
    data_dir = config$data$input_dir,
    age_group = config$processing$age_group,
    verbose = config$processing$verbose
  )

  # Step 3: Generate report
  message("📄 Generating assessment report...")
  report_path <- generate_assessment_report(
    results = results,
    patient_info = config$patient,
    output_dir = config$data$output_dir,
    format = config$output$format
  )

  message("✅ Assessment complete! Report saved to: ", report_path)
  return(report_path)
}

# Run if called directly
if (!interactive()) {
  main_analysis()
}
',
    patient_name,
    assessment_date
  )

  # Write analysis script
  analysis_path <- file.path(base_dir, "run_analysis.R")
  writeLines(analysis_script, analysis_path)
  message("🔬 Created analysis script: ", analysis_path)

  # Create data README
  data_readme <- sprintf(
    '# Data Directory for %s

## Required Files

Place your assessment data files in this directory:

- `neurocog.parquet` - Neurocognitive test data
- `neurobehav.parquet` - Neurobehavioral/emotional data
- `validity.parquet` - Performance/symptom validity data (optional)

## Data Format

Your Parquet/CSV files should have these columns:
- `test_name` - Name of the test battery
- `scale` - Specific subtest or scale name
- `score` - Standard score, scaled score, or T-score
- `percentile` - Percentile rank
- `range` - Descriptive range (e.g., "Average", "Below Average")
- `domain` - Cognitive/behavioral domain
- `subdomain` - More specific domain categorization

## Security Note

⚠️ **Patient data files are automatically excluded from git tracking**
Your patient data will remain local and private.
',
    patient_name
  )

  writeLines(data_readme, file.path(base_dir, "data", "README.md"))

  message("📋 Workspace setup complete!")
  message("📂 Next steps:")
  message("   1. Copy your data files to data/")
  message("   2. Run: source(\"run_analysis.R\"); main_analysis()")

  invisible(base_dir)
}

# If running this script directly
if (!interactive()) {
  # Get patient info from command line or prompt
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) >= 1) {
    patient_name <- args[1]
    age <- if (length(args) >= 2) as.numeric(args[2]) else NULL
    setup_patient_workspace(patient_name, age)
  } else {
    cat("Usage: Rscript setup_patient.R PATIENT_NAME [AGE]\n")
    cat("Example: Rscript setup_patient.R Isabella 12\n")
  }
}
