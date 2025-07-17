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

  # [ … DuckDB setup, UNION and processing logic unchanged … ]

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

    reader_sql <- switch(
      ext,
      csv = sprintf("read_csv_auto('%s')", f),
      parquet = sprintf("read_parquet('%s')", f),
      feather = sprintf("read_feather('%s')", f),
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
  # Implementation of z-statistics calculation
  # This would need to be implemented based on your existing logic
  # For now, returning data as-is
  return(data)
}
