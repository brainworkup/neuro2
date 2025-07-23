#!/usr/bin/env Rscript

# NEUROPSYCHOLOGICAL REPORT WORKFLOW WRAPPER
# This script ensures templates are set up before running the main workflow

# Function to print colored messages in the console
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
print_colored("🧠 NEUROPSYCHOLOGICAL REPORT WORKFLOW WRAPPER", "blue")
print_colored("==============================================", "blue")
print_colored("")

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Default configuration file
config_file <- "config.yml"

# Check if config file is provided as argument
if (length(args) > 0) {
  if (args[1] == "--config" && length(args) > 1) {
    config_file <- args[2]
  } else {
    config_file <- args[1]
  }
}

# Step 1: Run the template setup script
print_colored("Step 1: Setting up template files...", "blue")
setup_status <- system("./setup_templates.R")

# Check if setup was successful
if (setup_status != 0) {
  print_colored("Template setup failed. Please check the errors above.", "red")
  print_colored("Fix the template issues before running the workflow.", "red")
  quit(status = 1)
}

print_colored("Template setup completed successfully.", "green")

# Step 2: Run the main workflow
print_colored("Step 2: Running the main workflow...", "blue")
workflow_cmd <- paste0("Rscript unified_workflow_runner.R ", config_file)
print_colored(paste0("Executing: ", workflow_cmd), "blue")

workflow_status <- system(workflow_cmd)

# Check if workflow was successful
if (workflow_status != 0) {
  print_colored(
    "Workflow execution failed. Please check the errors above.",
    "red"
  )
  quit(status = 1)
} else {
  print_colored("Workflow completed successfully!", "green")
  quit(status = 0)
}
