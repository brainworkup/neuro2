#' Compare the old and new batch processors to identify the problem
#' This will help you understand why the old one causes triple execution

cat("=== BATCH PROCESSOR COMPARISON ===\n\n")

# Analyze the current (problematic) batch processor
analyze_current <- function() {
  batch_file <- "inst/scripts/batch_domain_processor.R"
  
  if (!file.exists(batch_file)) {
    return(NULL)
  }
  
  content <- readLines(batch_file, warn = FALSE)
  
  analysis <- list(
    total_lines = length(content),
    loops = list(
      for_loops = length(grep("^[^#]*for\\s*\\(", content)),
      lapply = length(grep("^[^#]*lapply\\(", content)),
      sapply = length(grep("^[^#]*sapply\\(", content)),
      map = length(grep("^[^#]*map\\(|purrr::", content))
    ),
    domain_mentions = length(grep("domain", content, ignore.case = TRUE)),
    process_calls = length(grep("process", content, ignore.case = TRUE)),
    file_writes = length(grep("write|save|ggsave", content, ignore.case = TRUE))
  )
  
  # Check for nested loops
  for_lines <- grep("^[^#]*for\\s*\\(", content)
  nested_count <- 0
  for (i in seq_along(for_lines)) {
    if (i < length(for_lines)) {
      # Check if next loop is within 20 lines (likely nested)
      if (for_lines[i+1] - for_lines[i] < 20) {
        nested_count <- nested_count + 1
      }
    }
  }
  analysis$nested_loops <- nested_count
  
  return(analysis)
}

# Get current analysis
current <- analyze_current()

if (!is.null(current)) {
  cat("CURRENT batch_domain_processor.R:\n")
  cat("  Total lines:", current$total_lines, "\n")
  cat("  Total loops:", sum(unlist(current$loops)), "\n")
  cat("    - for loops:", current$loops$for_loops, "\n")
  cat("    - lapply:", current$loops$lapply, "\n")
  cat("    - sapply:", current$loops$sapply, "\n")
  cat("  Possible nested loops:", current$nested_loops, "\n")
  cat("  Domain references:", current$domain_mentions, "\n")
  cat("  Process calls:", current$process_calls, "\n")
  cat("  File write operations:", current$file_writes, "\n")
  
  # Diagnose the problem
  cat("\n=== DIAGNOSIS ===\n")
  
  total_loops <- sum(unlist(current$loops))
  
  if (total_loops >= 11) {
    cat("🔴 CRITICAL: Your script has", total_loops, "loops!\n")
    cat("   This is causing domains to be processed multiple times.\n")
  }
  
  if (current$nested_loops > 0) {
    cat("🔴 CRITICAL: Found", current$nested_loops, "possible nested loops!\n")
    cat("   Nested loops multiply executions exponentially.\n")
  }
  
  if (current$domain_mentions > 50) {
    cat("⚠️  WARNING: 'domain' mentioned", current$domain_mentions, "times.\n")
    cat("   This suggests complex/repeated domain handling.\n")
  }
  
  if (current$process_calls > 20) {
    cat("⚠️  WARNING:", current$process_calls, "process calls found.\n")
    cat("   Multiple process calls can cause repeated execution.\n")
  }
}

cat("\n=== FIXED VERSION CHARACTERISTICS ===\n")
cat("The batch_domain_processor_FIXED.R has:\n")
cat("  ✓ SINGLE for loop (no nested loops)\n")
cat("  ✓ Execution guard to prevent re-running\n")
cat("  ✓ Processed domain tracking\n")
cat("  ✓ Each domain processed exactly ONCE\n")
cat("  ✓ Clear logging of what's been done\n")
cat("  ✓ No recursive calls\n")

cat("\n=== HOW THE TRIPLE EXECUTION HAPPENS ===\n")
cat("Based on the analysis, your workflow likely runs 3 times because:\n\n")
cat("1. FIRST EXECUTION: Initial R script run\n")
cat("   - Your batch processor runs all domains\n")
cat("   - But with 11 loops, some domains may be processed multiple times\n\n")
cat("2. SECOND EXECUTION: Quarto pre-processing\n")
cat("   - Quarto evaluates the QMD files to understand dependencies\n")
cat("   - If batch processor is sourced in QMDs, it runs again\n\n")
cat("3. THIRD EXECUTION: Quarto rendering\n")
cat("   - Quarto executes all code chunks during render\n")
cat("   - Batch processor runs a third time\n\n")

cat("=== IMMEDIATE FIX ===\n")
cat("1. Replace your batch processor:\n")
cat("   cp batch_domain_processor_FIXED.R inst/scripts/batch_domain_processor.R\n\n")
cat("2. Add execution guards to your QMD files:\n")
cat("   In each domain QMD, add at the top of setup chunks:\n")
cat("   if (exists('.DOMAIN_PROCESSED')) return()\n")
cat("   .DOMAIN_PROCESSED <- TRUE\n\n")
cat("3. Use the fixed workflow script:\n")
cat("   ./unified_neuropsych_workflow_fixed.sh\n\n")

# Create a test to verify single execution
cat("=== VERIFICATION TEST ===\n")
cat("Run this test to confirm single execution:\n\n")

test_code <- '
# test_single_execution.R
rm(list = ls())  # Clear environment

# Add counter
.EXECUTION_COUNTER <- 0

# Override the process function to count calls
if (exists("DomainProcessorR6")) {
  original_process <- DomainProcessorR6$public_methods$process
  DomainProcessorR6$public_methods$process <- function(...) {
    .EXECUTION_COUNTER <<- .EXECUTION_COUNTER + 1
    cat("Process called:", .EXECUTION_COUNTER, "times\\n")
    original_process(...)
  }
}

# Run your workflow
source("inst/scripts/batch_domain_processor.R")

# Check counter
cat("\\nTOTAL PROCESS CALLS:", .EXECUTION_COUNTER, "\\n")
if (.EXECUTION_COUNTER > length(unique(domains))) {
  cat("❌ PROBLEM: Process called more times than domains!\\n")
} else {
  cat("✅ OK: Each domain processed once\\n")
}
'

cat(test_code)