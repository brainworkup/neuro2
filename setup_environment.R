# Setup Environment for Neuropsychological Report Generation (neuro2)
# This script installs necessary packages and sets up the environment

# Function to check and install packages
install_if_missing <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    message(paste("Installing package:", package))
    install.packages(package)
  } else {
    message(paste("Package already installed:", package))
  }
}

# Required packages
required_packages <- c(
  "R6",
  "dplyr",
  "readr",
  "purrr",
  "stringr",
  "tidyr",
  "here",
  "quarto"
)

# Install required packages
for (pkg in required_packages) {
  install_if_missing(pkg)
}

# Check for R6 class files in the current package
message("\nChecking for R6 class files in neuro2 package...")
r6_files <- c(
  "R/ReportTemplateR6.R",
  "R/NeuropsychResultsR6.R",
  "R/NeuropsychReportSystemR6.R",
  "R/DomainProcessorR6Combo.R",
  "R/DotplotR6.R",
  "R/DrilldownR6.R",
  "R/DuckDBProcessorR6.R",
  "R/ReportUtilitiesR6.R",
  "R/TableGTR6.R",
  "R/TemplateContentManagerR6.R"
)

missing_files <- r6_files[!file.exists(r6_files)]
if (length(missing_files) > 0) {
  message("⚠️ Some R6 class files are missing:")
  for (file in missing_files) {
    message(paste0("  - ", file))
  }
  message("The workflow may not function correctly without these files.")
} else {
  message("✓ All required R6 class files are present.")
}

# Check for required packages for utility functions
message("\nChecking for packages needed by utility functions...")
utility_packages <- c("ggplot2", "gt")
for (pkg in utility_packages) {
  install_if_missing(pkg)
}

# Check for template directories
template_dirs <- c(
  "inst/quarto/_extensions/brainworkup/neurotyp-adult",
  "inst/quarto/_extensions/brainworkup/neurotyp-forensic",
  "inst/quarto/_extensions/brainworkup/neurotyp-pediatric"
)

for (template_dir in template_dirs) {
  if (!dir.exists(template_dir)) {
    message("\nTemplate directory not found:", template_dir)
    message("Creating directory structure...")
    dir.create(template_dir, recursive = TRUE, showWarnings = FALSE)
    message("You need to ensure template files are placed in this directory.")
  } else {
    message("\n✓ Template directory exists:", template_dir)
  }
}

# Check for data directories
for (dir in c("data-raw", "data", "output")) {
  if (!dir.exists(dir)) {
    message(paste0("\nCreating directory: ", dir))
    dir.create(dir, showWarnings = FALSE)
  } else {
    message(paste0("\n✓ Directory exists: ", dir))
  }
}

# Check for CSV files in data-raw/csv
csv_files <- list.files(path = "data-raw/csv", pattern = "\\.csv$")
if (length(csv_files) == 0) {
  message("\n⚠️ No CSV files found in data-raw/csv directory.")
  message("You need to add CSV files before running the workflow.")
} else {
  message(paste0(
    "\n✓ Found ",
    length(csv_files),
    " CSV files in data-raw/csv directory:"
  ))
  for (file in csv_files) {
    message(paste0("  - ", file))
  }
}

# Check only for essential template files that should already exist
# Other template files will be copied by the WorkflowRunner later
qmd_files <- c(
  "template.qmd" # Only check for the main template file
)

message("\nChecking for essential template files...")
for (file in qmd_files) {
  if (file.exists(file)) {
    message(paste0("✓ Found template file: ", file))
  } else {
    message(paste0("⚠️ Essential template file not found: ", file))
    message(
      "  This file is required and should be created before running the workflow."
    )
  }
}

message("\n✓ Environment setup complete.")
message("You can now run the workflow with: source('run_test_workflow.R')")
