#' Neuro2MainR6 Class
#'
#' @title High-level facade for neuro2 workflow
#' @description A thin R6 facade mirroring \code{MainOrchestratorR6} that offers a
#'   simplified public interface for common operations (setup, load, process, report).
#'
#' @docType class
#' @name Neuro2MainR6
#' @format An R6 class generator object.
#'
#' @section Methods:
#' \describe{
#'   \item{\code{$initialize(config_file = "config.yml", variables_file = NULL, verbose = TRUE)}}{Create a new facade instance.}
#'   \item{\code{$setup()}}{Initialize dependencies and internal components.}
#'   \item{\code{$check_environment()}}{Verify required packages and configuration.}
#'   \item{\code{$load_data(data_dir = "data-raw/csv", use_duckdb = TRUE, output_format = c("parquet","arrow","csv"))}}{Load or register datasets.}
#'   \item{\code{$process_domains(domains = NULL, age_group = c("child","adult"), include_multi_rater = TRUE)}}{Process requested domains.}
#'   \item{\code{$process_single_domain(processor = NULL, domain_key = NULL, rater = NULL)}}{Process a single domain.}
#'   \item{\code{$generate_report(template = "template.qmd", output_file = NULL, format = c("pdf","html","docx"))}}{Render the report.}
#'   \item{\code{$run_full_workflow(domains = NULL, age_group = NULL, load_data = TRUE, generate_report = TRUE)}}{Run the end-to-end workflow.}
#'   \item{\code{$detect_age_group()}}{Infer age group if not provided.}
#'   \item{\code{$validate_domains(domains)}}{Check domain keys against available data.}
#'   \item{\code{$show_summary()}}{Print a summary of processing and outputs.}
#'   \item{\code{$get_available_domains()}}{List available domains detected.}
#'   \item{\code{$get_status()}}{Return current status as a structured list.}
#' }
#'
#' @section Parameters (for methods above):
#' \describe{
#'   \item{\code{config_file}}{Path to YAML/JSON config.}
#'   \item{\code{variables_file}}{Optional path to variables YAML/JSON.}
#'   \item{\code{verbose}}{Logical; when \code{TRUE}, print progress.}
#'   \item{\code{data_dir}}{Directory containing input data.}
#'   \item{\code{use_duckdb}}{Logical; when \code{TRUE}, use DuckDB backend.}
#'   \item{\code{output_format}}{Preferred normalized storage: \code{"parquet"}, \code{"arrow"}, or \code{"csv"}.}
#'   \item{\code{domains}}{Character vector of domains to process.}
#'   \item{\code{age_group}}{Either \code{"child"} or \code{"adult"}.}
#'   \item{\code{include_multi_rater}}{Logical; include multi-rater behavioral measures if \code{TRUE}.}
#'   \item{\code{processor}}{Optional domain processor instance.}
#'   \item{\code{domain_key}}{Domain key/name to process.}
#'   \item{\code{rater}}{Optional rater ID (e.g., \code{"self"}, \code{"parent"}, \code{"teacher"}).}
#'   \item{\code{template}}{Path to Quarto/Typst template.}
#'   \item{\code{output_file}}{Optional explicit report output path.}
#'   \item{\code{format}}{Output format, typically one of \code{"pdf"}, \code{"html"}, or \code{"docx"}.}
#'   \item{\code{load_data}}{Logical; when \code{TRUE}, load/register data inside \code{$run_full_workflow()}.}
#'   \item{\code{generate_report}}{Logical; when \code{TRUE}, render the report inside \code{$run_full_workflow()}.}
#' }
#'
#' @return
#' Methods return the facade invisibly for chaining; queries return vectors/data frames
#' or lists describing the current state.
#'
#' @examples
#' \dontrun{
#' n2 <- Neuro2MainR6$new(config_file = "config.yml")
#' n2$setup()
#' n2$run_full_workflow(domains = c("memory","attention"))
#' }
#'
#' @export
NULL
