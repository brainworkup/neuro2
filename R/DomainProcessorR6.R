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
        # Create a generic filter structure for all domains
        # This can be extended later with a more sophisticated lookup mechanism
        # if domain-specific default filters are needed
        self$test_filters <- list(self = character(0), observer = character(0))
      } else {
        self$test_filters <- test_filters
      }
    },

    #' @description
    #' Load data from the specified input file.
    #'
    #' @return Invisibly returns self for method chaining.
    load_data = function() {
      # Skip loading if data already exists (e.g., injected from DuckDB)
      if (!is.null(self$data)) {
        message("Data already loaded, skipping file read.")
        return(invisible(self))
      }

      # Check if input_file is provided
      if (is.null(self$input_file)) {
        stop("No input file specified and no data pre-loaded.")
      }

      # Determine file extension to use appropriate reader
      file_ext <- tools::file_ext(self$input_file)

      if (file_ext == "parquet") {
        # Check if arrow package is available
        if (!requireNamespace("arrow", quietly = TRUE)) {
          stop(
            "The 'arrow' package is required to read Parquet files. Please install it with install.packages('arrow')"
          )
        }
        self$data <- arrow::read_parquet(self$input_file)
      } else if (file_ext == "feather") {
        # Check if arrow package is available
        if (!requireNamespace("arrow", quietly = TRUE)) {
          stop(
            "The 'arrow' package is required to read Feather files. Please install it with install.packages('arrow')"
          )
        }
        self$data <- arrow::read_feather(self$input_file)
      } else if (file_ext == "csv") {
        self$data <- readr::read_csv(self$input_file)
      } else {
        # Default to CSV for unknown extensions
        warning(
          "Unknown file extension: ",
          file_ext,
          ". Attempting to read as CSV."
        )
        self$data <- readr::read_csv(self$input_file)
      }

      invisible(self)
    },

    #' @description
    #' Filter data to include only the specified domains.
    #'
    #' @return Invisibly returns self for method chaining.
    filter_by_domain = function() {
      self$data <- self$data |> dplyr::filter(domain %in% self$domains)
      invisible(self)
    },

    #' @description
    #' Select relevant columns from the data.
    #'
    #' @return Invisibly returns self for method chaining.
    select_columns = function() {
      # Define all possible columns we want to select
      desired_columns <- c(
        "test",
        "test_name",
        "scale",
        "raw_score",
        "score",
        "ci_95",
        "percentile",
        "range",
        "domain",
        "subdomain",
        "narrow",
        "pass",
        "verbal",
        "timed",
        "result",
        "z",
        "z_mean_domain",
        "z_sd_domain",
        "z_mean_subdomain",
        "z_sd_subdomain",
        "z_mean_narrow",
        "z_sd_narrow",
        "z_mean_pass",
        "z_sd_pass",
        "z_mean_verbal",
        "z_sd_verbal",
        "z_mean_timed",
        "z_sd_timed"
      )

      # Only select columns that actually exist in the data
      existing_columns <- intersect(desired_columns, names(self$data))

      # Only warn about missing z-score columns if verbose mode
      # (they're expected to be missing in some workflows)
      missing_columns <- setdiff(desired_columns, existing_columns)
      missing_z_columns <- grep("^z", missing_columns, value = TRUE)
      missing_other_columns <- setdiff(missing_columns, missing_z_columns)

      if (length(missing_other_columns) > 0) {
        message(
          "Note: The following columns were not found in the data: ",
          paste(missing_other_columns, collapse = ", ")
        )
      }

      # If z-score columns are missing but percentile exists, calculate basic z-score
      if ("percentile" %in% names(self$data) && !"z" %in% names(self$data)) {
        self$data$z <- qnorm(self$data$percentile / 100)
        existing_columns <- c(existing_columns, "z")
      }

      self$data <- self$data |> dplyr::select(all_of(existing_columns))

      invisible(self)
    },

    #' @description
    #' Save the processed data to a file.
    #'
    #' @param filename Optional custom filename (default: based on pheno).
    #' @param format Output format ("csv", "parquet", or "feather", default: determined from filename extension).
    #' @return Invisibly returns self for method chaining.
    save_data = function(filename = NULL, format = NULL) {
      # Determine format from filename if not specified
      if (is.null(format) && !is.null(filename)) {
        format <- tools::file_ext(filename)
      }

      # If format is still NULL, use default from config or fall back to csv
      if (is.null(format)) {
        format <- "parquet" # Default to parquet for better performance
      }

      # Generate filename if not provided
      if (is.null(filename)) {
        filename <- paste0(self$pheno, ".", format)
      }

      # Full path to output file
      output_path <- here::here(self$output_dir, filename)

      # Save based on format
      if (format == "parquet") {
        # Check if arrow package is available
        if (!requireNamespace("arrow", quietly = TRUE)) {
          warning(
            "The 'arrow' package is required to write Parquet files. Falling back to CSV."
          )
          format <- "csv"
        } else {
          arrow::write_parquet(self$data, output_path)
        }
      } else if (format == "feather") {
        # Check if arrow package is available
        if (!requireNamespace("arrow", quietly = TRUE)) {
          warning(
            "The 'arrow' package is required to write Feather files. Falling back to CSV."
          )
          format <- "csv"
        } else {
          arrow::write_feather(self$data, output_path)
        }
      }

      # Fall back to CSV if needed
      if (format == "csv") {
        readr::write_excel_csv(
          self$data,
          output_path,
          na = "",
          col_names = TRUE,
          append = FALSE
        )
      }

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

      # If no scale_source was provided and we've reached this point,
      # return an empty vector - the calling code should handle this appropriately
      # This simplifies the design by removing dynamic lookups based on naming conventions
      return(character(0))
    },

    #' @description
    #' Filter data by test names for specific report types.
    #'
    #' @param report_type Type of report to filter for ("self", "observer", "performance").
    #' @return A filtered data frame.
    filter_by_test = function(report_type = "self") {
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
    #' @param report_type Type of report to generate ("self", "observer", "performance").
    #' @param output_file Output file path for the report.
    #' @return Invisibly returns self for method chaining.
    generate_report = function(report_type = "self", output_file = NULL) {
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
    #' Generate the domain number from phenotype for file naming.
    #'
    #' @return A two-digit string representing the domain number.
    get_domain_number = function() {
      domain_numbers <- c(
        iq = "01",
        academics = "02",
        verbal = "03",
        spatial = "04",
        memory = "05",
        executive = "06",
        motor = "07",
        social = "08",
        adhd = "09",
        emotion = "10",
        adaptive = "11",
        daily_living = "12"
      )

      num <- domain_numbers[tolower(self$pheno)]
      if (is.na(num) || is.null(num)) "99" else num
    },

    #' @description
    #' Get default scales for domain.
    #'
    #' @return A vector of scale names appropriate for the domain.
    get_default_scales = function() {
      # This would normally call a registry
      # For now, return the scales from get_scales()
      self$get_scales()
    },

    #' @description
    #' Get default plot titles for domain.
    #'
    #' @return A string containing the default title for domain plots.
    get_default_plot_titles = function() {
      titles <- list(
        iq = "Intellectual and cognitive abilities represent an individual's capacity to think, reason, and solve problems.",
        academics = "Academic skills reflect the application of cognitive abilities to educational tasks.",
        verbal = "Verbal and language functioning refers to the ability to access and apply acquired word knowledge.",
        spatial = "Visuospatial abilities involve perceiving, analyzing, and mentally manipulating visual information.",
        memory = "Memory functions are crucial for learning, daily functioning, and cognitive processing.",
        executive = "Attentional and executive functions underlie most domains of cognitive performance.",
        motor = "Motor functions involve the planning and execution of voluntary movements.",
        social = "Social cognition encompasses the mental processes involved in perceiving, interpreting, and responding to social information."
      )

      # Use %||% operator for NULL handling
      result <- titles[[tolower(self$pheno)]]
      if (is.null(result)) {
        paste(
          "This section presents results from the",
          self$domains[1],
          "domain assessment."
        )
      } else {
        result
      }
    },

    #' @description
    #' Generate domain QMD file.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path (default: NULL, will generate based on domain).
    #' @return The path to the generated file.
    generate_domain_qmd = function(domain_name = NULL, output_file = NULL) {
      # Use the first domain if domain_name not provided
      if (is.null(domain_name)) {
        domain_name <- self$domains[1]
      }

      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # If no output file specified, create default name with proper domain number
      if (is.null(output_file)) {
        output_file <- paste0(
          "_02-",
          domain_num,
          "_",
          tolower(self$pheno),
          ".qmd"
        )
      }

      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Generate QMD content
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-",
        tolower(self$pheno),
        "}\n\n",
        "{{< include _02-",
        domain_num,
        "_",
        tolower(self$pheno),
        "_text.qmd >}}\n\n",
        "```{r}\n",
        "#| label: setup-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n\n",
        "# Filter by domain\n",
        "domains <- c(\"",
        domain_name,
        "\")\n\n",
        "# Target phenotype\n",
        "pheno <- \"",
        tolower(self$pheno),
        "\"\n\n",
        "# Read the data file into a data frame\n",
        "file_ext <- tools::file_ext(\"",
        self$input_file,
        "\")\n",
        "if (file_ext == \"parquet\") {\n",
        "  # Check if arrow package is available\n",
        "  if (!requireNamespace(\"arrow\", quietly = TRUE)) {\n",
        "    stop(\"The 'arrow' package is required to read Parquet files.\")\n",
        "  }\n",
        "  ",
        tolower(self$pheno),
        " <- arrow::read_parquet(\"",
        self$input_file,
        "\")\n",
        "} else if (file_ext == \"feather\") {\n",
        "  # Check if arrow package is available\n",
        "  if (!requireNamespace(\"arrow\", quietly = TRUE)) {\n",
        "    stop(\"The 'arrow' package is required to read Feather files.\")\n",
        "  }\n",
        "  ",
        tolower(self$pheno),
        " <- arrow::read_feather(\"",
        self$input_file,
        "\")\n",
        "} else {\n",
        "  # Default to CSV for other formats\n",
        "  ",
        tolower(self$pheno),
        " <- readr::read_csv(\"",
        self$input_file,
        "\")\n",
        "}\n",
        "```\n\n"
        # ... additional content based on template
      )

      # Write to file
      cat(qmd_content, file = output_file)

      # Also generate the text file
      self$generate_domain_text_qmd(domain_name)

      return(output_file)
    },

    #' @description
    #' Generate domain text QMD file.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path (default: NULL, will generate based on domain).
    #' @param report_type Type of report to generate (default: "self").
    #' @return The path to the generated file.
    generate_domain_text_qmd = function(
      domain_name = NULL,
      output_file = NULL,
      report_type = "self"
    ) {
      # Use the first domain if domain_name not provided
      if (is.null(domain_name)) {
        domain_name <- self$domains[1]
      }

      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # If no output file specified, create default name with proper domain number
      if (is.null(output_file)) {
        if (report_type == "self") {
          output_file <- paste0(
            "_02-",
            domain_num,
            "_",
            tolower(self$pheno),
            "_text.qmd"
          )
        } else {
          output_file <- paste0(
            "_02-",
            domain_num,
            "_",
            tolower(self$pheno),
            "_text_",
            report_type,
            ".qmd"
          )
        }
      }

      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Filter data for this domain to create text summary
      filtered_data <- self$filter_by_test(report_type = report_type)

      # If there's no data after filtering, create a placeholder
      if (is.null(filtered_data) || nrow(filtered_data) == 0) {
        cat(
          "<summary>\n\nNo data available for ",
          domain_name,
          ".\n\n</summary>",
          file = output_file
        )
        return(output_file)
      }

      # Use NeuropsychResultsR6 to generate text
      results_processor <- NeuropsychResultsR6$new(
        data = filtered_data,
        file = output_file
      )

      results_processor$process()

      return(output_file)
    },

    #' @description
    #' Run the complete processing pipeline.
    #'
    #' @param generate_reports Whether to generate text reports (default: TRUE).
    #' @param report_types Vector of report types to generate (default: c("self")).
    #' @param generate_domain_files Whether to generate domain QMD files (default: FALSE).
    #' @return Invisibly returns self for method chaining.
    process = function(
      generate_reports = TRUE,
      report_types = c("self"),
      generate_domain_files = FALSE
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

      # Generate domain files if requested
      if (generate_domain_files) {
        self$generate_domain_qmd()
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
#' @param report_types Vector of report types to generate (default: c("self")).
#' @param generate_domain_files Whether to generate domain QMD files (default: FALSE).
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
  report_types = c("self"),
  generate_domain_files = FALSE
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
    report_types = report_types,
    generate_domain_files = generate_domain_files
  )

  invisible(processor$data)
}
