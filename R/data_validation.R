#' Validate and Load Assessment Data
#'
#' @description
#' Validates that required data files exist and loads them with proper formatting.
#' This is the missing function referenced in the analysis scripts.
#'
#' @param data_dir Directory containing data files
#' @param config Configuration list with data file specifications
#' @param required_files Character vector of required file names
#' @param verbose Whether to show detailed messages
#'
#' @return List of loaded data frames
#'
#' @export
validate_and_load_data <- function(
  data_dir = "data",
  config = NULL,
  required_files = c("neurocog.csv", "neurobehav.csv", "validity.csv"),
  verbose = TRUE
) {
  if (verbose) {
    message("🔍 Validating data files in: ", data_dir)
  }

  # Load config if not provided
  if (is.null(config)) {
    config_path <- "config.yml"
    if (file.exists(config_path)) {
      config <- yaml::read_yaml(config_path)
    } else {
      # Default config
      config <- list(
        data = list(
          files = list(
            neurocog = "neurocog.csv",
            neurobehav = "neurobehav.csv",
            validity = "validity.csv"
          )
        )
      )
    }
  }

  # Check if data directory exists
  if (!dir.exists(data_dir)) {
    stop("Data directory not found: ", data_dir)
  }

  # Validate file existence
  data_files <- list()
  validation_results <- list()

  # Check each required file
  for (file_type in names(config$data$files)) {
    file_name <- config$data$files[[file_type]]
    file_path <- file.path(data_dir, file_name)

    validation_results[[file_type]] <- list(
      file_name = file_name,
      file_path = file_path,
      exists = file.exists(file_path),
      required = file_name %in% required_files
    )

    if (file.exists(file_path)) {
      if (verbose) {
        message("  ✅ Found: ", file_name)
      }

      # Load the data
      data_files[[file_type]] <- .load_data_file(file_path, verbose = verbose)
    } else if (file_name %in% required_files) {
      stop("Required data file not found: ", file_path)
    } else {
      if (verbose) {
        message("  ⚠️  Optional file not found: ", file_name)
      }
    }
  }

  # Validate data content
  for (file_type in names(data_files)) {
    data <- data_files[[file_type]]
    validation <- .validate_data_content(data, file_type, verbose = verbose)
    validation_results[[file_type]]$content_valid <- validation$valid
    validation_results[[file_type]]$content_issues <- validation$issues
  }

  # Summary
  if (verbose) {
    valid_files <- sum(sapply(validation_results, function(x) {
      x$exists && x$content_valid
    }))
    total_files <- length(validation_results)
    message(
      "📊 Data validation complete: ",
      valid_files,
      "/",
      total_files,
      " files ready"
    )
  }

  # Attach validation results as attribute
  attr(data_files, "validation") <- validation_results

  return(data_files)
}

#' Load Data File with Format Detection
#'
#' @description
#' Loads a data file, detecting format (CSV, Parquet, Feather) automatically.
#'
#' @param file_path Path to the data file
#' @param verbose Whether to show loading messages
#'
#' @return Data frame
.load_data_file <- function(file_path, verbose = TRUE) {
  file_ext <- tolower(tools::file_ext(file_path))

  if (verbose) {
    message("    📄 Loading ", basename(file_path), " (", file_ext, ")")
  }

  data <- tryCatch(
    {
      switch(
        file_ext,
        "csv" = readr::read_csv(file_path, show_col_types = FALSE),
        "parquet" = {
          if (requireNamespace("arrow", quietly = TRUE)) {
            arrow::read_parquet(file_path)
          } else {
            stop("arrow package required for Parquet files")
          }
        },
        "feather" = {
          if (requireNamespace("arrow", quietly = TRUE)) {
            arrow::read_feather(file_path)
          } else {
            stop("arrow package required for Feather files")
          }
        },
        stop("Unsupported file format: ", file_ext)
      )
    },
    error = function(e) {
      stop("Failed to load ", file_path, ": ", e$message)
    }
  )

  if (verbose) {
    message("      📏 ", nrow(data), " rows, ", ncol(data), " columns")
  }

  return(data)
}

#' Validate Data Content
#'
#' @description
#' Validates that loaded data has the expected structure and content.
#'
#' @param data Data frame to validate
#' @param data_type Type of data ("neurocog", "neurobehav", "validity")
#' @param verbose Whether to show validation messages
#'
#' @return List with validation results
.validate_data_content <- function(data, data_type, verbose = TRUE) {
  validation <- list(valid = TRUE, issues = character())

  # Required columns for each data type
  required_columns <- list(
    neurocog = c("test_name", "scale", "score", "percentile", "domain"),
    neurobehav = c("test_name", "scale", "score", "percentile", "domain"),
    validity = c("test_name", "scale", "score", "domain")
  )

  expected_cols <- required_columns[[data_type]]
  if (is.null(expected_cols)) {
    validation$issues <- c(
      validation$issues,
      paste("Unknown data type:", data_type)
    )
    validation$valid <- FALSE
    return(validation)
  }

  # Check for required columns
  missing_cols <- setdiff(expected_cols, names(data))
  if (length(missing_cols) > 0) {
    validation$issues <- c(
      validation$issues,
      paste("Missing required columns:", paste(missing_cols, collapse = ", "))
    )
    validation$valid <- FALSE
  }

  # Check for empty data
  if (nrow(data) == 0) {
    validation$issues <- c(validation$issues, "Data file is empty")
    validation$valid <- FALSE
  }

  # Check for domains if domain column exists
  if ("domain" %in% names(data)) {
    domains <- unique(data$domain[!is.na(data$domain)])
    if (length(domains) == 0) {
      validation$issues <- c(validation$issues, "No valid domains found")
      validation$valid <- FALSE
    } else if (verbose) {
      message("      🧠 Found domains: ", paste(domains, collapse = ", "))
    }
  }

  # Check for scores if score columns exist
  score_cols <- intersect(c("score", "percentile"), names(data))
  if (length(score_cols) > 0) {
    for (col in score_cols) {
      valid_scores <- sum(!is.na(data[[col]]))
      if (valid_scores == 0) {
        validation$issues <- c(
          validation$issues,
          paste("No valid scores in", col)
        )
        validation$valid <- FALSE
      } else if (verbose) {
        message("      📊 ", valid_scores, " valid scores in ", col)
      }
    }
  }

  if (verbose && validation$valid) {
    message("      ✅ Data validation passed")
  } else if (verbose) {
    message(
      "      ❌ Data validation failed: ",
      paste(validation$issues, collapse = "; ")
    )
  }

  return(validation)
}

#' Get Available Domains from Data
#'
#' @description
#' Extracts unique domains from loaded data files.
#'
#' @param data_files List of loaded data frames
#' @param verbose Whether to show messages
#'
#' @return Character vector of available domains
.get_available_domains <- function(data_files, verbose = TRUE) {
  all_domains <- character()

  for (file_type in names(data_files)) {
    data <- data_files[[file_type]]
    if ("domain" %in% names(data)) {
      domains <- unique(data$domain[!is.na(data$domain)])
      all_domains <- c(all_domains, domains)

      if (verbose && length(domains) > 0) {
        message("📂 ", file_type, " domains: ", paste(domains, collapse = ", "))
      }
    }
  }

  unique_domains <- unique(all_domains)

  if (verbose) {
    message("🧠 Total unique domains: ", length(unique_domains))
  }

  return(unique_domains)
}
