#' Quick Fix for Triple Execution Problem
#' Run this before your workflow to clean up and prevent issues

message("🔧 APPLYING QUICK FIXES FOR WORKFLOW")

# 1. Clear all caches
clear_all_caches <- function() {
  message("Clearing caches...")
  
  # Clear knitr cache
  if (dir.exists("_cache")) {
    unlink("_cache", recursive = TRUE)
    message("  ✓ Cleared knitr cache")
  }
  
  # Clear Quarto cache
  if (dir.exists(".quarto")) {
    unlink(".quarto", recursive = TRUE)
    message("  ✓ Cleared Quarto cache")
  }
  
  # Clear any template cache
  cache_files <- list.files(pattern = "*_cache$", full.names = TRUE)
  for (cf in cache_files) {
    unlink(cf, recursive = TRUE)
    message("  ✓ Cleared ", cf)
  }
}

# 2. Remove duplicate QMD files
clean_duplicate_qmds <- function() {
  message("Checking for duplicate QMD files...")
  
  # Look for numbered QMDs (like file1.qmd, file2.qmd)
  qmd_files <- list.files(pattern = "_[0-9]+\\.qmd$")
  
  if (length(qmd_files) > 0) {
    message("  Found duplicate QMDs:")
    for (f in qmd_files) {
      message("    - ", f)
      file.remove(f)
    }
  } else {
    message("  ✓ No duplicates found")
  }
}

# 3. Fix template.qmd execution settings
fix_template_execution <- function() {
  if (!file.exists("template.qmd")) {
    message("  ⚠️  template.qmd not found")
    return()
  }
  
  message("Fixing template.qmd execution settings...")
  
  # Read template
  lines <- readLines("template.qmd")
  
  # Find YAML header
  yaml_start <- which(lines == "---")[1]
  yaml_end <- which(lines == "---")[2]
  
  if (!is.na(yaml_start) && !is.na(yaml_end)) {
    # Check for cache settings
    if (!any(grepl("cache:", lines[yaml_start:yaml_end]))) {
      # Add cache: true to execute block
      execute_line <- grep("^execute:", lines[yaml_start:yaml_end])
      if (length(execute_line) > 0) {
        # Find the execute block and add cache
        lines <- append(lines, "  cache: true", 
                       after = yaml_start + execute_line[1])
        message("  ✓ Added cache setting")
      }
    }
    
    # Write back
    writeLines(lines, "template.qmd")
  }
}

# 4. Create a workflow lock mechanism
create_workflow_lock <- function() {
  message("Setting up workflow lock...")
  
  lock_code <- '
# Workflow lock to prevent multiple executions
if (exists(".WORKFLOW_LOCK") && .WORKFLOW_LOCK) {
  stop("Workflow is already running! Clear .WORKFLOW_LOCK to continue.")
}
.WORKFLOW_LOCK <- TRUE
on.exit(rm(.WORKFLOW_LOCK, envir = .GlobalEnv), add = TRUE)
'
  
  # Save to file that can be sourced
  writeLines(lock_code, "workflow_lock.R")
  message("  ✓ Created workflow_lock.R")
  message("  Add 'source(\"workflow_lock.R\")' at the start of your scripts")
}

# 5. Environment cleanup
clean_environment <- function() {
  message("Cleaning R environment...")
  
  # Remove all workflow-related objects
  objs <- ls(envir = .GlobalEnv)
  workflow_objs <- grep("processor|domain|workflow", objs, 
                       value = TRUE, ignore.case = TRUE)
  
  if (length(workflow_objs) > 0) {
    rm(list = workflow_objs, envir = .GlobalEnv)
    message("  ✓ Removed ", length(workflow_objs), " workflow objects")
  }
  
  # Clear any execution counters
  if (file.exists(".execution_counter")) {
    file.remove(".execution_counter")
    message("  ✓ Reset execution counter")
  }
}

# 6. Check for problematic patterns
check_problematic_patterns <- function() {
  message("Checking for problematic patterns...")
  
  r_files <- list.files(path = "R", pattern = "\\.R$", full.names = TRUE)
  
  issues_found <- FALSE
  
  for (file in r_files) {
    content <- readLines(file, warn = FALSE)
    
    # Check for source() calls within functions
    if (any(grepl("source\\(.*\\)", content))) {
      func_lines <- grep("function.*\\{", content)
      source_lines <- grep("source\\(", content)
      
      for (sl in source_lines) {
        # Check if source is inside a function
        inside_func <- any(func_lines < sl)
        if (inside_func) {
          message("  ⚠️  Found source() inside function in ", basename(file))
          message("     Line ", sl, ": ", trimws(content[sl]))
          issues_found <- TRUE
        }
      }
    }
    
    # Check for recursive processing
    if (any(grepl("process.*process", content, ignore.case = TRUE))) {
      message("  ⚠️  Possible recursive processing in ", basename(file))
      issues_found <- TRUE
    }
  }
  
  if (!issues_found) {
    message("  ✓ No problematic patterns found")
  }
}

# Run all fixes
message("\n=== RUNNING QUICK FIXES ===\n")

clear_all_caches()
clean_duplicate_qmds()
fix_template_execution()
create_workflow_lock()
clean_environment()
check_problematic_patterns()

message("\n=== QUICK FIXES COMPLETE ===")
message("\nRecommended next steps:")
message("1. Use the new bash script: ./unified_neuropsych_workflow_fixed.sh")
message("2. Source workflow_lock.R at the start of your main scripts")
message("3. Run diagnose_workflow.R if issues persist")
message("4. Ensure all QMD includes use {{< include file.qmd >}} syntax")
message("5. Set cache: true in all code chunks that don't change")
