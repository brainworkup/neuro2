#!/usr/bin/env Rscript

# Test the dynamic output filename generation

# Read the _variables.yml file
if (file.exists("_variables.yml")) {
  variables <- yaml::read_yaml("_variables.yml")

  # Extract names
  first_name <- variables$first_name
  last_name <- variables$last_name

  # Clean names for filename (remove special characters)
  first_name <- gsub("[^A-Za-z0-9]", "", first_name)
  last_name <- gsub("[^A-Za-z0-9]", "", last_name)

  # Generate filename with current date
  date_str <- format(Sys.Date(), "%Y-%m-%d")

  output_file <- paste0(
    last_name,
    "-",
    first_name,
    "_neuropsych_report_",
    date_str,
    ".pdf"
  )

  cat("Based on _variables.yml:\n")
  cat("  First name:", variables$first_name, "\n")
  cat("  Last name:", variables$last_name, "\n")
  cat("\nGenerated output filename:\n")
  cat("  ", output_file, "\n")

  # Test what happens with the NeuropsychReportSystemR6 class
  cat("\nWhen initializing NeuropsychReportSystemR6, it will:\n")
  cat("1. Read patient info from _variables.yml\n")
  cat("2. Generate the filename:", output_file, "\n")
  cat("3. Use this filename unless explicitly overridden\n")
} else {
  cat("_variables.yml not found\n")
}
