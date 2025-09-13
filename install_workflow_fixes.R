#!/usr/bin/env Rscript

# Installer script for workflow fixes
# This script copies all the fixed files to your working directory

cat("========================================\n")
cat("NEUROPSYCH WORKFLOW FIX INSTALLER\n")
cat("========================================\n\n")

# Define source files (from outputs directory)
fix_files <- list(
  "complete_neuropsych_workflow_fixed_v2.R" = "Complete workflow script (main fix)",
  "generate_assets_for_domains_fixed.R" = "Asset generation function",
  "run_neuropsych_workflow.sh" = "Shell wrapper for Fish/Bash compatibility",
  "diagnose_workflow_issues.R" = "Diagnostic tool",
  "WORKFLOW_FIX_SUMMARY.md" = "Documentation"
)

# Check if files exist in outputs
outputs_dir <- "/mnt/user-data/outputs"
if (!dir.exists(outputs_dir)) {
  cat("ERROR: Outputs directory not found:", outputs_dir, "\n")
  cat("Please ensure you're running this from the correct environment.\n")
  stop("Installation failed")
}

# Copy files
cat("Installing fixes to current directory...\n\n")
copied <- 0
failed <- 0

for (file in names(fix_files)) {
  source_path <- file.path(outputs_dir, file)
  dest_path <- file
  
  cat(sprintf("%-45s", paste0(file, ":")))
  
  if (file.exists(source_path)) {
    tryCatch({
      # Check if file already exists
      if (file.exists(dest_path)) {
        # Backup existing file
        backup_path <- paste0(dest_path, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
        file.rename(dest_path, backup_path)
        cat("(backed up existing) ")
      }
      
      # Copy file
      file.copy(source_path, dest_path, overwrite = TRUE)
      
      # Make shell scripts executable
      if (grepl("\\.sh$", file)) {
        Sys.chmod(dest_path, "755")
      }
      
      cat("✓ INSTALLED\n")
      copied <- copied + 1
    }, error = function(e) {
      cat("✗ FAILED:", e$message, "\n")
      failed <- failed + 1
    })
  } else {
    cat("✗ NOT FOUND\n")
    failed <- failed + 1
  }
}

cat("\n")
cat("========================================\n")
cat("Installation Summary:\n")
cat("  Installed:", copied, "files\n")
if (failed > 0) {
  cat("  Failed:", failed, "files\n")
}
cat("========================================\n\n")

# Next steps
if (copied > 0) {
  cat("NEXT STEPS:\n")
  cat("1. Run diagnostics to check your environment:\n")
  cat("   source('diagnose_workflow_issues.R')\n\n")
  
  cat("2. Fix any issues identified (install packages, etc.)\n\n")
  
  cat("3. Run the fixed workflow:\n")
  cat("   source('complete_neuropsych_workflow_fixed_v2.R')\n\n")
  
  cat("   OR use the shell wrapper:\n")
  cat("   ./run_neuropsych_workflow.sh 'PatientName'\n\n")
  
  cat("4. Read WORKFLOW_FIX_SUMMARY.md for detailed information\n\n")
  
  # Check for Fish shell
  if (Sys.getenv("SHELL") == "/usr/local/bin/fish" || 
      Sys.getenv("SHELL") == "/opt/homebrew/bin/fish") {
    cat("FISH SHELL DETECTED:\n")
    cat("Consider using the shell wrapper (run_neuropsych_workflow.sh)\n")
    cat("or adding R to your Fish PATH:\n")
    cat("  set -x PATH", file.path(R.home("bin")), "$PATH\n\n")
  }
  
  cat("✅ Installation complete! You can now run the fixed workflow.\n")
} else {
  cat("❌ Installation failed. Please check the errors above.\n")
}
