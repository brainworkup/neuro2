#' ErrorHandlerR6 Class
#'
#' @title Error and validation helper for neuro2
#' @description An R6 class that centralizes safe evaluation, error/warning handling,
#'   lightweight validations, and simple diagnostics to help keep the pipeline robust.
#'
#' @docType class
#' @name ErrorHandlerR6
#' @format An R6 class generator object.
#'
#' @section Methods:
#' \describe{
#'   \item{\code{$initialize(config = NULL)}}{Create a new handler; optionally pass a configuration list.}
#'   \item{\code{$safe_execute(expr, context = NULL, fallback = NULL, silent = FALSE)}}{Safely evaluate an expression;
#'     capture errors/warnings and return \code{fallback} (if provided) on failure.}
#'   \item{\code{$handle_error(error, context = NULL, silent = FALSE)}}{Normalize and record an error condition with context.}
#'   \item{\code{$handle_warning(warning, context = NULL, silent = FALSE)}}{Normalize and record a warning condition with context.}
#'   \item{\code{$get_error_suggestions(message = NULL, context = NULL)}}{Return suggestions or troubleshooting tips based on a message/context.}
#'   \item{\code{$display_error(error_info)}}{Pretty-print a stored error record.}
#'   \item{\code{$get_recent_errors(n = 5)}}{Return the \code{n} most recent recorded errors.}
#'   \item{\code{$clear_log()}}{Clear stored errors and warnings.}
#'   \item{\code{$check_file_exists(file_path, context = NULL)}}{Return \code{TRUE} if a file exists; otherwise record and/or throw.}
#'   \item{\code{$check_required_columns(data, required_cols, context = NULL)}}{Validate that \code{data} contains all \code{required_cols}.}
#'   \item{\code{$check_package_available(package, context = NULL)}}{Return \code{TRUE} if a package is installed; otherwise record and/or throw.}
#' }
#'
#' @section Parameters (for methods above):
#' \describe{
#'   \item{\code{config}}{Optional list with handler configuration (verbosity, raise policy, etc.).}
#'   \item{\code{expr}}{An expression or function to execute safely.}
#'   \item{\code{context}}{Optional character vector or list giving call-site context (e.g., file, domain).}
#'   \item{\code{fallback}}{Value to return if \code{expr} fails; defaults to \code{NULL}.}
#'   \item{\code{silent}}{Logical; when \code{TRUE}, suppress console output.}
#'   \item{\code{error}}{An \code{error} object or condition.}
#'   \item{\code{warning}}{A \code{warning} object or condition.}
#'   \item{\code{message}}{Character string used to derive suggestions.}
#'   \item{\code{error_info}}{Structured list or object that represents a stored error.}
#'   \item{\code{n}}{Number of recent errors to return.}
#'   \item{\code{file_path}}{Path to a file to check.}
#'   \item{\code{data}}{A data frame / tibble to validate.}
#'   \item{\code{required_cols}}{Character vector of required column names.}
#'   \item{\code{package}}{Package name to check for availability.}
#' }
#'
#' @return
#' Most methods return the handler invisibly for chaining; query methods return logicals,
#' data structures, or user-provided fallbacks as appropriate.
#'
#' @examples
#' \dontrun{
#' eh <- ErrorHandlerR6$new()
#' safe <- eh$safe_execute(function() 1 + 1)
#' }
#'
#' @export
NULL
