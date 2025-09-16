#!/usr/bin/env Rscript

# Quick installer for neuropsych workflow fixes
cat("========================================\n")
cat("NEUROPSYCH WORKFLOW FIX INSTALLER\n")
cat("========================================\n\n")

# List of fix files to copy
fix_files <- c(
  "diagnose_quarto_issue.R",
  "complete_neuropsych_workflow_fixed_v3.R",
  "fix_typst_format.R",
  "QUARTO_RENDERING_FIX_GUIDE.md",
  "run_workflow.sh"
)

cat("This will install the following fixes:\n")
for (f in fix_files) {
  cat("  •", f, "\n")
}

cat("\nProceed with installation? (y/n): ")
response <- readline()

if (tolower(response) != "y") {
  cat("Installation cancelled.\n")
  quit()
}

# Get the output directory path
output_dir <- "/mnt/user-data/outputs"
target_dir <- getwd()

cat("\nInstalling to:", target_dir, "\n\n")

# Copy files
success_count <- 0
for (file in fix_files) {
  source_path <- file.path(output_dir, file)
  target_path <- file.path(target_dir, file)
  
  if (file.exists(source_path)) {
    # Backup existing file if it exists
    if (file.exists(target_path)) {
      backup_path <- paste0(target_path, ".backup")
      file.copy(target_path, backup_path, overwrite = TRUE)
      cat("  Backed up existing", file, "\n")
    }
    
    # Copy the fix file
    if (file.copy(source_path, target_path, overwrite = TRUE)) {
      cat("  ✅ Installed", file, "\n")
      success_count <- success_count + 1
      
      # Make shell scripts executable
      if (grepl("\\.sh$", file)) {
        Sys.chmod(target_path, "755")
      }
    } else {
      cat("  ❌ Failed to install", file, "\n")
    }
  } else {
    cat("  ⚠️  Source file not found:", file, "\n")
  }
}

cat("\n========================================\n")
cat("Installation complete:", success_count, "/", length(fix_files), "files installed\n")
cat("========================================\n\n")

if (success_count > 0) {
  cat("NEXT STEPS:\n")
  cat("1. Run diagnostics to identify issues:\n")
  cat("   Rscript diagnose_quarto_issue.R\n\n")
  
  cat("2. Try the fixed workflow:\n")
  cat("   Rscript complete_neuropsych_workflow_fixed_v3.R 'Ethan'\n\n")
  
  cat("3. Or use the shell wrapper (works with Fish shell):\n")
  cat("   ./run_workflow.sh Ethan\n\n")
  
  cat("4. If rendering still fails, fix the format:\n")
  cat("   Rscript fix_typst_format.R\n\n")
  
  cat("5. Read the guide for detailed information:\n")
  cat("   QUARTO_RENDERING_FIX_GUIDE.md\n\n")
  
  cat("For immediate help, try basic Typst format:\n")
  cat("   quarto render template.qmd --to typst\n\n")
}
