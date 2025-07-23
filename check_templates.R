#!/usr/bin/env Rscript

# Check for essential template files and copy them if needed
check_templates <- function() {
  # Define the source directory
  template_dir <- "inst/quarto/templates/typst-report"

  # Check if the directory exists
  if (!dir.exists(template_dir)) {
    cat("⚠️ Template directory not found:", template_dir, "\n")
    return(FALSE)
  }

  # List of essential template files
  essential_files <- c("template.qmd", "_quarto.yml", "_variables.yml")

  cat("Checking for essential template files...\n")

  # Check each essential file
  for (file in essential_files) {
    source_file <- file.path(template_dir, file)

    if (!file.exists(source_file)) {
      cat(
        "⚠️ Essential template file not found in source directory:",
        file,
        "\n"
      )
      cat("  Source path checked:", source_file, "\n")
      return(FALSE)
    }

    if (!file.exists(file)) {
      cat("📋 Copying essential template file:", file, "\n")
      file.copy(source_file, file)
      if (!file.exists(file)) {
        cat("⚠️ Failed to copy template file:", file, "\n")
        return(FALSE)
      }
    } else {
      cat("✓ Template file already exists:", file, "\n")
    }
  }

  cat("✅ All essential template files are in place.\n")
  return(TRUE)
}

# Run the check
check_templates()
