#' Load neuropsychological data using DuckDB for efficient processing
#'
#' This function replaces the traditional load_data() with DuckDB-powered loading
#' that doesn't require loading entire CSVs into memory.
#'
#' @param file_path Path to directory containing CSV files
#' @param output_dir Output directory for processed files
#' @param return_data Whether to return data or write to files
#' @param use_duckdb Whether to use DuckDB (default: TRUE)
#' @param output_format Output format: "csv", "parquet", "arrow", or "all" (default: "csv")
#' @param patient Patient name (if NULL, will try to read from _variables.yml)
#'
#' @return List of processed data or NULL if writing to files
#' @export
load_data_duckdb <- function(
  file_path,
  output_dir = here::here("data"),
  return_data = FALSE,
  use_duckdb = TRUE,
  output_format = "csv",
  patient = NULL
) {
  # Input validation
  if (missing(file_path)) {
    stop("Patient/file path must be specified.")
  }
  if (!dir.exists(file_path)) {
    stop("Specified file_path does not exist: ", file_path)
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Validate output_format
  valid_formats <- c("csv", "parquet", "arrow", "all")
  if (!output_format %in% valid_formats) {
    stop(
      "output_format must be one of: ",
      paste(valid_formats, collapse = ", ")
    )
  }

  # Connect to DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Get CSV files
  files <- dir(file_path, pattern = "*.csv", full.names = TRUE)

  if (length(files) == 0) {
    stop("No CSV files found in: ", file_path)
  }

  # Create a union of all CSV files with filename column
  # First, read each CSV to determine the common columns
  all_data <- list()

  for (i in seq_along(files)) {
    file <- files[i]
    # Read CSV using DuckDB
    query <- sprintf("SELECT * FROM read_csv_auto('%s')", file)
    df <- DBI::dbGetQuery(con, query)
    df$filename <- basename(file)

    # Ensure numeric columns are properly typed
    numeric_cols <- c(
      "raw_score",
      "score",
      "percentile",
      "ci_95",
      "z_score",
      "scaled_score",
      "t_score",
      "standard_score",
      "base_rate"
    )

    for (col in numeric_cols) {
      if (col %in% names(df)) {
        df[[col]] <- as.numeric(df[[col]])
      }
    }

    all_data[[i]] <- df
  }

  # Combine all dataframes
  neuropsych_df <- dplyr::bind_rows(all_data) |> dplyr::distinct()

  # Create a DuckDB table from the combined dataframe
  duckdb::duckdb_register(con, "neuropsych", neuropsych_df)

  # Create a persistent table
  DBI::dbExecute(
    con,
    "CREATE OR REPLACE TABLE neuropsych AS SELECT * FROM neuropsych"
  )

  # Add type conversions (z-score will be calculated in R)
  DBI::dbExecute(
    con,
    "
    CREATE OR REPLACE TABLE neuropsych_processed AS
    SELECT *,
      CAST(domain AS VARCHAR) as domain,
      CAST(subdomain AS VARCHAR) as subdomain,
      CAST(narrow AS VARCHAR) as narrow,
      CAST(pass AS VARCHAR) as pass,
      CAST(verbal AS VARCHAR) as verbal,
      CAST(timed AS VARCHAR) as timed
    FROM neuropsych
  "
  )

  # Process neurocognitive data
  DBI::dbExecute(
    con,
    "
    CREATE OR REPLACE TABLE neurocog_final AS
    SELECT * FROM neuropsych_processed
    WHERE test_type = 'npsych_test'
  "
  )

  # Process neurobehavioral data
  DBI::dbExecute(
    con,
    "
    CREATE OR REPLACE TABLE neurobehav_final AS
    SELECT * FROM neuropsych_processed
    WHERE test_type = 'rating_scale'
  "
  )

  # Process validity data
  DBI::dbExecute(
    con,
    "
    CREATE OR REPLACE TABLE validity_final AS
    SELECT * FROM neuropsych_processed
    WHERE test_type IN ('performance_validity', 'symptom_validity')
  "
  )

  # Fetch results for the result_list
  neuropsych <- DBI::dbGetQuery(
    con,
    "SELECT DISTINCT * FROM neuropsych_processed"
  )
  neurocog <- DBI::dbGetQuery(con, "SELECT * FROM neurocog_final")
  neurobehav <- DBI::dbGetQuery(con, "SELECT * FROM neurobehav_final")
  validity <- DBI::dbGetQuery(con, "SELECT * FROM validity_final")

  # Calculate z-scores in R (more accurate than SQL approximation)
  if ("percentile" %in% names(neuropsych)) {
    neuropsych$z <- ifelse(
      !is.na(neuropsych$percentile),
      qnorm(neuropsych$percentile / 100),
      NA_real_
    )
    neurocog$z <- ifelse(
      !is.na(neurocog$percentile),
      qnorm(neurocog$percentile / 100),
      NA_real_
    )
    neurobehav$z <- ifelse(
      !is.na(neurobehav$percentile),
      qnorm(neurobehav$percentile / 100),
      NA_real_
    )
    validity$z <- ifelse(
      !is.na(validity$percentile),
      qnorm(validity$percentile / 100),
      NA_real_
    )
  }

  # Calculate z-statistics using the helper function
  neurocog_groups <- c(
    "domain",
    "subdomain",
    "narrow",
    "pass",
    "verbal",
    "timed"
  )
  neurobehav_groups <- c("domain", "subdomain", "narrow")
  validity_groups <- c("domain", "subdomain", "narrow")

  neurocog <- calculate_z_stats(neurocog, neurocog_groups)
  neurobehav <- calculate_z_stats(neurobehav, neurobehav_groups)
  validity <- calculate_z_stats(validity, validity_groups)

  # Prepare the list of result tables
  result_list <- list(
    neuropsych = neuropsych,
    neurocog = neurocog,
    neurobehav = neurobehav,
    validity = validity
  )

  # Write files if not returning data
  if (!return_data) {
    dataset_names <- names(result_list)

    # Parquet
    if (output_format %in% c("parquet", "all")) {
      message("[DuckDB] Writing Parquet files...")
      for (name in dataset_names) {
        path <- file.path(output_dir, paste0(name, ".parquet"))
        query <- sprintf(
          "COPY (SELECT * FROM %s_final) TO '%s' (FORMAT PARQUET)",
          name,
          path
        )
        tryCatch(
          {
            DBI::dbExecute(con, query)
            message("[OK] Wrote: ", basename(path))
          },
          error = function(e) {
            warning(
              "Parquet write failed for ",
              basename(path),
              ". Falling back to arrow: ",
              e$message
            )
            arrow::write_parquet(result_list[[name]], path)
            message("[OK] Wrote (fallback): ", basename(path))
          }
        )
      }
    }

    # Arrow (Feather)
    if (output_format %in% c("arrow", "all")) {
      message("[Arrow] Writing Feather files...")
      for (name in dataset_names) {
        path <- file.path(output_dir, paste0(name, ".feather"))
        tryCatch(
          {
            arrow::write_feather(result_list[[name]], path)
            message("[OK] Wrote: ", basename(path))
          },
          error = function(e) {
            stop(
              "Failed to write Feather file ",
              basename(path),
              ": ",
              e$message
            )
          }
        )
      }
    }

    # CSV
    if (output_format %in% c("csv", "all")) {
      message("[DuckDB] Writing CSV files...")
      for (name in dataset_names) {
        path <- file.path(output_dir, paste0(name, ".csv"))
        readr::write_excel_csv(result_list[[name]], path)
        message("[OK] Wrote: ", basename(path))
      }
    }

    message(
      "[OK] Successfully wrote ",
      output_format,
      " files to: ",
      output_dir
    )
    message("[DuckDB] Processing complete!")
    return(invisible(NULL))
  }

  # If returning data
  message("[DuckDB] Processing complete!")
  return(result_list)
}

#' Query neuropsychological data using DuckDB
#'
#' Provides a simple interface for querying neuropsych data with SQL.
#'
#' @param query SQL query string
#' @param data_dir Directory containing data files (.csv, .parquet, .feather)
#' @param ... Additional parameters passed to dbGetQuery
#'
#' @return Query results as a data frame
#' @export
query_neuropsych <- function(query, data_dir = "data", ...) {
  # Connect to DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Discover files
  files <- list.files(
    data_dir,
    pattern = "\\.(csv|parquet|feather)$",
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(files) == 0) {
    stop("No .csv, .parquet or .feather files found in: ", data_dir)
  }

  # Register each as a view
  for (f in files) {
    ext <- tolower(tools::file_ext(f))
    table_name <- tools::file_path_sans_ext(basename(f))

    if (ext == "feather") {
      # For feather files, read with arrow and register as a table
      tryCatch(
        {
          feather_data <- arrow::read_feather(f)
          duckdb::duckdb_register(con, table_name, feather_data)
        },
        error = function(e) {
          warning("Failed to read feather file ", basename(f), ": ", e$message)
        }
      )
    } else {
      # For CSV and Parquet, use DuckDB's native readers
      reader_sql <- switch(
        ext,
        csv = sprintf("read_csv_auto('%s')", f),
        parquet = sprintf("read_parquet('%s')", f),
        stop("Unsupported file type: ", ext)
      )

      DBI::dbExecute(
        con,
        sprintf(
          "CREATE OR REPLACE VIEW %s AS SELECT * FROM %s",
          DBI::dbQuoteIdentifier(con, table_name),
          reader_sql
        )
      )
    }
  }

  # Run user’s query
  result <- DBI::dbGetQuery(con, query, ...)
  return(result)
}

#' Example DuckDB queries for neuropsychological data
#'
#' @return List of example queries
#' @export
get_example_queries <- function() {
  queries <- list(
    # Find all IQ scores
    iq_scores = "
      SELECT test, test_name, scale, score, percentile, range
      FROM neurocog
      WHERE domain = 'General Cognitive Ability'
        AND scale LIKE '%IQ%'
      ORDER BY percentile DESC
    ",

    # Cross-domain analysis
    cross_domain = "
      SELECT
        nc.domain as cognitive_domain,
        nc.percentile as cognitive_percentile,
        nb.domain as behavioral_domain,
        nb.percentile as behavioral_percentile
      FROM neurocog nc
      INNER JOIN neurobehav nb
        ON nc.test = nb.test
      WHERE nc.percentile < 25
        AND nb.percentile > 75
    ",

    # Domain summary with performance categories
    domain_summary = "
      SELECT
        domain,
        COUNT(*) as n_tests,
        AVG(percentile) as mean_percentile,
        CASE
          WHEN AVG(percentile) >= 75 THEN 'Above Average'
          WHEN AVG(percentile) >= 25 THEN 'Average'
          ELSE 'Below Average'
        END as performance_category
      FROM neurocog
      GROUP BY domain
      ORDER BY mean_percentile DESC
    ",

    # Validity check
    validity_check = "
      SELECT
        test_name,
        scale,
        score,
        CASE
          WHEN score < 45 THEN 'Invalid'
          WHEN score < 50 THEN 'Questionable'
          ELSE 'Valid'
        END as validity_status
      FROM validity
      WHERE domain = 'Performance Validity'
    ",

    # ADHD profile
    adhd_profile = "
      SELECT
        scale,
        percentile,
        CASE
          WHEN percentile >= 93 THEN 'Clinically Significant'
          WHEN percentile >= 85 THEN 'At Risk'
          ELSE 'Normal Range'
        END as clinical_significance
      FROM neurobehav
      WHERE domain = 'ADHD'
      ORDER BY percentile DESC
    "
  )

  return(queries)
}

#' Run example DuckDB query
#'
#' @param query_name Name of the example query
#' @param data_dir Directory containing data files
#'
#' @return Query results
#' @export
run_example_query <- function(query_name, data_dir = "data") {
  queries <- get_example_queries()

  if (!query_name %in% names(queries)) {
    stop(
      "Unknown query. Available queries: ",
      paste(names(queries), collapse = ", ")
    )
  }

  message("[DuckDB] Running query: ", query_name)
  result <- query_neuropsych(queries[[query_name]], data_dir)

  return(result)
}

#' Helper function to calculate z-statistics
#'
#' @param data Data frame containing neuropsychological test data
#' @param groups Character vector of grouping variables
#' @return Data frame with added z-statistics
calculate_z_stats <- function(data, groups) {
  # Filter out NA group variables to avoid unnecessary computations
  valid_vars <- groups[groups %in% names(data)]

  if (length(valid_vars) == 0) {
    return(data)
  }

  # Calculate statistics for each grouping variable
  for (var in valid_vars) {
    # Skip if variable is all NA
    if (all(is.na(data[[var]]))) {
      next
    }

    data <- data |>
      dplyr::group_by(dplyr::across(dplyr::all_of(var)), .add = TRUE) |>
      dplyr::mutate(
        !!paste0("z_mean_", var) := mean(z, na.rm = TRUE),
        !!paste0("z_sd_", var) := sd(z, na.rm = TRUE)
      ) |>
      dplyr::ungroup()
  }

  return(data)
}
