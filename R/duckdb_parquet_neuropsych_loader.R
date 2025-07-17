#' Load neuropsychological data using DuckDB for efficient processing
#'
#' This function replaces the traditional load_data() with DuckDB-powered loading
#' that doesn't require loading entire CSVs into memory.
#'
#' @param file_path Path to directory containing CSV files
#' @param output_dir Output directory for processed files
#' @param return_data Whether to return data or write to files
#' @param use_duckdb Whether to use DuckDB (default: TRUE)
#' @param output_format Output format: "csv", "parquet", or "both" (default: "csv")
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
  valid_formats <- c("csv", "parquet", "both")
  if (!output_format %in% valid_formats) {
    stop("output_format must be one of: ", paste(valid_formats, collapse = ", "))
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
  # if (!use_duckdb) {
  #   return(load_data(file_path, output_dir, return_data))
  # }

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

  # Create individual dataset views for file output
  DBI::dbExecute(con, "CREATE OR REPLACE VIEW neuropsych_final AS SELECT * FROM neuropsych_processed")

  # Process neurocognitive data with DuckDB
  neurocog_query <- sprintf(
    "
    CREATE OR REPLACE VIEW neurocog_final AS
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
  DBI::dbExecute(con, neurocog_query)

  # Process neurobehavioral data
  DBI::dbExecute(con, "
    CREATE OR REPLACE VIEW neurobehav_final AS
    SELECT * FROM neuropsych_processed
    WHERE test_type = 'rating_scale'
  ")

  # Process validity data
  DBI::dbExecute(con, "
    CREATE OR REPLACE VIEW validity_final AS
    SELECT * FROM neuropsych_processed
    WHERE test_type IN ('performance_validity', 'symptom_validity')
  ")

  # Get processed data for R processing and return
  neuropsych <- DBI::dbGetQuery(con, "SELECT * FROM neuropsych_final")
  neurocog <- DBI::dbGetQuery(con, "SELECT * FROM neurocog_final")
  neurobehav <- DBI::dbGetQuery(con, "SELECT * FROM neurobehav_final")
  validity <- DBI::dbGetQuery(con, "SELECT * FROM validity_final")

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
    # Define dataset names for DuckDB views
    dataset_names <- c("neuropsych", "neurocog", "neurobehav", "validity")

    # Write Parquet files using DuckDB
    if (output_format %in% c("parquet", "both")) {
      message("[DuckDB] Writing Parquet files...")

      for (name in dataset_names) {
        parquet_path <- file.path(output_dir, paste0(name, ".parquet"))

        # Use DuckDB to write directly to Parquet
        query <- sprintf(
          "COPY (SELECT * FROM %s_final) TO '%s' (FORMAT PARQUET)",
          name,
          parquet_path
        )

        tryCatch({
          DBI::dbExecute(con, query)
          message("[OK] Wrote: ", basename(parquet_path))
        }, error = function(e) {
          warning("Failed to write ", parquet_path, ": ", e$message)
          # Fallback to R method
          arrow::write_parquet(result_list[[name]], parquet_path)
          message("[OK] Wrote (fallback): ", basename(parquet_path))
        })
      }
    }

    # Write CSV files using R
    if (output_format %in% c("csv", "both")) {
      message("[DuckDB] Writing CSV files...")

      file_paths <- list(
        neuropsych = file.path(output_dir, "neuropsych.csv"),
        neurocog = file.path(output_dir, "neurocog.csv"),
        neurobehav = file.path(output_dir, "neurobehav.csv"),
        validity = file.path(output_dir, "validity.csv")
      )

      # Write files
      for (name in names(file_paths)) {
        readr::write_excel_csv(result_list[[name]], file_paths[[name]])
        message("[OK] Wrote: ", basename(file_paths[[name]]))
      }
    }

    message("[OK] Successfully wrote ", output_format, " files to: ", output_dir)
    message("[DuckDB] DuckDB processing complete!")

    return(invisible(NULL))
  }

  message("[DuckDB] DuckDB processing complete!")
  return(result_list)
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
