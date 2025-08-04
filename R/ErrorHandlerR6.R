#' ErrorHandlerR6 Class
#'
#' @title Centralized Error Handling System
#' @description Centralized error handling and user feedback system.
#'   Provides consistent error reporting with helpful suggestions.
#'
#' @field config Configuration object for error handling
#' @field error_log List containing logged errors
#'
#' @param config Configuration object (optional)
#' @param expr Expression to execute
#' @param context Context description for errors
#' @param fallback Value to return on error
#' @param silent Whether to suppress error messages
#' @param error Error object to handle
#' @param warning Warning object to handle
#' @param message Error message text
#' @param error_info Structured error information
#' @param n Number of recent errors to return
#' @param file_path Path to check
#' @param data Data frame to check
#' @param required_cols Vector of required column names
#' @param package Package name to check
#'
#' @export
ErrorHandlerR6 <- R6::R6Class(
  classname = "ErrorHandlerR6",
  public = list(
    config = NULL,
    error_log = NULL,
    
    initialize = function(config = NULL) {
      self$config <- config
      self$error_log <- list()
    },
    
    # Wrapper for safe execution with error recovery
    safe_execute = function(expr, context = "operation", 
                           fallback = NULL, silent = FALSE) {
      tryCatch({
        expr
      }, error = function(e) {
        self$handle_error(e, context, silent)
        fallback
      }, warning = function(w) {
        self$handle_warning(w, context, silent)
        suppressWarnings(expr)
      })
    },
    
    handle_error = function(error, context = "operation", silent = FALSE) {
      # Create structured error information
      error_info <- list(
        message = error$message,
        context = context,
        timestamp = Sys.time(),
        call = deparse(error$call),
        suggestions = self$get_error_suggestions(error$message, context)
      )
      
      # Log the error
      self$error_log <- append(self$error_log, list(error_info))
      
      if (!silent) {
        self$display_error(error_info)
      }
      
      invisible(error_info)
    },
    
    handle_warning = function(warning, context = "operation", silent = FALSE) {
      warning_info <- list(
        message = warning$message,
        context = context,
        timestamp = Sys.time(),
        type = "warning"
      )
      
      if (!silent && !is.null(self$config) && 
          self$config$get("processing.verbose", TRUE)) {
        cli::cli_alert_warning("{context}: {warning$message}")
      }
      
      invisible(warning_info)
    },
    
    get_error_suggestions = function(message, context) {
      suggestions <- character()
      
      # File not found errors
      if (grepl("file not found|cannot open|no such file", message, ignore.case = TRUE)) {
        suggestions <- c(
          "Check that the file path is correct and the file exists",
          "Ensure you have read permissions for the file",
          "Try using absolute paths instead of relative paths",
          "Run list.files() to see available files in the directory"
        )
      }
      
      # Data-related errors
      else if (grepl("object.*not found|could not find", message, ignore.case = TRUE)) {
        suggestions <- c(
          "Make sure the required data has been loaded",
          "Check that variable names are spelled correctly", 
          "Try running the data loading steps first",
          "Use ls() to see what objects are available"
        )
      }
      
      # Package/dependency errors
      else if (grepl("package.*not available|namespace", message, ignore.case = TRUE)) {
        suggestions <- c(
          "Install the missing package with install.packages()",
          "Check that the package name is spelled correctly",
          "Try restarting R and reloading packages",
          "Ensure you have the correct package version"
        )
      }
      
      # Database/DuckDB errors
      else if (grepl("duckdb|database|connection", message, ignore.case = TRUE)) {
        suggestions <- c(
          "Check that DuckDB is properly installed",
          "Try reconnecting to the database",
          "Ensure the database file is not corrupted",
          "Check available disk space"
        )
      }
      
      # Domain processing errors
      else if (context == "domain_processing") {
        suggestions <- c(
          "Verify that the domain name exists in your data",
          "Check that the input data file contains the expected columns",
          "Ensure the data has been properly filtered",
          "Try running with a simpler domain first"
        )
      }
      
      # Report generation errors
      else if (context == "report_generation") {
        suggestions <- c(
          "Check that all required template files exist",
          "Ensure Quarto is properly installed and configured",
          "Verify that all data dependencies are available",
          "Try generating individual sections first"
        )
      }
      
      # Generic suggestions
      if (length(suggestions) == 0) {
        suggestions <- c(
          "Check the error message details above",
          "Try the operation with simpler inputs first",
          "Ensure all required packages are loaded",
          "Check for typos in variable or file names"
        )
      }
      
      suggestions
    },
    
    display_error = function(error_info) {
      if (requireNamespace("cli", quietly = TRUE)) {
        cli::cli_div(theme = list(span.emph = list(color = "orange")))
        cli::cli_h1("Error in {error_info$context}")
        cli::cli_alert_danger("Message: {error_info$message}")
        
        if (length(error_info$suggestions) > 0) {
          cli::cli_h2("Suggestions:")
          for (suggestion in error_info$suggestions) {
            cli::cli_li(suggestion)
          }
        }
        
        cli::cli_alert_info("For more help, check the error log with error_handler$get_recent_errors()")
        cli::cli_end()
      } else {
        # Fallback to base R messaging
        cat("\n=== ERROR IN", toupper(error_info$context), "===\n")
        cat("Message:", error_info$message, "\n")
        if (length(error_info$suggestions) > 0) {
          cat("\nSuggestions:\n")
          for (i in seq_along(error_info$suggestions)) {
            cat(sprintf("  %d. %s\n", i, error_info$suggestions[i]))
          }
        }
        cat("\n")
      }
    },
    
    get_recent_errors = function(n = 5) {
      if (length(self$error_log) == 0) {
        message("No errors logged.")
        return(invisible(NULL))
      }
      
      # Return last n errors
      start_idx <- max(1, length(self$error_log) - n + 1)
      recent_errors <- self$error_log[start_idx:length(self$error_log)]
      
      if (requireNamespace("cli", quietly = TRUE)) {
        cli::cli_h2("Recent Errors:")
        for (i in seq_along(recent_errors)) {
          error <- recent_errors[[i]]
          cli::cli_alert_danger("[{error$timestamp}] {error$context}: {error$message}")
        }
      } else {
        cat("Recent Errors:\n")
        for (error in recent_errors) {
          cat(sprintf("[%s] %s: %s\n", 
                     error$timestamp, error$context, error$message))
        }
      }
      
      invisible(recent_errors)
    },
    
    clear_log = function() {
      self$error_log <- list()
      message("Error log cleared.")
      invisible(self)
    },
    
    # Helper methods for common operations
    check_file_exists = function(file_path, context = "file_check") {
      if (!file.exists(file_path)) {
        self$handle_error(
          simpleError(paste("File not found:", file_path)),
          context
        )
        return(FALSE)
      }
      TRUE
    },
    
    check_required_columns = function(data, required_cols, context = "data_check") {
      missing_cols <- setdiff(required_cols, names(data))
      if (length(missing_cols) > 0) {
        self$handle_error(
          simpleError(paste("Missing required columns:", 
                           paste(missing_cols, collapse = ", "))),
          context
        )
        return(FALSE)
      }
      TRUE
    },
    
    check_package_available = function(package, context = "package_check") {
      if (!requireNamespace(package, quietly = TRUE)) {
        self$handle_error(
          simpleError(paste("Package not available:", package)),
          context
        )
        return(FALSE)
      }
      TRUE
    }
  )
)

# Global error handler instance (optional convenience)
.neuro2_error_handler <- NULL

#' Get or create global error handler
#' @param config Optional configuration object
#' @export
get_error_handler <- function(config = NULL) {
  if (is.null(.neuro2_error_handler)) {
    .neuro2_error_handler <<- ErrorHandlerR6$new(config)
  }
  .neuro2_error_handler
}

#' Safe execution wrapper function
#' @param expr Expression to execute safely
#' @param context Context description for errors
#' @param fallback Value to return on error
#' @param silent Whether to suppress error messages
#' @export
safe_execute <- function(expr, context = "operation", 
                        fallback = NULL, silent = FALSE) {
  error_handler <- get_error_handler()
  error_handler$safe_execute(expr, context, fallback, silent)
}