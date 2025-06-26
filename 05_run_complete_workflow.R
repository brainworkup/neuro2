#!/usr/bin/env Rscript

# COMPLETE FORENSIC NEUROPSYCHOLOGICAL REPORT WORKFLOW
# This script runs all steps to generate a forensic report from raw CSV data

# Clear workspace and set up environment
rm(list = ls())
graphics.off()

# Set working directory (adjust as needed)
# setwd("path/to/your/project")

# Load required libraries
required_packages <- c(
  "tidyverse", "here", "readr", "dplyr", "ggplot2",
  "gt", "gtExtras", "glue", "janitor", "quarto", "rmarkdown"
)

# Install missing packages
missing_packages <- required_packages[!required_packages %in% installed.packages()[,"Package"]]
if (length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages)
}

# Load all packages
invisible(lapply(required_packages, library, character.only = TRUE))

# Start workflow
message("\n", strrep("=", 60))
message("FORENSIC NEUROPSYCHOLOGICAL REPORT GENERATION WORKFLOW")
message(strrep("=", 60))
message("\nPatient: Biggie")
message("Template: Forensic")
message("Date: ", Sys.Date())
message("\n")

# STEP 1: Import and Process Data
message("📊 STEP 1: Importing and processing data files...")
message(strrep("-", 40))

tryCatch({
  source("import_process_data.R")
  message("✅ Step 1 complete: Data imported and processed\n")
}, error = function(e) {
  stop("❌ Error in Step 1: ", e$message)
})

# Brief pause
Sys.sleep(1)

# STEP 2: Create Domain QMD Files  
message("📝 STEP 2: Creating domain QMD files...")
message(strrep("-", 40))

tryCatch({
  source("create_domain_qmds.R")
  message("✅ Step 2 complete: Domain files created\n")
}, error = function(e) {
  stop("❌ Error in Step 2: ", e$message)
})

# Brief pause
Sys.sleep(1)

# STEP 3: Render Domains and Generate Output
message("🔄 STEP 3: Rendering domains and generating output...")
message(strrep("-", 40))

tryCatch({
  source("render_domains.R")
  message("✅ Step 3 complete: Domain analyses completed\n")
}, error = function(e) {
  stop("❌ Error in Step 3: ", e$message)
})

# Brief pause
Sys.sleep(1)

# STEP 4: Generate Final Report
message("📄 STEP 4: Generating final forensic report...")
message(strrep("-", 40))

tryCatch({
  source("generate_final_report.R")
  message("✅ Step 4 complete: Final report generated\n")
}, error = function(e) {
  stop("❌ Error in Step 4: ", e$message)
})

# Final summary
message("\n", strrep("=", 60))
message("✅ WORKFLOW COMPLETED SUCCESSFULLY!")
message(strrep("=", 60))

# List generated outputs
message("\n📁 Generated outputs:")
output_files <- list.files(pattern = "forensic_report_biggie\\.(pdf|html)$")
if (length(output_files) > 0) {
  for (file in output_files) {
    message("   - ", file)
  }
}

# List data files
data_files <- list.files("data", pattern = "\\.csv$", full.names = TRUE)
if (length(data_files) > 0) {
  message("\n📊 Processed data files:")
  for (file in data_files) {
    message("   - ", file)
  }
}

# List figure files
figure_files <- list.files(pattern = "\\.(svg|png)$")
if (length(figure_files) > 0) {
  message("\n📈 Generated figures:")
  for (file in figure_files) {
    message("   - ", file)
  }
}

message("\n✨ All done! The forensic report is ready for review.")
message("\n")

# Optional: Open the PDF report
if (interactive()) {
  response <- readline("Would you like to open the PDF report? (y/n): ")
  if (tolower(response) == "y") {
    if (file.exists("forensic_report_biggie.pdf")) {
      if (.Platform$OS.type == "windows") {
        shell.exec("forensic_report_biggie.pdf")
      } else if (Sys.info()["sysname"] == "Darwin") {
        system("open forensic_report_biggie.pdf")
      } else {
        system("xdg-open forensic_report_biggie.pdf")
      }
    }
  }
}