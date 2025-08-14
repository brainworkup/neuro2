#!/usr/bin/env Rscript

# Quick test of domain generation

# Clean up first
cat("Removing existing domain files...\n")
existing_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
for (file in existing_files) {
  if (file.exists(file)) {
    file.remove(file)
    cat("Removed:", file, "\n")
  }
}

cat("Starting domain generation test...\n")

# Load the domain generator
source("R/workflow_domain_generator.R")
source("R/workflow_config.R")

# Load config
config <- load_workflow_config("config.yml")
cat("Patient age:", config$patient$age, "\n")

# Test just the domain generation
result <- generate_workflow_domains(config)
cat("Generation result:", result, "\n")

# Check what was generated
generated_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
cat("Generated", length(generated_files), "files:\n")
for (file in generated_files) {
  cat("  ✓", file, "\n")
}