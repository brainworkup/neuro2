#' Enhanced Utility Functions for NeurotypR
#'
#' @description
#' Core utility functions that provide common operations used throughout
#' the NeurotypR package. These functions improve performance, reduce
#' code duplication, and provide consistent behavior.
#'
#' @name neurotypr_utils
#' @keywords internal

#' Null Coalescing Operator
#'
#' @description
#' Returns the first non-null value from left to right.
#' Similar to ?? operator in other languages.
#'
#' @param x Primary value
#' @param y Default value if x is NULL
#' @export
#' @examples
#' # Returns "default" because x is NULL
#' x <- NULL
#' x %||% "default"
#'
#' # Returns "value" because x is not NULL
#' x <- "value"
#' x %||% "default"
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Safe CSV Reading with Error Handling
#'
#' @description
#' Reads a CSV file with comprehensive error handling and consistent options.
#' Returns NULL on failure instead of stopping execution.
#'
#' @param file Path to CSV file
#' @param ... Additional arguments passed to readr::read_csv
#' @return Data frame or NULL on error
#' @export
safe_read_csv <- function(file, ...) {
  cfg <- get_config()

  tryCatch(
    {
      if (cfg$get("verbose", FALSE)) {
        cli::cli_alert_info("Reading file: {.file {basename(file)}}")
      }

      readr::read_csv(
        file,
        show_col_types = FALSE,
        progress = cfg$get("verbose", FALSE),
        ...
      )
    },
    error = function(e) {
      cli::cli_alert_warning(
        "Failed to read {.file {basename(file)}}: {e$message}"
      )
      NULL
    }
  )
}

#' Read Multiple CSV Files
#'
#' @description
#' Reads multiple CSV files and combines them into a single data frame.
#' Handles errors gracefully by skipping problematic files.
#'
#' @param files Vector of file paths
#' @param .id Optional column name to store source file information
#' @param ... Additional arguments passed to safe_read_csv
#' @return Combined data frame
#' @export
read_multiple_csv <- function(files, .id = NULL, ...) {
  cfg <- get_config()

  if (length(files) == 0) {
    cli::cli_alert_warning("No files provided")
    return(data.frame())
  }

  # Use progress bar if verbose
  if (cfg$get("verbose", FALSE)) {
    results <- with_progress(
      files,
      function(file) {
        df <- safe_read_csv(file, ...)
        if (!is.null(.id) && !is.null(df)) {
          df[[.id]] <- basename(file)
        }
        df
      },
      message = "Reading CSV files"
    )
  } else {
    results <- lapply(files, function(file) {
      df <- safe_read_csv(file, ...)
      if (!is.null(.id) && !is.null(df)) {
        df[[.id]] <- basename(file)
      }
      df
    })
  }

  # Remove NULL results and combine
  results <- Filter(Negate(is.null), results)

  if (length(results) == 0) {
    cli::cli_alert_warning("No files could be read successfully")
    return(data.frame())
  }

  dplyr::bind_rows(results)
}

#' Progress Bar Wrapper
#'
#' @description
#' Executes a function on items with a progress bar.
#'
#' @param items Vector of items to process
#' @param fn Function to apply to each item
#' @param message Progress bar message
#' @return List of results
#' @export
with_progress <- function(items, fn, message = "Processing") {
  if (!requireNamespace("progress", quietly = TRUE)) {
    # Fallback to simple lapply if progress package not available
    return(lapply(items, fn))
  }

  pb <- progress::progress_bar$new(
    format = paste(message, "[:bar] :percent | :current/:total | ETA: :eta"),
    total = length(items),
    clear = FALSE,
    width = 60
  )

  lapply(items, function(item) {
    pb$tick()
    fn(item)
  })
}

#' Cached Function Execution
#'
#' @description
#' Caches function results using memoise for expensive operations.
#' Cache is session-specific by default.
#'
#' @param fn Function to cache
#' @param cache_dir Optional cache directory for persistent cache
#' @return Memoised function
#' @export
cache_function <- function(fn, cache_dir = NULL) {
  if (!requireNamespace("memoise", quietly = TRUE)) {
    cli::cli_alert_warning("memoise package not installed, caching disabled")
    return(fn)
  }

  if (is.null(cache_dir)) {
    # Use in-memory cache
    memoise::memoise(fn)
  } else {
    # Use filesystem cache
    cache <- memoise::cache_filesystem(cache_dir)
    memoise::memoise(fn, cache = cache)
  }
}

#' Parallel Processing Helper
#'
#' @description
#' Applies a function to items in parallel if enabled in configuration.
#' Falls back to sequential processing if parallel is disabled or unavailable.
#'
#' @param items Vector or list of items to process
#' @param fn Function to apply
#' @param ... Additional arguments passed to fn
#' @return List of results
#' @export
parallel_map <- function(items, fn, ...) {
  cfg <- get_config()

  use_parallel <- cfg$get("parallel_processing", FALSE)
  n_cores <- cfg$get("n_cores", 1)

  if (
    use_parallel && n_cores > 1 && requireNamespace("future", quietly = TRUE)
  ) {
    # Set up parallel processing
    oplan <- future::plan()
    on.exit(future::plan(oplan), add = TRUE)

    future::plan(future::multisession, workers = n_cores)

    # Use future.apply for parallel processing
    if (requireNamespace("future.apply", quietly = TRUE)) {
      future.apply::future_lapply(items, fn, ...)
    } else {
      # Fallback to sequential
      lapply(items, fn, ...)
    }
  } else {
    # Sequential processing
    lapply(items, fn, ...)
  }
}

#' Create Safe File Path
#'
#' @description
#' Creates a safe file path by sanitizing the filename and ensuring
#' the directory exists.
#'
#' @param ... Path components
#' @param create_dir Whether to create directory if it doesn't exist
#' @return Safe file path
#' @export
safe_path <- function(..., create_dir = TRUE) {
  # Combine path components
  components <- list(...)

  # Sanitize each component
  components <- lapply(components, function(x) {
    gsub("[^[:alnum:]._-]", "_", x)
  })

  # Create path
  path <- do.call(file.path, components)

  # Create directory if requested
  if (create_dir) {
    dir_path <- dirname(path)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
    }
  }

  path
}

#' Retry Function Execution
#'
#' @description
#' Retries a function execution with exponential backoff on failure.
#' Useful for network operations or file I/O that may temporarily fail.
#'
#' @param fn Function to execute
#' @param max_attempts Maximum number of attempts
#' @param initial_delay Initial delay in seconds
#' @param max_delay Maximum delay in seconds
#' @return Function result or NULL on failure
#' @export
retry_with_backoff <- function(
  fn,
  max_attempts = 3,
  initial_delay = 1,
  max_delay = 30
) {
  attempt <- 1
  delay <- initial_delay

  while (attempt <= max_attempts) {
    result <- tryCatch(
      {
        list(success = TRUE, value = fn())
      },
      error = function(e) {
        list(success = FALSE, error = e)
      }
    )

    if (result$success) {
      return(result$value)
    }

    if (attempt < max_attempts) {
      cli::cli_alert_warning(
        "Attempt {attempt}/{max_attempts} failed, retrying in {delay}s..."
      )
      Sys.sleep(delay)
      delay <- min(delay * 2, max_delay)
    }

    attempt <- attempt + 1
  }

  cli::cli_alert_danger("All {max_attempts} attempts failed")
  NULL
}

#' Validate Data Frame Structure
#'
#' @description
#' Validates that a data frame has required columns and types.
#'
#' @param df Data frame to validate
#' @param required_cols Character vector of required column names
#' @param col_types Named list of column types (optional)
#' @return TRUE if valid, otherwise stops with error
#' @export
validate_data_structure <- function(df, required_cols, col_types = NULL) {
  if (!is.data.frame(df)) {
    stop("Input must be a data frame")
  }

  # Check required columns
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Check column types if specified
  if (!is.null(col_types)) {
    for (col in names(col_types)) {
      if (col %in% names(df)) {
        expected_type <- col_types[[col]]
        actual_type <- class(df[[col]])[1]

        if (!inherits(df[[col]], expected_type)) {
          stop(sprintf(
            "Column '%s' must be of type %s, but is %s",
            col,
            expected_type,
            actual_type
          ))
        }
      }
    }
  }

  TRUE
}

#' Create Temporary Directory with Cleanup
#'
#' @description
#' Creates a temporary directory that is automatically cleaned up.
#'
#' @param prefix Directory prefix
#' @param cleanup Whether to cleanup on exit
#' @return Path to temporary directory
#' @export
create_temp_dir <- function(prefix = "neurotypr_", cleanup = TRUE) {
  temp_dir <- tempfile(pattern = prefix)
  dir.create(temp_dir, recursive = TRUE)

  if (cleanup) {
    # Register cleanup on exit
    reg.finalizer(
      environment(),
      function(e) {
        if (dir.exists(temp_dir)) {
          unlink(temp_dir, recursive = TRUE)
        }
      },
      onexit = TRUE
    )
  }

  temp_dir
}

#' Time Function Execution
#'
#' @description
#' Times the execution of a function and optionally prints the duration.
#'
#' @param expr Expression to time
#' @param message Optional message to display
#' @return Result of expression
#' @export
time_it <- function(expr, message = NULL) {
  cfg <- get_config()

  if (!cfg$get("verbose", FALSE)) {
    return(expr)
  }

  start_time <- Sys.time()
  result <- expr
  end_time <- Sys.time()

  duration <- end_time - start_time

  if (!is.null(message)) {
    cli::cli_alert_info(
      "{message} took {.field {format(duration, digits = 2)}}"
    )
  } else {
    cli::cli_alert_info(
      "Execution took {.field {format(duration, digits = 2)}}"
    )
  }

  invisible(result)
}

#' Safe Column Selection
#'
#' @description
#' Safely selects columns from a data frame, ignoring missing columns.
#'
#' @param df Data frame
#' @param cols Column names to select
#' @param warn Whether to warn about missing columns
#' @return Data frame with selected columns
#' @export
safe_select <- function(df, cols, warn = TRUE) {
  existing_cols <- intersect(cols, names(df))
  missing_cols <- setdiff(cols, names(df))

  if (length(missing_cols) > 0 && warn) {
    cli::cli_alert_warning(
      "Columns not found: {.field {missing_cols}}"
    )
  }

  df[existing_cols]
}

#' Batch Process with Error Collection
#'
#' @description
#' Processes items in batches, collecting errors instead of stopping.
#'
#' @param items Items to process
#' @param fn Function to apply
#' @param batch_size Size of each batch
#' @return List with results and errors
#' @export
batch_process <- function(items, fn, batch_size = 100) {
  n_items <- length(items)
  n_batches <- ceiling(n_items / batch_size)

  results <- list()
  errors <- list()

  cli::cli_progress_bar("Processing batches", total = n_batches)

  for (i in seq_len(n_batches)) {
    cli::cli_progress_update()

    start_idx <- (i - 1) * batch_size + 1
    end_idx <- min(i * batch_size, n_items)
    batch <- items[start_idx:end_idx]

    batch_results <- lapply(batch, function(item) {
      tryCatch(
        {
          list(success = TRUE, value = fn(item))
        },
        error = function(e) {
          list(success = FALSE, error = e, item = item)
        }
      )
    })

    # Separate successes and errors
    successes <- Filter(function(x) x$success, batch_results)
    failures <- Filter(function(x) !x$success, batch_results)

    if (length(successes) > 0) {
      results <- c(results, lapply(successes, function(x) x$value))
    }

    if (length(failures) > 0) {
      errors <- c(errors, failures)
    }
  }

  cli::cli_progress_done()

  if (length(errors) > 0) {
    cli::cli_alert_warning(
      "Completed with {length(errors)} error{?s}"
    )
  }

  list(results = results, errors = errors)
}
