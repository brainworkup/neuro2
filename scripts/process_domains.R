#!/usr/bin/env Rscript

# This script processes all domain QMD files and renders them to Typst format
# It's designed to be called from CMake but can also be run standalone

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Default values
path_data <- "data"
output_dir <- "output/domains"

# If arguments are provided, use them
if (length(args) >= 1) {
  path_data <- args[1]
}
if (length(args) >= 2) {
  output_dir <- args[2]
}

# Load required packages
library(quarto)
library(knitr)

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Predefined list of domain QMD files
domain_files <- c(
  "_02-01_iq.qmd",
  "_02-02_academics.qmd",
  "_02-03_verbal.qmd",
  "_02-04_spatial.qmd",
  "_02-05_memory.qmd",
  "_02-06_executive.qmd",
  "_02-07_motor.qmd",
  "_02-12_daily_living.qmd",
  "_02-08_social.qmd",
  "_02-09_adhd_adult.qmd",
  "_02-10_emotion_adult.qmd",
  "_02-09_adhd_child.qmd",
  "_02-10_emotion_child.qmd",
  "_02-11_adaptive.qmd",
  "_03-00_sirf.qmd"
)

# Process each domain file
results <- data.frame(
  file = character(),
  status = character(),
  error = character(),
  stringsAsFactors = FALSE
)

for (file in domain_files) {
  cat("Processing domain:", file, "\n")

  # Full paths
  input_path <- file.path(path_data, file)

  # Extract base name without extension for output filename
  base_name <- tools::file_path_sans_ext(basename(file))
  output_path <- file.path(output_dir, paste0(base_name, ".typ"))

  # Check if input file exists
  if (!file.exists(input_path)) {
    message("Warning: Input file does not exist: ", input_path)
    results <- rbind(
      results,
      data.frame(
        file = file,
        status = "error",
        error = "File not found",
        stringsAsFactors = FALSE
      )
    )
    next
  }

  # Attempt to render the file
  tryCatch(
    {
      # Extract just the filename from the output path
      output_filename <- basename(output_path)

      # Create output directory if it doesn't exist
      output_dir_path <- dirname(output_path)
      if (!dir.exists(output_dir_path)) {
        dir.create(output_dir_path, recursive = TRUE)
      }

      # Change to output directory, render, then change back
      original_dir <- getwd()
      setwd(output_dir_path)

      quarto::quarto_render(
        input_path,
        output_format = "typst",
        output_file = output_filename
      )

      # Change back to original directory
      setwd(original_dir)
      results <- rbind(
        results,
        data.frame(
          file = file,
          status = "success",
          error = "",
          stringsAsFactors = FALSE
        )
      )
    },
    error = function(e) {
      message("Error processing file: ", file, " - ", e$message)
      results <- rbind(
        results,
        data.frame(
          file = file,
          status = "error",
          error = e$message,
          stringsAsFactors = FALSE
        )
      )
    }
  )
}

# Write processing results to a file
results_path <- file.path(output_dir, "processing_results.csv")
write.csv(results, results_path, row.names = FALSE)

# Create a stamp file to indicate completion
stamp_file <- file.path(dirname(output_dir), "domains_processed.stamp")
file.create(stamp_file)

# Summary
cat("\nProcessing Summary:\n")
cat("Total files:", nrow(results), "\n")
cat("Successful:", sum(results$status == "success"), "\n")
cat("Failed:", sum(results$status == "error"), "\n")
cat("Results written to:", results_path, "\n")
cat("Stamp file created:", stamp_file, "\n")
