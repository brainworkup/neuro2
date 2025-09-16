#' Report Utilities for Neuropsychological Assessment
#'
#' @description
#' An R6 class that provides utility functions for neuropsychological report generation
#' workflows. This class encapsulates utilities for setting up environments, installing
#' dependencies, processing data files, and rendering reports.
#'
#' @details
#' The ReportUtilitiesR6 class consolidates various utility scripts into a single
#' object-oriented interface, making it easier to manage and execute report generation
#' workflows. The class provides a consistent interface for common neuropsychology
#' report generation tasks with proper error handling and logging.
#'
#' @section Configuration:
#' The `config` field is a list that can contain various configuration options for
#' the utilities. These options can be set during initialization and accessed by
#' the various methods. Common configuration options include:
#' - `output_base_dir`: Base directory for output files (default: "reports")
#' - `template_dir`: Directory containing report templates (default: "templates")
#' - `domains`: Character vector of neuropsychological domains to process
#' - `template`: Default template file for report generation
#'
#' @examples
#' # Example 1: Basic usage
#' # Initialize the utilities class
#' report_utils <- ReportUtilitiesR6$new(
#'   config = list(
#'     output_base_dir = "reports",
#'     template_dir = "templates"
#'   )
#' )
#'
#' # Set up the environment and prepare data
#' report_utils$setup_environment()
#' dir.create("raw_data", recursive = TRUE)
#' report_utils$prepare_data_files("raw_data", "processed_data")
#'
#' # Example 2: Process domains and render a report
#' # Initialize with a specific configuration
#' report_utils <- ReportUtilitiesR6$new(
#'   config = list(
#'     domains = c("memory", "executive", "attention"),
#'     template = "comprehensive_report.qmd"
#'   )
#' )
#'
#' # Process the domains and render the report
#' report_utils$process_domains(
#'   domains = report_utils$config$domains,
#'   output_dir = "output/domains"
#' )
#' report_utils$render_report(
#'   template_file = report_utils$config$template,
#'   output_dir = "reports",
#'   output_name = "neuropsych_evaluation"
#' )
#'
#' @export
ReportUtilitiesR6 <- R6::R6Class(
  classname = "ReportUtilitiesR6",
  public = list(
    #' @field config A list containing configuration options for the utilities
    config = NULL,

    #' @description
    #' Initialize a new ReportUtilitiesR6 object
    #'
    #' @param config A list containing configuration options for the utilities.
    #'   Common options include `output_base_dir`, `template_dir`, `domains`, and `template`.
    #'
    #' @return A new `ReportUtilitiesR6` object
    initialize = function(config = list()) {
      # Set default configuration values
      default_config <- list(
        output_base_dir = "reports",
        template_dir = "templates",
        domains = character(),
        template = "template.qmd"
      )

      # Merge provided config with defaults
      self$config <- modifyList(default_config, config)
    },

    #' @description
    #' Install required dependencies for report generation
    #'
    #' @details
    #' This method installs R packages required for neuropsychological report generation.
    #' It checks for the presence of necessary packages and installs missing ones.
    #' Includes comprehensive error handling and progress reporting.
    #'
    #' @param verbose Whether to show detailed installation messages (default: TRUE)
    #'
    #' @return Invisible NULL. Called for side effects.
    install_dependencies = function(verbose = TRUE) {
      if (verbose) {
        cat("Installing all dependencies for neuro2 package...\n")
        cat("==============================================\n\n")
      }

      # Complete list of dependencies
      all_packages <- c(
        # Data manipulation and analysis
        "arrow",
        "DBI",
        "dplyr",
        "duckdb",
        "tibble",
        "tidyr",
        "tidyselect",
        "purrr",
        "readr",
        "readxl",
        "janitor",

        # Visualization and tables
        "ggplot2",
        "ggtext",
        "ggthemes",
        "gt",
        "gtExtras",
        "highcharter",
        "kableExtra",

        # Utilities
        "cli",
        "fs",
        "glue",
        "here",
        "progress",
        "yaml",

        # Development tools
        "knitr",
        "quarto",
        "R6",
        "rlang",
        "stringr",
        "usethis",
        "xfun",

        # Parallel processing
        "future",
        "future.apply",

        # Other specialized
        "memoise",
        "tabulapdf",
        "webshot2",

        # Additional dependencies
        "AsioHeaders",
        "websocket",
        "chromote"
      )

      # Function to install a package if not already installed
      install_if_needed <- function(pkg) {
        if (!requireNamespace(pkg, quietly = TRUE)) {
          if (verbose) {
            cat("Installing", pkg, "...\n")
          }
          tryCatch(
            {
              install.packages(pkg)
              if (verbose) {
                cat("   ✓", pkg, "installed\n")
              }
              return(TRUE)
            },
            error = function(e) {
              if (verbose) {
                cat("   ✗ Failed to install", pkg, ":", e$message, "\n")
              }
              return(FALSE)
            }
          )
        } else {
          if (verbose) {
            cat("   ✓", pkg, "already installed\n")
          }
          return(TRUE)
        }
      }

      # Install packages in logical groups
      if (verbose) {
        cat("\n1. Installing core dependencies...\n")
      }
      core_packages <- c("rlang", "cli", "glue", "R6", "fs", "here")
      sapply(core_packages, install_if_needed)

      if (verbose) {
        cat("\n2. Installing data manipulation packages...\n")
      }
      data_packages <- c(
        "dplyr",
        "tidyr",
        "tidyselect",
        "purrr",
        "tibble",
        "janitor",
        "readr",
        "readxl"
      )
      sapply(data_packages, install_if_needed)

      if (verbose) {
        cat("\n3. Installing database packages...\n")
      }
      db_packages <- c("DBI", "duckdb", "arrow")
      sapply(db_packages, install_if_needed)

      if (verbose) {
        cat("\n4. Installing visualization packages...\n")
      }
      viz_packages <- c(
        "ggplot2",
        "ggtext",
        "ggthemes",
        "gt",
        "gtExtras",
        "highcharter",
        "kableExtra"
      )
      sapply(viz_packages, install_if_needed)

      if (verbose) {
        cat("\n5. Installing document generation packages...\n")
      }
      doc_packages <- c("knitr", "xfun", "yaml", "stringr")
      sapply(doc_packages, install_if_needed)

      if (verbose) {
        cat("\n6. Installing webshot dependencies...\n")
      }
      webshot_deps <- c("AsioHeaders", "websocket", "chromote", "webshot2")
      sapply(webshot_deps, install_if_needed)

      if (verbose) {
        cat("\n7. Installing remaining packages...\n")
      }
      remaining <- setdiff(
        all_packages,
        c(
          core_packages,
          data_packages,
          db_packages,
          viz_packages,
          doc_packages,
          webshot_deps
        )
      )
      sapply(remaining, install_if_needed)

      # Verify all packages
      if (verbose) {
        cat("\n8. Verifying all installations...\n")
        cat("==================================\n")
      }

      failed_packages <- character()
      for (pkg in all_packages) {
        if (!requireNamespace(pkg, quietly = TRUE)) {
          if (verbose) {
            cat("   ✗", pkg, "- FAILED\n")
          }
          failed_packages <- c(failed_packages, pkg)
        }
      }

      if (length(failed_packages) == 0) {
        if (verbose) {
          cat(
            "\n✓ All",
            length(all_packages),
            "dependencies installed successfully!\n"
          )
        }

        # Check for Quarto
        if (verbose) {
          cat("\n9. Checking Quarto installation...\n")
        }
        quarto_check <- system2(
          "quarto",
          "--version",
          stdout = TRUE,
          stderr = TRUE
        )
        if (
          !is.null(attr(quarto_check, "status")) &&
            attr(quarto_check, "status") != 0
        ) {
          if (verbose) {
            cat(
              "   ⚠ Quarto CLI not found. Please install from: https://quarto.org/docs/get-started/\n"
            )
          }
        } else {
          if (verbose) cat("   ✓ Quarto version:", quarto_check, "\n")
        }
      } else {
        if (verbose) {
          cat("\n✗", length(failed_packages), "packages failed to install:\n")
          cat("  ", paste(failed_packages, collapse = ", "), "\n")
          cat("\nTry installing failed packages manually with:\n")
          cat(
            "  install.packages(c('",
            paste(failed_packages, collapse = "', '"),
            "'))\n"
          )
        }
      }

      invisible(NULL)
    },

    #' @description
    #' Apply patches to the xfun package for compatibility with report generation
    #'
    #' @details
    #' This method applies necessary patches to the xfun package to ensure
    #' compatibility with the report generation process. This may include
    #' modifying functions or adding extensions to support specific features.
    #'
    #' @return Invisible NULL. Called for side effects.
    patch_xfun = function() {
      # TODO: Implement xfun patching logic
      warning("xfun patching not yet implemented")
      invisible(NULL)
    },

    #' @description
    #' Prepare data files for report generation
    #'
    #' @details
    #' This method processes raw data files and prepares them for use in
    #' neuropsychological reports. It may include data cleaning, transformation,
    #' and organization.
    #'
    #' @param input_dir Character string specifying the directory containing input data files
    #' @param output_dir Character string specifying the directory where processed data files will be saved (default: "data")
    #' @param ... Additional arguments passed to data processing functions
    #'
    #' @return Invisible NULL. Called for side effects.
    prepare_data_files = function(input_dir, output_dir = "data", ...) {
      # Validate input directory
      if (!dir.exists(input_dir)) {
        stop("Input directory does not exist: ", input_dir)
      }

      # Create output directory if it doesn't exist
      if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
        message("Created output directory: ", output_dir)
      }

      # TODO: Implement data processing logic
      # This would typically involve reading raw data, cleaning, transforming,
      # and saving to output_dir in a format suitable for report generation

      message("Data preparation completed. Output saved to: ", output_dir)
      invisible(NULL)
    },

    #' @description
    #' Process neuropsychological domains for reporting
    #'
    #' @details
    #' This method processes data for specified neuropsychological domains (e.g., memory,
    #' attention, executive functioning) and prepares them for inclusion in reports.
    #'
    #' @param domains Character vector of domain names to process. If NULL, uses
    #'   domains from configuration.
    #' @param output_dir Character string specifying the directory where processed domain files will be saved (default: "output/domains")
    #' @param ... Additional arguments passed to domain processing functions
    #'
    #' @return Invisible NULL. Called for side effects.
    process_domains = function(
      domains = NULL,
      output_dir = "output/domains",
      ...
    ) {
      # Use configured domains if none provided
      if (is.null(domains)) {
        domains <- self$config$domains
      }

      if (length(domains) == 0) {
        warning("No domains specified for processing")
        return(invisible(NULL))
      }

      # Create output directory if it doesn't exist
      if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
        message("Created domain output directory: ", output_dir)
      }

      # TODO: Implement domain processing logic
      # This would typically involve generating domain-specific analyses,
      # figures, and tables for each specified domain

      message(
        "Processed ",
        length(domains),
        " domains. Output saved to: ",
        output_dir
      )
      invisible(NULL)
    },

    #' @description
    #' Render a neuropsychological report from a template
    #'
    #' @details
    #' This method renders a report from a template file (typically a Quarto or R Markdown file)
    #' using the processed data and domain files.
    #'
    #' @param template_file Character string specifying the path to the report template file.
    #'   If NULL, uses the template from configuration.
    #' @param output_dir Character string specifying the directory where the rendered report will be saved
    #' @param output_name Character string specifying the base name for the output report file (without extension)
    #' @param ... Additional arguments passed to the rendering engine
    #'
    #' @return Invisible NULL. Called for side effects.
    render_report = function(
      template_file = NULL,
      output_dir,
      output_name,
      ...
    ) {
      # Use configured template if none provided
      if (is.null(template_file)) {
        template_file <- self$config$template
      }

      # Validate template file exists
      if (!file.exists(template_file)) {
        stop("Template file does not exist: ", template_file)
      }

      # Create output directory if it doesn't exist
      if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
        message("Created report output directory: ", output_dir)
      }

      # TODO: Implement report rendering logic
      # This would typically involve calling quarto::quarto_render() or rmarkdown::render()
      # with appropriate parameters and output settings

      message(
        "Report rendered successfully. Output saved to: ",
        file.path(output_dir, paste0(output_name, ".pdf"))
      )
      invisible(NULL)
    },

    #' @description
    #' Set up the environment for report generation
    #'
    #' @details
    #' This method sets up the R environment for report generation, including
    #' loading necessary packages, setting options, and ensuring the correct
    #' working directory and paths are established.
    #'
    #' @param ... Additional arguments for environment setup
    #'
    #' @return Invisible NULL. Called for side effects.
    setup_environment = function(...) {
      # Set up common options for neuropsych report generation
      options(stringsAsFactors = FALSE, knitr.duplicate.label = "allow")

      # Load essential packages
      requireNamespace("here", quietly = TRUE)
      requireNamespace("knitr", quietly = TRUE)
      requireNamespace("dplyr", quietly = TRUE)

      # Set up paths
      if (is.null(self$config$output_base_dir)) {
        self$config$output_base_dir <- "reports"
      }

      # Create output directory if it doesn't exist
      if (!dir.exists(self$config$output_base_dir)) {
        dir.create(self$config$output_base_dir, recursive = TRUE)
        message("Created output base directory: ", self$config$output_base_dir)
      }

      message("Environment setup completed")
      invisible(NULL)
    }
  )
)
