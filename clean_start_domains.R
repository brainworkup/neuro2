#!/usr/bin/env Rscript

# Remove existing incomplete domain files
domain_files_to_remove <- c(
  "_02-01_iq.qmd", "_02-01_iq_text.qmd",
  "_02-02_academics.qmd", "_02-02_academics_text.qmd",
  "_02-03_verbal.qmd", "_02-03_verbal_text.qmd",
  "_02-04_spatial.qmd", "_02-04_spatial_text.qmd",
  "_02-05_memory.qmd", "_02-05_memory_text.qmd",
  "_02-06_executive.qmd", "_02-06_executive_text.qmd",
  "_02-07_motor.qmd", "_02-07_motor_text.qmd",
  "_02-10_emotion_child.qmd"
)

cat("Removing existing incomplete domain files...\n")
for (file in domain_files_to_remove) {
  if (file.exists(file)) {
    file.remove(file)
    cat("✓ Removed:", file, "\n")
  }
}

cat("Cleanup complete!\n")