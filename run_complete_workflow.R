#!/usr/bin/env Rscript

# COMPLETE WORKFLOW RUNNER
# Starts from data processing and generates clean domain files

# Function to print colored messages
print_colored <- function(message, color = "blue") {
  colors <- list(
    red = "\033[0;31m",
    green = "\033[0;32m",
    yellow = "\033[1;33m",
    blue = "\033[0;34m",
    reset = "\033[0m"
  )

  cat(paste0(colors[[color]], message, colors$reset, "\n"))
}

# Print header
print_colored("🔄 COMPLETE NEUROPSYCH WORKFLOW", "blue")
print_colored("===============================", "blue")

# Step 1: Remove existing domain files
print_colored("Step 1: Cleaning up existing domain files...", "blue")

domain_files_to_remove <- c(
  "_02-01_iq.qmd",
  "_02-01_iq_text.qmd",
  "_02-02_academics.qmd",
  "_02-02_academics_text.qmd",
  "_02-03_verbal.qmd",
  "_02-03_verbal_text.qmd",
  "_02-04_spatial.qmd",
  "_02-04_spatial_text.qmd",
  "_02-05_memory.qmd",
  "_02-05_memory_text.qmd",
  "_02-06_executive.qmd",
  "_02-06_executive_text.qmd",
  "_02-07_motor.qmd",
  "_02-07_motor_text.qmd",
  "_02-10_emotion_child.qmd",
  "_02-10_emotion_child_text_self.qmd",
  "_02-10_emotion_child_text_parent.qmd"
)

removed_count <- 0
for (file in domain_files_to_remove) {
  if (file.exists(file)) {
    file.remove(file)
    print_colored(paste("✓ Removed:", file), "red")
    removed_count <- removed_count + 1
  }
}

if (removed_count == 0) {
  print_colored("No existing domain files to remove", "green")
} else {
  print_colored(
    paste("Removed", removed_count, "existing domain files"),
    "green"
  )
}

# Step 2: Run the WorkflowRunnerR6
print_colored("Step 2: Running complete workflow...", "blue")

# Source the required modules
source("R/workflow_utils.R")
source("R/workflow_config.R")
source("R/WorkflowRunnerR6.R")

# Load configuration
config <- load_workflow_config("config.yml")

# Create and run the workflow
workflow <- WorkflowRunnerR6$new(config)
result <- workflow$run_workflow()

# Print summary
workflow$print_summary(result)

if (result) {
  print_colored("✅ COMPLETE WORKFLOW SUCCESSFUL", "green")

  # List generated domain files
  generated_files <- list.files(pattern = "^_02-[0-9]+_.*\\.qmd$")
  if (length(generated_files) > 0) {
    print_colored(
      paste("Generated", length(generated_files), "domain files:"),
      "green"
    )
    for (file in sort(generated_files)) {
      print_colored(paste("  ✓", file), "green")
    }
  }
} else {
  print_colored("❌ WORKFLOW FAILED", "red")
  quit(status = 1)
}
