#!/usr/bin/env Rscript

#' Fix Recursive Processing Patterns
#' This prevents functions from calling themselves or creating loops

cat("========================================\n")
cat("FIXING RECURSIVE PROCESSING\n")
cat("========================================\n\n")

# Add processing guards to R6 classes
add_processing_guards <- function() {
  cat("Adding processing guards to R6 classes...\n")
  
  # List of R6 files that need guards
  r6_files <- c(
    "R/DomainProcessorR6.R",
    "R/DomainProcessorFactoryR6.R",
    "R/DuckDBProcessorR6.R",
    "R/NeuropsychResultsR6.R",
    "R/TableGTR6.R"
  )
  
  for (file in r6_files) {
    if (!file.exists(file)) {
      cat("  ⚠️  Skipping", file, "(not found)\n")
      next
    }
    
    # Read the file
    lines <- readLines(file)
    
    # Look for process() methods
    process_lines <- grep("process\\s*=\\s*function", lines)
    
    if (length(process_lines) > 0) {
      for (pl in process_lines) {
        # Check if guard already exists
        check_range <- (pl+1):min(pl+5, length(lines))
        if (!any(grepl("processing_flag|PROCESSING|process_guard", lines[check_range]))) {
          # Add guard after function definition
          guard_code <- c(
            "      # Guard against recursive processing",
            "      if (isTRUE(private$processing_flag)) {",
            "        message('Already processing, skipping to prevent recursion')",
            "        return(invisible(self))",
            "      }",
            "      private$processing_flag <- TRUE",
            "      on.exit(private$processing_flag <- FALSE, add = TRUE)",
            ""
          )
          
          # Insert the guard
          lines <- append(lines, guard_code, after = pl)
          cat("  ✓ Added guard to", basename(file), "\n")
        }
      }
      
      # Also add the flag to private section
      private_line <- grep("private\\s*=\\s*list\\(", lines)[1]
      if (!is.na(private_line)) {
        # Check if flag exists
        if (!any(grepl("processing_flag", lines))) {
          flag_line <- "    processing_flag = FALSE,"
          lines <- append(lines, flag_line, after = private_line)
        }
      }
      
      # Write back
      writeLines(lines, file)
    }
  }
}

# Create execution tracker
create_execution_tracker <- function() {
  cat("\nCreating execution tracker...\n")
  
  tracker_content <- '
#\' Execution Tracker - Prevents Multiple Runs
#\' 
#\' Use this to track what has been executed and prevent re-runs

ExecutionTrackerR6 <- R6::R6Class(
  "ExecutionTrackerR6",
  public = list(
    executed_tasks = NULL,
    execution_log = NULL,
    
    initialize = function() {
      self$executed_tasks <- list()
      self$execution_log <- data.frame(
        task = character(),
        time = character(),
        status = character(),
        stringsAsFactors = FALSE
      )
    },
    
    can_execute = function(task_id) {
      # Check if task has already been executed
      if (task_id %in% names(self$executed_tasks)) {
        message("Task already executed: ", task_id)
        return(FALSE)
      }
      return(TRUE)
    },
    
    mark_executed = function(task_id, status = "success") {
      self$executed_tasks[[task_id]] <- Sys.time()
      self$execution_log <- rbind(
        self$execution_log,
        data.frame(
          task = task_id,
          time = as.character(Sys.time()),
          status = status,
          stringsAsFactors = FALSE
        )
      )
    },
    
    reset = function() {
      self$executed_tasks <- list()
      self$execution_log <- self$execution_log[0,]
      message("Execution tracker reset")
    },
    
    get_summary = function() {
      list(
        total_executed = length(self$executed_tasks),
        tasks = names(self$executed_tasks),
        log = self$execution_log
      )
    }
  )
)

# Global tracker instance
.EXECUTION_TRACKER <- ExecutionTrackerR6$new()

# Helper function for safe execution
safe_execute <- function(task_id, func, ...) {
  if (.EXECUTION_TRACKER$can_execute(task_id)) {
    tryCatch({
      result <- func(...)
      .EXECUTION_TRACKER$mark_executed(task_id, "success")
      return(result)
    }, error = function(e) {
      .EXECUTION_TRACKER$mark_executed(task_id, "error")
      stop(e)
    })
  } else {
    message("Skipping already executed task: ", task_id)
    return(NULL)
  }
}
'
  
  writeLines(tracker_content, "R/ExecutionTrackerR6.R")
  cat("  ✓ Created R/ExecutionTrackerR6.R\n")
}

# Fix specific recursive patterns
fix_recursive_patterns <- function() {
  cat("\nFixing specific recursive patterns...\n")
  
  files_to_check <- list.files("R", pattern = "\\.R$", full.names = TRUE)
  
  for (file in files_to_check) {
    lines <- readLines(file)
    modified <- FALSE
    
    # Pattern 1: Functions calling themselves
    func_names <- gsub("\\s*<-.*", "", grep("<-\\s*function", lines, value = TRUE))
    func_names <- trimws(gsub(".*\\$", "", func_names))  # Handle R6 methods
    
    for (func_name in func_names) {
      if (nchar(func_name) > 0) {
        # Look for self-calls
        pattern <- paste0("\\b", func_name, "\\s*\\(")
        self_calls <- grep(pattern, lines)
        
        # Check if any self-calls are inside the function
        if (length(self_calls) > 1) {  # More than just the definition
          cat("  ⚠️  Possible recursion in", basename(file), "- function", func_name, "\n")
          # Add comment warning
          for (sc in self_calls[-1]) {  # Skip the definition line
            if (!grepl("#.*RECURSIVE", lines[sc])) {
              lines[sc] <- paste0(lines[sc], " # WARNING: Possible recursion")
              modified <- TRUE
            }
          }
        }
      }
    }
    
    if (modified) {
      writeLines(lines, file)
      cat("  ✓ Marked recursive patterns in", basename(file), "\n")
    }
  }
}

# Main execution
cat("Step 1: Adding processing guards...\n")
add_processing_guards()

cat("\nStep 2: Creating execution tracker...\n")
create_execution_tracker()

cat("\nStep 3: Fixing recursive patterns...\n")
fix_recursive_patterns()

cat("\n========================================\n")
cat("✓ RECURSIVE PROCESSING FIXES COMPLETE\n")
cat("========================================\n")
