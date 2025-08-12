#' DuckDB Data Processor
#'
#' @description
#' An R6 class that provides an efficient data processing pipeline for
#' neuropsychological data using the DuckDB database engine. It allows for
#' SQL-based querying and processing of large datasets without loading them
#' entirely into memory, which is ideal for performance and scalability.
#'
#' @details
#' The `DuckDBProcessorR6` class handles the connection to a DuckDB database
#' (either in-memory or file-based), registration of data files (CSV, Parquet,
#' Arrow/Feather) as virtual tables, and execution of SQL queries. It is
#' designed to integrate seamlessly with other R6-based components in this
#' package.
#' @docType class
#' @format An R6 class object
#'
#' @field con Database connection object
#' @field db_path Database file path
#' @field tables Registered tables
#' @field data_paths Data file paths
#'
#' @section Methods:
#' \describe{
#'   \item{\code{initialize(db_path = ":memory:", data_dir = "data", auto_register = TRUE)}}{
#'     Initialize a new DuckDBProcessorR6 object.
#'     \itemize{
#'       \item \code{db_path}: Path to the DuckDB database file (default: ":memory:")
#'       \item \code{data_dir}: Directory containing data files (default: "data")
#'       \item \code{auto_register}: Automatically register CSV files (default: TRUE)
#'     }
#'   }
#'   \item{\code{connect()}}{
#'     Create or reconnect to the DuckDB database.
#'   }
#'   \item{\code{disconnect()}}{
#'     Close the database connection.
#'   }
#'   \item{\code{register_csv(file_path, table_name = NULL, options = NULL)}}{
#'     Register a CSV file as a virtual table.
#'     \itemize{
#'       \item \code{file_path}: Path to the CSV file
#'       \item \code{table_name}: Name for the table (default: based on filename)
#'       \item \code{options}: Additional CSV reading options
#'     }
#'   }
#'   \item{\code{register_parquet(file_path, table_name = NULL)}}{
#'     Register a Parquet file as a virtual table.
#'     \itemize{
#'       \item \code{file_path}: Path to the Parquet file
#'       \item \code{table_name}: Name for the table (default: based on filename)
#'     }
#'   }
#'   \item{\code{register_arrow(file_path, table_name = NULL)}}{
#'     Register an Arrow/Feather file as a virtual table.
#'     \itemize{
#'       \item \code{file_path}: Path to the Arrow/Feather file
#'       \item \code{table_name}: Name for the table (default: based on filename)
#'     }
#'   }
#'   \item{\code{register_all_csvs(data_dir = "data", pattern = "*.csv")}}{
#'     Register all CSV files in a directory.
#'     \itemize{
#'       \item \code{data_dir}: Directory containing CSV files
#'       \item \code{pattern}: File pattern to match (default: "*.csv")
#'     }
#'   }
#'   \item{\code{register_all_files(data_dir = "data", formats = c("parquet", "arrow", "csv"))}}{
#'     Register all data files in a directory.
#'     \itemize{
#'       \item \code{data_dir}: Directory containing data files
#'       \item \code{formats}: Character vector of formats to register
#'     }
#'   }
#'   \item{\code{export_to_parquet(table_name, output_path, compression = "zstd")}}{
#'     Export data to Parquet format.
#'     \itemize{
#'       \item \code{table_name}: Name of the table to export
#'       \item \code{output_path}: Path for the output Parquet file
#'       \item \code{compression}: Compression algorithm (default: "zstd")
#'     }
#'   }
#'   \item{\code{query(query, params = NULL)}}{
#'     Execute a SQL query and return results.
#'     \itemize{
#'       \item \code{query}: SQL query string
#'       \item \code{params}: Named list of parameters for parameterized queries
#'     }
#'   }
#'   \item{\code{execute(statement, params = NULL)}}{
#'     Execute a SQL statement that doesn't return results.
#'     \itemize{
#'       \item \code{statement}: SQL statement string
#'       \item \code{params}: Named list of parameters for parameterized statements
#'     }
#'   }
#'   \item{\code{query_lazy(table_name)}}{
#'     Create a lazy reference to a table for dplyr operations.
#'     \itemize{
#'       \item \code{table_name}: Name of the table
#'     }
#'   }
#'   \item{\code{process_domain(domain, data_type = "neurocog", scales = NULL)}}{
#'     Process a specific domain using SQL.
#'     \itemize{
#'       \item \code{domain}: Domain name to process
#'       \item \code{data_type}: Type of data ("neurocog", "neurobehav", or "validity")
#'       \item \code{scales}: Optional vector of scales to include
#'     }
#'   }
#'   \item{\code{calculate_z_stats(table_name, group_vars)}}{
#'     Calculate z-score statistics.
#'     \itemize{
#'       \item \code{table_name}: Table to process
#'       \item \code{group_vars}: Vector of grouping variables
#'     }
#'   }
#'   \item{\code{export_to_r6(domain, processor_class = "DomainProcessorR6")}}{
#'     Export query results to standard R6 processors.
#'     \itemize{
#'       \item \code{domain}: Domain to export
#'       \item \code{processor_class}: R6 class to use (default: DomainProcessorR6)
#'     }
#'   }
#'   \item{\code{get_domain_summary(include_all = TRUE)}}{
#'     Get domain summary statistics using SQL.
#'     \itemize{
#'       \item \code{include_all}: Whether to include all domains
#'     }
#'   }
#'   \item{\code{create_indexes()}}{
#'     Create optimized indexes for faster queries.
#'   }
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery dbExecute
#' @importFrom duckdb duckdb duckdb_register_arrow
#' @importFrom dplyr tbl collect
#' @importFrom arrow read_feather as_arrow_table
#'
#' @export
DuckDBProcessorR6 <- R6::R6Class(
  classname = "DuckDBProcessorR6",
  public = list(
    # Database connection object
    con = NULL,
    # Database file path
    db_path = NULL,
    # Registered tables
    tables = NULL,
    # Data file paths
    data_paths = NULL,
    # Available extensions
    available_extensions = NULL,

    # Initialize a new DuckDBProcessorR6 object
    initialize = function(
      db_path = ":memory:",
      data_dir = "data",
      auto_register = TRUE
    ) {
      self$db_path <- db_path
      self$tables <- list()
      self$available_extensions <- character(0)
      self$data_paths <- list(
        neurocog = file.path(data_dir, "neurocog.csv"),
        neurobehav = file.path(data_dir, "neurobehav.csv"),
        validity = file.path(data_dir, "validity.csv"),
        neuropsych = file.path(data_dir, "neuropsych.csv")
      )

      # Connect to database with robust extension handling
      self$connect()

      # Auto-register CSV files if requested
      if (auto_register && dir.exists(data_dir)) {
        self$register_all_csvs(data_dir)
      }
    },

    # Create or reconnect to the DuckDB database
    connect = function() {
      if (!is.null(self$con)) {
        self$disconnect()
      }

      self$con <- DBI::dbConnect(duckdb::duckdb(), self$db_path)
      self$available_extensions <- character(0)

      # Get DuckDB version for extension compatibility
      version_info <- private$get_duckdb_version()
      message(paste("🦆 DuckDB version:", version_info$version))
      message(paste("🖥️  Platform:", version_info$platform))

      # Define extensions with platform/version compatibility
      extensions <- list(
        list(
          name = "parquet",
          required = TRUE,
          description = "Parquet file format support"
        ),
        list(
          name = "fts",
          required = FALSE,
          description = "Full-text search capabilities"
        ),
        list(
          name = "json",
          required = FALSE,
          description = "JSON processing functions"
        )
      )

      # Try to install and load extensions with fallback
      for (ext in extensions) {
        success <- private$install_extension_safe(
          ext$name,
          required = ext$required,
          description = ext$description
        )

        if (success) {
          self$available_extensions <- c(self$available_extensions, ext$name)
        }
      }

      # Special handling for feather/arrow - use alternative approach
      feather_success <- private$setup_arrow_support()
      if (feather_success) {
        message("✅ Arrow/Feather support configured via R arrow package")
      }

      # Report available extensions
      if (length(self$available_extensions) > 0) {
        message(
          "✅ Available extensions:",
          paste(self$available_extensions, collapse = ", ")
        )
      } else {
        message("⚠️  No extensions loaded - basic functionality only")
      }

      invisible(self)
    },

    # Close the database connection
    disconnect = function() {
      if (!is.null(self$con)) {
        DBI::dbDisconnect(self$con, shutdown = TRUE)
        self$con <- NULL
        self$available_extensions <- character(0)
      }
      invisible(self)
    },

    # Register a CSV file as a virtual table
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

      # Create view from CSV with error handling
      query <- sprintf(
        "CREATE OR REPLACE VIEW %s AS SELECT * FROM read_csv_auto('%s'%s)",
        table_name,
        file_path,
        option_str
      )

      tryCatch(
        {
          DBI::dbExecute(self$con, query)
          self$tables[[table_name]] <- file_path
          message(paste(
            "✅ Registered",
            table_name,
            "from",
            basename(file_path)
          ))
        },
        error = function(e) {
          warning(paste("Failed to register", table_name, ":", e$message))
        }
      )

      invisible(self)
    },

    # Register a Parquet file as a virtual table
    register_parquet = function(file_path, table_name = NULL) {
      if (!file.exists(file_path)) {
        stop("File not found: ", file_path)
      }

      # Check if parquet extension is available
      if (!"parquet" %in% self$available_extensions) {
        warning("Parquet extension not available - falling back to CSV")
        return(self$register_csv(file_path, table_name))
      }

      # Generate table name from file if not provided
      if (is.null(table_name)) {
        table_name <- tools::file_path_sans_ext(basename(file_path))
      }

      # Create view from Parquet with error handling
      query <- sprintf(
        "CREATE OR REPLACE VIEW %s AS SELECT * FROM read_parquet('%s')",
        table_name,
        file_path
      )

      tryCatch(
        {
          DBI::dbExecute(self$con, query)
          self$tables[[table_name]] <- file_path
          message(paste(
            "✅ Registered",
            table_name,
            "from",
            basename(file_path)
          ))
        },
        error = function(e) {
          warning(paste(
            "Failed to register Parquet file",
            table_name,
            ":",
            e$message
          ))
          # Try CSV fallback if available
          csv_path <- sub("\\.parquet$", ".csv", file_path, ignore.case = TRUE)
          if (file.exists(csv_path)) {
            message("🔄 Attempting CSV fallback...")
            self$register_csv(csv_path, table_name)
          }
        }
      )

      invisible(self)
    },

    # Register an Arrow/Feather file as a virtual table
    register_arrow = function(file_path, table_name = NULL) {
      if (!file.exists(file_path)) {
        stop("File not found: ", file_path)
      }

      # Generate table name from file if not provided
      if (is.null(table_name)) {
        table_name <- tools::file_path_sans_ext(basename(file_path))
      }

      # Try Arrow package approach (recommended)
      success <- private$register_arrow_via_r(file_path, table_name)

      if (!success) {
        # Fallback to CSV if available
        csv_path <- sub(
          "\\.(arrow|feather)$",
          ".csv",
          file_path,
          ignore.case = TRUE
        )
        if (file.exists(csv_path)) {
          message("🔄 Arrow registration failed, using CSV fallback...")
          self$register_csv(csv_path, table_name)
        } else {
          warning(paste(
            "Failed to register Arrow file and no CSV fallback available:",
            file_path
          ))
        }
      }

      invisible(self)
    },

    # Register all CSV files in a directory
    register_all_csvs = function(data_dir = "data", pattern = "*.csv") {
      csv_files <- list.files(data_dir, pattern = pattern, full.names = TRUE)

      for (file in csv_files) {
        self$register_csv(file)
      }

      invisible(self)
    },

    # Register all data files in a directory
    register_all_files = function(
      data_dir = "data",
      formats = c("parquet", "arrow", "csv")
    ) {
      # Priority order: Parquet (fastest) -> Arrow -> CSV (slowest)
      registered_tables <- character(0)

      # Register Parquet files first (highest priority)
      if ("parquet" %in% formats && "parquet" %in% self$available_extensions) {
        parquet_files <- list.files(
          data_dir,
          pattern = "\\.parquet$",
          full.names = TRUE
        )
        for (file in parquet_files) {
          table_name <- tools::file_path_sans_ext(basename(file))
          if (!table_name %in% registered_tables) {
            self$register_parquet(file)
            registered_tables <- c(registered_tables, table_name)
          }
        }
      }

      # Register Arrow/Feather files (second priority)
      if ("arrow" %in% formats) {
        arrow_files <- list.files(
          data_dir,
          pattern = "\\.(arrow|feather)$",
          full.names = TRUE
        )
        for (file in arrow_files) {
          table_name <- tools::file_path_sans_ext(basename(file))
          if (!table_name %in% registered_tables) {
            self$register_arrow(file)
            registered_tables <- c(registered_tables, table_name)
          }
        }
      }

      # Register CSV files last (fallback)
      if ("csv" %in% formats) {
        csv_files <- list.files(
          data_dir,
          pattern = "\\.csv$",
          full.names = TRUE
        )
        for (file in csv_files) {
          table_name <- tools::file_path_sans_ext(basename(file))
          if (!table_name %in% registered_tables) {
            self$register_csv(file)
            registered_tables <- c(registered_tables, table_name)
          }
        }
      }

      invisible(self)
    },

    # Export data to Parquet format
    export_to_parquet = function(
      table_name,
      output_path,
      compression = "zstd"
    ) {
      if (!table_name %in% names(self$tables)) {
        stop("Table not found: ", table_name)
      }

      if (!"parquet" %in% self$available_extensions) {
        stop("Parquet extension not available")
      }

      query <- sprintf(
        "COPY %s TO '%s' (FORMAT PARQUET, COMPRESSION %s)",
        table_name,
        output_path,
        compression
      )

      tryCatch(
        {
          DBI::dbExecute(self$con, query)
          message(paste("✅ Exported", table_name, "to", output_path))
        },
        error = function(e) {
          warning(paste("Failed to export to Parquet:", e$message))
        }
      )

      invisible(self)
    },

    # Execute a SQL query and return results
    query = function(query, params = NULL) {
      if (is.null(self$con)) {
        stop("No database connection. Call connect() first.")
      }

      tryCatch(
        {
          if (!is.null(params)) {
            result <- DBI::dbGetQuery(self$con, query, params = params)
          } else {
            result <- DBI::dbGetQuery(self$con, query)
          }
          return(result)
        },
        error = function(e) {
          stop(paste("Query failed:", e$message, "\nQuery:", query))
        }
      )
    },

    # Execute a SQL statement that doesn't return results
    execute = function(statement, params = NULL) {
      if (is.null(self$con)) {
        stop("No database connection. Call connect() first.")
      }

      tryCatch(
        {
          if (!is.null(params)) {
            result <- DBI::dbExecute(self$con, statement, params = params)
          } else {
            result <- DBI::dbExecute(self$con, statement)
          }
          invisible(result)
        },
        error = function(e) {
          warning(paste(
            "Statement execution failed:",
            e$message,
            "\nStatement:",
            statement
          ))
          invisible(NA)
        }
      )
    },

    # Create a lazy reference to a table for dplyr operations
    query_lazy = function(table_name) {
      if (!table_name %in% names(self$tables)) {
        stop("Table not found: ", table_name)
      }

      return(dplyr::tbl(self$con, table_name))
    },

    # Process a specific domain using SQL
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

    # Calculate z-score statistics
    calculate_z_stats = function(table_name, group_vars) {
      # For complex z-score calculations, export to R and use the tidy_data function
      data <- self$query(sprintf(
        "SELECT * FROM %s WHERE z IS NOT NULL",
        table_name
      ))

      # Use the existing calculate_z_stats function from tidy_data.R
      result <- calculate_z_stats(data, group_vars)

      return(result)
    },

    # Export query results to standard R6 processors
    export_to_r6 = function(domain, processor_class = "DomainProcessorR6") {
      # Query the domain data
      data <- self$process_domain(domain)

      # Create processor
      if (processor_class == "DomainProcessorR6") {
        # Create a clean phenotype name from domain
        pheno <- tolower(gsub(" ", "_", domain))

        # Map common domains to their expected phenotype names
        pheno_map <- c(
          "general_cognitive_ability" = "iq",
          "memory" = "memory",
          "attention/executive" = "executive",
          "verbal/language" = "verbal",
          "visuospatial" = "spatial",
          "academic_skills" = "academics",
          "motor" = "motor",
          "social_cognition" = "social",
          "adhd" = "adhd",
          "emotional/behavioral/personality" = "emotion",
          "adaptive_behavior" = "adaptive"
        )

        # Use mapped name if available
        if (pheno %in% names(pheno_map)) {
          pheno <- pheno_map[pheno]
        }

        processor <- DomainProcessorR6$new(
          domains = domain,
          pheno = pheno,
          input_file = "data/neurocog.csv", # Set a default for compatibility
          output_dir = "data"
        )

        # Inject the queried data
        processor$data <- data
      }

      return(processor)
    },

    # Get domain summary statistics using SQL
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

    # Create optimized indexes for faster queries
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
        tryCatch(self$execute(idx), error = function(e) {
          # Indexes might fail on views, which is okay
          NULL
        })
      }

      invisible(self)
    }
  ),

  private = list(
    # Finalizer method (now in private section as per R6 2.4.0)
    finalize = function() {
      self$disconnect()
    },

    # Get DuckDB version and platform information
    get_duckdb_version = function() {
      tryCatch(
        {
          version_result <- DBI::dbGetQuery(self$con, "SELECT version()")
          version_string <- version_result[[1]][1]

          # Extract version number
          version_match <- regmatches(
            version_string,
            regexpr("v[0-9.]+", version_string)
          )
          version <- if (length(version_match) > 0) version_match else "unknown"

          # Determine platform
          platform <- paste(
            Sys.info()["sysname"],
            Sys.info()["machine"],
            sep = "_"
          )
          platform <- tolower(gsub(" ", "_", platform))

          return(list(
            version = version,
            platform = platform,
            full = version_string
          ))
        },
        error = function(e) {
          return(list(
            version = "unknown",
            platform = "unknown",
            full = "unknown"
          ))
        }
      )
    },

    # Safely install and load a DuckDB extension
    install_extension_safe = function(
      ext_name,
      required = FALSE,
      description = ""
    ) {
      tryCatch(
        {
          # Try to install the extension
          DBI::dbExecute(self$con, paste0("INSTALL '", ext_name, "'"))

          # Try to load the extension
          DBI::dbExecute(self$con, paste0("LOAD '", ext_name, "'"))

          message(paste("✅", ext_name, "extension loaded successfully"))
          if (nzchar(description)) {
            message(paste("   →", description))
          }
          return(TRUE)
        },
        error = function(e) {
          if (required) {
            warning(paste(
              "Required extension",
              ext_name,
              "failed to load:",
              e$message
            ))
          } else {
            message(paste(
              "⚠️  Optional extension",
              ext_name,
              "not available:",
              e$message
            ))
          }
          return(FALSE)
        }
      )
    },

    # Set up Arrow/Feather support using R arrow package
    setup_arrow_support = function() {
      # Check if arrow package is available
      if (!requireNamespace("arrow", quietly = TRUE)) {
        message(
          "ℹ️  Arrow package not available - install with: install.packages('arrow')"
        )
        return(FALSE)
      }

      # Test arrow functionality
      tryCatch(
        {
          # Create a small test table to verify arrow integration works
          test_data <- data.frame(test_col = 1:3)
          arrow_table <- arrow::as_arrow_table(test_data)
          duckdb::duckdb_register_arrow(self$con, "arrow_test", arrow_table)

          # Clean up test table
          DBI::dbExecute(self$con, "DROP VIEW IF EXISTS arrow_test")

          return(TRUE)
        },
        error = function(e) {
          message("⚠️  Arrow integration test failed:", e$message)
          return(FALSE)
        }
      )
    },

    # Register Arrow file using R arrow package
    register_arrow_via_r = function(file_path, table_name) {
      # Check if arrow package is available
      if (!requireNamespace("arrow", quietly = TRUE)) {
        return(FALSE)
      }

      tryCatch(
        {
          # Read Arrow table using R package
          arrow_table <- arrow::read_feather(file_path)

          # Register with DuckDB
          duckdb::duckdb_register_arrow(self$con, table_name, arrow_table)

          self$tables[[table_name]] <- file_path
          message(paste(
            "✅ Registered",
            table_name,
            "from",
            basename(file_path),
            "(via R arrow)"
          ))

          return(TRUE)
        },
        error = function(e) {
          message(paste("Failed to register Arrow file via R:", e$message))
          return(FALSE)
        }
      )
    }
  )
)

#' Process neuropsych data using DuckDB
#'
#' This function provides a high-level interface to DuckDB processing.
#'
#' @param data_dir Directory containing CSV files
#' @param domain Domain to process
#' @param output_dir Directory for output files
#' @return Processed data
#'
#' @export
process_with_duckdb <- function(
  data_dir = "data",
  domain = NULL,
  output_dir = "output"
) {
  # Create processor
  processor <- DuckDBProcessorR6$new(data_dir = data_dir)

  # Process specific domain if provided
  if (!is.null(domain)) {
    result <- processor$process_domain(domain)
  } else {
    # Get domain summary
    result <- processor$get_domain_summary()
  }

  # Clean up
  processor$disconnect()

  return(result)
}
