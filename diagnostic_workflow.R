#' Diagnostic Script for Triple Execution Issue
#' Run this to identify where the workflow is being called multiple times

# Create a log file to track executions
log_file <- "workflow_diagnostics.log"

# Function to log with timestamp
log_message <- function(msg, file = log_file) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s\n", timestamp, msg), file = file, append = TRUE)
  message(sprintf("[%s] %s", timestamp, msg))
}

# Clear previous log
if (file.exists(log_file)) {
  file.remove(log_file)
}

log_message("=== WORKFLOW DIAGNOSTIC STARTED ===")

# Check 1: Environment variables
log_message("Checking environment for duplicate calls...")
log_message(paste("Working directory:", getwd()))
log_message(paste("R version:", R.version.string))

# Check 2: Look for recursive sourcing
check_recursive_sourcing <- function() {
  # Get the call stack
  calls <- sys.calls()

  if (length(calls) > 0) {
    log_message(paste("Call stack depth:", length(calls)))

    # Look for duplicate source() calls
    source_calls <- grep("source", sapply(calls, deparse), value = TRUE)
    if (length(source_calls) > 0) {
      log_message("Found source() calls in stack:")
      for (call in source_calls) {
        log_message(paste("  -", substr(call, 1, 100)))
      }
    }
  }
}

check_recursive_sourcing()

# Check 3: Trace Quarto/knitr execution
if (exists("knitr") && !is.null(knitr::opts_chunk$get("label"))) {
  current_chunk <- knitr::opts_chunk$get("label")
  log_message(paste("Currently executing chunk:", current_chunk))
}

# Check 4: Look for multiple QMD files being processed
qmd_files <- list.files(pattern = "\\.qmd$", recursive = TRUE)
# Filter out files in _arxiv/ directory
qmd_files <- qmd_files[!grepl("_arxiv/", qmd_files, fixed = TRUE)]
log_message(paste("Found", length(qmd_files), "QMD files (excluding _arxiv/):"))
for (f in qmd_files) {
  log_message(paste("  -", f))
}

# Check 5: Check for circular includes
check_circular_includes <- function(file, visited = character()) {
  if (file %in% visited) {
    log_message(paste("CIRCULAR INCLUDE DETECTED:", file))
    return(TRUE)
  }

  if (!file.exists(file)) {
    return(FALSE)
  }

  content <- readLines(file, warn = FALSE)
  include_lines <- grep("\\{\\{< include", content, value = TRUE)

  if (length(include_lines) > 0) {
    log_message(paste("File", file, "includes:"))
    for (line in include_lines) {
      # Extract included file name
      included_file <- gsub(".*include\\s+([^\\s>]+).*", "\\1", line)
      log_message(paste("  -", included_file))

      # Recursively check
      if (file.exists(included_file)) {
        check_circular_includes(included_file, c(visited, file))
      }
    }
  }

  return(FALSE)
}

# Check main template for circular includes
if (file.exists("template.qmd")) {
  log_message("Checking template.qmd for circular includes...")
  check_circular_includes("template.qmd")
}

# Check 6: Monitor R6 class instantiation
trace_r6_creation <- function() {
  if (exists("DomainProcessorR6")) {
    # Add tracing to the initialize method
    original_init <- DomainProcessorR6$public_methods$initialize

    DomainProcessorR6$public_methods$initialize <- function(...) {
      log_message(paste(
        "DomainProcessorR6 instantiated with args:",
        paste(list(...), collapse = ", ")
      ))
      original_init(...)
    }
  }
}

trace_r6_creation()

# Check 7: Look for duplicate batch processing
check_batch_files <- function() {
  batch_scripts <- list.files(
    pattern = "batch.*\\.(R|r)$",
    path = c(".", "R", "inst/scripts"),
    full.names = TRUE
  )

  if (length(batch_scripts) > 0) {
    log_message(paste("Found", length(batch_scripts), "batch scripts:"))
    for (script in batch_scripts) {
      log_message(paste("  -", script))

      # Check for loops in the script
      if (file.exists(script)) {
        content <- readLines(script, warn = FALSE)
        loop_lines <- grep("for.*in|while|repeat", content)
        if (length(loop_lines) > 0) {
          log_message(paste("    Contains", length(loop_lines), "loop(s)"))
        }
      }
    }
  }
}

check_batch_files()

# Check 8: Memory objects that might indicate multiple runs
check_duplicate_objects <- function() {
  # Look for numbered objects that might indicate multiple runs
  all_objects <- ls(envir = .GlobalEnv)

  # Pattern for duplicated objects (like data1, data2, data3)
  numbered_objects <- grep("[0-9]+$", all_objects, value = TRUE)

  if (length(numbered_objects) > 0) {
    log_message("Found numbered objects (possible duplicates):")
    for (obj in numbered_objects) {
      log_message(paste("  -", obj))
    }
  }

  # Check for .Last.value being a list of similar items
  if (exists(".Last.value") && is.list(.Last.value)) {
    if (length(.Last.value) == 3) {
      log_message(
        "WARNING: .Last.value has 3 elements - possible triple execution"
      )
    }
  }
}

check_duplicate_objects()

# Check 9: Execution counter
create_execution_counter <- function() {
  counter_file <- ".execution_counter"

  if (file.exists(counter_file)) {
    count <- as.numeric(readLines(counter_file, n = 1))
    count <- count + 1
  } else {
    count <- 1
  }

  writeLines(as.character(count), counter_file)
  log_message(paste("EXECUTION COUNT:", count))

  if (count > 1) {
    log_message("WARNING: This is execution number " %+% count)
    log_message("The workflow has been called multiple times!")
  }

  return(count)
}

execution_count <- create_execution_counter()

# Summary
log_message("=== DIAGNOSTIC COMPLETE ===")
log_message(paste("Log saved to:", log_file))

# Print recommendations
cat("\n=== RECOMMENDATIONS ===\n")
if (execution_count > 1) {
  cat("⚠️  MULTIPLE EXECUTIONS DETECTED!\n")
  cat("   Check the following:\n")
  cat("   1. Your bash script for multiple 'quarto render' calls\n")
  cat("   2. Your QMD files for recursive includes\n")
  cat("   3. Your R scripts for loops processing domains\n")
  cat("   4. Cache settings in Quarto (try --cache-refresh)\n")
} else {
  cat("✓ Single execution confirmed\n")
}

# Clean up counter for next run (optional)
if (interactive()) {
  response <- readline("Reset execution counter? (y/n): ")
  if (tolower(response) == "y") {
    file.remove(".execution_counter")
    cat("Counter reset.\n")
  }
}
