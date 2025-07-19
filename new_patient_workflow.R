#!/usr/bin/env Rscript

# NEW PATIENT WORKFLOW SCRIPT
# Complete workflow for processing a new patient's neuropsychological data
# Run this script after placing CSV files in data-raw/csv/ and updating _variables.yml

cat("🧠 NEUROPSYCH REPORT GENERATION - NEW PATIENT WORKFLOW\n")
cat("====================================================\n\n")

# Step 1: Check prerequisites
cat("Step 1: Checking prerequisites...\n")

# Check if CSV files exist
csv_files <- list.files("data-raw/csv", pattern = "\\.csv$", full.names = TRUE)
if (length(csv_files) == 0) {
  stop("❌ No CSV files found in data-raw/csv/\n   Please add your test data CSV files to data-raw/csv/ directory")
}

cat("✅ Found", length(csv_files), "CSV files:\n")
for (file in basename(csv_files)) {
  cat("   -", file, "\n")
}

# Check if _variables.yml exists
if (!file.exists("_variables.yml")) {
  stop("❌ _variables.yml not found\n   Please update patient information in _variables.yml")
}

# Step 2: Load required packages
cat("\nStep 2: Loading required packages...\n")
required_packages <- c("dplyr", "readr", "here", "yaml", "quarto")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("Installing", pkg, "...\n")
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE, quietly = TRUE)
}
cat("✅ Packages loaded successfully\n")

# Step 3: Process data (CSV → Parquet)
cat("\nStep 3: Processing data (CSV → Parquet conversion)...\n")

# Load the data processing function
if (file.exists("R/duckdb_neuropsych_loader.R")) {
  source("R/duckdb_neuropsych_loader.R")
  
  # Process the data
  load_data_duckdb(
    file_path = "data-raw/csv",
    output_dir = "data",
    output_format = "all"
  )
  cat("✅ Data processing complete\n")
  
  # Step 3.5: Add score ranges based on percentiles
  cat("\nStep 3.5: Adding score ranges to processed data...\n")
  
  # Source the PDF processing functions if available
  if (file.exists("R/pdf.R")) {
    source("R/pdf.R")
  }
  
  # Process each generated CSV file to add ranges
  data_files <- list.files("data", pattern = "\\.csv$", full.names = TRUE)
  
  for (file in data_files) {
    cat("   Adding ranges to", basename(file), "...\n")
    
    # Read the data
    data <- read.csv(file, stringsAsFactors = FALSE)
    
    # Add score ranges if percentile column exists
    if ("percentile" %in% colnames(data)) {
      # Apply gpluck_make_score_ranges function
      if (exists("gpluck_make_score_ranges")) {
        data <- gpluck_make_score_ranges(data, test_type = "npsych_test")
      } else {
        # Manual range assignment if function not available
        data$range <- case_when(
          data$percentile >= 98 ~ "Exceptionally High",
          data$percentile >= 91 & data$percentile <= 97 ~ "Above Average",
          data$percentile >= 75 & data$percentile <= 90 ~ "High Average",
          data$percentile >= 25 & data$percentile <= 74 ~ "Average",
          data$percentile >= 9 & data$percentile <= 24 ~ "Low Average",
          data$percentile >= 2 & data$percentile <= 8 ~ "Below Average",
          data$percentile < 2 ~ "Exceptionally Low",
          TRUE ~ NA_character_
        )
      }
      
      # Write back the file
      write.csv(data, file, row.names = FALSE)
    }
  }
  
  cat("✅ Score ranges added successfully\n")
  
} else {
  cat("⚠️  DuckDB loader not found, using basic CSV processing...\n")
  
  # Basic CSV consolidation
  all_data <- data.frame()
  for (csv_file in csv_files) {
    cat("   Processing", basename(csv_file), "...\n")
    data <- read.csv(csv_file, stringsAsFactors = FALSE)
    all_data <- rbind(all_data, data)
  }
  
  # Add score ranges to consolidated data
  if ("percentile" %in% colnames(all_data)) {
    all_data$range <- case_when(
      all_data$percentile >= 98 ~ "Exceptionally High",
      all_data$percentile >= 91 & all_data$percentile <= 97 ~ "Above Average",
      all_data$percentile >= 75 & all_data$percentile <= 90 ~ "High Average",
      all_data$percentile >= 25 & all_data$percentile <= 74 ~ "Average",
      all_data$percentile >= 9 & all_data$percentile <= 24 ~ "Low Average",
      all_data$percentile >= 2 & all_data$percentile <= 8 ~ "Below Average",
      all_data$percentile < 2 ~ "Exceptionally Low",
      TRUE ~ NA_character_
    )
  }
  
  # Create basic output files
  dir.create("data", showWarnings = FALSE)
  write.csv(all_data, "data/neuropsych.csv", row.names = FALSE)
  cat("✅ Basic CSV processing complete with score ranges\n")
}

# Step 4: Load patient information
cat("\nStep 4: Loading patient information...\n")
patient_info <- yaml::read_yaml("_variables.yml")
cat("✅ Patient:", patient_info$patient, "\n")
cat("   Age:", patient_info$age, "\n")
cat("   DOE:", patient_info$doe, "\n")

# Step 5: Generate domain files and report
cat("\nStep 5: Generating report...\n")

if (file.exists("neuro2_r6_update_workflow.R")) {
  cat("   Using R6 workflow (recommended)...\n")
  source("neuro2_r6_update_workflow.R")
} else if (file.exists("neuro2_duckdb_workflow.R")) {
  cat("   Using DuckDB workflow...\n")
  source("neuro2_duckdb_workflow.R")
} else {
  cat("⚠️  No workflow script found, running basic template render...\n")
  if (file.exists("template.qmd")) {
    quarto::quarto_render("template.qmd")
  } else {
    cat("❌ template.qmd not found\n")
  }
}

# Step 6: Final report rendering
cat("\nStep 6: Rendering final PDF report...\n")
if (file.exists("template.qmd")) {
  tryCatch({
    quarto::quarto_render("template.qmd", output_format = "typst-pdf")
    cat("✅ Report generated successfully!\n")
  }, error = function(e) {
    cat("⚠️  PDF rendering failed:", e$message, "\n")
    cat("   Trying HTML format...\n")
    quarto::quarto_render("template.qmd", output_format = "html")
  })
} else {
  cat("❌ template.qmd not found\n")
}

# Summary
cat("\n" , "=" , rep("=", 50), "\n")
cat("🎉 WORKFLOW COMPLETE!\n\n")

cat("Generated files:\n")
if (dir.exists("data")) {
  data_files <- list.files("data", full.names = FALSE)
  for (file in data_files) {
    cat("   📊", file, "\n")
  }
}

# Check for generated domain files
domain_files <- list.files(".", pattern = "_02-.*\\.qmd$", full.names = FALSE)
if (length(domain_files) > 0) {
  cat("\nGenerated domain sections:\n")
  for (file in domain_files) {
    cat("   📝", file, "\n")
  }
}

# Check for final report
if (file.exists("template.pdf")) {
  cat("\n🎯 Final report: template.pdf\n")
} else if (file.exists("template.html")) {
  cat("\n🎯 Final report: template.html\n")
}

cat("\nNext steps:\n")
cat("1. Review generated domain files (_02-XX_*.qmd)\n")
cat("2. Check data files in data/ directory\n")
cat("3. Open final report (template.pdf or template.html)\n")
cat("4. Customize as needed and re-run: quarto render template.qmd\n")

cat("\n✨ Happy reporting! ✨\n")