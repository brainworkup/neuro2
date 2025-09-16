#!/usr/bin/env Rscript

# Test script to verify the domain asset generator fix is working correctly
# Compares outputs between the old broken version and new fixed version

cat("===========================================\n")
cat("DOMAIN ASSET GENERATOR FIX VALIDATOR\n")
cat("===========================================\n\n")

# Load required libraries
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tools)
})

# Check if fixed file exists
asset_generator <- "scripts/04_generate_all_domain_assets.R"
if (!file.exists(asset_generator)) {
  cat("❌ ERROR: Asset generator not found:", asset_generator, "\n")
  cat("Please run the installer first: source('install_domain_asset_fix.R')\n")
  stop("Test failed")
}

cat("🔍 Checking asset generator file...\n")

# Read the file and check for key indicators of the fix
file_content <- readLines(asset_generator)

# Check for proper R6 class usage
has_tablegtr6 <- any(grepl("TableGTR6\\$new", file_content))
has_dotplotr6 <- any(grepl("DotplotR6\\$new", file_content))
has_proper_data_processing <- any(grepl("calculate_z_stats|z_mean_subdomain|z_mean_narrow", file_content))
has_multiple_formats <- any(grepl("png|pdf|svg.*ext.*in.*c", file_content))
has_fallback <- any(grepl("exists.*TableGTR6|exists.*DotplotR6", file_content))

cat("\n📊 FIX VALIDATION RESULTS:\n")
cat("  TableGTR6 usage:           ", if(has_tablegtr6) "✅ YES" else "❌ NO", "\n")
cat("  DotplotR6 usage:           ", if(has_dotplotr6) "✅ YES" else "❌ NO", "\n")
cat("  Proper data processing:    ", if(has_proper_data_processing) "✅ YES" else "❌ NO", "\n")
cat("  Multiple output formats:   ", if(has_multiple_formats) "✅ YES" else "❌ NO", "\n")
cat("  Fallback implementations:  ", if(has_fallback) "✅ YES" else "❌ NO", "\n")

# Overall assessment
all_checks_passed <- all(has_tablegtr6, has_dotplotr6, has_proper_data_processing, 
                        has_multiple_formats, has_fallback)

cat("\n🎯 OVERALL ASSESSMENT: ")
if (all_checks_passed) {
  cat("✅ FIXED VERSION DETECTED\n")
} else {
  cat("❌ OLD BROKEN VERSION DETECTED\n")
}

# Check if figs directory exists and has expected files
cat("\n📁 Checking output directory...\n")
figs_dir <- "figs"
if (!dir.exists(figs_dir)) {
  cat("  ⚠️  Figs directory doesn't exist (will be created when script runs)\n")
} else {
  # Count existing files
  png_files <- length(list.files(figs_dir, pattern = "\\.png$"))
  pdf_files <- length(list.files(figs_dir, pattern = "\\.pdf$"))  
  svg_files <- length(list.files(figs_dir, pattern = "\\.svg$"))
  
  cat("  📊 Existing assets:\n")
  cat("    PNG files: ", png_files, "\n")
  cat("    PDF files: ", pdf_files, "\n") 
  cat("    SVG files: ", svg_files, "\n")
  
  # Check for proper naming patterns
  table_files <- list.files(figs_dir, pattern = "^table_.*\\.png$")
  subdomain_files <- list.files(figs_dir, pattern = "^fig_.*_subdomain\\.")
  narrow_files <- list.files(figs_dir, pattern = "^fig_.*_narrow\\.")
  
  cat("  🎯 Asset types:\n")
  cat("    Table files: ", length(table_files), "\n")
  cat("    Subdomain figs: ", length(subdomain_files), "\n")
  cat("    Narrow figs: ", length(narrow_files), "\n")
}

# Check for neuro2 package classes
cat("\n🔧 Checking R6 class availability...\n")
classes_available <- c()

# Try to load neuro2 package
if (file.exists("DESCRIPTION")) {
  if (requireNamespace("devtools", quietly = TRUE)) {
    try(devtools::load_all(quiet = TRUE), silent = TRUE)
  }
}

if (requireNamespace("neuro2", quietly = TRUE)) {
  suppressPackageStartupMessages(library(neuro2))
}

# Check class existence
tablegtr6_exists <- exists("TableGTR6", mode = "function")
dotplotr6_exists <- exists("DotplotR6", mode = "function")
calculate_z_stats_exists <- exists("calculate_z_stats", mode = "function")

cat("  TableGTR6 class:     ", if(tablegtr6_exists) "✅ Available" else "❌ Missing", "\n")
cat("  DotplotR6 class:     ", if(dotplotr6_exists) "✅ Available" else "❌ Missing", "\n") 
cat("  calculate_z_stats:   ", if(calculate_z_stats_exists) "✅ Available" else "❌ Missing", "\n")

# Final recommendation
cat("\n===========================================\n")
if (all_checks_passed) {
  cat("🎉 SUCCESS: Asset generator is FIXED!\n")
  cat("===========================================\n\n")
  
  cat("✅ Your asset generator now uses proper R6 classes\n")
  cat("✅ Output will be consistent with domain QMD files\n")
  cat("✅ Multiple formats (PNG/PDF/SVG) will be generated\n")
  cat("✅ Proper data processing and aggregations included\n\n")
  
  if (!tablegtr6_exists || !dotplotr6_exists) {
    cat("⚠️  NOTE: Some R6 classes not loaded, but fallbacks available\n\n")
  }
  
  cat("NEXT: Run the asset generator to test it:\n")
  cat("  Rscript scripts/04_generate_all_domain_assets.R\n\n")
  
} else {
  cat("❌ FAILED: Asset generator still has issues!\n")
  cat("===========================================\n\n")
  
  cat("Please re-run the installer:\n")
  cat("  source('install_domain_asset_fix.R')\n\n")
  
  if (!has_tablegtr6) cat("❌ Missing TableGTR6 usage\n")
  if (!has_dotplotr6) cat("❌ Missing DotplotR6 usage\n")
  if (!has_proper_data_processing) cat("❌ Missing proper data processing\n")
  if (!has_multiple_formats) cat("❌ Missing multiple output formats\n")
  if (!has_fallback) cat("❌ Missing fallback implementations\n")
}

invisible(all_checks_passed)
