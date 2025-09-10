#!/usr/bin/env Rscript

# Quick File Upload Script for neuro2
# A simple wrapper to make file uploading as easy as possible

suppressPackageStartupMessages({
  if (!requireNamespace("neuro2", quietly = TRUE)) {
    stop("neuro2 package not found. Please install it first.")
  }
  library(neuro2)
})

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Help message
if (length(args) == 0 || args[1] %in% c("-h", "--help", "help")) {
  cat("🧠 neuro2 Quick File Upload\n")
  cat("===========================\n\n")
  cat("Usage:\n")
  cat("  Rscript quick_upload.R <patient_name> [method] [options]\n\n")
  cat("Arguments:\n")
  cat("  patient_name    Required. Name of the patient\n")
  cat("  method          Optional. Upload method: 'csv', 'pdf', or 'interactive' (default)\n\n")
  cat("Examples:\n")
  cat("  Rscript quick_upload.R \"John Doe\"                    # Interactive mode\n")
  cat("  Rscript quick_upload.R \"Jane Smith\" csv              # CSV upload mode\n")
  cat("  Rscript quick_upload.R \"Bob Johnson\" pdf             # PDF extraction mode\n\n")
  cat("For more options, use R directly:\n")
  cat("  upload_files(method = 'interactive')\n\n")
  quit(status = 0)
}

# Extract arguments
patient_name <- args[1]
method <- if (length(args) >= 2) args[2] else "interactive"

# Validate method
valid_methods <- c("csv", "pdf", "interactive")
if (!method %in% valid_methods) {
  cat("❌ Invalid method:", method, "\n")
  cat("Valid methods:", paste(valid_methods, collapse = ", "), "\n")
  quit(status = 1)
}

# Welcome message
cat("🧠 neuro2 Quick File Upload\n")
cat("===========================\n")
cat("Patient:", patient_name, "\n")
cat("Method:", method, "\n\n")

# Check requirements first
cat("📋 Checking system requirements...\n")
requirements <- check_upload_requirements()

if (!requirements$overall) {
  cat("\n❌ System not ready for file upload.\n")
  cat("Please fix the issues above and try again.\n")
  quit(status = 1)
}

cat("✅ System is ready for file upload!\n\n")

# Run the upload
tryCatch({
  result <- upload_files(
    method = method,
    patient_name = patient_name
  )
  
  if (result$success) {
    cat("\n🎉 Upload successful!\n")
    
    # Ask if user wants to run the workflow
    if (interactive()) {
      response <- readline(prompt = "Run the neuro2 workflow now? (y/n): ")
      if (tolower(response) %in% c("y", "yes")) {
        cat("🚀 Running workflow...\n")
        system(paste("./unified_neuropsych_workflow.sh", shQuote(patient_name)))
      }
    } else {
      cat("💡 To run the workflow:\n")
      cat("   ./unified_neuropsych_workflow.sh", shQuote(patient_name), "\n")
    }
    
    quit(status = 0)
  } else {
    cat("\n❌ Upload failed:", result$message, "\n")
    quit(status = 1)
  }
  
}, error = function(e) {
  cat("\n❌ Error during upload:", e$message, "\n")
  quit(status = 1)
})