#!/usr/bin/env Rscript

#' Complete Neuropsychological Report Workflow (FIXED)
#' 
#' This script provides a unified entry point for the entire neuropsych report
#' generation process, from raw data to final PDF output.
#' 
#' FIXES:
#' 1. Uses generate_domain_files.R instead of check_all_templates.R for domains
#' 2. Only generates assets for domains with data
#' 3. Ensures figures are saved in figs/ directory
#' 
#' Usage:
#'   Rscript complete_neuropsych_workflow_fixed.R [patient_name]
#' 
#' Example:
#'   Rscript complete_neuropsych_workflow_fixed.R "John Doe"

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
patient_name <- if (length(args) > 0) args[1] else "Patient"

# Set up logging
log_file <- paste0("workflow_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
sink(log_file, split = TRUE)

cat("========================================\n")
cat("NEUROPSYCH REPORT GENERATION WORKFLOW\n")
cat("Patient:", patient_name, "\n")
cat("Started:", format(Sys.time()), "\n")
cat("========================================\n\n")

# Track workflow state
workflow_state <- list(
  templates_checked = FALSE,
  data_processed = FALSE,
  domains_generated = FALSE,
  assets_generated = FALSE,
  report_rendered = FALSE
)

# Track domains with data for asset generation
domains_with_data <- character()

# Error handler
handle_error <- function(step, e) {
  cat("\n❌ ERROR in", step, ":\n")
  cat(e$message, "\n")
  cat("\nWorkflow state:\n")
  print(workflow_state)
  cat("\nPlease fix the error and re-run the workflow.\n")
  sink()
  stop(paste("Workflow failed at:", step))
}

# Step 1: Environment setup and template checking ONLY
cat("\n📋 STEP 1: Checking environment and copying template files...\n")
tryCatch({
  # Load the package
  if (file.exists("DESCRIPTION")) {
    suppressMessages(devtools::load_all("."))
  } else {
    library(neuro2)
  }
  
  # Copy config.yml from template if it doesn't exist
  if (!file.exists("config.yml")) {
    file.copy(
      from = "inst/quarto/templates/typst-report/config.yml",
      to = "config.yml",
      overwrite = TRUE
    )
    cat("✓ Copied config.yml from template\n")
  }
  
  # Only copy essential template files, NOT domain files
  essential_template_files <- c(
    "_00-00_tests.qmd",
    "_01-00_nse.qmd",
    "_01-01_behav_obs.qmd",
    "_03-00_sirf_text.qmd",
    "_03-00_sirf.qmd",
    "_03-01_recs.qmd",
    "_03-02_signature.qmd",
    "_03-03_appendix.qmd",
    "_03-03a_informed_consent.qmd",
    "_03-03b_examiner_qualifications.qmd",
    "_quarto.yml",
    "_variables.yml",
    "template.qmd"
  )
  
  template_dir <- "inst/quarto/templates/typst-report"
  for (file in essential_template_files) {
    if (!file.exists(file)) {
      source_file <- file.path(template_dir, file)
      if (file.exists(source_file)) {
        file.copy(source_file, file)
        cat("✓ Copied", file, "from template\n")
      }
    }
  }
  
  workflow_state$templates_checked <- TRUE
  cat("✅ Template files verified (not domain files)\n")
}, error = function(e) handle_error("template checking", e))

# Step 2: Data processing
cat("\n🔄 STEP 2: Processing raw data...\n")
tryCatch({
  # Ensure output directories exist
  dir.create("data", showWarnings = FALSE)
  dir.create("figs", showWarnings = FALSE)
  dir.create("output", showWarnings = FALSE)
  
  # Check if data already processed
  data_files <- c("data/neurocog.parquet", "data/neurobehav.parquet", "data/validity.parquet")
  if (all(file.exists(data_files))) {
    cat("ℹ️  Data files already exist. Skipping processing.\n")
    cat("   Delete files in data/ to reprocess.\n")
  } else {
    result <- system2("Rscript", "inst/scripts/data_processor_module.R", 
                     stdout = TRUE, stderr = TRUE)
    if (!all(file.exists(data_files))) {
      stop("Data processing failed - output files not created")
    }
  }
  workflow_state$data_processed <- TRUE
  cat("✅ Data processed successfully\n")
}, error = function(e) handle_error("data processing", e))

# Step 3: Domain file generation using generate_domain_files.R
cat("\n📄 STEP 3: Generating domain files based on available data...\n")
tryCatch({
  # Clear any existing domain files created by check_all_templates.R
  old_domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
  if (length(old_domain_files) > 0) {
    cat("Removing", length(old_domain_files), "old domain files...\n")
    file.remove(old_domain_files)
  }
  
  # Generate domain QMD files using the proper script
  result <- system2("Rscript", "generate_domain_files.R", 
                   stdout = TRUE, stderr = TRUE)
  
  # Parse output to find which domains were generated
  output_lines <- result[grepl("Generated:|Processing|Found", result)]
  cat(paste(output_lines, collapse = "\n"), "\n")
  
  # Check which domain files were created
  domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
  if (length(domain_files) == 0) {
    warning("No domain files generated - check if data contains valid domains")
  } else {
    cat("✅ Generated", length(domain_files), "domain files:\n")
    for (file in domain_files) {
      cat("   -", file, "\n")
      # Extract domain from filename
      domain <- gsub("_02-[0-9]+_(.+)\\.qmd", "\\1", file)
      domains_with_data <- c(domains_with_data, domain)
    }
  }
  workflow_state$domains_generated <- TRUE
}, error = function(e) handle_error("domain generation", e))

# Step 4: Asset generation (only for domains with data)
cat("\n🎨 STEP 4: Generating tables and figures for domains with data...\n")
tryCatch({
  # Load required packages
  suppressPackageStartupMessages({
    library(arrow)
    library(dplyr)
    library(ggplot2)
    library(gt)
  })
  
  # Source the R6 classes if needed
  if (file.exists("R/DomainProcessorFactoryR6.R")) {
    source("R/DomainProcessorFactoryR6.R")
  }
  
  # Generate assets only for domains that have data
  cat("Generating assets for domains:", paste(domains_with_data, collapse = ", "), "\n")
  
  # Run the asset generation script
  if (length(domains_with_data) > 0) {
    # Set environment variable to ensure figures go to figs/
    Sys.setenv(FIGURE_OUTPUT_DIR = "figs")
    
    result <- system2("Rscript", "generate_all_domain_assets.R", 
                     stdout = TRUE, stderr = TRUE,
                     env = c("DOMAINS_WITH_DATA" = paste(domains_with_data, collapse = ",")))
    
    # Check if figures were created in the right place
    fig_files_root <- list.files(pattern = "^fig_.*\\.svg$")
    fig_files_figs <- list.files("figs", pattern = "^fig_.*\\.svg$")
    
    # Move any figures from root to figs/
    if (length(fig_files_root) > 0) {
      cat("Moving", length(fig_files_root), "figures from root to figs/...\n")
      for (fig in fig_files_root) {
        file.rename(fig, file.path("figs", fig))
      }
    }
    
    # Verify critical assets exist
    critical_assets <- file.path("figs", "fig_sirf_overall.svg")
    if (!all(file.exists(critical_assets))) {
      warning("Some critical assets missing - report may have errors")
    } else {
      cat("✅ Critical assets verified\n")
    }
  }
  
  workflow_state$assets_generated <- TRUE
  cat("✅ Assets generated successfully\n")
}, error = function(e) handle_error("asset generation", e))

# Step 5: Report rendering
cat("\n📑 STEP 5: Rendering final report...\n")
tryCatch({
  # Determine report format from config
  if (file.exists("config.yml")) {
    config <- yaml::read_yaml("config.yml")
    format <- config$report$format %||% "neurotyp-adult-typst"
  } else {
    format <- "neurotyp-adult-typst"
  }
  
  cat("Using format:", format, "\n")
  
  # Clear any cached render data
  if (dir.exists("_freeze")) {
    unlink("_freeze", recursive = TRUE)
    cat("Cleared render cache\n")
  }
  
  # Render with Quarto
  result <- system2("quarto", 
                   args = c("render", "template.qmd", "-t", format),
                   stdout = TRUE, stderr = TRUE)
  
  # Print last few lines of output for debugging
  if (length(result) > 0) {
    cat("\nQuarto output (last 10 lines):\n")
    tail_output <- tail(result, 10)
    cat(paste(tail_output, collapse = "\n"), "\n")
  }
  
  # Check for output in multiple possible locations
  possible_outputs <- c(
    "output/template.pdf",
    "template.pdf",
    "_output/template.pdf"
  )
  
  output_file <- NULL
  for (path in possible_outputs) {
    if (file.exists(path)) {
      output_file <- path
      break
    }
  }
  
  if (!is.null(output_file)) {
    # Move to standard location if needed
    if (output_file != "output/template.pdf") {
      file.rename(output_file, "output/template.pdf")
      output_file <- "output/template.pdf"
    }
    cat("✅ Report rendered successfully:", output_file, "\n")
    workflow_state$report_rendered <- TRUE
  } else {
    stop("Report rendering failed - no output file created")
  }
}, error = function(e) handle_error("report rendering", e))

# Summary
cat("\n========================================\n")
cat("WORKFLOW COMPLETE\n")
cat("Patient:", patient_name, "\n")
cat("Completed:", format(Sys.time()), "\n")

# Show final state
cat("\nFinal workflow state:\n")
for (step in names(workflow_state)) {
  status <- if (workflow_state[[step]]) "✅" else "❌"
  cat(sprintf("  %s %s\n", status, gsub("_", " ", step)))
}

if (workflow_state$report_rendered) {
  cat("\n🎉 Success! Your report is ready at: output/template.pdf\n")
} else {
  cat("\n⚠️  Workflow incomplete. Check the log for errors.\n")
}

cat("\nDomains processed:\n")
for (domain in domains_with_data) {
  cat("  -", domain, "\n")
}

cat("========================================\n")

# Close log
sink()
cat("\nWorkflow log saved to:", log_file, "\n")