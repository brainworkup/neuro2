#' DuckDBProcessorR6 Class
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
#' Arrow/Feather) as virtual tables, and execution of SQL queries. It also
#' registers and uses the package master lookup (`lookup_neuropsych_scales`)
#' to enrich neurocognitive/behavioral data with domain/subdomain/narrow
#' (and, for neurocog, pass/verbal/timed), and offers summary helpers.
#'
#' Core features:
#' - Connection & extension management
#' - Auto-registration of CSVs (and helpers for Parquet/Arrow)
#' - Lookup registration into DuckDB (with normalized join_key)
#' - `domains_ref` materialization from the lookup
#' - Enriched views: `neurocog_enriched`, `neurobehav_enriched`
#' - Summaries across domain/subdomain/narrow, with optional stream split
#'
#' @docType class
#' @format An R6 class object
#'
#' @field con Database connection object
#' @field db_path Database file path
#' @field tables Registered tables
#' @field data_paths Data file paths
#' @field available_extensions Character vector of available DuckDB extensions
#'
#' @section Methods:
#' \describe{
#'   \item{\code{initialize(db_path = ":memory:", data_dir = "data", auto_register = TRUE, setup = TRUE, ...)}}{
#'     Initialize, optionally auto-register data, and bootstrap lookup/domains/views.
#'   }
#'   \item{\code{connect()}}{
#'     Create or reconnect to the DuckDB database.
#'   }
#'   \item{\code{disconnect()}}{
#'     Close the database connection.
#'   }
#'   \item{\code{register_csv(file_path, table_name = NULL, options = NULL)}}{
#'     Register a CSV file as a virtual table.
#'   }
#'   \item{\code{register_parquet(file_path, table_name = NULL)}}{
#'     Register a Parquet file as a virtual table.
#'   }
#'   \item{\code{register_arrow(file_path, table_name = NULL)}}{
#'     Register an Arrow/Feather file as a virtual table.
#'   }
#'   \item{\code{register_all_csvs(data_dir = "data", pattern = "*.csv")}}{
#'     Register all CSV files in a directory.
#'   }
#'   \item{\code{register_all_files(data_dir = "data", formats = c("parquet","arrow","csv"))}}{
#'     Register all supported files in a directory.
#'   }
#'   \item{\code{export_to_parquet(table_name, output_path, compression = "zstd")}}{
#'     Export a registered table to Parquet.
#'   }
#'   \item{\code{query(query, params = NULL)}}{
#'     Execute a SQL query and return results.
#'   }
#'   \item{\code{execute(statement, params = NULL)}}{
#'     Execute a SQL statement that doesn't return results.
#'   }
#'   \item{\code{query_lazy(table_name)}}{
#'     Create a lazy reference to a table for dplyr operations.
#'   }
#'   \item{\code{process_domain(domain, data_type = "neurocog", scales = NULL)}}{
#'     Process a specific domain using SQL.
#'   }
#'   \item{\code{export_to_r6(domain, processor_class = "DomainProcessorR6")}}{
#'     Export processed results to a standard R6 processor.
#'   }
#'   \item{\code{get_domain_summary(include_all = TRUE, by_stream = FALSE)}}{
#'     Get domain-level summary statistics (wrapper over enriched/union).
#'   }
#'   \item{\code{ensure_lookup_registered(force = FALSE)}}{
#'     Public bootstrap: make lookup available in DuckDB with join_key.
#'   }
#'   \item{\code{ensure_domains_ref(force = FALSE)}}{
#'     Public bootstrap: rebuild domains_ref from the lookup.
#'   }
#'   \item{\code{refresh_enriched_views()}}{
#'     Public bootstrap: create enriched views and log unmapped keys.
#'   }
#'   \item{\code{create_indexes()}}{
#'     Create optimized indexes for faster queries.
#'   }
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery dbExecute
#' @importFrom duckdb duckdb duckdb_register duckdb_register_arrow
#' @importFrom dplyr tbl collect distinct mutate if_else group_by summarize
#' @importFrom rlang .data syms
#' @importFrom methods is
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

    #' @description Constructor. Create a new DuckDBProcessorR6 instance and
    #'   optionally auto-register data files, then bootstrap lookup + domains +
    #'   enriched views so summaries/plots are ready to run.
    #' @param db_path Path to the DuckDB database file. Use ":memory:" for in-memory DB.
    #' @param data_dir Directory containing data files to register.
    #' @param auto_register If TRUE, attempt to auto-register supported data files from `data_dir`.
    #' @param setup If TRUE (default), run bootstrap (register lookup, build domains_ref, refresh views).
    #' @param force_lookup If TRUE, re-register the in-memory lookup even if present.
    #' @param force_domains_ref If TRUE, rebuild domains_ref even if present.
    #' @param refresh_views If TRUE (default), (re)create enriched views after data registration.
    #' @param verbose If TRUE (default), print progress messages during bootstrap.
    #' @return Invisibly returns `self`.
    initialize = function(
      db_path = ":memory:",
      data_dir = "data",
      auto_register = TRUE,
      setup = TRUE,
      force_lookup = FALSE,
      force_domains_ref = FALSE,
      refresh_views = TRUE,
      verbose = TRUE
    ) {
      self$db_path <- db_path
      self$tables <- list()
      self$available_extensions <- character(0)
      self$data_paths <- list(
        neurocog   = file.path(data_dir, "neurocog.parquet"),
        neurobehav = file.path(data_dir, "neurobehav.parquet"),
        validity   = file.path(data_dir, "validity.parquet"),
        neuropsych = file.path(data_dir, "neuropsych.parquet")
      )

      self$connect()

      if (isTRUE(auto_register) && dir.exists(data_dir)) {
        self$register_all_csvs(data_dir)
      }

      if (isTRUE(setup)) {
        if (verbose) message("• Ensuring lookup is registered …")
        self$ensure_lookup_registered(force = force_lookup)

        if (verbose) message("• Ensuring domains_ref exists …")
        self$ensure_domains_ref(force = force_domains_ref)

        if (isTRUE(refresh_views)) {
          if (verbose) message("• Refreshing enriched views …")
          self$refresh_enriched_views()
        }

        if (verbose) message("✓ DuckDB bootstrap complete.")
      }

      invisible(self)
    },

    #' @description Open (or re-open) a DuckDB connection based on `db_path` and set up extensions.
    #' @return Invisibly returns `self` after establishing a connection.
    connect = function() {
      if (!is.null(self$con)) {
        self$disconnect()
      }
      self$con <- DBI::dbConnect(duckdb::duckdb(), self$db_path)
      self$available_extensions <- character(0)

      version_info <- private$get_duckdb_version()
      message(paste("🦆 DuckDB version:", version_info$version))
      message(paste("🖥️  Platform:", version_info$platform))

      extensions <- list(
        list(name = "parquet", required = TRUE,  description = "Parquet file format support"),
        list(name = "fts",     required = FALSE, description = "Full-text search capabilities"),
        list(name = "json",    required = FALSE, description = "JSON processing functions")
      )

      for (ext in extensions) {
        success <- private$install_extension_safe(ext$name, required = ext$required, description = ext$description)
        if (success) self$available_extensions <- c(self$available_extensions, ext$name)
      }

      if (private$setup_arrow_support()) {
        message("✅ Arrow/Feather support configured via R arrow package")
      }

      if (length(self$available_extensions) > 0) {
        message("✅ Available extensions: ", paste(self$available_extensions, collapse = ", "))
      } else {
        message("⚠️  No extensions loaded - basic functionality only")
      }
      invisible(self)
    },

    #' @description Close the open DuckDB connection if present.
    #' @return Invisibly returns `self`.
    disconnect = function() {
      if (!is.null(self$con)) {
        DBI::dbDisconnect(self$con, shutdown = TRUE)
        self$con <- NULL
        self$available_extensions <- character(0)
      }
      invisible(self)
    },

    #' @description Register a CSV file as a virtual table for SQL access.
    #' @param file_path Path to the CSV file.
    #' @param table_name Optional table name. If NULL, derived from filename.
    #' @param options Named list of DuckDB CSV reader options (e.g., header, delim).
    #' @return Invisibly returns `self`.
    register_csv = function(file_path, table_name = NULL, options = NULL) {
      if (!file.exists(file_path)) stop("File not found: ", file_path)
      if (is.null(table_name)) table_name <- tools::file_path_sans_ext(basename(file_path))

      option_str <- ""
      if (!is.null(options)) {
        option_str <- paste0(", ", paste(names(options), "=", options, collapse = ", "))
      }

      query <- sprintf(
        "CREATE OR REPLACE VIEW %s AS SELECT * FROM read_csv_auto('%s'%s)",
        table_name, normalizePath(file_path, winslash = "/", mustWork = FALSE), option_str
      )

      tryCatch({
        DBI::dbExecute(self$con, query)
        self$tables[[table_name]] <- file_path
        message("✅ Registered ", table_name, " from ", basename(file_path))
      }, error = function(e) {
        warning("Failed to register ", table_name, ": ", e$message)
      })

      invisible(self)
    },

    #' @description Register a Parquet file as a virtual table for SQL access.
    #' @param file_path Path to the Parquet file.
    #' @param table_name Optional table name. If NULL, derived from filename.
    #' @return Invisibly returns `self`.
    register_parquet = function(file_path, table_name = NULL) {
      if (!file.exists(file_path)) stop("File not found: ", file_path)
      if (!"parquet" %in% self$available_extensions) {
        warning("Parquet extension not available - falling back to CSV")
        return(self$register_csv(file_path, table_name))
      }
      if (is.null(table_name)) table_name <- tools::file_path_sans_ext(basename(file_path))

      query <- sprintf("CREATE OR REPLACE VIEW %s AS SELECT * FROM read_parquet('%s')",
                       table_name, normalizePath(file_path, winslash = "/", mustWork = FALSE))

      tryCatch({
        DBI::dbExecute(self$con, query)
        self$tables[[table_name]] <- file_path
        message("✅ Registered ", table_name, " from ", basename(file_path))
      }, error = function(e) {
        warning("Failed to register Parquet file ", table_name, ": ", e$message)
        csv_path <- sub("\\.parquet$", ".csv", file_path, ignore.case = TRUE)
        if (file.exists(csv_path)) {
          message("🔄 Attempting CSV fallback...")
          self$register_csv(csv_path, table_name)
        }
      })

      invisible(self)
    },

    #' @description Register an Arrow/Feather file as a virtual table for SQL access.
    #' @param file_path Path to the Feather/Arrow file.
    #' @param table_name Optional table name. If NULL, derived from filename.
    #' @return Invisibly returns `self`.
    register_arrow = function(file_path, table_name = NULL) {
      if (!file.exists(file_path)) stop("File not found: ", file_path)
      if (is.null(table_name)) table_name <- tools::file_path_sans_ext(basename(file_path))

      success <- private$register_arrow_via_r(file_path, table_name)
      if (!success) {
        csv_path <- sub("\\.(arrow|feather)$", ".csv", file_path, ignore.case = TRUE)
        if (file.exists(csv_path)) {
          message("🔄 Arrow registration failed, using CSV fallback...")
          self$register_csv(csv_path, table_name)
        } else {
          warning("Failed to register Arrow file and no CSV fallback available: ", file_path)
        }
      }
      invisible(self)
    },

    #' @description Register all CSV files in a directory that match `pattern`.
    #' @param data_dir Directory containing CSV files to register.
    #' @param pattern Glob pattern for files (default: "*.csv").
    #' @return Invisibly returns `self`.
    register_all_csvs = function(data_dir = "data", pattern = "*.csv") {
      csv_files <- list.files(data_dir, pattern = pattern, full.names = TRUE)
      for (file in csv_files) self$register_csv(file)
      invisible(self)
    },

    #' @description Register all supported files (parquet/arrow/csv) in a directory.
    #' @param data_dir Directory containing files to register.
    #' @param formats Character vector of formats (subset of c("parquet","arrow","csv")).
    #' @return Invisibly returns `self`.
    register_all_files = function(data_dir = "data", formats = c("parquet", "arrow", "csv")) {
      registered_tables <- character(0)

      if ("parquet" %in% formats && "parquet" %in% self$available_extensions) {
        parquet_files <- list.files(data_dir, pattern = "\\.parquet$", full.names = TRUE)
        for (file in parquet_files) {
          table_name <- tools::file_path_sans_ext(basename(file))
          if (!table_name %in% registered_tables) {
            self$register_parquet(file); registered_tables <- c(registered_tables, table_name)
          }
        }
      }

      if ("arrow" %in% formats) {
        arrow_files <- list.files(data_dir, pattern = "\\.(arrow|feather)$", full.names = TRUE)
        for (file in arrow_files) {
          table_name <- tools::file_path_sans_ext(basename(file))
          if (!table_name %in% registered_tables) {
            self$register_arrow(file); registered_tables <- c(registered_tables, table_name)
          }
        }
      }

      if ("csv" %in% formats) {
        csv_files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)
        for (file in csv_files) {
          table_name <- tools::file_path_sans_ext(basename(file))
          if (!table_name %in% registered_tables) {
            self$register_csv(file); registered_tables <- c(registered_tables, table_name)
          }
        }
      }
      invisible(self)
    },

    #' @description Export a registered table to a Parquet file.
    #' @param table_name Name of the registered table to export.
    #' @param output_path Destination Parquet file path.
    #' @param compression Compression codec to use (e.g., "zstd").
    #' @return Invisibly returns `self`.
    export_to_parquet = function(table_name, output_path, compression = "zstd") {
      if (!table_name %in% names(self$tables)) stop("Table not found: ", table_name)
      if (!"parquet" %in% self$available_extensions) stop("Parquet extension not available")

      query <- sprintf("COPY %s TO '%s' (FORMAT PARQUET, COMPRESSION %s)",
                       table_name, normalizePath(output_path, winslash = "/", mustWork = FALSE), compression)

      tryCatch({
        DBI::dbExecute(self$con, query)
        message("✅ Exported ", table_name, " to ", output_path)
      }, error = function(e) {
        warning("Failed to export to Parquet: ", e$message)
      })
      invisible(self)
    },

    #' @description Execute a SQL query and return results as a data frame.
    #' @param query SQL query string. May reference registered tables.
    #' @param params Optional named list of parameter values for parameterized queries.
    #' @return A data.frame with query results.
    query = function(query, params = NULL) {
      if (is.null(self$con)) stop("No database connection. Call connect() first.")
      tryCatch({
        if (!is.null(params)) DBI::dbGetQuery(self$con, query, params = params)
        else DBI::dbGetQuery(self$con, query)
      }, error = function(e) {
        stop("Query failed: ", e$message, "\nQuery: ", query)
      })
    },

    #' @description Execute a SQL statement that does not return rows (e.g., CREATE INDEX).
    #' @param statement SQL statement string.
    #' @param params Optional named list of parameter values.
    #' @return Invisibly returns TRUE on success.
    execute = function(statement, params = NULL) {
      if (is.null(self$con)) stop("No database connection. Call connect() first.")
      tryCatch({
        if (!is.null(params)) DBI::dbExecute(self$con, statement, params = params)
        else DBI::dbExecute(self$con, statement)
        invisible(TRUE)
      }, error = function(e) {
        warning("Statement execution failed: ", e$message, "\nStatement: ", statement)
        invisible(FALSE)
      })
    },

    #' @description Return a lazy dplyr table reference to an existing DuckDB table.
    #' @param table_name Name of a registered table.
    #' @return A dplyr tbl_lazy object.
    query_lazy = function(table_name) {
      if (!table_name %in% names(self$tables)) stop("Table not found: ", table_name)
      dplyr::tbl(self$con, table_name)
    },

    #' @description Process and return data for a given domain via SQL, optionally filtered by stream and scales.
    #' @param domain Domain name (character).
    #' @param data_type Type of data: "neurocog", "neurobehav", or "validity".
    #' @param scales Optional character vector of scales to include; NULL includes defaults for the domain.
    #' @return A data.frame with processed domain data.
    process_domain = function(domain, data_type = "neurocog", scales = NULL) {
      base_query <- sprintf("SELECT * FROM %s WHERE domain = '%s'", data_type, domain)
      if (!is.null(scales)) {
        scale_list <- paste0("'", scales, "'", collapse = ", ")
        base_query <- paste0(base_query, " AND scale IN (", scale_list, ")")
      }
      base_query <- paste0(base_query, " ORDER BY percentile DESC")
      self$query(base_query)
    },

    #' @description Export processed results into a standard R6 processor (e.g., DomainProcessorR6).
    #' @param domain Domain name to export.
    #' @param processor_class R6 class name or generator to use (default: "DomainProcessorR6").
    #' @return An instance of the target R6 processor initialized with the domain data, or a list if class not found.
    export_to_r6 = function(domain, processor_class = "DomainProcessorR6") {
      data <- self$process_domain(domain)
      if (processor_class == "DomainProcessorR6") {
        pheno_map <- c(
          "General Cognitive Ability" = "iq",
          "Academic Skills" = "academics",
          "Verbal/Language" = "verbal",
          "Visual Perception/Construction" = "spatial",
          "Memory" = "memory",
          "Attention/Executive" = "executive",
          "Motor" = "motor",
          "Social Cognition" = "social",
          "ADHD/Executive Function" = "adhd",
          "Emotional/Behavioral/Social/Personality" = "emotion",
          "Adaptive Functioning" = "adaptive",
          "Daily Living" = "daily_living",
          "Validity" = "validity",
          "ADHD" = "adhd",
          "Psychiatric Disorders" = "emotion",
          "Personality Disorders" = "emotion",
          "Substance Use" = "emotion",
          "Psychosocial Problems" = "emotion",
          "Emotional/Behavioral/Personality" = "emotion",
          "Behavioral/Emotional/Social" = "emotion",
          "Performance Validity" = "validity",
          "Symptom Validity" = "validity",
          "Effort/Validity" = "validity"
        )
        pheno <- if (domain %in% names(pheno_map)) pheno_map[[domain]] else tolower(gsub(" ", "_", domain))
        if (exists("DomainProcessorR6")) {
          processor <- DomainProcessorR6$new(domains = domain, pheno = pheno, input_file = "data/neurocog.csv", output_dir = "data")
          processor$data <- data
          return(processor)
        } else {
          warning("DomainProcessorR6 class not found. Returning raw data.")
          return(list(data = data, domain = domain, pheno = pheno))
        }
      }
      list(data = data, domain = domain)
    },

    #' @description Return summary statistics across domains (neurocog + neurobehav).
    #' @param include_all If TRUE, include all known domains (requires a domain reference table; otherwise falls back to domains with data).
    #' @param by_stream If TRUE, return one row per (domain, stream). If FALSE, streams are combined.
    #' @return A data.frame with domain-level summary metrics.
    get_domain_summary = function(include_all = TRUE, by_stream = FALSE) {
      tbls <- self$query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'")$table_name
      has_cog <- "neurocog" %in% tbls
      has_behav <- "neurobehav" %in% tbls
      if (!has_cog && !has_behav) stop("Neither 'neurocog' nor 'neurobehav' tables are present.")

      sources <- c()
      if (has_cog)   sources <- c(sources, "SELECT 'neurocog' AS stream, domain, percentile, z FROM neurocog")
      if (has_behav) sources <- c(sources, "SELECT 'neurobehav' AS stream, domain, percentile, z FROM neurobehav")
      union_sql <- paste(sources, collapse = "\nUNION ALL\n")

      grp_cols <- if (by_stream) "domain, stream" else "domain"
      sel_cols <- if (by_stream) "domain, stream" else "domain"

      summarize_sql <- sprintf("
        WITH all_rows AS (%s)
        SELECT %s,
               COUNT(*)        AS n_tests,
               AVG(percentile) AS mean_percentile,
               AVG(z)          AS mean_z,
               STDDEV(z)       AS sd_z,
               MIN(percentile) AS min_percentile,
               MAX(percentile) AS max_percentile
        FROM all_rows
        WHERE percentile IS NOT NULL
        GROUP BY %s
        ORDER BY mean_percentile DESC
      ", union_sql, sel_cols, grp_cols)

      if (isTRUE(include_all) && "domains_ref" %in% tbls) {
        summarize_sql <- sprintf("
          WITH all_rows AS (%s),
          agg AS (
            SELECT %s,
                   COUNT(*)        AS n_tests,
                   AVG(percentile) AS mean_percentile,
                   AVG(z)          AS mean_z,
                   STDDEV(z)       AS sd_z,
                   MIN(percentile) AS min_percentile,
                   MAX(percentile) AS max_percentile
            FROM all_rows
            WHERE percentile IS NOT NULL
            GROUP BY %s
          )
          SELECT %s,
                 COALESCE(agg.n_tests, 0)     AS n_tests,
                 agg.mean_percentile,
                 agg.mean_z,
                 agg.sd_z,
                 agg.min_percentile,
                 agg.max_percentile
          FROM domains_ref ref
          LEFT JOIN agg ON ref.domain = agg.domain %s
          ORDER BY mean_percentile DESC NULLS LAST, ref.domain
        ",
        union_sql, sel_cols, grp_cols, sel_cols,
        if (by_stream) "AND agg.stream IN ('neurocog','neurobehav')" else "")
      }

      self$query(summarize_sql)
    },

    #' @description Public bootstrap: make lookup visible with join_key.
    #' @param force If TRUE, re-register even if present.
    ensure_lookup_registered = function(force = FALSE) {
      if (!isTRUE(force) && private$duckdb_has_relation(self$con, "lookup_neuropsych_scales")) {
        ok <- tryCatch({ invisible(DBI::dbGetQuery(self$con, "SELECT COUNT(*) FROM lookup_neuropsych_scales")); TRUE },
                       error = function(e) FALSE)
        if (ok) return(invisible(FALSE))
      }

      lkp <- private$get_lookup_df()
      req_cols <- c("stream","domain","subdomain","narrow","scale","test","test_name")
      missing <- setdiff(req_cols, names(lkp))
      if (length(missing)) stop("lookup_neuropsych_scales is missing required columns: ", paste(missing, collapse = ", "))
      if (!"pass" %in% names(lkp))   lkp$pass   <- NA
      if (!"verbal" %in% names(lkp)) lkp$verbal <- NA
      if (!"timed" %in% names(lkp))  lkp$timed  <- NA

      DBI::dbExecute(self$con, "DROP VIEW IF EXISTS lookup_neuropsych_scales")
      if (private$duckdb_has_relation(self$con, "lookup_neuropsych_scales_mem")) {
        DBI::dbExecute(self$con, "DROP TABLE lookup_neuropsych_scales_mem")
      }

      duckdb::duckdb_register(self$con, "lookup_neuropsych_scales_mem", lkp)

      DBI::dbExecute(self$con, "
        CREATE VIEW lookup_neuropsych_scales AS
        SELECT *,
               COALESCE(
                 NULLIF(lower(trim(scale)),     ''),
                 NULLIF(lower(trim(test)),      ''),
                 NULLIF(lower(trim(test_name)), '')
               ) AS join_key
        FROM lookup_neuropsych_scales_mem
      ")
      invisible(TRUE)
    },

    #' @description Public bootstrap: rebuild domains_ref from the lookup; carries pass/verbal/timed only for neurocog.
    #' @param force If TRUE, rebuild even if domains_ref already exists.
    ensure_domains_ref = function(force = FALSE) {
      self$ensure_lookup_registered()
      if (!isTRUE(force) && private$duckdb_has_relation(self$con, "domains_ref")) return(invisible(FALSE))

      DBI::dbExecute(self$con, "DROP TABLE IF EXISTS domains_ref")
      DBI::dbExecute(self$con, "
        CREATE TABLE domains_ref AS
        SELECT DISTINCT
          domain,
          subdomain,
          narrow,
          stream,
          CASE WHEN stream = 'neurocog' THEN pass   ELSE NULL END AS pass,
          CASE WHEN stream = 'neurocog' THEN verbal ELSE NULL END AS verbal,
          CASE WHEN stream = 'neurocog' THEN timed  ELSE NULL END AS timed
        FROM lookup_neuropsych_scales
        WHERE domain IS NOT NULL
      ")
      invisible(TRUE)
    },

    #' @description Public bootstrap: create/refresh enriched views; logs unmapped keys per stream to `unmapped_tests_log`.
    refresh_enriched_views = function() {
      self$ensure_lookup_registered()

      DBI::dbExecute(self$con, "DROP VIEW IF EXISTS neurocog_enriched")
      DBI::dbExecute(self$con, sprintf("
        CREATE VIEW neurocog_enriched AS
        WITH src AS (
          SELECT c.*, %s AS join_key FROM neurocog c
        )
        SELECT
          s.* EXCLUDE join_key,
          l.domain, l.subdomain, l.narrow,
          l.pass, l.verbal, l.timed,
          'neurocog' AS stream
        FROM src s
        LEFT JOIN lookup_neuropsych_scales l
          ON s.join_key = l.join_key AND l.stream = 'neurocog'
      ", private$sql_join_key("c")))

      DBI::dbExecute(self$con, "DROP VIEW IF EXISTS neurobehav_enriched")
      DBI::dbExecute(self$con, sprintf("
        CREATE VIEW neurobehav_enriched AS
        WITH src AS (
          SELECT b.*, %s AS join_key FROM neurobehav b
        )
        SELECT
          s.* EXCLUDE join_key,
          l.domain, l.subdomain, l.narrow,
          NULL::BOOLEAN AS pass,
          NULL::BOOLEAN AS verbal,
          NULL::BOOLEAN AS timed,
          'neurobehav' AS stream
        FROM src s
        LEFT JOIN lookup_neuropsych_scales l
          ON s.join_key = l.join_key AND l.stream = 'neurobehav'
      ", private$sql_join_key("b")))

      log_unmapped <- function(stream, base_table) {
        df <- DBI::dbGetQuery(self$con, sprintf("
          WITH src AS (
            SELECT *, %s AS join_key_norm FROM %s
          )
          SELECT CURRENT_TIMESTAMP AS ts,
                 '%s' AS stream,
                 join_key_norm AS join_key,
                 COUNT(*) AS n_rows
          FROM src
          WHERE domain IS NULL AND join_key_norm IS NOT NULL
          GROUP BY join_key_norm
          ORDER BY n_rows DESC, join_key_norm
        ", private$sql_join_key("src"), base_table, stream))

        if (nrow(df)) {
          if (!private$duckdb_has_relation(self$con, "unmapped_tests_log")) {
            DBI::dbExecute(self$con, "
              CREATE TABLE unmapped_tests_log(
                ts TIMESTAMP,
                stream TEXT,
                join_key TEXT,
                n_rows BIGINT
              )
            ")
          }
          duckdb::duckdb_register(self$con, "unmapped_tmp", df)
          on.exit(try(DBI::dbRemoveTable(self$con, "unmapped_tmp"), silent = TRUE), add = TRUE)
          DBI::dbExecute(self$con, "INSERT INTO unmapped_tests_log SELECT * FROM unmapped_tmp")
          warning(sprintf("[%s] %d unmapped key(s). Examples: %s. See table 'unmapped_tests_log'.",
                          stream, nrow(df), paste(head(df$join_key, 10), collapse = ", ")), call. = FALSE)
        }
      }

      log_unmapped("neurocog",   "neurocog")
      log_unmapped("neurobehav", "neurobehav")
      invisible(TRUE)
    },

    #' @description Create useful indexes on commonly-queried columns to speed up SQL operations.
    #' @return Invisibly returns TRUE on success.
    create_indexes = function() {
      idx <- c(
        "CREATE INDEX IF NOT EXISTS idx_neurocog_domain  ON neurocog(domain)",
        "CREATE INDEX IF NOT EXISTS idx_neurocog_test    ON neurocog(test)",
        "CREATE INDEX IF NOT EXISTS idx_neurocog_scale   ON neurocog(scale)",
        "CREATE INDEX IF NOT EXISTS idx_neurobehav_domain ON neurobehav(domain)",
        "CREATE INDEX IF NOT EXISTS idx_validity_domain   ON validity(domain)"
      )
      for (q in idx) try(self$execute(q), silent = TRUE)
      invisible(TRUE)
    }
  ),

  private = list(

    finalize = function() {
      self$disconnect()
    },

    get_duckdb_version = function() {
      tryCatch({
        version_result <- DBI::dbGetQuery(self$con, "SELECT version()")
        version_string <- version_result[[1]][1]
        version_match <- regmatches(version_string, regexpr("v[0-9.]+", version_string))
        version <- if (length(version_match) > 0) version_match else "unknown"
        platform <- paste(Sys.info()["sysname"], Sys.info()["machine"], sep = "_")
        platform <- tolower(gsub(" ", "_", platform))
        list(version = version, platform = platform, full = version_string)
      }, error = function(e) {
        list(version = "unknown", platform = "unknown", full = "unknown")
      })
    },

    install_extension_safe = function(ext_name, required = FALSE, description = "") {
      tryCatch({
        DBI::dbExecute(self$con, paste0("INSTALL '", ext_name, "'"))
        DBI::dbExecute(self$con, paste0("LOAD '", ext_name, "'"))
        message("✅ ", ext_name, " extension loaded successfully", if (nzchar(description)) paste0(" — ", description) else "")
        TRUE
      }, error = function(e) {
        if (required) {
          warning("Required extension ", ext_name, " failed to load: ", e$message)
        } else {
          message("⚠️  Optional extension ", ext_name, " not available: ", e$message)
        }
        FALSE
      })
    },

    setup_arrow_support = function() {
      if (!requireNamespace("arrow", quietly = TRUE)) {
        message("ℹ️  Arrow package not available - install with: install.packages('arrow')")
        return(FALSE)
      }
      tryCatch({
        test_data <- data.frame(test_col = 1:3)
        arrow_table <- arrow::as_arrow_table(test_data)
        duckdb::duckdb_register_arrow(self$con, "arrow_test", arrow_table)
        DBI::dbExecute(self$con, "DROP VIEW IF EXISTS arrow_test")
        TRUE
      }, error = function(e) {
        message("⚠️  Arrow integration test failed: ", e$message); FALSE
      })
    },

    register_arrow_via_r = function(file_path, table_name) {
      if (!requireNamespace("arrow", quietly = TRUE)) return(FALSE)
      tryCatch({
        arrow_table <- arrow::read_feather(file_path)
        duckdb::duckdb_register_arrow(self$con, table_name, arrow_table)
        self$tables[[table_name]] <- file_path
        message("✅ Registered ", table_name, " from ", basename(file_path), " (via R arrow)")
        TRUE
      }, error = function(e) {
        message("Failed to register Arrow file via R: ", e$message); FALSE
      })
    },

    # ---- Helper utilities used by bootstrap ----

    duckdb_has_relation = function(conn, name) {
      out <- tryCatch({
        DBI::dbGetQuery(conn, "
          SELECT table_name AS name FROM information_schema.tables WHERE table_schema = 'main'
          UNION ALL
          SELECT table_name AS name FROM information_schema.views  WHERE table_schema = 'main'
        ")
      }, error = function(e) data.frame(name = character(0)))
      name %in% out$name
    },

    get_lookup_df = function() {
      if (exists("lookup_neuropsych_scales", where = asNamespace("neuro2"), inherits = FALSE)) {
        get("lookup_neuropsych_scales", envir = asNamespace("neuro2"), inherits = FALSE)
      } else if (exists("lookup_neuropsych_scales")) {
        lookup_neuropsych_scales
      } else {
        stop("lookup_neuropsych_scales not found in neuro2 namespace.")
      }
    },

    sql_join_key = function(alias) {
      sprintf(
        "COALESCE(
           NULLIF(lower(trim(%1$s.scale)), ''),
           NULLIF(lower(trim(%1$s.test)), ''),
           NULLIF(lower(trim(%1$s.test_name)), '')
         )", alias
      )
    }
  )
)

#' Process neuropsych data using DuckDB
#'
#' @description High-level convenience wrapper to create a processor, optionally
#' process a domain or return a domain summary, then disconnect.
#' @param data_dir Directory containing CSV files.
#' @param domain Domain to process (optional).
#' @param output_dir Directory for output files (unused, reserved).
#' @return Processed data (domain) or a domain summary data.frame.
#' @export
process_with_duckdb <- function(data_dir = "data", domain = NULL, output_dir = "output") {
  processor <- DuckDBProcessorR6$new(data_dir = data_dir)
  on.exit(processor$disconnect(), add = TRUE)

  if (!is.null(domain)) {
    processor$process_domain(domain)
  } else {
    processor$get_domain_summary()
  }
}
