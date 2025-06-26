#' NeuropsychReportSystemR6 Class
#'
#' An R6 class that orchestrates the entire neuropsychological report generation system.
#' This class coordinates utilities, template management, domain processing, and report generation.
#'
#' @field config Configuration parameters for the report system.
#' @field utilities ReportUtilitiesR6 object for utility functions.
#' @field template_manager ReportTemplateR6 object for template management.
#' @field content_manager TemplateContentManagerR6 object for content files.
#' @field domain_processors List of DomainProcessorR6 objects for different domains.
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize the report system with configuration.}
#'   \item{setup_environment}{Set up the environment for report generation.}
#'   \item{prepare_data}{Prepare data files for report generation.}
#'   \item{generate_domain_files}{Generate domain-specific QMD files.}
#'   \item{generate_report}{Generate the complete report.}
#' }
#'
#' @importFrom R6 R6Class
#' @export
NeuropsychReportSystemR6 <- R6::R6Class(
  classname = "NeuropsychReportSystemR6",
  public = list(
    config = NULL,
    utilities = NULL,
    template_manager = NULL,
    content_manager = NULL,
    domain_processors = NULL,

    #' @description
    #' Initialize a new NeuropsychReportSystemR6 object with configuration.
    #'
    #' @param config List of configuration parameters.
    #' @param template_dir Directory containing template files.
    #' @param output_dir Directory for output files.
    #'
    #' @return A new NeuropsychReportSystemR6 object
    initialize = function(
      config = list(),
      template_dir = "inst/extdata/_extensions",
      output_dir = "output"
    ) {
      # Set default config values if not provided
      default_config <- list(
        patient_name = "Patient",
        domains = c(
          "General Cognitive Ability",
          "Verbal",
          "Spatial",
          "Memory",
          "Attention/Executive",
          "ADHD",
          c(
            "Psychiatric Disorders",
            "Personality Disorders",
            "Substance Use",
            "Psychosocial Problems",
            "Behavioral/Emotional/Social",
            "Emotional/Behavioral/Personality"
          )
        ),
        data_files = list(
          neurocog = "data-raw/neurocog.csv",
          neurobehav = "data-raw/neurobehav.csv",
          neuropsych = "data-raw/neuropsych.csv",
          validity = "data-raw/validity.csv"
        ),
        template_file = "template.qmd",
        output_file = "neuropsych_report.pdf"
      )

      # Merge provided config with defaults
      self$config <- modifyList(default_config, config)

      # Initialize component classes
      self$utilities <- structure(list(), class = "ReportUtilitiesR6") # Placeholder
      self$template_manager <- ReportTemplateR6$new(
        template_dir = template_dir,
        output_dir = output_dir
      )
      self$content_manager <- structure(
        list(template_dir = template_dir, get_content = function(file_name) {
          file_path <- file.path(template_dir, file_name)
          if (file.exists(file_path)) {
            return(readLines(file_path, warn = FALSE))
          } else {
            warning("Content file not found: ", file_name)
            return(NULL)
          }
        }),
        class = "TemplateContentManagerR6"
      ) # Placeholder

      # Initialize domain processors
      self$domain_processors <- list()
      for (domain in self$config$domains) {
        domain_key <- gsub(" ", "_", tolower(domain))
        self$domain_processors[[domain_key]] <- DomainProcessorR6$new(
          domains = domain,
          pheno = domain_key,
          input_file = self$config$data_files$neurocog
        )
      }
    },

    #' @description
    #' Set up the environment for report generation.
    #'
    #' @param install_deps Whether to install dependencies.
    #' @return Invisibly returns self for method chaining.
    setup_environment = function(install_deps = FALSE) {
      # Load required packages
      packages <- c(
        "dplyr",
        "glue",
        "gt",
        "here",
        "janitor",
        "knitr",
        "purrr",
        "quarto",
        "readr",
        "readxl",
        "rmarkdown",
        "stringr",
        "tidyr",
        "NeurotypR",
        "NeurotypR"
      )

      for (pkg in packages) {
        if (!requireNamespace(pkg, quietly = TRUE)) {
          if (install_deps) {
            install.packages(pkg)
          } else {
            warning("Package not available: ", pkg)
          }
        }
        library(pkg, character.only = TRUE)
      }

      # Set environment variables
      Sys.setenv(PATIENT = self$config$patient_name)

      invisible(self)
    },

    #' @description
    #' Prepare data files for report generation.
    #'
    #' @param input_dir Directory containing input data files.
    #' @param output_dir Directory for output data files.
    #' @return Invisibly returns self for method chaining.
    prepare_data = function(input_dir = "data/csv", output_dir = "data") {
      # Check if output directory exists
      if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
      }

      # If the data files already exist, skip preparation
      if (all(file.exists(unlist(self$config$data_files)))) {
        message("Data files already exist, skipping preparation")
        return(invisible(self))
      }

      # This would call the prepare_data_files function from ReportUtilitiesR6
      # For now, just show a message
      message("Preparing data files from ", input_dir, " to ", output_dir)

      invisible(self)
    },

    #' @description
    #' Generate domain-specific QMD files for the report.
    #'
    #' @param domains List of domains to generate files for (default: all configured domains).
    #' @return Invisibly returns self for method chaining.
    generate_domain_files = function(domains = NULL) {
      # Use configured domains if none specified
      if (is.null(domains)) {
        domains <- self$config$domains
      }

      # Generate domain files for each domain
      for (domain in domains) {
        domain_key <- gsub(" ", "_", tolower(domain))
        if (domain_key %in% names(self$domain_processors)) {
          processor <- self$domain_processors[[domain_key]]

          # Process the domain data
          processor$load_data()
          processor$filter_by_domain()
          processor$select_columns()
          processor$save_data()

          # Generate domain QMD files
          domain_file <- paste0("_02-01_", domain_key, ".qmd")
          text_file <- paste0("_02-01_", domain_key, "_text.qmd")

          message("Generating domain files for: ", domain)
          message("  - ", domain_file)
          message("  - ", text_file)

          # This would call the generate_domain_qmd and generate_domain_text_qmd methods
          # For now, just generate simple placeholder files if they don't exist
          if (!file.exists(domain_file)) {
            cat(
              paste0(
                "## ",
                domain,
                " {#sec-",
                domain_key,
                "}\n\n",
                "{{< include _02-01_",
                domain_key,
                "_text.qmd >}}\n\n"
              ),
              file = domain_file
            )
          }

          if (!file.exists(text_file)) {
            # Generate text file using NeuropsychResultsR6
            filtered_data <- processor$filter_by_test("self_report")
            if (!is.null(filtered_data) && nrow(filtered_data) > 0) {
              results_obj <- NeuropsychResultsR6$new(
                data = filtered_data,
                file = text_file
              )
              results_obj$process()
            } else {
              # Create placeholder if no data
              cat(
                "<summary>\n\nPlaceholder summary for ",
                domain,
                ".\n\n</summary>",
                file = text_file
              )
            }
          }
        } else {
          warning("No processor configured for domain: ", domain)
        }
      }

      invisible(self)
    },

    #' @description
    #' Generate the complete neuropsychological report.
    #'
    #' @param template_file Template file to use (default: from config).
    #' @param output_file Output file for the report (default: from config).
    #' @param variables List of variables to use in the template.
    #' @return Invisibly returns self for method chaining.
    generate_report = function(
      template_file = NULL,
      output_file = NULL,
      variables = NULL
    ) {
      # Use configured values if not specified
      if (is.null(template_file)) {
        template_file <- self$config$template_file
      }
      if (is.null(output_file)) {
        output_file <- self$config$output_file
      }

      # Use default variables from config if not specified
      if (is.null(variables)) {
        variables <- list(
          patient = self$config$patient_name,
          # Add other variables as needed
          date_of_report = format(Sys.Date(), "%Y-%m-%d")
        )
      }

      # Generate template with ReportTemplateR6
      message("Generating report template: ", template_file)
      self$template_manager$variables <- variables
      self$template_manager$generate_template(template_file)

      # Render the report
      message("Rendering report to: ", output_file)
      self$template_manager$render_report(
        input_file = template_file,
        output_file = output_file
      )

      invisible(self)
    },

    #' @description
    #' Run the complete report generation workflow.
    #'
    #' @param setup Whether to set up the environment.
    #' @param prepare_data Whether to prepare data files.
    #' @param domains List of domains to include (default: all configured domains).
    #' @return Invisibly returns self for method chaining.
    run_workflow = function(setup = TRUE, prepare_data = TRUE, domains = NULL) {
      if (setup) {
        self$setup_environment()
      }

      if (prepare_data) {
        self$prepare_data()
      }

      # Generate domain files
      self$generate_domain_files(domains)

      # Generate and render report
      self$generate_report()

      message("Report generation workflow completed")
      invisible(self)
    }
  )
)

#' Generate Complete Neuropsychological Report (Function Wrapper)
#'
#' This function encapsulates the entire workflow for generating neuropsychological reports.
#' It's a wrapper around the NeuropsychReportSystemR6 class.
#'
#' @param patient_name Patient's name for the report.
#' @param domains List of domains to include in the report.
#' @param data_files List of paths to data files.
#' @param template_dir Directory containing template files.
#' @param output_dir Directory for output files.
#' @param template_file Template file to use.
#' @param output_file Output file for the report.
#' @param setup Whether to set up the environment.
#' @param prepare_data Whether to prepare data files.
#'
#' @return Invisibly returns the NeuropsychReportSystemR6 object.
#' @export
#' @rdname generate_neuropsych_report_system
generate_neuropsych_report_system <- function(
  patient_name,
  domains = c(
    "General Cognitive Ability",
    "ADHD",
    "Memory",
    "Executive Functions"
  ),
  data_files = list(
    neurocog = "data-raw/neurocog.csv",
    neurobehav = "data-raw/neurobehav.csv",
    neuropsych = "data-raw/neuropsych.csv",
    validity = "data-raw/validity.csv"
  ),
  template_dir = "inst/extdata/_extensions/brainworkup",
  output_dir = "output",
  template_file = "template.qmd",
  output_file = "neuropsych_report.pdf",
  setup = TRUE,
  prepare_data = TRUE
) {
  # Create configuration
  config <- list(
    patient_name = patient_name,
    domains = domains,
    data_files = data_files,
    template_file = template_file,
    output_file = output_file
  )

  # Create report system
  report_system <- NeuropsychReportSystemR6$new(
    config = config,
    template_dir = template_dir,
    output_dir = output_dir
  )

  # Run the workflow
  report_system$run_workflow(setup = setup, prepare_data = prepare_data)

  invisible(report_system)
}
