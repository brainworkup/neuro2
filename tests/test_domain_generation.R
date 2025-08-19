#!/usr/bin/env Rscript

# Test domain generation in isolation

# Remove existing files first
domain_files <- c(
  "_02-01_iq.qmd", "_02-01_iq_text.qmd",
  "_02-02_academics.qmd", "_02-02_academics_text.qmd",
  "_02-03_verbal.qmd", "_02-03_verbal_text.qmd",
  "_02-04_spatial.qmd", "_02-04_spatial_text.qmd",
  "_02-05_memory.qmd", "_02-05_memory_text.qmd",
  "_02-06_executive.qmd", "_02-06_executive_text.qmd",
  "_02-07_motor.qmd", "_02-07_motor_text.qmd",
  "_02-10_emotion_child.qmd"
)

cat("Removing existing domain files...\n")
for (file in domain_files) {
  if (file.exists(file)) {
    file.remove(file)
    cat("✓ Removed:", file, "\n")
  }
}

# Test domain generation directly
cat("Testing domain generation...\n")
source("R/workflow_domain_generator.R")
source("R/workflow_config.R")

# Load config
config <- load_workflow_config("config.yml")

# Test the main generation function
cat("Calling generate_workflow_domains...\n")
result <- generate_workflow_domains(config)

cat("Result:", result, "\n")

# List what was generated
generated <- list.files(pattern = "^_02-[0-9]+_.*\\.qmd$")
cat("Generated files:\n")
for (file in generated) {
  cat("  ✓", file, "\n")
}