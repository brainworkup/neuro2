#' DomainProcessorR6 Class
#'
#' An R6 class that encapsulates a complete data processing pipeline for neuropsychological domains.
#' This class handles loading data, filtering by domain, processing, and outputting results in various formats.
#'
#' @field domains Character vector of domain names to process.
#' @field pheno Target phenotype identifier string.
#' @field input_file Path to the input CSV file (neurocog.csv, neurobehav.csv, or validity.csv).
#' @field output_dir Directory where output files will be saved (default: "data").
#' @field scale_source Source of scales information (default: NULL, will use package internal data).
#' @field test_filters List of test filters for different report types (default: NULL).
#' @field data The loaded and processed data.
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new DomainProcessorR6 object with configuration parameters.}
#'   \item{load_data}{Load data from the specified input file.}
#'   \item{filter_by_domain}{Filter data to include only the specified domains.}
#'   \item{select_columns}{Select relevant columns from the data.}
#'   \item{save_data}{Save the processed data to a CSV file.}
#'   \item{get_scales}{Get scale names for the specified phenotype.}
#'   \item{filter_by_test}{Filter data by test names for specific report types.}
#'   \item{generate_report}{Generate text reports for different report types.}
#'   \item{process}{Run the complete processing pipeline.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr filter select arrange desc distinct
#' @importFrom readr read_csv write_excel_csv
#' @importFrom here here
#' @export
DomainProcessorR6 <- R6::R6Class(
  classname = "DomainProcessorR6",
  public = list(
    domains = NULL,
    pheno = NULL,
    input_file = NULL,
    output_dir = "data",
    scale_source = NULL,
    test_filters = NULL,
    data = NULL,

    #' @description
    #' Initialize a new DomainProcessorR6 object with configuration parameters.
    #'
    #' @param domains Character vector of domain names to process.
    #' @param pheno Target phenotype identifier string.
    #' @param input_file Path to the input CSV file (neurocog.csv, neurobehav.csv, or validity.csv).
    #' @param output_dir Directory where output files will be saved (default: "data").
    #' @param scale_source Source of scales information (default: NULL, will use package internal data).
    #' @param test_filters List of test filters for different report types (default: NULL).
    #'
    #' @return A new DomainProcessorR6 object
    initialize = function(
      domains,
      pheno,
      input_file,
      output_dir = "data",
      scale_source = NULL,
      test_filters = NULL
    ) {
      self$domains <- domains
      self$pheno <- pheno
      self$input_file <- input_file
      self$output_dir <- output_dir
      self$scale_source <- scale_source

      # Set default test filters if none provided
      if (is.null(test_filters)) {
        # Example default filters for ADHD domain
        if ("ADHD" %in% domains) {
          self$test_filters <- list(
            self_report = c(
              "caars_self",
              "cefi_self",
              "caars2_self",
              "brown_efa_self",
              "pai",
              "cefi_self_12-18"
            ),
            observer = c(
              "caars_observer",
              "cefi_observer",
              "caars2_observer",
              "brown_efa_observer"
            ),
            performance = c(
              "cpt",
              "d_kefs",
              "tova",
              "wais",
              "wms"
            )
          )
        } else {
          # Generic empty filter structure
          self$test_filters <- list(
            self_report = character(0),
            observer = character(0),
            performance = character(0)
          )
        }
      } else {
        self$test_filters <- test_filters
      }
    },

    #' @description
    #' Load data from the specified input file.
    #'
    #' @return Invisibly returns self for method chaining.
    load_data = function() {
      self$data <- readr::read_csv(self$input_file)
      invisible(self)
    },

    #' @description
    #' Filter data to include only the specified domains.
    #'
    #' @return Invisibly returns self for method chaining.
    filter_by_domain = function() {
      self$data <- self$data |>
        dplyr::filter(domain %in% self$domains)
      invisible(self)
    },

    #' @description
    #' Select relevant columns from the data.
    #'
    #' @return Invisibly returns self for method chaining.
    select_columns = function() {
      self$data <- self$data |>
        dplyr::select(
          test,
          test_name,
          scale,
          raw_score,
          score,
          ci_95,
          percentile,
          range,
          domain,
          subdomain,
          narrow,
          pass,
          verbal,
          timed,
          result,
          z,
          z_mean_domain,
          z_sd_domain,
          z_mean_subdomain,
          z_sd_subdomain,
          z_mean_narrow,
          z_sd_narrow
        )
      invisible(self)
    },

    #' @description
    #' Save the processed data to a CSV file.
    #'
    #' @param filename Optional custom filename (default: based on pheno).
    #' @return Invisibly returns self for method chaining.
    save_data = function(filename = NULL) {
      if (is.null(filename)) {
        filename <- paste0(self$pheno, ".csv")
      }

      readr::write_excel_csv(
        self$data,
        here::here(self$output_dir, filename),
        na = "",
        col_names = TRUE,
        append = FALSE
      )

      invisible(self)
    },

    #' @description
    #' Get scale names for the specified phenotype.
    #'
    #' @return A vector of scale names.
    get_scales = function() {
      # If scale_source is provided, use it
      if (!is.null(self$scale_source)) {
        return(self$scale_source)
      }

      # Otherwise try to get scales from package internal data
      # This is just a placeholder - you'll need to adapt this to your actual package structure
      scales <- NULL

      tryCatch(
        {
          # Try to get scales from package data based on phenotype
          # Example: scales_adhd_adult for pheno="adhd"
          scale_name <- paste0("scales_", self$pheno, "_adult")
          if (exists(scale_name, envir = asNamespace("NeurotypR"))) {
            scales <- get(scale_name, envir = asNamespace("NeurotypR"))
          }
        },
        error = function(e) {
          warning("Could not retrieve scales from package data: ", e$message)
        }
      )

      return(scales)
    },

    #' @description
    #' Filter data by test names for specific report types.
    #'
    #' @param report_type Type of report to filter for ("self_report", "observer", "performance").
    #' @return A filtered data frame.
    filter_by_test = function(report_type = "self_report") {
      if (!report_type %in% names(self$test_filters)) {
        stop(
          "Invalid report type. Must be one of: ",
          paste(names(self$test_filters), collapse = ", ")
        )
      }

      test_list <- self$test_filters[[report_type]]

      filtered_data <- self$data |>
        dplyr::filter(test %in% test_list) |>
        dplyr::arrange(dplyr::desc(percentile)) |>
        dplyr::distinct(.keep_all = FALSE)

      return(filtered_data)
    },

    #' @description
    #' Generate text reports for different report types.
    #'
    #' @param report_type Type of report to generate ("self_report", "observer", "performance").
    #' @param output_file Output file path for the report.
    #' @return Invisibly returns self for method chaining.
    generate_report = function(
      report_type = "self_report",
      output_file = NULL
    ) {
      # Get filtered data for the specified report type
      filtered_data <- self$filter_by_test(report_type)

      # Generate default output filename if not provided
      if (is.null(output_file)) {
        output_file <- paste0(
          "_02-09_",
          self$pheno,
          "_adult_text_",
          gsub("_report", "", report_type),
          ".qmd"
        )
      }

      # Use the NeuropsychResultsR6 class we created earlier
      results_processor <- NeuropsychResultsR6$new(
        data = filtered_data,
        file = output_file
      )

      results_processor$process()

      invisible(self)
    },

    #' @description
    #' Run the complete processing pipeline.
    #'
    #' @param generate_reports Whether to generate text reports (default: TRUE).
    #' @param report_types Vector of report types to generate (default: c("self_report")).
    #' @return Invisibly returns self for method chaining.
    process = function(
      generate_reports = TRUE,
      report_types = c("self_report")
    ) {
      # Run the complete pipeline
      self$load_data()
      self$filter_by_domain()
      self$select_columns()
      self$save_data()

      # Get scales (could be used for further processing)
      scales <- self$get_scales()

      # Generate reports if requested
      if (generate_reports) {
        for (report_type in report_types) {
          if (report_type %in% names(self$test_filters)) {
            self$generate_report(report_type)
          }
        }
      }

      invisible(self)
    }
  )
)

#' Process Neuropsychological Domain Data (Function Wrapper)
#'
#' This function encapsulates a complete data processing pipeline for neuropsychological domains.
#' It's a wrapper around the DomainProcessorR6 class.
#'
#' @param domains Character vector of domain names to process.
#' @param pheno Target phenotype identifier string.
#' @param input_file Path to the input CSV file (neurocog.csv, neurobehav.csv, or validity.csv).
#' @param output_dir Directory where output files will be saved (default: "data").
#' @param scale_source Source of scales information (default: NULL, will use package internal data).
#' @param test_filters List of test filters for different report types (default: NULL).
#' @param generate_reports Whether to generate text reports (default: TRUE).
#' @param report_types Vector of report types to generate (default: c("self_report")).
#'
#' @return Invisibly returns the processed data.
#' @export
#' @rdname process_domain_data
process_domain_data <- function(
  domains,
  pheno,
  input_file,
  output_dir = "data",
  scale_source = NULL,
  test_filters = NULL,
  generate_reports = TRUE,
  report_types = c("self_report")
) {
  # Create a DomainProcessorR6 object and run the processing pipeline
  processor <- DomainProcessorR6$new(
    domains = domains,
    pheno = pheno,
    input_file = input_file,
    output_dir = output_dir,
    scale_source = scale_source,
    test_filters = test_filters
  )

  processor$process(
    generate_reports = generate_reports,
    report_types = report_types
  )

  invisible(processor$data)
}
