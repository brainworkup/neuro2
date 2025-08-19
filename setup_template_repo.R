# File: inst/scripts/setup_template_repo.R
# Run this to set up your neuro2 repository as a template

#' Setup Template Repository Structure
#' This creates all the necessary template files for patient workspaces
setup_template_repo <- function() {
  
  # Create patient template config
  patient_config <- list(
    patient = list(
      name = "PATIENT_NAME",
      age = "PATIENT_AGE", 
      date_of_birth = "PATIENT_DOB",
      assessment_date = "ASSESSMENT_DATE"
    ),
    data = list(
      input_dir = "data",
      output_dir = "output",
      format = "parquet",  # or "csv"
      neurocog_file = "neurocog.csv",
      neurobehav_file = "neurobehav.csv"
    ),
    processing = list(
      verbose = TRUE,
      parallel = FALSE,
      age_group = "auto"  # auto-detect from age
    ),
    output = list(
      generate_qmd = TRUE,
      generate_plots = TRUE,
      generate_tables = TRUE,
      output_format = "typst"  # or "pdf", "html"
    )
  )
  
  # Write config template
  yaml::write_yaml(
    patient_config, 
    file = "inst/patient_template/config.yml"
  )
  
  # Create patient setup script
  setup_script <- '#!/usr/bin/env Rscript
# File: setup_patient.R
# Run this script to set up a new patient workspace

#\' Set up patient workspace for neuropsychological assessment
#\' @param patient_name Patient identifier (will be used in file names)
#\' @param age Patient age in years
#\' @param assessment_date Date of assessment
#\' @param base_dir Base directory for workspace (default: current directory)
setup_patient_workspace <- function(
  patient_name, 
  age = NULL,
  assessment_date = Sys.Date(),
  base_dir = "."
) {
  
  message("🧠 Setting up neuropsychological assessment workspace for ", patient_name)
  
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
  analysis_script <- sprintf(\'
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
  data_files <- validate_and_load_data()
  
  # Step 2: Process all domains
  message("🧠 Processing cognitive and behavioral domains...")
  results <- process_all_domains(
    age_group = config$processing$age_group,
    verbose = config$processing$verbose
  )
  
  # Step 3: Generate report
  message("📄 Generating assessment report...")
  report_path <- generate_complete_report(
    patient_name = config$patient$name,
    results = results,
    output_format = config$output$output_format
  )
  
  message("✅ Assessment complete! Report saved to: ", report_path)
  return(report_path)
}

# Run if called directly
if (!interactive()) {
  main_analysis()
}
\', patient_name, assessment_date)
  
  # Write analysis script
  analysis_path <- file.path(base_dir, "run_analysis.R")
  writeLines(analysis_script, analysis_path)
  message("🔬 Created analysis script: ", analysis_path)
  
  # Create data README
  data_readme <- sprintf(\'# Data Directory for %s

## Required Files

Place your assessment data files in this directory:

- `neurocog.csv` - Neurocognitive test data
- `neurobehav.csv` - Neurobehavioral/emotional data  
- `validity.csv` - Performance/symptom validity data (optional)

## Data Format

Your CSV files should have these columns:
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
\', patient_name)
  
  writeLines(data_readme, file.path(base_dir, "data", "README.md"))
  
  message("📋 Workspace setup complete!")
  message("📂 Next steps:")
  message("   1. Copy your data files to data/")
  message("   2. Run: source(\\"run_analysis.R\\"); main_analysis()")
  
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
    cat("Usage: Rscript setup_patient.R PATIENT_NAME [AGE]\\n")
    cat("Example: Rscript setup_patient.R Isabella 12\\n")
  }
}
'
  
  writeLines(setup_script, "inst/patient_template/setup_patient.R")
  
  # Create main neuro2 loader
  neuro2_loader <- '
# File: R/setup_neuro2.R
# Main loader for neuro2 functionality

#\' Load neuro2 package functionality
#\' @param verbose Whether to show loading messages
load_neuro2 <- function(verbose = TRUE) {
  
  if (verbose) message("🧠 Loading neuro2 neuropsychological assessment tools...")
  
  # Load required packages
  required_packages <- c(
    "dplyr", "readr", "ggplot2", "gt", "gtExtras", 
    "yaml", "here", "R6", "glue", "arrow"
  )
  
  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      message("Installing required package: ", pkg)
      install.packages(pkg)
    }
    library(pkg, character.only = TRUE, quietly = !verbose)
  }
  
  # Source all R6 classes and utilities
  r_files <- list.files("R", pattern = "\\\\.R$", full.names = TRUE)
  r_files <- r_files[!grepl("setup_neuro2.R", r_files)]
  
  for (file in r_files) {
    if (verbose) message("  Loading: ", basename(file))
    source(file)
  }
  
  if (verbose) message("✅ neuro2 loaded successfully!")
  
  invisible(TRUE)
}

# Auto-load when sourced
if (!exists(".neuro2_loaded")) {
  load_neuro2()
  .neuro2_loaded <- TRUE
}
'
  
  writeLines(neuro2_loader, "R/setup_neuro2.R")
  
  message("✅ Template repository setup complete!")
  message("📋 Next steps:")
  message("   1. Commit all changes to git")
  message("   2. Go to GitHub repo Settings → Check 'Template repository'")
  message("   3. Update README.md with usage instructions")
}

# Run the setup
setup_template_repo()