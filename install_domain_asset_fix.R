#!/usr/bin/env Rscript

# Quick installer for domain asset generator fix
# This replaces the broken version with the properly working R6-based version

cat("===========================================\n")
cat("DOMAIN ASSET GENERATOR FIX INSTALLER\n") 
cat("===========================================\n\n")

# Define file paths
original_file <- "scripts/04_generate_all_domain_assets.R"
fixed_file <- "scripts/04_generate_all_domain_assets_FIXED.R"
backup_file <- paste0(original_file, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))

# Check if fixed file exists
if (!file.exists(fixed_file)) {
  cat("❌ ERROR: Fixed file not found at:", fixed_file, "\n")
  cat("Please ensure you're running this from the correct environment.\n")
  stop("Installation failed")
}

# Backup existing file if it exists
if (file.exists(original_file)) {
  cat("📋 Backing up original file...\n")
  if (file.copy(original_file, backup_file)) {
    cat("  ✅ Backup created:", backup_file, "\n")
  } else {
    cat("  ❌ Backup failed!\n")
    stop("Could not create backup")
  }
} else {
  cat("ℹ️  Original file not found (creating new)\n")
}

# Copy fixed file
cat("\n🔧 Installing fixed version...\n")
if (file.copy(fixed_file, original_file, overwrite = TRUE)) {
  cat("  ✅ Successfully installed:", original_file, "\n")
  
  # Make executable if on Unix-like system
  if (.Platform$OS.type == "unix") {
    Sys.chmod(original_file, "755")
    cat("  ✅ Made executable\n")
  }
  
} else {
  cat("  ❌ Installation failed!\n")
  stop("Could not copy fixed file")
}

# Summary
cat("\n===========================================\n")
cat("🎯 INSTALLATION COMPLETE!\n")
cat("===========================================\n\n")

cat("WHAT WAS FIXED:\n")
cat("✅ Now uses proper TableGTR6 class instead of basic gt()\n")
cat("✅ Now uses proper DotplotR6 class instead of basic ggplot()\n")
cat("✅ Creates multiple output formats (PNG, PDF, SVG)\n")
cat("✅ Proper z-score calculations and data aggregations\n")
cat("✅ Better error handling and fallback options\n")
cat("✅ Consistent with your domain QMD file implementations\n\n")

cat("NEXT STEPS:\n")
cat("1. Run the fixed script:\n")
cat("   Rscript 04_generate_all_domain_assets.R\n\n")
cat("2. Check the generated files in figs/ directory\n")
cat("3. Compare quality with your domain QMD outputs\n\n")

cat("FILES:\n")
cat("  Original (backup):", if(file.exists(backup_file)) backup_file else "N/A", "\n")
cat("  Fixed version:    ", original_file, "\n")
cat("  Documentation:    /mnt/user-data/outputs/DOMAIN_ASSET_GENERATOR_FIX_SUMMARY.md\n\n")

cat("🚀 The asset generator now produces high-quality, consistent output!\n")
