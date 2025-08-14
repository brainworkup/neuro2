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
    initialize = function(config = list(),
                          template_dir = "inst/quarto/_extensions/brainworkup",
                          output_dir = "output") {
      # Set default config values if not provided
      default_config <- list(
        patient = "Biggie",
        domains = c(
          "domain_iq",
          "domain_academics",
          "domain_verbal",
          "domain_spatial",
          "domain_memory",
          "domain_executive",
          "domain_motor",
          "domain_social",
          "domain_adhd_adult",
          "domain_adhd_child",
          "domain_emotion_adult",
          "domain_emotion_child",
          "domain_adaptive",
          "domain_daily_living"
        ),
        data_files = list(
          neurocog = "data/neurocog.parquet",
          neurobehav = "data/neurobehav.parquet",
          neuropsych = "data/neuropsych.parquet",
          validity = "data/validity.parquet"
        ),
        template_file = "template.qmd",
        output_file = "neuropsych_report.pdf"
      )

      # Merge provided config with defaults
      self$config <- modifyList(default_config, config)

      # Generate dynamic output filename if not explicitly provided
      if (
        !("output_file" %in% names(config)) ||
          config$output_file == "neuropsych_report.pdf" ||
          is.null(config$output_file)
      ) {
        # Try to read patient info from _variables.yml
        variables_file <- "_variables.yml"
        if (file.exists(variables_file)) {
          tryCatch(
            {
              # Read YAML file
              variables <- yaml::read_yaml(variables_file)

              # Extract names
              first_name <- variables$first_name
              last_name <- variables$last_name

              # Clean names for filename (remove special characters)
              first_name <- gsub("[^A-Za-z0-9]", "", first_name)
              last_name <- gsub("[^A-Za-z0-9]", "", last_name)

              # Generate filename with current date
              date_str <- format(Sys.Date(), "%Y-%m-%d")

              if (
                !is.null(last_name) &&
                  !is.null(first_name) &&
                  nchar(last_name) > 0 &&
                  nchar(first_name) > 0
              ) {
                self$config$output_file <- paste0(
                  last_name,
                  "-",
                  first_name,
                  "_neuropsych_report_",
                  date_str,
                  ".pdf"
                )
                message("Output file will be: ", self$config$output_file)
              }
            },
            error = function(e) {
              warning(
                "Could not read patient info from _variables.yml: ",
                e$message
              )
            }
          )
        }
      }

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
      # Flatten domains in case some are vectors (like domain_emotion_adult)
      flat_domains <- unlist(self$config$domains)

      # Define domain to pheno mapping based on create_sysdata.R
      domain_pheno_map <- list(
        "General Cognitive Ability" = "iq",
        "Academic Skills" = "academics",
        "Verbal/Language" = "verbal",
        "Visual Perception/Construction" = "spatial",
        "Memory" = "memory",
        "Attention/Executive" = "executive",
        "Motor" = "motor",
        "Social Cognition" = "social",
        "ADHD" = "adhd",
        "Psychiatric Disorders" = "emotion",
        "Personality Disorders" = "emotion",
        "Substance Use" = "emotion",
        "Psychosocial Problems" = "emotion",
        "Behavioral/Emotional/Social" = "emotion",
        "Emotional/Behavioral/Personality" = "emotion",
        "Adaptive Functioning" = "adaptive",
        "Daily Living" = "daily_living"
      )

      # Determine the appropriate data file based on domain type
      for (domain in flat_domains) {
        # Get proper pheno name from mapping, or create a safe default
        pheno <- domain_pheno_map[[domain]]
        if (is.null(pheno)) {
          # Fallback: create safe pheno from domain name
          pheno <- gsub("[/ ]", "_", tolower(domain))
        }

        # Select appropriate input file based on domain type using the domain_pheno_map
        # This is more maintainable than hardcoding specific domain names
        pheno <- domain_pheno_map[[domain]]

        # Create a mapping of data file types based on domain categories
        # This is more maintainable than hardcoding specific phenotypes
        data_file_mapping <- list(
          # Cognitive domains
          "iq" = "neurocog",
          "academics" = "neurocog",
          "verbal" = "neurocog",
          "spatial" = "neurocog",
          "memory" = "neurocog",
          "executive" = "neurocog",
          "motor" = "neurocog",
          "social" = "neurocog",
          "daily_living" = "neurocog",

          # Behavioral/emotional domains
          "adhd" = "neurobehav",
          "emotion" = "neurobehav",
          "adaptive" = "neurobehav",
          "social" = "neurobehav",

          # Validity domains
          "validity" = "validity"
        )

        # Determine which file to use based on phenotype
        if (is.null(pheno)) {
          # Default to neurocog for unknown domains
          input_file <- self$config$data_files$neurocog
        } else if (pheno == "social") {
          # Special handling for social cognition which has both neurocognitive and behavioral measures
          # For social cognition, we need to check the domain name to determine which file to use

          # If domain contains behavioral keywords, use neurobehav
          if (
            grepl(
              "behavioral|rating|scale|questionnaire|social skill",
              tolower(domain),
              ignore.case = TRUE
            )
          ) {
            input_file <- self$config$data_files$neurobehav
          } else {
            # Default to neurocog for cognitive measures of social cognition
            input_file <- self$config$data_files$neurocog
          }
        } else {
          # Look up the file type in the mapping
          file_type <- data_file_mapping[[pheno]]

          # If not found in mapping, default to neurocog
          if (is.null(file_type)) {
            file_type <- "neurocog"
          }

          input_file <- self$config$data_files[[file_type]]
        }

        self$domain_processors[[pheno]] <- DomainProcessorR6$new(
          domains = domain,
          pheno = pheno,
          input_file = input_file
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
        "tidyr"
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
      Sys.setenv(PATIENT = self$config$patient)

      invisible(self)
    },

    #' @description
    #' Prepare data files for report generation.
    #'
    #' @param input_dir Directory containing input data files.
    #' @param output_dir Directory for output data files.
    #' @return Invisibly returns self for method chaining.
    prepare_data = function(input_dir = "data-raw", output_dir = "data") {
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
    #' @param data_dir Directory containing CSV data files (default: "data-raw/csv/").
    #' @return Invisibly returns self for method chaining.
    generate_domain_files = function(domains = NULL,
                                     data_dir = "data-raw/csv/") {
      # If domains not specified, extract from actual data
      if (is.null(domains)) {
        # Extract domains from CSV files
        csv_files <- list.files(
          data_dir,
          pattern = "\\.csv$",
          full.names = TRUE
        )
        all_domains <- character()

        for (file in csv_files) {
          data <- readr::read_csv(file, show_col_types = FALSE)
          if ("domain" %in% names(data)) {
            all_domains <- c(all_domains, unique(data$domain))
          }
        }

        domains <- unique(all_domains)
        message("Found ", length(domains), " unique domains in data")
      }

      # Flatten domains in case some are vectors
      flat_domains <- unlist(domains)

      # Define canonical domain order with adult/child variants
      # Each entry can be a string or a list with 'domain' and 'variant'
      domain_config <- list(
        list(domain = "General Cognitive Ability", number = "01", pheno = "iq"),
        list(domain = "Academic Skills", number = "02", pheno = "academics"),
        list(domain = "Verbal/Language", number = "03", pheno = "verbal"),
        list(
          domain = "Visual Perception/Construction",
          number = "04",
          pheno = "spatial"
        ),
        list(domain = "Memory", number = "05", pheno = "memory"),
        list(
          domain = "Attention/Executive",
          number = "06",
          pheno = "executive"
        ),
        list(domain = "Motor", number = "07", pheno = "motor"),
        list(domain = "Social Cognition", number = "08", pheno = "social"),
        # ADHD has adult/child variants
        list(
          domain = "ADHD",
          number = "09",
          pheno = "adhd",
          variants = c("adult", "child")
        ),
        # Emotion domains all map to same number with adult/child variants
        list(
          domain = c(
            "Emotional/Behavioral/Personality",
            "Behavioral/Emotional/Social",
            "Psychiatric Disorders",
            "Personality Disorders",
            "Substance Use",
            "Psychosocial Problems"
          ),
          number = "10",
          pheno = "emotion",
          variants = c("adult", "child")
        ),
        list(
          domain = "Adaptive Functioning",
          number = "11",
          pheno = "adaptive"
        ),
        list(domain = "Daily Living", number = "12", pheno = "daily_living"),
        list(domain = "Symptom Validity", number = "13", pheno = "validity")
      )

      # Determine patient type (adult/child) based on data or config
      # This could be enhanced to detect from actual test data
      patient_type <- "adult" # Default to adult, could be parameterized

      # Process domains according to configuration
      generated_files <- character()

      for (config in domain_config) {
        # Get all domain names for this config
        domain_names <- if (is.character(config$domain)) {
          config$domain
        } else {
          unlist(config$domain)
        }

        # Check if any of these domains exist in the data
        matching_domains <- intersect(domain_names, flat_domains)

        if (length(matching_domains) > 0) {
          # Determine variant to use
          variant_suffix <- ""
          if (!is.null(config$variants) && patient_type %in% config$variants) {
            variant_suffix <- paste0("_", patient_type)
          }

          # Generate file names
          pheno_name <- paste0(config$pheno, variant_suffix)
          domain_file <- paste0("_02-", config$number, "_", pheno_name, ".qmd")
          text_file <- paste0(
            "_02-",
            config$number,
            "_",
            pheno_name,
            "_text.qmd"
          )

          # Get the processor for this phenotype
          if (config$pheno %in% names(self$domain_processors)) {
            processor <- self$domain_processors[[config$pheno]]

            # Update processor domains to include all matching domains
            processor$domains <- matching_domains

            # Process the domain data
            if (!is.null(processor$input_file)) {
              file_ext <- tools::file_ext(processor$input_file)

              if (file_ext %in% c("parquet", "feather")) {
                # Load data using appropriate method
                if (file_ext == "parquet") {
                  processor$data <- arrow::read_parquet(processor$input_file)
                } else if (file_ext == "feather") {
                  processor$data <- arrow::read_feather(processor$input_file)
                }
                processor$filter_by_domain()
                processor$select_columns()
                processor$save_data()
              } else {
                # Standard CSV processing
                processor$load_data()
                processor$filter_by_domain()
                processor$select_columns()
                processor$save_data()
              }
            }

            message(
              "Generating domain files for: ",
              paste(matching_domains, collapse = ", ")
            )
            message("  - ", domain_file)
            message("  - ", text_file)

            # Generate the domain QMD file
            domain_title <- matching_domains[1] # Use first matching domain as title
            cat(
              paste0(
                "## ",
                domain_title,
                " {#sec-",
                config$pheno,
                "}\n\n",
                "{{< include ",
                text_file,
                " >}}\n\n",
                "```{r}\n",
                "#| label: data-",
                pheno_name,
                "\n",
                "#| include: false\n\n",
                "# Domain-specific data is loaded here if needed\n",
                "# The domain processor has already prepared the data\n",
                "```\n\n",
                "```{r}\n",
                "#| label: table-",
                pheno_name,
                "\n",
                "#| tbl-cap: \"",
                domain_title,
                " Test Results\"\n",
                "#| echo: false\n\n",
                "# Table generation code here\n",
                "# This would use the processed data for this domain\n",
                "```\n"
              ),
              file = domain_file
            )

            # Generate text file
            filtered_data <- processor$filter_by_test("self")
            if (!is.null(filtered_data) && nrow(filtered_data) > 0) {
              if (exists("NeuropsychResultsR6")) {
                results_obj <- NeuropsychResultsR6$new(
                  data = filtered_data,
                  file = text_file
                )
                results_obj$process()
              } else {
                cat(
                  "<summary>\n\n",
                  "Results for ",
                  domain_title,
                  " domain.\n\n",
                  "</summary>",
                  file = text_file
                )
              }
            } else {
              cat(
                "<summary>\n\n",
                "No data available for ",
                domain_title,
                " domain.\n\n",
                "</summary>",
                file = text_file
              )
            }

            generated_files <- c(generated_files, domain_file)
          } else {
            warning("No processor configured for phenotype: ", config$pheno)
          }
        }
      }

      message("\nGenerated ", length(generated_files), " domain files")
      invisible(self)
    },

    #' @description
    #' Generate the complete neuropsychological report.
    #'
    #' @param template_file Template file to use (default: from config).
    #' @param output_file Output file for the report (default: from config).
    #' @param variables List of variables to use in the template.
    #' @return Invisibly returns self for method chaining.
    generate_report = function(template_file = NULL,
                               output_file = NULL,
                               variables = NULL) {
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
          patient = self$config$patient,
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
#' @param patient Patient's name for the report.
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
  patient,
  domains = c(
    "domain_iq",
    "domain_academics",
    "domain_verbal",
    "domain_spatial",
    "domain_memory",
    "domain_executive",
    "domain_motor",
    "domain_social",
    "domain_adhd_adult",
    "domain_emotion_adult",
    "domain_adhd_child",
    "domain_emotion_child",
    "domain_adaptive",
    "domain_daily_living"
  ),
  data_files = list(
    neurocog = "data/neurocog.csv",
    neurobehav = "data/neurobehav.csv",
    neuropsych = "data/neuropsych.csv",
    validity = "data/validity.csv"
  ),
  template_dir = "inst/quarto/_extensions/brainworkup",
  output_dir = "output",
  template_file = "template.qmd",
  output_file = "neuropsych_report.pdf",
  setup = TRUE,
  prepare_data = TRUE
) {
  # Create configuration
  config <- list(
    patient = patient,
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
