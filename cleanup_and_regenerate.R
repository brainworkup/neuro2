#!/usr/bin/env Rscript

# CLEANUP AND REGENERATE SCRIPT
# This script removes incomplete domain files and regenerates them properly

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry)
}

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

print_colored("🗑️  CLEANUP AND REGENERATE DOMAIN FILES", "blue")
print_colored("=======================================", "blue")

# Step 1: Remove existing incomplete domain files
domain_files_to_remove <- list.files(
  pattern = "^_02-[0-9]+_.*\\.qmd$",
  full.names = FALSE
)

if (length(domain_files_to_remove) > 0) {
  print_colored(paste("Found", length(domain_files_to_remove), "domain files to remove"), "yellow")
  
  for (file in domain_files_to_remove) {
    if (file.exists(file)) {
      file.remove(file)
      print_colored(paste("✓ Removed:", file), "red")
    }
  }
} else {
  print_colored("No existing domain files to remove", "green")
}

# Step 2: Check for data files
print_colored("Checking for data files...", "blue")

data_dir <- "data"
if (!dir.exists(data_dir)) {
  dir.create(data_dir, recursive = TRUE)
  print_colored("Created data directory", "green")
}

# Check what data files exist
csv_files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)
parquet_files <- list.files(data_dir, pattern = "\\.parquet$", full.names = TRUE)

if (length(csv_files) == 0 && length(parquet_files) == 0) {
  print_colored("No data files found in data/ directory", "red")
  print_colored("Data files need to be generated first", "yellow")
  print_colored("Run the data processing workflow first", "yellow")
  quit(status = 1)
}

print_colored("Found data files:", "green")
for (file in c(csv_files, parquet_files)) {
  print_colored(paste("  -", basename(file)), "green")
}

# Step 3: Run the domain generation workflow
print_colored("Starting domain generation workflow...", "blue")

# Source the workflow
source("R/workflow_utils.R")
source("R/workflow_config.R") 
source("R/WorkflowRunnerR6.R")

# Load configuration
config <- load_workflow_config("config.yml")

# Create and run the workflow
workflow <- WorkflowRunnerR6$new(config)

# Only run domain generation step
print_colored("Running domain generation...", "blue")
result <- workflow$generate_domains()

if (result) {
  print_colored("✅ Domain generation completed successfully", "green")
} else {
  print_colored("❌ Domain generation failed", "red")
  quit(status = 1)
}

print_colored("✅ CLEANUP AND REGENERATE COMPLETE", "green")