#!/usr/bin/env Rscript

#' Install the FIXED DomainProcessorR6.R File
#' 
#' This replaces your DomainProcessorR6.R with the fixed version

cat("\n")
cat("════════════════════════════════════════════\n")
cat("   📦 INSTALLING FIXED DomainProcessorR6.R  \n")
cat("════════════════════════════════════════════\n\n")

# Source file with fixes already applied
source_file <- "/mnt/user-data/outputs/DomainProcessorR6_FIXED.R"

if (!file.exists(source_file)) {
  stop("Fixed file not found. Run fix_domainprocessor_source.R first.")
}

# Find where to install it
target_locations <- c(
  "R/DomainProcessorR6.R",           # Package R directory
  "DomainProcessorR6.R",              # Current directory
  here::here("R", "DomainProcessorR6.R")  # Using here package
)

cat("Looking for DomainProcessorR6.R in your project...\n\n")

installed <- FALSE

for (target in target_locations) {
  # Check if this location exists or if parent directory exists
  parent_dir <- dirname(target)
  
  if (file.exists(target) || dir.exists(parent_dir)) {
    cat("📄 Found location: ", target, "\n")
    
    # Backup existing file if it exists
    if (file.exists(target)) {
      backup_file <- paste0(target, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
      file.copy(target, backup_file)
      cat("   ✅ Backed up existing file to: ", basename(backup_file), "\n")
    }
    
    # Copy the fixed file
    if (file.copy(source_file, target, overwrite = TRUE)) {
      cat("   ✅ Installed fixed version!\n")
      installed <- TRUE
      
      # If it's in R/ directory, remind to reload
      if (grepl("^R/", target)) {
        cat("\n")
        cat("   ⚠️  IMPORTANT: This file is in a package R/ directory.\n")
        cat("   You need to reload the package:\n")
        cat("     • devtools::load_all()  # For development\n")
        cat("     • devtools::install()   # For installation\n")
        cat("     • Or restart R session and reload\n")
      }
      
      break
    } else {
      cat("   ❌ Failed to copy file\n")
    }
  }
}

if (!installed) {
  # Just copy to current directory
  cat("\n📄 No existing DomainProcessorR6.R found.\n")
  cat("   Copying to current directory...\n")
  
  if (file.copy(source_file, "DomainProcessorR6.R", overwrite = TRUE)) {
    cat("   ✅ Created DomainProcessorR6.R in current directory\n")
    installed <- TRUE
  }
}

if (installed) {
  cat("\n")
  cat("════════════════════════════════════════════\n")
  cat("   ✅ INSTALLATION COMPLETE!                \n")
  cat("════════════════════════════════════════════\n\n")
  
  cat("The fixed DomainProcessorR6.R is now installed.\n\n")
  
  cat("WHAT WAS FIXED:\n")
  cat("• All image paths now include 'figs/' prefix\n")
  cat("• table_iq.png → figs/table_iq.png\n")
  cat("• fig_iq_subdomain.svg → figs/fig_iq_subdomain.svg\n")
  cat("• And all other image references\n\n")
  
  cat("NEXT STEPS:\n")
  cat("1. Source or reload the file/package\n")
  cat("2. Delete old _02-*.qmd files (optional)\n")
  cat("3. Re-run your workflow:\n")
  cat("   Rscript complete_neuropsych_workflow.R 'Ethan'\n\n")
  
  cat("Your workflow should now work without file path errors! 🎉\n")
} else {
  cat("\n❌ Installation failed.\n")
  cat("Please manually copy the file from:\n")
  cat("  ", source_file, "\n")
  cat("To your R/ directory.\n")
}
