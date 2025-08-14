#' ErrorHandlerR6 Class
#'
#' @title Centralized Error Handling System
#' @description Centralized error handling and user feedback system.
#'   Provides consistent error reporting with helpful suggestions.
#'
#' @docType class
#' @format An R6 class object
#' @section Methods:
#' \describe{
#'   \item{\code{$initialize}}{See method docs below.}
#'   \item{\code{$safe_execute}}{See method docs below.}
#'   \item{\code{$handle_error}}{See method docs below.}
#'   \item{\code{$handle_warning}}{See method docs below.}
#'   \item{\code{$get_error_suggestions}}{See method docs below.}
#'   \item{\code{$display_error}}{See method docs below.}
#'   \item{\code{$get_recent_errors}}{See method docs below.}
#'   \item{\code{$clear_log}}{See method docs below.}
#'   \item{\code{$check_file_exists}}{See method docs below.}
#'   \item{\code{$check_required_columns}}{See method docs below.}
#'   \item{\code{$check_package_available}}{See method docs below.}
#' }
#'
#' @field config Configuration object for error handling
#' @field error_log List containing logged errors
#'
#' @export
ErrorHandlerR6 <- R6::R6Class(
  classname = "ErrorHandlerR6",
  public = list(
    config = NULL,
    error_log = NULL,

    #' @description Constructor. Create a new ErrorHandlerR6 instance and initialize the error log.

    #' @param config Optional configuration object with settings (e.g., verbosity).

    #' @return A new ErrorHandlerR6 object (invisible).

    initialize = function(config = NULL) {
      self$config <- config
      self$error_log <- list()
    },

    # Wrapper for safe execution with error recovery
    #' @description Execute an expression safely, catching and logging any errors or warnings.
    #' @param expr Expression or function to execute.
    #' @param context Character label describing the operation (for logging).
    #' @param fallback Value to return if an error occurs.
    #' @param silent If TRUE, suppress user-facing messages.
    #' @return Result of the expression on success; otherwise `fallback`.

    safe_execute = function(expr,
                            context = "operation",
                            fallback = NULL,
                            silent = FALSE) {
      tryCatch(
        {
          expr
        },
        error = function(e) {
          self$handle_error(e, context, silent)
          fallback
        },
        warning = function(w) {
          self$handle_warning(w, context, silent)
          suppressWarnings(expr)
        }
      )
    },

    #' @description Handle an error by constructing a structured entry, logging it, and optionally displaying it.

    #' @param error Condition object returned by an error handler.

    #' @param context Character description of where the error occurred.

    #' @param silent If TRUE, do not display the error to the console.

    #' @return Invisibly returns a structured error info list.

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

    #' @description Handle a warning by logging it and optionally emitting a cli warning.

    #' @param warning Condition object representing the warning.

    #' @param context Character description of where the warning occurred.

    #' @param silent If TRUE, do not display the warning to the console.

    #' @return Invisibly returns a structured warning info list.

    handle_warning = function(warning, context = "operation", silent = FALSE) {
      warning_info <- list(
        message = warning$message,
        context = context,
        timestamp = Sys.time(),
        type = "warning"
      )

      if (
        !silent &&
          !is.null(self$config) &&
          self$config$get("processing.verbose", TRUE)
      ) {
        cli::cli_alert_warning("{context}: {warning$message}")
      }

      invisible(warning_info)
    },

    #' @description Return human-readable suggestions for resolving a given error message in a context.

    #' @param message The error message text.

    #' @param context Character label indicating the operation context.

    #' @return Character vector of suggestions.

    get_error_suggestions = function(message, context) {
      suggestions <- character()

      # File not found errors
      if (
        grepl(
          "file not found|cannot open|no such file",
          message,
          ignore.case = TRUE
        )
      ) {
        suggestions <- c(
          "Check that the file path is correct and the file exists",
          "Ensure you have read permissions for the file",
          "Try using absolute paths instead of relative paths",
          "Run list.files() to see available files in the directory"
        )
      } else if (
        grepl("object.*not found|could not find", message, ignore.case = TRUE)
      ) {
        # Data-related errors
        suggestions <- c(
          "Make sure the required data has been loaded",
          "Check that variable names are spelled correctly",
          "Try running the data loading steps first",
          "Use ls() to see what objects are available"
        )
      } else if (
        grepl("package.*not available|namespace", message, ignore.case = TRUE)
      ) {
        # Package/dependency errors
        suggestions <- c(
          "Install the missing package with install.packages()",
          "Check that the package name is spelled correctly",
          "Try restarting R and reloading packages",
          "Ensure you have the correct package version"
        )
      } else if (
        grepl("duckdb|database|connection", message, ignore.case = TRUE)
      ) {
        # Database/DuckDB errors
        suggestions <- c(
          "Check that DuckDB is properly installed",
          "Try reconnecting to the database",
          "Ensure the database file is not corrupted",
          "Check available disk space"
        )
      } else if (context == "domain_processing") {
        # Domain processing errors
        suggestions <- c(
          "Verify that the domain name exists in your data",
          "Check that the input data file contains the expected columns",
          "Ensure the data has been properly filtered",
          "Try running with a simpler domain first"
        )
      } else if (context == "report_generation") {
        # Report generation errors
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

    #' @description Pretty-print an error entry to the console using cli if available; otherwise fallback to base output.

    #' @param error_info Structured list created by `handle_error()` containing message, context, and suggestions.

    #' @return Invisibly returns self.

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

        cli::cli_alert_info(
          "For more help, check the error log with error_handler$get_recent_errors()"
        )
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

    #' @description Retrieve and optionally print the last `n` errors from the internal log.

    #' @param n Number of recent errors to retrieve (default 5).

    #' @return Invisibly returns the retrieved list of error entries.

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
          cli::cli_alert_danger(
            "[{error$timestamp}] {error$context}: {error$message}"
          )
        }
      } else {
        cat("Recent Errors:\n")
        for (error in recent_errors) {
          cat(sprintf(
            "[%s] %s: %s\n",
            error$timestamp,
            error$context,
            error$message
          ))
        }
      }

      invisible(recent_errors)
    },

    #' @description Clear the internal error log.

    #' @return Invisibly returns self.

    clear_log = function() {
      self$error_log <- list()
      message("Error log cleared.")
      invisible(self)
    },

    # Helper methods for common operations
    #' @description Verify that a file exists; if not, log an error and return FALSE.
    #' @param file_path Path to the file to check.
    #' @param context Character context label for logging (default 'file_check').
    #' @return Logical indicating file existence.

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

    #' @description Verify that a data frame contains all `required_cols`; log and return FALSE if any are missing.

    #' @param data Data frame to validate.

    #' @param required_cols Character vector of required column names.

    #' @param context Character context label for logging (default 'data_check').

    #' @return Logical; TRUE if all required columns are present.

    check_required_columns = function(data,
                                      required_cols,
                                      context = "data_check") {
      missing_cols <- setdiff(required_cols, names(data))
      if (length(missing_cols) > 0) {
        self$handle_error(
          simpleError(paste(
            "Missing required columns:",
            paste(missing_cols, collapse = ", ")
          )),
          context
        )
        return(FALSE)
      }
      TRUE
    },

    #' @description Check whether an R package is installed and available; log an error and return FALSE if missing.

    #' @param package Character package name to check.

    #' @param context Character context label for logging (default 'package_check').

    #' @return Logical; TRUE if package is available.

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
safe_execute <- function(
  expr,
  context = "operation",
  fallback = NULL,
  silent = FALSE
) {
  error_handler <- get_error_handler()
  error_handler$safe_execute(expr, context, fallback, silent)
}
