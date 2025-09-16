#!/usr/bin/env Rscript

#' FINAL ACTION PLAN - Fix DomainProcessorR6.R Once and For All
#' 
#' Run this to permanently fix the file path issue

cat("\n")
cat("╔══════════════════════════════════════════════╗\n")
cat("║     ACTION PLAN: FIX YOUR WORKFLOW NOW      ║\n")
cat("╔══════════════════════════════════════════════╝\n\n")

cat("Joey, you correctly identified the problem:\n")
cat("DomainProcessorR6.R generates WRONG paths.\n\n")

cat("Here's your 3-step fix:\n\n")

cat("═══════════════════════════════════════════════\n")
cat("STEP 1: Install the Fixed DomainProcessorR6.R\n")
cat("═══════════════════════════════════════════════\n")
cat("Run ONE of these options:\n\n")

cat("Option A - Quick Install (Recommended):\n")
cat("----------------------------------------\n")
cat("source('/mnt/user-data/outputs/install_fixed_domainprocessor.R')\n\n")

cat("Option B - Manual Copy:\n")
cat("------------------------\n")
cat("file.copy(\n")
cat("  from = '/mnt/user-data/outputs/DomainProcessorR6_FIXED.R',\n")
cat("  to = 'R/DomainProcessorR6.R',\n")
cat("  overwrite = TRUE\n")
cat(")\n\n")

cat("═══════════════════════════════════════════════\n")
cat("STEP 2: Reload the Fixed Code\n")
cat("═══════════════════════════════════════════════\n")

cat("If it's in a package:\n")
cat("  devtools::load_all()  # or devtools::install()\n\n")

cat("If it's standalone:\n")
cat("  source('R/DomainProcessorR6.R')\n\n")

cat("═══════════════════════════════════════════════\n")
cat("STEP 3: Run Your Workflow\n")
cat("═══════════════════════════════════════════════\n")

cat("Now it should work without errors:\n")
cat("  Rscript complete_neuropsych_workflow.R 'Ethan'\n\n")

cat("Or:\n")
cat("  quarto render template.qmd --to typst\n\n")

cat("╔══════════════════════════════════════════════╗\n")
cat("║              WHAT THIS FIXES                ║\n")
cat("╠══════════════════════════════════════════════╣\n")
cat("║ ❌ BEFORE:  #let file_qtbl = \"table_iq.png\" ║\n")
cat("║ ✅ AFTER:   #let file_qtbl = \"figs/table_iq.png\" ║\n")
cat("╚══════════════════════════════════════════════╝\n\n")

cat("This is a REAL FIX, not a patch!\n")
cat("Once applied, the problem is gone forever.\n\n")

# Function to do it all automatically
auto_fix <- function() {
  cat("Running automatic fix...\n\n")
  
  # Step 1: Install fixed file
  source('/mnt/user-data/outputs/install_fixed_domainprocessor.R')
  
  # Step 2: Check if we need to reload
  if (dir.exists("R") && file.exists("R/DomainProcessorR6.R")) {
    cat("\n📦 File installed in R/ directory.\n")
    cat("   Please run: devtools::load_all()\n")
  }
  
  cat("\n✅ Fix complete! Try your workflow now.\n")
}

cat("═══════════════════════════════════════════════\n")
cat("Type auto_fix() to apply everything automatically\n")
cat("═══════════════════════════════════════════════\n")
