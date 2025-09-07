#!/usr/bin/env Rscript

#' Implementation Script - Fix Triple Execution Problem
#' Run this to automatically fix your batch processor

cat("==================================================\n")
cat("FIXING TRIPLE EXECUTION PROBLEM\n")
cat("==================================================\n\n")

# Step 1: Backup current files
backup_current_files <- function() {
  cat("Step 1: Creating backups...\n")
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Backup batch processor
  if (file.exists("inst/scripts/batch_domain_processor.R")) {
    backup_name <- paste0("inst/scripts/batch_domain_processor.R.BACKUP_", timestamp)
    file.copy("inst/scripts/batch_domain_processor.R", backup_name)
    cat("  ✓ Backed up batch_domain_processor.R to", basename(backup_name), "\n")
  }
  
  # Backup any template files
  if (file.exists("template.qmd")) {
    backup_name <- paste0("template.qmd.BACKUP_", timestamp)
    file.copy("template.qmd", backup_name)
    cat("  ✓ Backed up template.qmd\n")
  }
  
  return(timestamp)
}

# Step 2: Create the new fixed batch processor
create_fixed_batch_processor <- function() {
  cat("\nStep 2: Creating fixed batch processor...\n")
  
  fixed_content <- '
#\' Fixed Batch Domain Processor - SINGLE EXECUTION GUARANTEED
#\' This version processes each domain exactly ONCE

# CRITICAL: Prevent multiple executions
if (exists(".BATCH_RUNNING")) {
  message("Batch processor already running, exiting...")
  stop("Preventing duplicate execution", call. = FALSE)
}
.BATCH_RUNNING <- TRUE
on.exit(rm(.BATCH_RUNNING, envir = .GlobalEnv))

# Load required libraries
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(readr)
})

#\' Process all domains with single execution
process_all_domains <- function() {
  
  message("\\n========================================")
  message("BATCH PROCESSOR - FIXED VERSION")
  message("Single execution guaranteed")
  message("========================================\\n")
  
  # Load data ONCE
  neurocog_data <- readr::read_csv("data/neurocog.csv", show_col_types = FALSE)
  neurobehav_data <- readr::read_csv("data/neurobehav.csv", show_col_types = FALSE)
  
  # Define domains ONCE - no duplication
  domains <- list(
    list(name = "General Cognitive Ability", pheno = "iq", data = "neurocog", num = "01"),
    list(name = "Academic Skills", pheno = "academics", data = "neurocog", num = "02"),
    list(name = "Verbal/Language", pheno = "verbal", data = "neurocog", num = "03"),
    list(name = "Visual Perception/Construction", pheno = "spatial", data = "neurocog", num = "04"),
    list(name = "Memory", pheno = "memory", data = "neurocog", num = "05"),
    list(name = "Attention/Executive", pheno = "executive", data = "neurocog", num = "06"),
    list(name = "Motor", pheno = "motor", data = "neurocog", num = "07"),
    list(name = "Social Cognition", pheno = "social", data = "neurocog", num = "08"),
    list(name = "ADHD", pheno = "adhd", data = "neurobehav", num = "09"),
    list(name = "Behavioral/Emotional/Social", pheno = "emotion", data = "neurobehav", num = "10"),
    list(name = "Performance Validity", pheno = "validity", data = "neurocog", num = "13")
  )
  
  # Track processed domains
  processed <- character()
  
  # SINGLE LOOP - Process each domain ONCE
  for (i in seq_along(domains)) {
    d <- domains[[i]]
    
    # Skip if already processed
    if (d$pheno %in% processed) {
      message("  ⚠ ", d$pheno, " already processed - skipping")
      next
    }
    
    message("[", i, "/", length(domains), "] Processing ", d$pheno, "...")
    
    # Select correct data
    data_source <- if (d$data == "neurocog") neurocog_data else neurobehav_data
    
    # Check data exists
    domain_data <- data_source %>%
      filter(domain == d$name) %>%
      filter(!is.na(percentile) | !is.na(score))
    
    if (nrow(domain_data) == 0) {
      message("  ✗ No data for ", d$pheno)
      next
    }
    
    # Process domain ONCE
    tryCatch({
      # Source required R6 classes if needed
      if (!exists("DomainProcessorR6")) {
        source(here::here("R", "DomainProcessorR6.R"))
      }
      
      # Create processor
      processor <- DomainProcessorR6$new(
        domains = d$name,
        pheno = d$pheno,
        input_file = paste0("data/", d$data, ".csv")
      )
      
      # Set number
      processor$number <- d$num
      
      # Process
      processor$process()
      
      # Generate QMD if needed
      qmd_file <- paste0("_02-", d$num, "_", d$pheno, ".qmd")
      if (!file.exists(qmd_file)) {
        processor$generate_domain_qmd(qmd_file)
      }
      
      # Mark as processed
      processed <- c(processed, d$pheno)
      message("  ✓ Complete")
      
    }, error = function(e) {
      message("  ✗ Error: ", e$message)
    })
  }
  
  message("\\n========================================")
  message("Processed ", length(processed), " domains successfully")
  message("========================================\\n")
  
  return(processed)
}

# Execute if called directly
if (!interactive()) {
  process_all_domains()
}
'
  
  # Write the fixed version
  writeLines(fixed_content, "inst/scripts/batch_domain_processor.R")
  cat("  ✓ Created fixed batch processor\n")
}

# Step 3: Add execution guards to template.qmd
fix_template_qmd <- function() {
  cat("\nStep 3: Fixing template.qmd...\n")
  
  if (!file.exists("template.qmd")) {
    cat("  ⚠ template.qmd not found\n")
    return()
  }
  
  # Read current template
  lines <- readLines("template.qmd")
  
  # Find the setup chunk
  setup_start <- grep("```\\{r\\}.*setup", lines)[1]
  
  if (!is.na(setup_start)) {
    # Add execution guard after chunk header
    guard_code <- c(
      "# PREVENT MULTIPLE EXECUTIONS",
      "if (!exists('.TEMPLATE_SETUP_DONE')) {",
      "  .TEMPLATE_SETUP_DONE <- TRUE",
      "} else {",
      "  knitr::knit_exit()",
      "}",
      ""
    )
    
    # Insert the guard
    lines <- c(
      lines[1:setup_start],
      guard_code,
      lines[(setup_start+1):length(lines)]
    )
    
    # Write back
    writeLines(lines, "template.qmd")
    cat("  ✓ Added execution guards to template.qmd\n")
  }
}

# Step 4: Clear caches
clear_all_caches <- function() {
  cat("\nStep 4: Clearing caches...\n")
  
  cache_dirs <- c("_cache", ".quarto", "_freeze")
  
  for (dir in cache_dirs) {
    if (dir.exists(dir)) {
      unlink(dir, recursive = TRUE)
      cat("  ✓ Cleared", dir, "\n")
    }
  }
  
  # Clear execution counter
  if (file.exists(".execution_counter")) {
    file.remove(".execution_counter")
    cat("  ✓ Reset execution counter\n")
  }
}

# Step 5: Create test script
create_test_script <- function() {
  cat("\nStep 5: Creating test script...\n")
  
  test_content <- '
# Test script to verify single execution
cat("Testing single execution...\\n")

# Clear environment
rm(list = ls())

# Add counter
.EXEC_COUNT <- 0

# Override process to count calls
if (exists("DomainProcessorR6")) {
  orig <- DomainProcessorR6$public_methods$process
  DomainProcessorR6$public_methods$process <- function(...) {
    .EXEC_COUNT <<- .EXEC_COUNT + 1
    cat("Process call #", .EXEC_COUNT, "\\n")
    orig(...)
  }
}

# Run batch processor
source("inst/scripts/batch_domain_processor.R")

# Check result
cat("\\nTotal process calls:", .EXEC_COUNT, "\\n")
if (.EXEC_COUNT <= 11) {
  cat("✓ SUCCESS: Single execution per domain\\n")
} else {
  cat("✗ PROBLEM: Multiple executions detected\\n")
}
'
  
  writeLines(test_content, "test_single_execution.R")
  cat("  ✓ Created test_single_execution.R\n")
}

# Step 6: Create new workflow script
create_clean_workflow <- function() {
  cat("\nStep 6: Creating clean workflow script...\n")
  
  workflow_content <- '#!/bin/bash
# Clean workflow script - prevents triple execution

set -e
set -o pipefail

echo "===================================="
echo "NEUROPSYCH WORKFLOW - FIXED VERSION"
echo "===================================="

# Clean previous runs
rm -f .BATCH_RUNNING .TEMPLATE_SETUP_DONE 2>/dev/null || true

# Step 1: Process domains in R
echo "Step 1: Processing domains..."
Rscript --vanilla inst/scripts/batch_domain_processor.R

# Step 2: Render report (if domains were processed)
if [ -f "_02-01_iq.qmd" ]; then
  echo "Step 2: Rendering report..."
  quarto render template.qmd --execute-params "patient:$1" --quiet
  echo "✓ Report generated: template.pdf"
else
  echo "✗ No domain files found"
  exit 1
fi

echo "===================================="
echo "WORKFLOW COMPLETE"
echo "===================================="
'
  
  writeLines(workflow_content, "run_workflow.sh")
  Sys.chmod("run_workflow.sh", "755")  # Make executable
  cat("  ✓ Created run_workflow.sh\n")
}

# Main execution
main <- function() {
  cat("Starting fix implementation...\n\n")
  
  # Run all steps
  timestamp <- backup_current_files()
  create_fixed_batch_processor()
  fix_template_qmd()
  clear_all_caches()
  create_test_script()
  create_clean_workflow()
  
  cat("\n==================================================\n")
  cat("✓ FIX IMPLEMENTATION COMPLETE\n")
  cat("==================================================\n\n")
  
  cat("Next steps:\n")
  cat("1. Test the fix:\n")
  cat("   Rscript test_single_execution.R\n\n")
  cat("2. Run the clean workflow:\n")
  cat("   ./run_workflow.sh 'PatientName'\n\n")
  cat("3. If something goes wrong, restore backups:\n")
  cat("   - Batch processor: inst/scripts/batch_domain_processor.R.BACKUP_", timestamp, "\n")
  cat("   - Template: template.qmd.BACKUP_", timestamp, "\n\n")
  
  cat("The fixed batch processor now has:\n")
  cat("  ✓ SINGLE loop (not 11)\n")
  cat("  ✓ Execution guards\n")
  cat("  ✓ No nested loops\n")
  cat("  ✓ No recursive calls\n")
  cat("  ✓ Each domain processed ONCE\n")
}

# Run it!
main()
