#' DuckDBProcessorR6 Class
#'
#' An R6 class that provides efficient data processing using DuckDB for neuropsychological data.
#' This class enables SQL-based querying without loading entire datasets into memory.
#'
#' @field con DuckDB connection object
#' @field db_path Path to the DuckDB database file (default: in-memory)
#' @field tables List of registered tables in the database
#' @field data_paths List of paths to data files
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new DuckDBProcessorR6 object with database connection.}
#'   \item{connect}{Create or reconnect to the DuckDB database.}
#'   \item{disconnect}{Close the database connection.}
#'   \item{register_csv}{Register a CSV file as a virtual table.}
#'   \item{register_all_csvs}{Register all CSV files in a directory.}
#'   \item{query}{Execute a SQL query and return results.}
#'   \item{query_lazy}{Create a lazy reference to a table for dplyr operations.}
#'   \item{process_domain}{Process a specific domain using SQL.}
#'   \item{calculate_z_stats}{Calculate z-score statistics using SQL.}
#'   \item{export_to_r6}{Export query results to standard R6 processors.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery dbExecute
#' @importFrom duckdb duckdb
#' @importFrom dplyr tbl collect
#' @export
DuckDBProcessorR6 <- R6::R6Class(
  classname = "DuckDBProcessorR6",
  public = list(
    con = NULL,
    db_path = NULL,
    tables = NULL,
    data_paths = NULL,

    #' @description
    #' Initialize a new DuckDBProcessorR6 object with database connection.
    #'
    #' @param db_path Path to DuckDB database file (default: ":memory:" for in-memory)
    #' @param data_dir Directory containing CSV files (default: "data")
    #' @param auto_register Whether to automatically register all CSVs (default: TRUE)
    #'
    #' @return A new DuckDBProcessorR6 object
    initialize = function(
      db_path = ":memory:",
      data_dir = "data",
      auto_register = TRUE
    ) {
      self$db_path <- db_path
      self$tables <- list()
      self$data_paths <- list(
        neurocog = file.path(data_dir, "neurocog.csv"),
        neurobehav = file.path(data_dir, "neurobehav.csv"),
        validity = file.path(data_dir, "validity.csv"),
        neuropsych = file.path(data_dir, "neuropsych.csv")
      )

      # Connect to database
      self$connect()

      # Auto-register CSV files if requested
      if (auto_register && dir.exists(data_dir)) {
        self$register_all_csvs(data_dir)
      }
    },

    #' @description
    #' Create or reconnect to the DuckDB database.
    #'
    #' @return Invisibly returns self for method chaining.
    connect = function() {
      if (!is.null(self$con)) {
        self$disconnect()
      }

      self$con <- DBI::dbConnect(duckdb::duckdb(), self$db_path)

      # Set up useful extensions
      DBI::dbExecute(self$con, "INSTALL 'json'")
      DBI::dbExecute(self$con, "LOAD 'json'")

      invisible(self)
    },

    #' @description
    #' Close the database connection.
    #'
    #' @return Invisibly returns self for method chaining.
    disconnect = function() {
      if (!is.null(self$con)) {
        DBI::dbDisconnect(self$con, shutdown = TRUE)
        self$con <- NULL
      }
      invisible(self)
    },

    #' @description
    #' Register a CSV file as a virtual table in DuckDB.
    #'
    #' @param file_path Path to the CSV file
    #' @param table_name Name for the table (default: based on filename)
    #' @param options Additional CSV reading options
    #'
    #' @return Invisibly returns self for method chaining.
    register_csv = function(file_path, table_name = NULL, options = NULL) {
      if (!file.exists(file_path)) {
        stop("File not found: ", file_path)
      }

      # Generate table name from file if not provided
      if (is.null(table_name)) {
        table_name <- tools::file_path_sans_ext(basename(file_path))
      }

      # Build options string
      option_str <- ""
      if (!is.null(options)) {
        option_str <- paste0(
          ", ",
          paste(names(options), "=", options, collapse = ", ")
        )
      }

      # Create view from CSV
      query <- sprintf(
        "CREATE OR REPLACE VIEW %s AS SELECT * FROM read_csv_auto('%s'%s)",
        table_name,
        file_path,
        option_str
      )

      DBI::dbExecute(self$con, query)
      self$tables[[table_name]] <- file_path

      message(paste("✅ Registered", table_name, "from", basename(file_path)))

      invisible(self)
    },

    #' @description
    #' Register all CSV files in a directory.
    #'
    #' @param data_dir Directory containing CSV files
    #' @param pattern File pattern to match (default: "*.csv")
    #'
    #' @return Invisibly returns self for method chaining.
    register_all_csvs = function(data_dir = "data", pattern = "*.csv") {
      csv_files <- list.files(data_dir, pattern = pattern, full.names = TRUE)

      for (file in csv_files) {
        self$register_csv(file)
      }

      invisible(self)
    },

    #' @description
    #' Execute a SQL query and return results.
    #'
    #' @param query SQL query string
    #' @param params Named list of parameters for parameterized queries
    #'
    #' @return Query results as a data frame
    query = function(query, params = NULL) {
      if (is.null(self$con)) {
        stop("No database connection. Call connect() first.")
      }

      if (!is.null(params)) {
        result <- DBI::dbGetQuery(self$con, query, params = params)
      } else {
        result <- DBI::dbGetQuery(self$con, query)
      }

      return(result)
    },

    #' @description
    #' Create a lazy reference to a table for dplyr operations.
    #'
    #' @param table_name Name of the table
    #'
    #' @return A dplyr tbl object
    query_lazy = function(table_name) {
      if (!table_name %in% names(self$tables)) {
        stop("Table not found: ", table_name)
      }

      return(dplyr::tbl(self$con, table_name))
    },

    #' @description
    #' Process a specific domain using SQL.
    #'
    #' @param domain Domain name to process
    #' @param data_type Type of data ("neurocog", "neurobehav", or "validity")
    #' @param scales Optional vector of scales to include
    #'
    #' @return Processed data for the domain
    process_domain = function(domain, data_type = "neurocog", scales = NULL) {
      # Base query
      base_query <- sprintf(
        "SELECT * FROM %s WHERE domain = '%s'",
        data_type,
        domain
      )

      # Add scale filter if provided
      if (!is.null(scales)) {
        scale_list <- paste0("'", scales, "'", collapse = ", ")
        base_query <- paste0(base_query, " AND scale IN (", scale_list, ")")
      }

      # Order by percentile
      base_query <- paste0(base_query, " ORDER BY percentile DESC")

      return(self$query(base_query))
    },

    #' @description
    #' Calculate z-score statistics using SQL (optimized for DuckDB).
    #'
    #' @param table_name Table to process
    #' @param group_vars Vector of grouping variables
    #'
    #' @return Data with calculated z-score statistics
    calculate_z_stats = function(table_name, group_vars) {
      # For complex z-score calculations, export to R and use the tidy_data function
      data <- self$query(sprintf("SELECT * FROM %s WHERE z IS NOT NULL", table_name))
      
      # Use the existing calculate_z_stats function from tidy_data.R
      result <- calculate_z_stats(data, group_vars)
      
      return(result)
    },

    #' @description
    #' Export query results to standard R6 processors.
    #'
    #' @param domain Domain to export
    #' @param processor_class R6 class to use (default: DomainProcessorR6)
    #'
    #' @return An R6 processor object with the data
    export_to_r6 = function(domain, processor_class = "DomainProcessorR6") {
      # Query the domain data
      data <- self$process_domain(domain)

      # Create processor
      if (processor_class == "DomainProcessorR6") {
        processor <- DomainProcessorR6$new(
          domains = domain,
          pheno = tolower(gsub(" ", "_", domain)),
          input_file = NULL # We'll inject data directly
        )
        processor$data <- data
      }

      return(processor)
    },

    #' @description
    #' Get domain summary statistics using SQL.
    #'
    #' @param include_all Whether to include all domains (default: TRUE)
    #'
    #' @return Summary statistics by domain
    get_domain_summary = function(include_all = TRUE) {
      query <- "
        SELECT 
          domain,
          COUNT(*) as n_tests,
          AVG(percentile) as mean_percentile,
          AVG(z) as mean_z,
          STDDEV(z) as sd_z,
          MIN(percentile) as min_percentile,
          MAX(percentile) as max_percentile
        FROM neurocog
        WHERE percentile IS NOT NULL
        GROUP BY domain
        ORDER BY mean_percentile DESC
      "

      return(self$query(query))
    },

    #' @description
    #' Create optimized indexes for faster queries.
    #'
    #' @return Invisibly returns self for method chaining.
    create_indexes = function() {
      # Create indexes on commonly queried columns
      indexes <- c(
        "CREATE INDEX IF NOT EXISTS idx_neurocog_domain ON neurocog(domain)",
        "CREATE INDEX IF NOT EXISTS idx_neurocog_test ON neurocog(test)",
        "CREATE INDEX IF NOT EXISTS idx_neurocog_scale ON neurocog(scale)",
        "CREATE INDEX IF NOT EXISTS idx_neurobehav_domain ON neurobehav(domain)",
        "CREATE INDEX IF NOT EXISTS idx_validity_domain ON validity(domain)"
      )

      for (idx in indexes) {
        tryCatch(DBI::dbExecute(self$con, idx), error = function(e) {
          # Indexes might fail on views, which is okay
          NULL
        })
      }

      invisible(self)
    }
  ),
  private = list(
    # Finalize method to ensure connection is closed
    finalize = function() {
      self$disconnect()
    }
  )
)

#' Process neuropsych data using DuckDB (Function Wrapper)
#'
#' This function provides a high-level interface to DuckDB processing.
#'
#' @param data_dir Directory containing CSV files
#' @param domain Domain to process (optional)
#' @param output_format Format for output ("data.frame", "r6", or "lazy")
#'
#' @return Processed data in the specified format
#' @export
process_with_duckdb <- function(
  data_dir = "data",
  domain = NULL,
  output_format = "data.frame"
) {
  # Create processor
  ddb <- DuckDBProcessorR6$new(data_dir = data_dir)

  # Process based on request
  if (!is.null(domain)) {
    result <- ddb$process_domain(domain)
  } else {
    result <- ddb$get_domain_summary()
  }

  # Format output
  if (output_format == "r6" && !is.null(domain)) {
    result <- ddb$export_to_r6(domain)
  }

  # Clean up
  ddb$disconnect()

  return(result)
}
