# File: R/neuro2-package.R

#' neuro2: Neuropsychological Assessment Report Generator
#'
#' @description
#' The neuro2 package provides a comprehensive toolkit for generating
#' neuropsychological assessment reports. It includes R6 classes for
#' processing cognitive and behavioral test data, generating publication-quality
#' tables and figures, and creating formatted reports using Quarto and Typst.
#'
#' @section Main Classes:
#' \describe{
#'   \item{\code{\link{DomainProcessorR6}}}{Process domain-specific assessment data}
#'   \item{\code{\link{DomainProcessorFactoryR6}}}{Factory for creating processors}
#'   \item{\code{\link{TableGTR6}}}{Generate formatted assessment tables}
#'   \item{\code{\link{DotplotR6}}}{Create domain-specific visualizations}
#'   \item{\code{\link{NeuropsychResultsR6}}}{Manage assessment results}
#' }
#'
#' @section Workflow Functions:
#' \describe{
#'   \item{\code{\link{create_patient_workspace}}}{Set up assessment workspace}
#'   \item{\code{\link{process_all_domains}}}{Process all assessment domains}
#'   \item{\code{\link{generate_assessment_report}}}{Create final report}
#' }
#'
#' @section Package Options:
#' \describe{
#'   \item{\code{neuro2.verbose}}{Show verbose output (default: TRUE)}
#'   \item{\code{neuro2.parallel}}{Use parallel processing (default: FALSE)}
#'   \item{\code{neuro2.output_dir}}{Default output directory (default: "output")}
#' }
#'
#' @docType package
#' @name neuro2-package
#' @aliases neuro2
#' @keywords internal
"_PACKAGE"

#' Create Patient Workspace
#'
#' @description
#' Sets up a complete workspace for neuropsychological assessment analysis.
#' Creates necessary directories, configuration files, and analysis scripts.
#'
#' @param patient_name Character string identifying the patient
#' @param age Numeric age in years (used to determine adult vs child protocols)
#' @param assessment_date Date of assessment (default: current date)
#' @param workspace_dir Directory to create workspace in (default: current directory)
#' @param data_files Named list of data file paths (optional)
#' @param config Custom configuration list (optional)
#'
#' @return Path to created workspace directory
#'
#' @examples
#' \dontrun{
#' # Basic setup
#' workspace <- create_patient_workspace("Isabella", age = 12)
#'
#' # With custom data files
#' workspace <- create_patient_workspace(
#'   "Isabella", 
#'   age = 12,
#'   data_files = list(
#'     neurocog = "path/to/cognitive_data.csv",
#'     neurobehav = "path/to/behavioral_data.csv"
#'   )
#' )
#' }
#'
#' @export
create_patient_workspace <- function(
  patient_name,
  age = NULL,
  assessment_date = Sys.Date(),
  workspace_dir = ".",
  data_files = NULL,
  config = NULL
) {
  
  # Validate inputs
  if (missing(patient_name) || is.null(patient_name) || nchar(patient_name) == 0) {
    stop("patient_name is required")
  }
  
  # Create clean patient identifier
  patient_id <- gsub("[^A-Za-z0-9_-]", "_", patient_name)
  
  # Create workspace directory
  workspace_path <- file.path(workspace_dir, paste0(patient_id, "_neuro"))
  if (!dir.exists(workspace_path)) {
    dir.create(workspace_path, recursive = TRUE)
  }
  
  # Create subdirectories
  subdirs <- c("data", "figs", "output", "tmp", "scripts")
  for (subdir in subdirs) {
    subdir_path <- file.path(workspace_path, subdir)
    if (!dir.exists(subdir_path)) {
      dir.create(subdir_path, recursive = TRUE)
    }
  }
  
  # Create configuration
  workspace_config <- list(
    patient = list(
      name = patient_name,
      id = patient_id,
      age = age,
      assessment_date = as.character(assessment_date),
      age_group = if (!is.null(age)) {
        if (age >= 18) "adult" else "child"
      } else "auto"
    ),
    data = list(
      input_dir = "data",
      output_dir = "output",
      format = "csv",
      files = data_files %||% list(
        neurocog = "neurocog.csv",
        neurobehav = "neurobehav.csv",
        validity = "validity.csv"
      )
    ),
    processing = list(
      verbose = getOption("neuro2.verbose", TRUE),
      parallel = getOption("neuro2.parallel", FALSE),
      generate_plots = TRUE,
      generate_tables = TRUE
    ),
    output = list(
      format = "typst",
      include_figures = TRUE,
      include_tables = TRUE,
      theme = "default"
    )
  )
  
  # Merge with custom config if provided
  if (!is.null(config)) {
    workspace_config <- modifyList(workspace_config, config)
  }
  
  # Write configuration
  config_path <- file.path(workspace_path, "config.yml")
  yaml::write_yaml(workspace_config, config_path)
  
  # Create main analysis script (FIXED VERSION)
  source("R/data_validation.R")  # Load the validation functions
  analysis_script <- create_fixed_analysis_script(patient_name, Sys.Date())
  
  # Write analysis script
  script_path <- file.path(workspace_path, "scripts", "run_analysis.R")
  writeLines(analysis_script, script_path)
  
  # Create data README
  data_readme <- '# Data Directory

## Required Files

Place your assessment data files here:

- `neurocog.csv` - Cognitive test results
- `neurobehav.csv` - Behavioral/emotional test results  
- `validity.csv` - Performance/symptom validity (optional)

## Data Format

CSV files should include these columns:
- `test_name` - Test battery name
- `scale` - Subtest or scale name
- `score` - Numerical score
- `percentile` - Percentile rank (0-100)
- `range` - Descriptive classification
- `domain` - Cognitive/behavioral domain

See package vignettes for detailed format specifications.
'
  
  writeLines(data_readme, file.path(workspace_path, "data", "README.md"))
  
  # Create .gitignore for workspace
  gitignore_content <- c(
    "# Patient data (keep private)",
    "data/*.csv",
    "data/*.xlsx", 
    "data/*.parquet",
    "",
    "# Generated outputs",
    "figs/",
    "output/*.pdf",
    "output/*.html",
    "tmp/",
    "",
    "# R specific", 
    ".Rhistory",
    ".RData",
    ".Ruserdata"
  )
  
  writeLines(gitignore_content, file.path(workspace_path, ".gitignore"))
  
  # Print setup summary
  message("✅ Patient workspace created: ", workspace_path)
  message("📋 Next steps:")
  message("   1. Copy data files to: ", file.path(workspace_path, "data"))
  message("   2. cd ", workspace_path)
  message("   3. Rscript scripts/run_analysis.R")
  
  invisible(workspace_path)
}

#' Process All Assessment Domains
#'
#' @description
#' Processes all available domains in the assessment data and generates
#' domain-specific outputs (tables, figures, QMD files).
#'
#' @param data_dir Directory containing assessment data files
#' @param age_group Age group for processing ("adult", "child", or "auto")
#' @param domains Specific domains to process (NULL for all available)
#' @param output_dir Directory for generated outputs
#' @param verbose Whether to show detailed progress messages
#'
#' @return List of processed domain results
#'
#' @examples
#' \dontrun{
#' # Process all domains
#' results <- process_all_domains("data", age_group = "child")
#'
#' # Process specific domains only
#' results <- process_all_domains(
#'   "data", 
#'   domains = c("iq", "memory", "adhd"),
#'   age_group = "child"
#' )
#' }
#'
#' @export
process_all_domains <- function(
  data_dir = "data",
  age_group = "auto", 
  domains = NULL,
  output_dir = "output",
  verbose = TRUE
) {
  
  if (verbose) {
    message("🔍 Discovering available domains in: ", data_dir)
  }
  
  # Create factory for domain processing
  factory <- DomainProcessorFactoryR6$new(
    config = list(
      data = list(
        neurocog = file.path(data_dir, "neurocog.csv"),
        neurobehav = file.path(data_dir, "neurobehav.csv"),
        validity = file.path(data_dir, "validity.csv"),
        output_dir = output_dir
      ),
      processing = list(verbose = verbose)
    )
  )
  
  # Get available domains
  if (is.null(domains)) {
    registry_info <- factory$get_registry_info()
    domains <- registry_info$domain_key
  }
  
  if (verbose) {
    message("📊 Processing ", length(domains), " domains: ", 
            paste(domains, collapse = ", "))
  }
  
  # Process domains
  results <- factory$batch_create(
    domain_keys = domains,
    age_group = age_group,
    include_multi_rater = TRUE
  )
  
  # Process each result
  processed_results <- list()
  
  for (domain_key in names(results)) {
    processor <- results[[domain_key]]
    
    if (is.null(processor)) {
      if (verbose) message("⚠️  Skipping ", domain_key, " (no data)")
      next
    }
    
    if (verbose) message("⚙️  Processing ", domain_key)
    
    # Handle multi-rater results
    if (is.list(processor) && !inherits(processor, "R6")) {
      # Multi-rater domain
      domain_results <- list()
      for (rater in names(processor)) {
        rater_processor <- processor[[rater]]
        if (!is.null(rater_processor)) {
          domain_results[[rater]] <- rater_processor$process(
            generate_domain_files = TRUE
          )
        }
      }
      processed_results[[domain_key]] <- domain_results
    } else {
      # Single processor
      processed_results[[domain_key]] <- processor$process(
        generate_domain_files = TRUE
      )
    }
  }
  
  if (verbose) {
    success_count <- length(processed_results)
    message("✅ Successfully processed ", success_count, " domains")
  }
  
  # Set class for S3 methods
  class(processed_results) <- c("neuro2_results", "list")
  
  return(processed_results)
}

#' Generate Assessment Report
#'
#' @description
#' Creates a complete neuropsychological assessment report from processed
#' domain results using Quarto and Typst.
#'
#' @param results Processed domain results from process_all_domains()
#' @param patient_info List with patient information (name, age, etc.)
#' @param output_dir Directory for report output
#' @param format Output format ("typst", "pdf", "html")
#' @param template Report template to use
#'
#' @return Path to generated report file
#'
#' @examples
#' \dontrun{
#' # Basic report generation
#' results <- process_all_domains("data")
#' report <- generate_assessment_report(
#'   results,
#'   patient_info = list(name = "Isabella", age = 12)
#' )
#' }
#'
#' @export
generate_assessment_report <- function(
  results,
  patient_info,
  output_dir = "output",
  format = "typst",
  template = NULL
) {
  
  if (!inherits(results, "neuro2_results")) {
    stop("results must be output from process_all_domains()")
  }
  
  message("📄 Generating assessment report for ", patient_info$name)
  
  # Ensure output directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Create report QMD file
  report_qmd <- file.path(output_dir, "assessment_report.qmd")
  
  # Generate report content
  report_content <- generate_report_content(results, patient_info, template)
  
  # Write QMD file
  writeLines(report_content, report_qmd)
  
  # Render report
  if (requireNamespace("quarto", quietly = TRUE)) {
    output_file <- quarto::quarto_render(
      report_qmd,
      output_format = format
    )
  } else {
    warning("quarto package not available. QMD file created but not rendered.")
    output_file <- report_qmd
  }
  
  message("✅ Report generated: ", output_file)
  return(output_file)
}

# S3 methods for neuro2_results
#' @export
print.neuro2_results <- function(x, ...) {
  cat("Neuropsychological Assessment Results\n")
  cat("=====================================\n\n")
  cat("Processed domains:", length(x), "\n")
  
  for (domain in names(x)) {
    cat("  •", domain, "\n")
  }
  
  invisible(x)
}

#' @export
summary.neuro2_results <- function(object, ...) {
  cat("Assessment Summary\n")
  cat("=================\n\n")
  
  # Count successful domains
  success_count <- sum(!sapply(object, is.null))
  total_count <- length(object)
  
  cat("Domains processed:", success_count, "/", total_count, "\n\n")
  
  # Domain details
  for (domain in names(object)) {
    result <- object[[domain]]
    if (!is.null(result)) {
      cat("✅", domain, "- processed successfully\n")
    } else {
      cat("❌", domain, "- processing failed\n")
    }
  }
  
  invisible(object)
}

# Helper function to generate report content
generate_report_content <- function(results, patient_info, template) {
  # This would generate the actual QMD content
  # Implementation depends on your specific template structure
  
  content <- c(
    "---",
    "title: 'Neuropsychological Assessment Report'",
    paste0("subtitle: '", patient_info$name, "'"),
    paste0("date: '", Sys.Date(), "'"),
    "format:",
    "  typst:",
    "    toc: true",
    "    margin: 0.79in",
    "    fontsize: 9pt",
    "---",
    "",
    "# Assessment Results",
    "",
    "This report presents the results of a comprehensive neuropsychological assessment.",
    ""
  )
  
  # Add domain includes
  domain_includes <- character()
  for (domain in names(results)) {
    if (!is.null(results[[domain]])) {
      # Look for generated QMD files
      qmd_files <- list.files(
        pattern = paste0(".*", domain, ".*\\.qmd$"),
        full.names = FALSE
      )
      
      for (qmd_file in qmd_files) {
        domain_includes <- c(domain_includes, paste0("{{< include ", qmd_file, " >}}"))
      }
    }
  }
  
  content <- c(content, domain_includes)
  
  return(content)
}