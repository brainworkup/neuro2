#!/usr/bin/env Rscript

#' REAL FIX: Modify DomainProcessorR6.R to Generate Correct Paths
#' 
#' This script modifies the actual DomainProcessorR6.R file to fix the root cause

cat("\n")
cat("════════════════════════════════════════════\n")
cat("   🔧 FIXING DomainProcessorR6.R SOURCE    \n")
cat("════════════════════════════════════════════\n\n")

cat("This will modify DomainProcessorR6.R to generate correct paths.\n")
cat("The fix will be permanent - no more patches needed!\n\n")

# Function to apply the fix
fix_domain_processor_source <- function(file_path) {
  
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }
  
  # Create backup
  backup_path <- paste0(file_path, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy(file_path, backup_path)
  cat("✅ Backup created: ", basename(backup_path), "\n\n")
  
  # Read the file
  lines <- readLines(file_path)
  
  cat("📝 Applying fixes...\n")
  fixes_applied <- 0
  
  # Fix #1: Line 1217 - table_adhd_adult.png
  if (lines[1217] == '        "// #let file_qtbl = \\"table_adhd_adult.png\\"\\n\\n",') {
    lines[1217] <- '        "// #let file_qtbl = \\"figs/table_adhd_adult.png\\"\\n\\n",'
    cat("  ✅ Fixed line 1217: table_adhd_adult.png\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #2: Line 1219 - fig_adhd_adult_subdomain.svg
  if (lines[1219] == '        "#let file_fig = \\"fig_adhd_adult_subdomain.svg\\"\\n\\n",') {
    lines[1219] <- '        "#let file_fig = \\"figs/fig_adhd_adult_subdomain.svg\\"\\n\\n",'
    cat("  ✅ Fixed line 1219: fig_adhd_adult_subdomain.svg\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #3: Line 1229 - table_adhd_adult.png
  if (lines[1229] == '        "#let file_qtbl = \\"table_adhd_adult.png\\"\\n\\n",') {
    lines[1229] <- '        "#let file_qtbl = \\"figs/table_adhd_adult.png\\"\\n\\n",'
    cat("  ✅ Fixed line 1229: table_adhd_adult.png\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #4: Line 1231 - fig_adhd_adult_narrow.svg
  if (lines[1231] == '        "#let file_fig = \\"fig_adhd_adult_narrow.svg\\"\\n\\n",') {
    lines[1231] <- '        "#let file_fig = \\"figs/fig_adhd_adult_narrow.svg\\"\\n\\n",'
    cat("  ✅ Fixed line 1231: fig_adhd_adult_narrow.svg\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #5: Line 1596 - table_adhd_child.png (commented)
  if (lines[1596] == '        "// #let file_qtbl = \\"table_adhd_child.png\\"\\n\\n",') {
    lines[1596] <- '        "// #let file_qtbl = \\"figs/table_adhd_child.png\\"\\n\\n",'
    cat("  ✅ Fixed line 1596: table_adhd_child.png (comment)\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #6: Line 1598 - fig_adhd_child_subdomain.svg
  if (lines[1598] == '        "#let file_fig = \\"fig_adhd_child_subdomain.svg\\"\\n\\n",') {
    lines[1598] <- '        "#let file_fig = \\"figs/fig_adhd_child_subdomain.svg\\"\\n\\n",'
    cat("  ✅ Fixed line 1598: fig_adhd_child_subdomain.svg\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #7: Line 1608 - table_adhd_child.png
  if (lines[1608] == '        "#let file_qtbl = \\"table_adhd_child.png\\"\\n\\n",') {
    lines[1608] <- '        "#let file_qtbl = \\"figs/table_adhd_child.png\\"\\n\\n",'
    cat("  ✅ Fixed line 1608: table_adhd_child.png\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #8: Line 1610 - fig_adhd_child_narrow.svg
  if (lines[1610] == '        "#let file_fig = \\"fig_adhd_child_narrow.svg\\"\\n\\n",') {
    lines[1610] <- '        "#let file_fig = \\"figs/fig_adhd_child_narrow.svg\\"\\n\\n",'
    cat("  ✅ Fixed line 1610: fig_adhd_child_narrow.svg\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #9: Line 2205 - fig_emotion_child_self_subdomain.svg
  if (lines[2205] == '        "#let file_fig = \\"fig_emotion_child_self_subdomain.svg\\"\\n\\n",') {
    lines[2205] <- '        "#let file_fig = \\"figs/fig_emotion_child_self_subdomain.svg\\"\\n\\n",'
    cat("  ✅ Fixed line 2205: fig_emotion_child_self_subdomain.svg\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #10: Line 2256 - fig_emotion_child_parent_subdomain.svg
  if (lines[2256] == '        "#let file_fig = \\"fig_emotion_child_parent_subdomain.svg\\"\\n\\n",') {
    lines[2256] <- '        "#let file_fig = \\"figs/fig_emotion_child_parent_subdomain.svg\\"\\n\\n",'
    cat("  ✅ Fixed line 2256: fig_emotion_child_parent_subdomain.svg\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #11: Line 2623 - fig_emotion_adult_subdomain.svg
  if (lines[2623] == '        "#let file_fig = \\"fig_emotion_adult_subdomain.svg\\"\\n\\n",') {
    lines[2623] <- '        "#let file_fig = \\"figs/fig_emotion_adult_subdomain.svg\\"\\n\\n",'
    cat("  ✅ Fixed line 2623: fig_emotion_adult_subdomain.svg\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #12: Line 2635 - fig_emotion_adult_narrow.svg
  if (lines[2635] == '        "#let file_fig = \\"fig_emotion_adult_narrow.svg\\"\\n\\n",') {
    lines[2635] <- '        "#let file_fig = \\"figs/fig_emotion_adult_narrow.svg\\"\\n\\n",'
    cat("  ✅ Fixed line 2635: fig_emotion_adult_narrow.svg\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #13: Line 3007 - Concatenated table path
  if (lines[3007] == '        "#let file_qtbl = \\"table_",') {
    lines[3007] <- '        "#let file_qtbl = \\"figs/table_",'
    cat("  ✅ Fixed line 3007: concatenated table path\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #14: Line 3011 - Concatenated fig path (subdomain)
  if (lines[3011] == '        "#let file_fig = \\"fig_",') {
    lines[3011] <- '        "#let file_fig = \\"figs/fig_",'
    cat("  ✅ Fixed line 3011: concatenated fig path (subdomain)\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #15: Line 3064 - Second concatenated table path
  if (lines[3064] == '        "#let file_qtbl = \\"table_",') {
    lines[3064] <- '        "#let file_qtbl = \\"figs/table_",'
    cat("  ✅ Fixed line 3064: concatenated table path (2nd)\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Fix #16: Line 3068 - Second concatenated fig path (narrow)
  if (lines[3068] == '        "#let file_fig = \\"fig_",') {
    lines[3068] <- '        "#let file_fig = \\"figs/fig_",'
    cat("  ✅ Fixed line 3068: concatenated fig path (narrow)\n")
    fixes_applied <- fixes_applied + 1
  }
  
  # Write the fixed file
  writeLines(lines, file_path)
  
  cat("\n")
  cat("════════════════════════════════════════════\n")
  cat("✅ Applied", fixes_applied, "fixes to DomainProcessorR6.R\n")
  cat("════════════════════════════════════════════\n\n")
  
  return(fixes_applied)
}

# Main execution
main <- function() {
  # Look for DomainProcessorR6.R
  possible_paths <- c(
    "/mnt/user-data/uploads/DomainProcessorR6.R",  # Uploaded file
    "R/DomainProcessorR6.R",                        # Package location
    "DomainProcessorR6.R",                          # Current directory
    here::here("R", "DomainProcessorR6.R")          # Using here package
  )
  
  file_path <- NULL
  for (path in possible_paths) {
    if (file.exists(path)) {
      file_path <- path
      break
    }
  }
  
  if (is.null(file_path)) {
    cat("❌ Could not find DomainProcessorR6.R\n")
    cat("\nPlease specify the path to your DomainProcessorR6.R file.\n")
    return(FALSE)
  }
  
  cat("📄 Found DomainProcessorR6.R at:\n   ", file_path, "\n\n")
  cat("This will modify the file to add 'figs/' to all image paths.\n")
  cat("A backup will be created first.\n\n")
  
  cat("Proceed? (y/n): ")
  if (interactive()) {
    response <- readline()
    if (tolower(response) != "y") {
      cat("Cancelled.\n")
      return(FALSE)
    }
  }
  
  # Apply the fix
  fixes <- fix_domain_processor_source(file_path)
  
  if (fixes > 0) {
    cat("🎉 SUCCESS! The source file has been fixed.\n\n")
    
    cat("IMPORTANT NEXT STEPS:\n")
    cat("1. If this is in a package, rebuild the package:\n")
    cat("   devtools::load_all() or devtools::install()\n\n")
    
    cat("2. If using directly, source the file:\n")
    cat("   source('", file_path, "')\n\n")
    
    cat("3. Regenerate your domain files:\n")
    cat("   - Delete existing _02-*.qmd files\n")
    cat("   - Re-run your workflow\n\n")
    
    cat("4. Or fix existing QMD files with:\n")
    cat("   source('/mnt/user-data/outputs/quick_fix_paths.R')\n\n")
    
    cat("The file path issue is now permanently fixed!\n")
  } else {
    cat("⚠️  No fixes were applied.\n")
    cat("The file may have already been fixed or has unexpected content.\n")
  }
  
  return(TRUE)
}

# Copy the fixed file to user's R directory if needed
copy_to_package <- function() {
  source_file <- "/mnt/user-data/uploads/DomainProcessorR6.R"
  target_file <- "R/DomainProcessorR6.R"
  
  if (file.exists(source_file) && dir.exists("R")) {
    cat("\nWould you like to copy the fixed file to R/DomainProcessorR6.R? (y/n): ")
    if (interactive()) {
      response <- readline()
      if (tolower(response) == "y") {
        if (file.exists(target_file)) {
          file.copy(target_file, paste0(target_file, ".backup"))
        }
        file.copy(source_file, target_file, overwrite = TRUE)
        cat("✅ Copied fixed file to R/DomainProcessorR6.R\n")
        cat("   Remember to reload the package!\n")
      }
    }
  }
}

# Run
if (!interactive()) {
  main()
} else {
  cat("Run main() to apply the fix\n")
  cat("Or copy and paste this to fix immediately:\n")
  cat("  source('/mnt/user-data/outputs/fix_domainprocessor_source.R'); main()\n")
}
