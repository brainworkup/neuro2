#' DuckDBProcessorR6 Class
#'
#' @title DuckDB-backed data processor for neuro2
#' @description An R6 class that manages a DuckDB connection and provides helpers
#'   to register CSV/Parquet/Arrow data sources, run queries (eager and lazy),
#'   compute simple statistics, and export data. This block documents the class
#'   that is defined elsewhere (do not edit that file). Place this file in \code{R/}
#'   so roxygen2 can generate documentation without modifying the original source.
#'
#' @docType class
#' @name DuckDBProcessorR6
#' @format An R6 class generator object.
#'
#' @section Public fields:
#' \describe{
#'   \item{\code{available_extensions}}{Character vector of DuckDB extensions detected
#'     or enabled by the processor (e.g., "httpfs", "parquet", "json").}
#' }
#'
#' @section Methods:
#' \describe{
#'   \item{\code{$initialize(db_path = NULL, data_dir = ".", auto_register = TRUE)}}{Create a new processor.
#'     If \code{db_path} is \code{NULL}, an in-memory/temporary DB is used. When
#'     \code{auto_register} is \code{TRUE}, common datasets in \code{data_dir} may be registered.}
#'   \item{\code{$connect()}}{Open (or reopen) the DuckDB connection.}
#'   \item{\code{$disconnect()}}{Safely close the DuckDB connection.}
#'   \item{\code{$register_csv(file_path, table_name, options = list())}}{Register a CSV file
#'     as a DuckDB table (optionally pass read options, e.g., \code{delim}, \code{header}).}
#'   \item{\code{$register_parquet(file_path, table_name)}}{Register a Parquet file or directory
#'     as a DuckDB table (uses the parquet scanner).}
#'   \item{\code{$register_arrow(file_path, table_name)}}{Register an Arrow/Feather file or dataset.}
#'   \item{\code{$register_all_csvs(data_dir = ".", pattern = "\\\\.(csv|tsv)$")}}{Register all CSV/TSV files
#'     in a directory that match \code{pattern}.}
#'   \item{\code{$register_all_files(data_dir = ".", formats = c("csv","tsv","parquet","feather"))}}{Register all supported
#'     data files in \code{data_dir}.}
#'   \item{\code{$export_to_parquet(table_name, output_path, compression = "zstd")}}{Export a DuckDB table to a Parquet file.}
#'   \item{\code{$query(query, params = NULL)}}{Run a SQL query and return a data frame result (eager).}
#'   \item{\code{$execute(statement, params = NULL)}}{Execute a SQL statement (e.g., \code{CREATE}, \code{INSERT}); returns invisibly.}
#'   \item{\code{$query_lazy(table_name)}}{Return a lazy table (e.g., \pkg{dbplyr}/\pkg{dplyr} compatible) for \code{table_name}.}
#'   \item{\code{$process_domain(domain, data_type = c("neurocognitive","neurobehavioral"), scales = NULL)}}{Domain-specific
#'     processing helper that prepares/filters/joins the relevant tables for downstream reporting.}
#'   \item{\code{$calculate_z_stats(table_name, group_vars = NULL)}}{Compute basic z-score statistics by groups if provided.}
#'   \item{\code{$export_to_r6(domain, processor_class)}}{Export a prepared domain dataset into another R6 processor instance.}
#'   \item{\code{$get_domain_summary(include_all = FALSE)}}{Return a short summary list/data frame for the domains detected/processed.}
#'   \item{\code{$create_indexes()}}{Create useful indexes on common join/filter columns to speed up queries.}
#' }
#'
#' @details
#' This documentation topic exists separately from the class definition to satisfy
#' roxygen2's R6 method/field documentation checks without modifying the original code file.
#' The processor wraps \pkg{duckdb} / \pkg{DBI} and often integrates with \pkg{dplyr}/\pkg{dbplyr}
#' for lazy querying. Registration helpers typically use \code{duckdb_register()} or virtual tables.
#'
#' @section Parameters (for methods above):
#' \describe{
#'   \item{\code{db_path}}{Path to a DuckDB database file. Use \code{NULL} for temporary/in-memory.}
#'   \item{\code{data_dir}}{Directory containing input data files to auto-register or scan.}
#'   \item{\code{auto_register}}{Logical; if \code{TRUE}, attempt to auto-register common files on init.}
#'   \item{\code{file_path}}{Path to a single data file (CSV/TSV/Parquet/Feather/Arrow).}
#'   \item{\code{table_name}}{Name of the DuckDB table to create/register or reference.}
#'   \item{\code{options}}{List of reader options for CSV/TSV registration (e.g., \code{delim}, \code{na}, \code{header}).}
#'   \item{\code{pattern}}{File name pattern (regular expression) used when bulk-registering CSV/TSV files.}
#'   \item{\code{formats}}{Character vector of file formats to search for during bulk registration.}
#'   \item{\code{output_path}}{Path to write Parquet output (file or directory).}
#'   \item{\code{compression}}{Compression codec for Parquet writes (e.g., \code{"zstd"}, \code{"snappy"}).}
#'   \item{\code{query}}{SQL query string for eager results.}
#'   \item{\code{statement}}{SQL statement string for non-query operations.}
#'   \item{\code{params}}{Optional named list of parameter bindings for parameterized SQL.}
#'   \item{\code{domain}}{Domain key/name to process (e.g., \code{"attention"}, \code{"executive"}).}
#'   \item{\code{data_type}}{Either \code{"neurocognitive"} or \code{"neurobehavioral"}.}
#'   \item{\code{scales}}{Optional character vector of scale IDs or names to include.}
#'   \item{\code{group_vars}}{Optional character vector of grouping variables for z-score summaries.}
#'   \item{\code{processor_class}}{R6 generator or instance that will receive exported data.}
#'   \item{\code{include_all}}{Logical; when \code{TRUE}, include all known domains in the summary.}
#' }
#'
#' @return
#' Unless otherwise stated, methods return the processor invisibly (for chaining) or
#' a data frame (for eager \code{$query()}) or a lazy table/tbl_dbi (\code{$query_lazy()}).
#'
#' @seealso \pkg{duckdb}, \pkg{DBI}, \pkg{dbplyr}, \pkg{dplyr}
#'
#' @examples
#' \dontrun{
#' p <- DuckDBProcessorR6$new(db_path = NULL, data_dir = "data-raw/csv", auto_register = TRUE)
#' p$connect()
#' p$register_csv("data-raw/csv/wisc5.csv", "wisc5")
#' df <- p$query("SELECT * FROM wisc5 LIMIT 5")
#' p$disconnect()
#' }
#'
#' @export
NULL
