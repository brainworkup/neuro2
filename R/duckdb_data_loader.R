#' Load neuropsychological data using DuckDB for efficient processing
#'
#' This function replaces the traditional load_data() with DuckDB-powered loading
#' that doesn't require loading entire CSVs into memory.
#'
#' @param file_path Path to directory containing CSV files
#' @param output_dir Output directory for processed files
#' @param return_data Whether to return data or write to files
#' @param use_duckdb Whether to use DuckDB (default: TRUE)
#'
#' @return List of processed data or NULL if writing to files
#' @export
load_data_duckdb <- function(
  file_path,
  output_dir = here::here("data"),
  return_data = FALSE,
  use_duckdb = TRUE
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

  # If not using DuckDB, fall back to traditional approach
  if (!use_duckdb) {
    return(load_data(file_path, output_dir, return_data))
  }

  message("[DuckDB] Loading data with DuckDB...")

  # Initialize DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Get CSV files
  files <- dir(file_path, pattern = "*.csv", full.names = TRUE)

  if (length(files) == 0) {
    stop("No CSV files found in the specified directory.")
  }

  # Register all CSV files as views in DuckDB
  for (file in files) {
    table_name <- tools::file_path_sans_ext(basename(file))
    query <- sprintf(
      "CREATE OR REPLACE VIEW %s AS SELECT *, '%s' as filename FROM read_csv_auto('%s', ignore_errors=true)",
      table_name,
      basename(file),
      file
    )
    DBI::dbExecute(con, query)
  }

  # Combine all data using SQL UNION
  table_names <- tools::file_path_sans_ext(basename(files))
  union_query <- paste(
    sprintf("SELECT * FROM %s", table_names),
    collapse = " UNION ALL "
  )

  # Create combined view
  DBI::dbExecute(
    con,
    sprintf("CREATE OR REPLACE VIEW neuropsych AS %s", union_query)
  )

  # Process data using SQL
  process_query <- "
    SELECT DISTINCT *,
      CASE 
        WHEN percentile IS NOT NULL THEN 
          CAST((percentile / 100.0) AS DOUBLE)
        ELSE NULL
      END as percentile_decimal,
      -- Calculate z-scores using DuckDB's built-in functions
      CASE 
        WHEN percentile IS NOT NULL AND percentile > 0 AND percentile < 100 THEN
          -- Using inverse normal CDF approximation
          CASE
            WHEN percentile = 50 THEN 0
            WHEN percentile < 50 THEN -ABS(SQRT(2) * SQRT(-2 * LN(percentile/100.0)))
            ELSE ABS(SQRT(2) * SQRT(-2 * LN(1 - percentile/100.0)))
          END
        ELSE NULL
      END as z
    FROM neuropsych
  "

  # Get processed data
  neuropsych <- DBI::dbGetQuery(con, process_query)

  # Convert character columns
  char_cols <- c("domain", "subdomain", "narrow", "pass", "verbal", "timed")
  for (col in char_cols) {
    if (col %in% names(neuropsych)) {
      neuropsych[[col]] <- as.character(neuropsych[[col]])
    }
  }

  # Define grouping variables
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

  # Process neurocognitive data with DuckDB
  neurocog_query <- sprintf(
    "
    SELECT *,
      AVG(z) OVER (PARTITION BY %s) as z_mean_domain,
      STDDEV(z) OVER (PARTITION BY %s) as z_sd_domain,
      AVG(z) OVER (PARTITION BY %s) as z_mean_subdomain,
      STDDEV(z) OVER (PARTITION BY %s) as z_sd_subdomain
    FROM neuropsych
    WHERE test_type = 'npsych_test'
  ",
    "domain",
    "domain",
    "subdomain",
    "subdomain"
  )

  neurocog <- DBI::dbGetQuery(con, neurocog_query)

  # Process neurobehavioral data
  neurobehav_query <- "
    SELECT * FROM neuropsych
    WHERE test_type = 'rating_scale'
  "
  neurobehav <- DBI::dbGetQuery(con, neurobehav_query)

  # Process validity data
  validity_query <- "
    SELECT * FROM neuropsych
    WHERE test_type IN ('performance_validity', 'symptom_validity')
  "
  validity <- DBI::dbGetQuery(con, validity_query)

  # Add missing z-statistics using R (if needed)
  neurocog <- calculate_z_stats(neurocog, neurocog_groups)
  neurobehav <- calculate_z_stats(neurobehav, neurobehav_groups)
  validity <- calculate_z_stats(validity, validity_groups)

  # Prepare output
  result_list <- list(
    neuropsych = neuropsych,
    neurocog = neurocog,
    neurobehav = neurobehav,
    validity = validity
  )

  # Write files if not returning data
  if (!return_data) {
    file_paths <- list(
      neuropsych = file.path(output_dir, "neuropsych.csv"),
      neurocog = file.path(output_dir, "neurocog.csv"),
      neurobehav = file.path(output_dir, "neurobehav.csv"),
      validity = file.path(output_dir, "validity.csv")
    )

    # Write files
    for (name in names(file_paths)) {
      readr::write_excel_csv(result_list[[name]], file_paths[[name]])
    }

    message("[OK] Successfully wrote files to: ", output_dir)
    message("[DuckDB] DuckDB processing complete!")

    return(invisible(NULL))
  }

  return(result_list)
}

#' Query neuropsychological data using DuckDB
#'
#' Provides a simple interface for querying neuropsych data with SQL
#'
#' @param query SQL query string
#' @param data_dir Directory containing data files
#' @param ... Additional parameters passed to dbGetQuery
#'
#' @return Query results as a data frame
#' @export
query_neuropsych <- function(query, data_dir = "data", ...) {
  # Initialize DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Register data files
  for (file in c("neurocog.csv", "neurobehav.csv", "validity.csv")) {
    if (file.exists(file.path(data_dir, file))) {
      table_name <- tools::file_path_sans_ext(file)
      DBI::dbExecute(
        con,
        sprintf(
          "CREATE OR REPLACE VIEW %s AS SELECT * FROM read_csv_auto('%s')",
          table_name,
          file.path(data_dir, file)
        )
      )
    }
  }

  # Execute query
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
      SELECT test_name, scale, score, percentile 
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

#' Calculate z-statistics helper function
#'
#' @param data Data frame to process
#' @param group_vars Grouping variables
#'
#' @return Data frame with z-statistics
calculate_z_stats <- function(data, group_vars) {
  # This function remains the same as the original
  # but could be optimized with data.table or DuckDB if needed

  for (var in group_vars) {
    if (var %in% names(data)) {
      z_mean_col <- paste0("z_mean_", var)
      z_sd_col <- paste0("z_sd_", var)

      if (!z_mean_col %in% names(data)) {
        data <- data |>
          dplyr::group_by(!!rlang::sym(var)) |>
          dplyr::mutate(
            !!z_mean_col := mean(z, na.rm = TRUE),
            !!z_sd_col := sd(z, na.rm = TRUE)
          ) |>
          dplyr::ungroup()
      }
    }
  }

  return(data)
}
