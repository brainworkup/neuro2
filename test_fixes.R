# Test script to verify fixes for neuropsychological report generation

# Load necessary libraries
library(neuro2)

# Get the current directory (should be the project root)
project_dir <- getwd()

# Set up a test directory
test_dir <- file.path(tempdir(), "neuro2_test")
dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)
setwd(test_dir)

# Create test data directories
dir.create("data", showWarnings = FALSE)
dir.create("R", showWarnings = FALSE)
dir.create(
  "inst/quarto/templates/typst-report",
  recursive = TRUE,
  showWarnings = FALSE
)

# Copy necessary files from the project directory to the test directory
file.copy(
  file.path(project_dir, "unified_workflow_runner.R"),
  "unified_workflow_runner.R"
)
file.copy(
  file.path(project_dir, "R/NeuropsychReportSystemR6.R"),
  "R/NeuropsychReportSystemR6.R"
)
file.copy(file.path(project_dir, "_03-00_sirf.qmd"), "_03-00_sirf.qmd")
file.copy(
  file.path(project_dir, "inst/quarto/templates/typst-report/_03-00_sirf.qmd"),
  "inst/quarto/templates/typst-report/_03-00_sirf.qmd"
)

# Create sample CSV data files
neurocog_data <- data.frame(
  domain = c("General Cognitive Ability", "Memory", "Attention/Executive"),
  test = c("wais4", "wms4", "dkefs"),
  test_name = c("WAIS-IV", "WMS-IV", "D-KEFS"),
  scale = c("FSIQ", "Auditory Memory", "Trail Making"),
  score = c(100, 95, 90),
  z = c(0, -0.33, -0.67),
  percentile = c(50, 45, 40),
  range = c("Average", "Average", "Average"),
  stringsAsFactors = FALSE
)

neurobehav_data <- data.frame(
  domain = c("ADHD", "Psychiatric Disorders"),
  test = c("caars2_self", "pai"),
  test_name = c("CAARS2 Self", "PAI"),
  scale = c("Inattention/Executive Dysfunction", "Depression"),
  score = c(65, 70),
  z = c(1.5, 2.0),
  percentile = c(93, 98),
  range = c("Elevated", "Clinically Significant"),
  stringsAsFactors = FALSE
)

# Write sample data to CSV files
write.csv(neurocog_data, "data/neurocog.csv", row.names = FALSE)
write.csv(neurobehav_data, "data/neurobehav.csv", row.names = FALSE)

# Create a minimal _variables.yml file
cat(
  '
first_name: "Test"
last_name: "Patient"
date_of_birth: "2000-01-01"
date_of_evaluation: "2023-01-01"
age: 23
gender: "male"
',
  file = "_variables_test.yml"
)

# Create a minimal _03-00_sirf_text.qmd file
cat(
  '
This is a test summary for the neuropsychological report.
',
  file = "_03-00_sirf_text.qmd"
)

# Test the workflow runner
cat("Testing unified_workflow_runner.R...\n")
tryCatch(
  {
    source("unified_workflow_runner.R")
    runner <- UnifiedWorkflowRunner$new()
    runner$initialize_environment()
    cat("Initialization successful!\n")

    # Test domain variable definitions
    cat("Testing domain variable definitions...\n")
    source("_03-00_sirf.qmd")
    cat("Domain variables loaded successfully!\n")

    cat("All tests passed! The fixes appear to be working correctly.\n")
  },
  error = function(e) {
    cat("Error during testing:", e$message, "\n")
  }
)

# Return to the original directory
setwd(project_dir)

# Clean up
unlink(test_dir, recursive = TRUE)

cat("Test completed. Returned to original directory.\n")
