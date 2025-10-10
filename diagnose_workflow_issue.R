#!/usr/bin/env Rscript

# Diagnostic Script for Neuropsych Workflow Issue
# This will help identify where the extra run_neuropsych_workflow() call is coming from

cat("========================================\n")
cat("WORKFLOW DIAGNOSTIC TOOL\n")
cat("========================================\n\n")

# Step 1: Check what's in 00_complete_neuropsych_workflow.R
cat("📋 Checking 00_complete_neuropsych_workflow.R...\n")

workflow_file <- "inst/scripts/00_complete_neuropsych_workflow.R"
if (file.exists(workflow_file)) {
  workflow_content <- readLines(workflow_file)
  
  # Look for function definition
  func_def_line <- grep("^run_neuropsych_workflow\\s*<-\\s*function", workflow_content)
  if (length(func_def_line) > 0) {
    cat("✅ Function definition found at line:", func_def_line, "\n")
  } else {
    cat("❌ Function definition NOT found!\n")
  }
  
  # Look for function calls at the end of the file
  last_20_lines <- tail(workflow_content, 20)
  func_calls <- grep("run_neuropsych_workflow\\(", last_20_lines)
  
  if (length(func_calls) > 0) {
    cat("⚠️  Found function call(s) at end of file:\n")
    cat("    Lines (from end):", length(workflow_content) - 20 + func_calls, "\n")
    cat("    Content:\n")
    for (i in func_calls) {
      cat("      ", last_20_lines[i], "\n")
    }
  } else {
    cat("✅ No trailing function calls found\n")
  }
  
} else {
  cat("❌ File not found:", workflow_file, "\n")
}

cat("\n")

# Step 2: Check joey_startup_clean.R
cat("📋 Checking joey_startup_clean.R...\n")

startup_file <- "joey_startup_clean.R"
if (file.exists(startup_file)) {
  startup_content <- readLines(startup_file)
  
  # Count how many times run_neuropsych_workflow is called
  calls <- grep("run_neuropsych_workflow\\(", startup_content)
  
  cat("   Found", length(calls), "call(s) to run_neuropsych_workflow:\n")
  for (i in calls) {
    cat("     Line", i, ":", startup_content[i], "\n")
  }
} else {
  cat("❌ File not found:", startup_file, "\n")
}

cat("\n")

# Step 3: Check for .Rprofile or other startup files
cat("📋 Checking for startup files that might interfere...\n")

startup_files <- c(".Rprofile", ".Renviron", ".Rproj.user")
for (file in startup_files) {
  if (file.exists(file) || dir.exists(file)) {
    cat("   ⚠️  Found:", file, "\n")
  }
}

cat("\n")

# Step 4: List all R scripts in inst/scripts
cat("📋 Listing all scripts in inst/scripts/...\n")
if (dir.exists("inst/scripts")) {
  scripts <- list.files("inst/scripts", pattern = "\\.R$", full.names = TRUE)
  cat("   Found", length(scripts), "R scripts:\n")
  for (script in scripts) {
    cat("     -", basename(script), "\n")
  }
} else {
  cat("❌ Directory not found: inst/scripts/\n")
}

cat("\n")

# Step 5: Check for run_workflow.R specifically
cat("📋 Checking for 'run_workflow.R' (mentioned as potentially old)...\n")
run_workflow_locations <- c(
  "run_workflow.R",
  "inst/scripts/run_workflow.R",
  "R/run_workflow.R"
)

for (loc in run_workflow_locations) {
  if (file.exists(loc)) {
    cat("   ⚠️  FOUND OLD FILE:", loc, "\n")
    cat("      This might be causing issues!\n")
  }
}

cat("\n========================================\n")
cat("DIAGNOSTIC COMPLETE\n")
cat("========================================\n\n")

cat("RECOMMENDATIONS:\n")
cat("1. Check the locations marked with ⚠️  above\n")
cat("2. Look for any trailing function calls in your workflow file\n")
cat("3. Consider using the fixed workflow script I'll provide\n")
