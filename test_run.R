# Simple script to run the test workflow
# Run this in your R console or RStudio

# First, make sure we're in the correct directory
cat("Current working directory:", getwd(), "\n")

# Source the setup environment script to check requirements
cat("\n--- Running setup_environment.R ---\n")
source("setup_environment.R")

# Source the check_package script to verify R6 classes
cat("\n--- Running check_package.R ---\n")
source("check_package.R")

# Source the run_test_workflow script
cat("\n--- Running run_test_workflow.R ---\n")
tryCatch(
  {
    source("run_test_workflow.R")
    cat("Workflow completed successfully!\n")
  },
  error = function(e) {
    cat("Error running workflow:", e$message, "\n")

    # Try to provide more context about the error
    if (grepl("NeuropsychReportSystemR6", e$message)) {
      cat("This might be related to the R6 class not being loaded correctly.\n")
      cat("Check that you've sourced all R6 class files.\n")
    } else if (grepl("Column", e$message)) {
      cat("This might be related to missing columns in your data.\n")
      cat("Check the structure of your CSV files.\n")
    } else {
      cat("Check the error message for more details.\n")
    }
  }
)
