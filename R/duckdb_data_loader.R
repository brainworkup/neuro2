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
  use_duckdb = TRUE,
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

  # Get patient name from _variables.yml if not provided
  if (is.null(patient)) {
    variables_file <- here::here("_variables.yml")
    if (file.exists(variables_file)) {
      variables <- yaml::read_yaml(variables_file)
      patient <- variables$patient
    } else {
      patient <- "Unknown"
      warning("_variables.yml not found, using 'Unknown' as patient name")
    }
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
  table_names <- character()
  for (file in files) {
    table_name <- tools::file_path_sans_ext(basename(file))
    table_names <- c(table_names, table_name)
    query <- sprintf(
      "CREATE OR REPLACE VIEW %s AS SELECT *, '%s' as filename FROM read_csv_auto('%s', ignore_errors=true)",
      table_name,
      basename(file),
      file
    )
    DBI::dbExecute(con, query)
  }

  # Get all unique column names across all tables
  all_columns <- character()
  for (table_name in table_names) {
    columns_query <- sprintf("SELECT * FROM %s LIMIT 0", table_name)
    cols <- names(DBI::dbGetQuery(con, columns_query))
    all_columns <- unique(c(all_columns, cols))
  }

  # Remove 'filename' from the list as we'll add it separately
  # Keep index in all_columns so we can handle it properly
  all_columns <- setdiff(all_columns, "filename")

  # Build UNION query with explicit column ordering
  union_parts <- character()
  for (table_name in table_names) {
    # Get columns present in this table
    columns_query <- sprintf("SELECT * FROM %s LIMIT 0", table_name)
    table_cols <- names(DBI::dbGetQuery(con, columns_query))

    # Build SELECT clause with all columns in consistent order
    select_parts <- character()

    # Check if this table already has an index column
    has_index <- "index" %in% table_cols

    # If no index column exists, add patient name as index first
    if (!has_index && "index" %in% all_columns) {
      select_parts <- c(select_parts, sprintf("'%s' AS index", patient))
    }

    for (col in all_columns) {
      if (col %in% table_cols) {
        select_parts <- c(select_parts, col)
      } else if (col != "index") {
        # Add NULL for missing columns (except index which we handle separately)
        select_parts <- c(select_parts, sprintf("NULL AS %s", col))
      }
    }

    # Add filename column at the end
    select_parts <- c(select_parts, "filename")

    # Create the SELECT statement for this table
    table_query <- sprintf(
      "SELECT %s FROM %s",
      paste(select_parts, collapse = ", "),
      table_name
    )
    union_parts <- c(union_parts, table_query)
  }

  # Combine all parts with UNION ALL
  union_query <- paste(union_parts, collapse = " UNION ALL ")

  # Create combined view
  DBI::dbExecute(
    con,
    sprintf("CREATE OR REPLACE VIEW neuropsych AS %s", union_query)
  )

  # Get column names from the combined view to build explicit select list
  view_columns <- names(DBI::dbGetQuery(
    con,
    "SELECT * FROM neuropsych LIMIT 0"
  ))

  # Build the select list with all columns - we'll filter in the final output
  select_list <- paste(view_columns, collapse = ", ")

  # Process data using SQL (excluding description and true_score)
  # Convert percentile 0 to 0.5 and use TRY_CAST to handle malformed CSV data
  process_query <- sprintf(
    "
    SELECT DISTINCT %s,
      CASE
        WHEN TRY_CAST(percentile AS DOUBLE) = 0 THEN 0.005  -- Convert 0 to 0.5 percentile (0.5/100)
        WHEN TRY_CAST(percentile AS DOUBLE) IS NOT NULL THEN
          TRY_CAST(percentile AS DOUBLE) / 100.0
        ELSE NULL
      END as percentile_decimal,
      -- Calculate z-scores using DuckDB's built-in functions
      CASE
        WHEN TRY_CAST(percentile AS DOUBLE) = 0 THEN
          -- z-score for 0.5th percentile
          -ABS(SQRT(2) * SQRT(-2 * LN(0.005)))
        WHEN TRY_CAST(percentile AS DOUBLE) IS NOT NULL
          AND TRY_CAST(percentile AS DOUBLE) > 0
          AND TRY_CAST(percentile AS DOUBLE) < 100 THEN
          -- Using inverse normal CDF approximation
          CASE
            WHEN TRY_CAST(percentile AS DOUBLE) = 50 THEN 0
            WHEN TRY_CAST(percentile AS DOUBLE) < 50 THEN
              -ABS(SQRT(2) * SQRT(-2 * LN(TRY_CAST(percentile AS DOUBLE)/100.0)))
            ELSE
              ABS(SQRT(2) * SQRT(-2 * LN(1 - TRY_CAST(percentile AS DOUBLE)/100.0)))
          END
        ELSE NULL
      END as z
    FROM neuropsych
  ",
    select_list
  )

  # Create a processed view with calculated z-scores
  DBI::dbExecute(
    con,
    sprintf("CREATE OR REPLACE VIEW neuropsych_processed AS %s", process_query)
  )

  # Get processed data
  neuropsych <- DBI::dbGetQuery(con, "SELECT * FROM neuropsych_processed")

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
      STDDEV(z) OVER (PARTITION BY %s) as z_sd_subdomain,
      AVG(z) OVER (PARTITION BY %s) as z_mean_narrow,
      STDDEV(z) OVER (PARTITION BY %s) as z_sd_narrow
    FROM neuropsych_processed
    WHERE test_type = 'npsych_test'
  ",
    "domain",
    "domain",
    "subdomain",
    "subdomain",
    "narrow",
    "narrow"
  )

  neurocog <- DBI::dbGetQuery(con, neurocog_query)

  # Process neurobehavioral data
  neurobehav_query <- "
    SELECT * FROM neuropsych_processed
    WHERE test_type = 'rating_scale'
  "
  neurobehav <- DBI::dbGetQuery(con, neurobehav_query)

  # Process validity data
  validity_query <- "
    SELECT * FROM neuropsych_processed
    WHERE test_type IN ('performance_validity', 'symptom_validity')
  "
  validity <- DBI::dbGetQuery(con, validity_query)

  # Add missing z-statistics using R (if needed)
  neurocog <- calculate_z_stats(neurocog, neurocog_groups)
  neurobehav <- calculate_z_stats(neurobehav, neurobehav_groups)
  validity <- calculate_z_stats(validity, validity_groups)

  # Remove description and true_score columns from all result dataframes
  cols_to_remove <- c("description", "true_score")

  for (col in cols_to_remove) {
    if (col %in% names(neuropsych)) {
      neuropsych[[col]] <- NULL
    }
    if (col %in% names(neurocog)) {
      neurocog[[col]] <- NULL
    }
    if (col %in% names(neurobehav)) {
      neurobehav[[col]] <- NULL
    }
    if (col %in% names(validity)) {
      validity[[col]] <- NULL
    }
  }

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
