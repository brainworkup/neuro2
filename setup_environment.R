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
  "R/IQReportGeneratorR6.R",
  "R/DomainProcessorR6.R"
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

# Check for template directory
template_dir <- "inst/extdata/_extensions/neurotyp-forensic"
if (!dir.exists(template_dir)) {
  message("\nTemplate directory not found:", template_dir)
  message("Creating directory structure...")
  dir.create(template_dir, recursive = TRUE, showWarnings = FALSE)
  message("You need to ensure template files are placed in this directory.")
} else {
  message("\n✓ Template directory exists:", template_dir)
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

# Check for CSV files in data-raw
csv_files <- list.files(path = "data-raw", pattern = "\\.csv$")
if (length(csv_files) == 0) {
  message("\n⚠️ No CSV files found in data-raw directory.")
  message("You need to add CSV files before running the workflow.")
} else {
  message(paste0(
    "\n✓ Found ",
    length(csv_files),
    " CSV files in data-raw directory:"
  ))
  for (file in csv_files) {
    message(paste0("  - ", file))
  }
}

# Check for template QMD files
qmd_files <- c(
  "_01-00_nse_forensic.qmd",
  "_02-00_behav_obs.qmd",
  "_02-01_iq_text.qmd",
  "_02-05_memory_text.qmd",
  "_03-00_sirf_text.qmd",
  "_03-01_recommendations.qmd"
)

missing_qmd <- qmd_files[!file.exists(qmd_files)]
if (length(missing_qmd) > 0) {
  message("\n⚠️ Some template QMD files are missing:")
  for (file in missing_qmd) {
    message(paste0("  - ", file))
  }
  message("These files are needed for the report template.")
} else {
  message("\n✓ All template QMD files are present.")
}

message("\n✓ Environment setup complete.")
message("You can now run the workflow with: source('run_test_workflow.R')")
