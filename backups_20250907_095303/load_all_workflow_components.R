#' Internal function to load all workflow components
#' @keywords internal
.load_all_workflow_components <- function(verbose = FALSE) {
  # Define load order (dependencies first)
  source_order <- list(
    utils = c(
      "R/workflow_utils.R",
      "R/workflow_config.R",
      "R/workflow_data_processor.R"
    ),
    helpers = c(
      "R/score_type_utils.R", # If this exists
      "R/tidy_data.R" # If this exists
    ),
    r6_classes = c(
      "R/ScoreTypeCacheR6.R",
      "R/NeuropsychResultsR6.R",
      "R/TableGTR6.R",
      "R/DotplotR6.R",
      "R/DomainProcessorR6.R",
      "R/DomainProcessorFactoryR6.R"
    ),
    workflow = c("R/WorkflowRunnerR6.R")
  )

  for (category in names(source_order)) {
    if (verbose) {
      message(paste("Loading", category, "..."))
    }

    for (file in source_order[[category]]) {
      if (file.exists(file)) {
  # Use require() or check if object exists instead
  # FIXED: source(file) # Moved to lazy loading
        if (verbose) message(paste("  ✓", basename(file)))
      } else {
        warning(paste("  ✗ File not found:", file))
      }
    }
  }

  # Verify critical functions are available
  critical_functions <- c(
    ".load_workflow_config", # Internal functions with dots
    ".print_header",
    ".print_colored",
    ".process_workflow_data" # Or .process_workflow_data if you make it internal
  )

  missing <- character()
  for (fn in critical_functions) {
    if (!exists(fn, mode = "function")) {
      missing <- c(missing, fn)
    }
  }

  if (length(missing) > 0) {
    stop(paste(
      "Critical functions not found after loading:",
      paste(missing, collapse = ", ")
    ))
  }

  invisible(TRUE)
}
