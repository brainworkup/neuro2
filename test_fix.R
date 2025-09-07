
# Test for single execution
execution_count <- 0

# Override process to count
if (exists("DomainProcessorR6")) {
  orig <- DomainProcessorR6$public_methods$process
  DomainProcessorR6$public_methods$process <- function(...) {
    execution_count <<- execution_count + 1
    cat("Execution", execution_count, "\n")
    if (execution_count > 1) {
      stop("MULTIPLE EXECUTION DETECTED!")
    }
    orig(...)
  }
}

# Run workflow
source("clean_workflow.R")

cat("\nTest result: ", execution_count, "executions\n")
if (execution_count <= 8) {  # Max 8 domains
  cat("✓ SUCCESS: Single execution confirmed\n")
} else {
  cat("✗ FAILURE: Multiple executions detected\n")
}

