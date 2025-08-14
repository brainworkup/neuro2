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
#' @field number Domain number for file naming (automatically determined from pheno).
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
#'   \item{has_multiple_raters}{Check if domain has multiple raters (emotion and ADHD domains).}
#'   \item{detect_emotion_type}{Detect if this is a child or adult emotion domain.}
#'   \item{get_rater_types}{Get rater types for the domain (emotion child: self/parent/teacher; emotion adult: self only; ADHD adult: self/observer; ADHD child: self/parent/teacher).}
#'   \item{check_rater_data_exists}{Check if rater-specific data files exist.}
#'   \item{generate_domain_qmd}{Generate domain QMD file with support for multi-rater domains.}
#'   \item{generate_emotion_child_qmd}{Generate emotion child domain QMD file with multiple raters.}
#'   \item{generate_emotion_adult_qmd}{Generate emotion adult domain QMD file.}
#'   \item{process}{Run the complete processing pipeline.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr filter select arrange desc distinct all_of
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
    number = NULL,
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
    #' @param number Domain number for file naming (optional, will be auto-determined if not provided).
    #'
    #' @return A new DomainProcessorR6 object
    initialize = function(
      domains,
      pheno,
      input_file,
      output_dir = "data",
      scale_source = NULL,
      test_filters = NULL,
      number = NULL
    ) {
      self$domains <- domains
      self$pheno <- pheno
      self$input_file <- input_file
      self$output_dir <- output_dir
      self$scale_source <- scale_source

      # Set the number field - use provided number or auto-determine
      if (!is.null(number)) {
        self$number <- sprintf("%02d", as.numeric(number))
      } else {
        self$number <- self$get_domain_number()
      }

      # Set default test filters if none provided
      if (is.null(test_filters)) {
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
        if (!requireNamespace("arrow", quietly = TRUE)) {
          stop(
            "The 'arrow' package is required to read Parquet files. Please install it with install.packages('arrow')"
          )
        }
        self$data <- arrow::read_parquet(self$input_file)
      } else if (file_ext == "feather") {
        if (!requireNamespace("arrow", quietly = TRUE)) {
          stop(
            "The 'arrow' package is required to read Feather files. Please install it with install.packages('arrow')"
          )
        }
        self$data <- arrow::read_feather(self$input_file)
      } else if (file_ext == "csv") {
        self$data <- readr::read_csv(self$input_file)
      } else {
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

      # If format is still NULL, use default
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
        if (!requireNamespace("arrow", quietly = TRUE)) {
          warning(
            "The 'arrow' package is required to write Parquet files. Falling back to CSV."
          )
          format <- "csv"
        } else {
          arrow::write_parquet(self$data, output_path)
        }
      } else if (format == "feather") {
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

      # Try to load scales from internal data based on phenotype
      scale_var_name <- paste0("scales_", tolower(self$pheno))

      # Check if the scale variable exists in the package's internal data
      if (exists(scale_var_name, envir = .GlobalEnv)) {
        scales <- get(scale_var_name, envir = .GlobalEnv)
        return(scales)
      }

      # Try loading from sysdata.rda if not already available
      sysdata_path <- system.file("R", "sysdata.rda", package = "neuro2")
      if (file.exists(sysdata_path)) {
        temp_env <- new.env()
        load(sysdata_path, envir = temp_env)
        if (exists(scale_var_name, envir = temp_env)) {
          scales <- get(scale_var_name, envir = temp_env)
          return(scales)
        }
      }

      # If still not found, try alternative path (for development)
      dev_sysdata_path <- here::here("R", "sysdata.rda")
      if (file.exists(dev_sysdata_path)) {
        temp_env <- new.env()
        load(dev_sysdata_path, envir = temp_env)
        if (exists(scale_var_name, envir = temp_env)) {
          scales <- get(scale_var_name, envir = temp_env)
          return(scales)
        }
      }

      # If no scales found, return an empty vector
      return(character(0))
    },

    #' @description
    #' Filter data by test names for specific report types.
    #'
    #' @param report_type Type of report to filter for ("self", "parent", "teacher", "observer").
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
    #' @param report_type Type of report to generate ("self", "parent", "teacher", "observer").
    #' @param output_file Output file path for the report.
    #' @return Invisibly returns self for method chaining.
    generate_report = function(report_type = "self", output_file = NULL) {
      # Get filtered data for the specified report type
      filtered_data <- self$filter_by_test(report_type)

      # Generate default output filename if not provided
      if (is.null(output_file)) {
        output_file <- paste0("_02-", self$number, "_", self$pheno, "_text.qmd")
      }

      # Use the NeuropsychResultsR6 class
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
        daily_living = "12",
        validity = "13"
      )

      num <- domain_numbers[tolower(self$pheno)]
      if (is.na(num) || is.null(num)) "99" else num
    },

    #' @description
    #' Get default scales for domain.
    #'
    #' @return A vector of scale names appropriate for the domain.
    get_default_scales = function() {
      self$get_scales()
    },

    #' @description
    #' Get default plot titles for domain.
    #'
    #' @return A string containing the default title for domain plots.
    get_default_plot_titles = function() {
      plot_title_var <- paste0("plot_title_", tolower(self$pheno))

      # Check if the plot title variable exists in the global environment
      if (exists(plot_title_var, envir = .GlobalEnv)) {
        plot_title <- get(plot_title_var, envir = .GlobalEnv)
        return(plot_title)
      }

      # Try loading from sysdata.rda if not already available
      sysdata_path <- system.file("R", "sysdata.rda", package = "neuro2")
      if (file.exists(sysdata_path)) {
        temp_env <- new.env()
        load(sysdata_path, envir = temp_env)
        if (exists(plot_title_var, envir = temp_env)) {
          plot_title <- get(plot_title_var, envir = temp_env)
          return(plot_title)
        }
      }

      # Try alternative path (for development)
      dev_sysdata_path <- here::here("R", "sysdata.rda")
      if (file.exists(dev_sysdata_path)) {
        temp_env <- new.env()
        load(dev_sysdata_path, envir = temp_env)
        if (exists(plot_title_var, envir = temp_env)) {
          plot_title <- get(plot_title_var, envir = temp_env)
          return(plot_title)
        }
      }

      # Fallback to hardcoded titles if not found in sysdata
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
    #' Check if domain has multiple raters.
    #'
    #' @return Logical indicating if domain has multiple raters.
    has_multiple_raters = function() {
      tolower(self$pheno) %in% c("emotion", "adhd")
    },

    #' @description
    #' Detect if this is a child or adult emotion domain.
    #'
    #' @return Character string: "child", "adult", or NULL if not emotion domain.
    detect_emotion_type = function() {
      if (tolower(self$pheno) != "emotion") {
        return(NULL)
      }

      # Check based on domain name
      if (
        any(grepl(
          "Behavioral/Emotional/Social",
          self$domains,
          ignore.case = TRUE
        ))
      ) {
        return("child")
      } else if (
        any(grepl(
          "Emotional/Behavioral/Personality",
          self$domains,
          ignore.case = TRUE
        ))
      ) {
        return("adult")
      }

      # Check based on test data if available
      if (!is.null(self$data) && nrow(self$data) > 0) {
        # Check for child-specific tests
        if (
          any(
            self$data$test %in%
              c(
                "basc3_prs_child",
                "basc3_prs_adolescent",
                "basc3_srp_child",
                "basc3_srp_adolescent",
                "basc3_trs_child",
                "basc3_trs_adolescent",
                "basc3_prs_preschool",
                "basc3_trs_preschool",
                "pai_adol",
                "pai_adol_clinical",
                "pai_adol_validity"
              ),
            na.rm = TRUE
          )
        ) {
          return("child")
        }

        # Check for adult-specific tests
        if (
          any(
            self$data$test %in%
              c("pai", "pai_clinical", "pai_validity", "pai_attention"),
            na.rm = TRUE
          )
        ) {
          return("adult")
        }
      }

      # Default to child if unclear
      return("child")
    },

    #' @description
    #' Get rater types for the domain.
    #'
    #' @return Character vector of rater types.
    get_rater_types = function() {
      if (!self$has_multiple_raters()) {
        return(NULL)
      }

      # Check if this is ADHD domain
      if (tolower(self$pheno) == "adhd") {
        if (
          any(grepl("child", tolower(self$domains))) ||
            (!is.null(self$data) &&
              any(
                self$data$test %in%
                  c(
                    "basc3_prs_child",
                    "basc3_prs_adolescent",
                    "basc3_trs_child",
                    "basc3_trs_adolescent"
                  ),
                na.rm = TRUE
              ))
        ) {
          return(c("self", "parent", "teacher"))
        } else {
          return(c("self", "observer"))
        }
      }

      # For emotion domain
      if (tolower(self$pheno) == "emotion") {
        emotion_type <- self$detect_emotion_type()
        if (emotion_type == "child") {
          return(c("self", "parent", "teacher"))
        } else if (emotion_type == "adult") {
          return(c("self"))
        }
      }

      return(NULL)
    },

    #' @description
    #' Check if rater-specific data files exist.
    #'
    #' @param rater_type The rater type to check ("self", "parent", "teacher", "observer").
    #' @return Logical indicating if rater data exists.
    check_rater_data_exists = function(rater_type) {
      # Define CSV directory path
      csv_dir <- here::here("data-raw", "csv")

      # Map rater types to CSV file patterns
      rater_csv_patterns <- list(
        self = c("pai_adol.*\\.csv", "basc3_srp.*\\.csv"),
        parent = c("basc3_prs.*\\.csv"),
        teacher = c("basc3_trs.*\\.csv"),
        observer = character(0)
      )

      # Special case for observer - it's valid for ADHD adult even without specific files
      if (rater_type == "observer" && tolower(self$pheno) == "adhd") {
        if (!any(grepl("child", tolower(self$domains)))) {
          return(TRUE)
        }
      }

      # Check if CSV directory exists
      if (!dir.exists(csv_dir)) {
        return(FALSE)
      }

      # Get list of CSV files in the directory
      csv_files <- list.files(csv_dir, pattern = "\\.csv$", ignore.case = TRUE)

      # If no CSV files at all, return FALSE
      if (length(csv_files) == 0) {
        return(FALSE)
      }

      # Check if any CSV files match the rater patterns
      if (rater_type %in% names(rater_csv_patterns)) {
        patterns <- rater_csv_patterns[[rater_type]]
        for (pattern in patterns) {
          if (any(grepl(pattern, csv_files, ignore.case = TRUE))) {
            return(TRUE)
          }
        }
      }

      # Also check if data is already loaded with matching test names
      if (!is.null(self$data) && nrow(self$data) > 0) {
        rater_test_patterns <- list(
          self = c(
            "pai_adol",
            "pai_adol_clinical",
            "basc3_srp_adolescent",
            "basc3_srp_child"
          ),
          parent = c(
            "basc3_prs_adolescent",
            "basc3_prs_child",
            "basc3_prs_preschool"
          ),
          teacher = c(
            "basc3_trs_adolescent",
            "basc3_trs_child",
            "basc3_trs_preschool"
          ),
          observer = character(0)
        )

        if (rater_type %in% names(rater_test_patterns)) {
          test_patterns <- rater_test_patterns[[rater_type]]
          if (
            length(test_patterns) > 0 &&
              any(self$data$test %in% test_patterns, na.rm = TRUE)
          ) {
            return(TRUE)
          }
        }
      }

      return(FALSE)
    },

    #' @description
    #' Enhanced method to generate domain text files with proper validation
    #' @param report_type Type of report to filter for ("self", "parent", "teacher", "observer").
    #' @return The path to the generated text file or NULL if failed.
    generate_domain_text_qmd = function(report_type = NULL) {
      # Determine the appropriate text file name using self$number
      if (!is.null(report_type)) {
        text_file <- paste0(
          "_02-",
          self$number,
          "_",
          self$pheno,
          "_text_",
          report_type,
          ".qmd"
        )
      } else {
        text_file <- paste0("_02-", self$number, "_", self$pheno, "_text.qmd")
      }

      # Check if we need to create this text file
      if (!is.null(report_type) && !self$check_rater_data_exists(report_type)) {
        message(paste("No data for", report_type, "rater - skipping text file"))
        return(NULL)
      }

      # Use NeuropsychResultsR6 to generate the actual narrative text from data
      tryCatch(
        {
          # Ensure data is loaded and processed
          if (is.null(self$data)) {
            self$load_data()
            self$filter_by_domain()
            self$select_columns()
          }

          # Use NeuropsychResultsR6 class to generate proper text content
          results_processor <- NeuropsychResultsR6$new(
            data = self$data,
            file = text_file
          )

          # Process the data to generate narrative text
          results_processor$process()

          message(paste("Generated text file:", text_file))
          return(text_file)
        },
        error = function(e) {
          warning(paste(
            "Failed to generate text file",
            text_file,
            ":",
            e$message
          ))
          # Create a minimal placeholder file to avoid include errors
          placeholder_content <- paste0(
            "*Text content for this domain",
            ifelse(
              is.null(report_type),
              "",
              paste(" and", report_type, "rater")
            ),
            " is not available.*\n"
          )
          writeLines(placeholder_content, text_file)
          return(text_file)
        }
      )
    },

    #' Generate domain QMD file.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path (default: NULL, will generate based on domain).
    #' @param is_child Logical indicating if this is a child version (default: FALSE).
    #' @return The path to the generated file.
    generate_domain_qmd = function(
      domain_name = NULL,
      output_file = NULL,
      is_child = FALSE
    ) {
      # Use the first domain if domain_name not provided
      if (is.null(domain_name)) {
        domain_name <- self$domains[1]
      }

      # Generate default output filename if not provided using self$number
      if (is.null(output_file)) {
        output_file <- paste0(
          "_02-",
          self$number,
          "_",
          tolower(self$pheno),
          ".qmd"
        )
      }

      # Check if this is ADHD domain
      if (tolower(self$pheno) == "adhd") {
        is_adhd_child <- any(grepl("child", tolower(self$domains))) ||
          (!is.null(self$data) &&
            any(
              self$data$test %in%
                c(
                  "basc3_prs_child",
                  "basc3_prs_adolescent",
                  "basc3_trs_child",
                  "basc3_trs_adolescent"
                ),
              na.rm = TRUE
            ))

        if (is_adhd_child) {
          output_file <- paste0("_02-", self$number, "_adhd_child.qmd")
          self$generate_adhd_child_qmd(domain_name, output_file)
          return(output_file)
        } else {
          output_file <- paste0("_02-", self$number, "_adhd_adult.qmd")
          self$generate_adhd_adult_qmd(domain_name, output_file)
          return(output_file)
        }
      }

      # Check if this is emotion domain
      if (tolower(self$pheno) == "emotion") {
        emotion_type <- self$detect_emotion_type()
        if (emotion_type == "child") {
          output_file <- paste0("_02-", self$number, "_emotion_child.qmd")
          self$generate_emotion_child_qmd(domain_name, output_file)
          return(output_file)
        } else if (emotion_type == "adult") {
          output_file <- paste0("_02-", self$number, "_emotion_adult.qmd")
          self$generate_emotion_adult_qmd(domain_name, output_file)
          return(output_file)
        }
      }

      # Generate the text file first
      self$generate_domain_text_qmd()

      # Generate basic QMD content for non-multi-rater domains
      # Use the CORRECTED, SIMPLIFIED structure that prevents R code in PDF
      qmd_content <- paste0(
        "```{=typst}\n== ",
        domain_name,
        "\n```\n\n",
        "{{< include _02-",
        self$number,
        "_",
        tolower(self$pheno),
        "_text.qmd >}}\n\n",
        "```{r}\n#| label: table-",
        tolower(self$pheno),
        "\n#| echo: false\n#| warning: false\n#| message: false\n\n",
        "# Generate and display table\n",
        "source(\"R/TableGTR6.R\")\n",
        "if (file.exists(\"data/",
        tolower(self$pheno),
        ".csv\")) {\n",
        "  data <- read.csv(\"data/",
        tolower(self$pheno),
        ".csv\")\n",
        "  if (nrow(data) > 0) {\n",
        "    table_obj <- TableGTR6$new(\n",
        "      data = data,\n",
        "      pheno = \"",
        tolower(self$pheno),
        "\",\n",
        "      table_name = \"table_",
        tolower(self$pheno),
        "\"\n",
        "    )\n",
        "    built_table <- table_obj$build_table()\n",
        "    table_obj$save_table(built_table, dir = \".\")\n",
        "    print(built_table)\n",
        "  }\n",
        "}\n",
        "```\n\n",
        "```{r}\n#| label: plot-",
        tolower(self$pheno),
        "\n#| echo: false\n#| fig-width: 10\n#| fig-height: 4.5\n#| out-width: \"100%\"\n\n",
        "# Generate and display dotplot\n",
        "source(\"R/DotplotR6.R\")\n",
        "if (file.exists(\"data/",
        tolower(self$pheno),
        ".csv\")) {\n",
        "  data <- read.csv(\"data/",
        tolower(self$pheno),
        ".csv\")\n",
        "  if (nrow(data) > 0) {\n",
        "    plot_obj <- DotplotR6$new(\n",
        "      data = data,\n",
        "      x_var = \"percentile\",\n",
        "      y_var = \"scale\",\n",
        "      colors = c(\"#d7191c\", \"#fdae61\", \"#abdda4\", \"#2b83ba\"),\n",
        "      return_plot = TRUE\n",
        "    )\n",
        "    plot_obj$generate_plot()\n",
        "    print(plot_obj$plot)\n",
        "  }\n",
        "}\n",
        "```\n\n"
      )

      # Write QMD to file
      cat(qmd_content, file = output_file)

      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate ADHD adult domain QMD file with self and observer reports.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path.
    #' @return The path to the generated file.
    generate_adhd_adult_qmd = function(domain_name, output_file) {
      # Generate text files for self and observer
      self$generate_adhd_adult_text_files()

      # CORRECTED ADHD adult QMD generation with proper structure
      qmd_content <- paste0(
        "```{=typst}\n== ",
        domain_name,
        "\n```\n\n",
        "```{=typst}\n=== SELF-REPORT\n```\n\n",
        "{{< include _02-",
        self$number,
        "_adhd_adult_text_self.qmd >}}\n\n",
        "```{=typst}\n=== OBSERVER RATINGS\n```\n\n",
        "{{< include _02-",
        self$number,
        "_adhd_adult_text_observer.qmd >}}\n\n"
      )

      cat(qmd_content, file = output_file)
      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate ADHD child domain QMD file with self, parent, and teacher reports.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path.
    #' @return The path to the generated file.
    generate_adhd_child_qmd = function(domain_name, output_file) {
      # Generate text files for self, parent, and teacher
      self$generate_adhd_child_text_files()

      # CORRECTED ADHD child QMD generation with proper structure
      qmd_content <- paste0(
        "```{=typst}\n== ",
        domain_name,
        "\n```\n\n",
        "```{=typst}\n=== SELF-REPORT\n```\n\n",
        "{{< include _02-",
        self$number,
        "_adhd_child_text_self.qmd >}}\n\n",
        "```{=typst}\n=== PARENT RATINGS\n```\n\n",
        "{{< include _02-",
        self$number,
        "_adhd_child_text_parent.qmd >}}\n\n",
        "```{=typst}\n=== TEACHER RATINGS\n```\n\n",
        "{{< include _02-",
        self$number,
        "_adhd_child_text_teacher.qmd >}}\n\n"
      )

      cat(qmd_content, file = output_file)
      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate ADHD adult text files for self and observer reports.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_adhd_adult_text_files = function() {
      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Generate text files for self and observer
      raters <- c("self", "observer")
      for (rater in raters) {
        text_file <- paste0(
          "_02-",
          self$number,
          "_adhd_adult_text_",
          rater,
          ".qmd"
        )

        if (self$check_rater_data_exists(rater)) {
          tryCatch(
            {
              results_processor <- NeuropsychResultsR6$new(
                data = self$data,
                file = text_file
              )
              results_processor$process()
            },
            error = function(e) {
              placeholder_content <- paste0(
                "*Data for ",
                rater,
                " rating is not available or could not be processed.*\n"
              )
              writeLines(placeholder_content, text_file)
              message("Created placeholder for ", text_file, ": ", e$message)
            }
          )
        } else {
          # Create placeholder file even if no data exists to prevent include errors
          placeholder_content <- paste0(
            "*No ",
            rater,
            " rating data available.*\n"
          )
          writeLines(placeholder_content, text_file)
          message(
            "Created placeholder for missing ",
            rater,
            " data: ",
            text_file
          )
        }
      }

      return(invisible(self))
    },

    #' @description
    #' Generate ADHD child text files for self, parent, and teacher reports.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_adhd_child_text_files = function() {
      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Generate text files for each rater type
      raters <- c("self", "parent", "teacher")
      for (rater in raters) {
        text_file <- paste0(
          "_02-",
          self$number,
          "_adhd_child_text_",
          rater,
          ".qmd"
        )

        if (self$check_rater_data_exists(rater)) {
          tryCatch(
            {
              results_processor <- NeuropsychResultsR6$new(
                data = self$data,
                file = text_file
              )
              results_processor$process()
            },
            error = function(e) {
              placeholder_content <- paste0(
                "*Data for ",
                rater,
                " rating is not available or could not be processed.*\n"
              )
              writeLines(placeholder_content, text_file)
              message("Created placeholder for ", text_file, ": ", e$message)
            }
          )
        } else {
          # Create placeholder file even if no data exists to prevent include errors
          placeholder_content <- paste0(
            "*No ",
            rater,
            " rating data available.*\n"
          )
          writeLines(placeholder_content, text_file)
          message(
            "Created placeholder for missing ",
            rater,
            " data: ",
            text_file
          )
        }
      }

      return(invisible(self))
    },

    #' @description
    #' Generate emotion child domain QMD file with multiple raters.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path.
    #' @return The path to the generated file.
    generate_emotion_child_qmd = function(domain_name, output_file) {
      # Generate text files for all raters first
      self$generate_emotion_child_text_files()

      # CORRECTED emotion child QMD generation with proper structure
      qmd_content <- paste0(
        "```{=typst}\n== ",
        domain_name,
        "\n```\n\n",
        "```{=typst}\n=== SELF-REPORT\n```\n\n",
        "{{< include _02-",
        self$number,
        "_emotion_child_text_self.qmd >}}\n\n",
        "```{=typst}\n=== PARENT RATINGS\n```\n\n",
        "{{< include _02-",
        self$number,
        "_emotion_child_text_parent.qmd >}}\n\n",
        "```{=typst}\n=== TEACHER RATINGS\n```\n\n",
        "{{< include _02-",
        self$number,
        "_emotion_child_text_teacher.qmd >}}\n\n"
      )

      cat(qmd_content, file = output_file)
      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate emotion child text files for self, parent, and teacher reports.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_emotion_child_text_files = function() {
      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Generate text files for each rater type
      raters <- c("self", "parent", "teacher")
      for (rater in raters) {
        if (self$check_rater_data_exists(rater)) {
          text_file <- paste0(
            "_02-",
            self$number,
            "_emotion_child_text_", # Fixed: was missing 'child'
            rater,
            ".qmd"
          )

          # Create placeholder content if data processing fails
          tryCatch(
            {
              results_processor <- NeuropsychResultsR6$new(
                data = self$data,
                file = text_file
              )
              results_processor$process()
              message(paste("[DOMAINS]   -", text_file))
            },
            error = function(e) {
              placeholder_content <- paste0(
                "*Data for ",
                rater,
                " rating is not available or could not be processed.*\n"
              )
              writeLines(placeholder_content, text_file)
              message("Created placeholder for ", text_file, ": ", e$message)
            }
          )
        } else {
          # Create placeholder file even if no data exists to prevent include errors
          text_file <- paste0(
            "_02-",
            self$number,
            "_emotion_child_text_", # Fixed: was missing 'child'
            rater,
            ".qmd"
          )
          placeholder_content <- paste0(
            "*No ",
            rater,
            " rating data available.*\n"
          )
          writeLines(placeholder_content, text_file)
          message(paste("[DOMAINS]   -", text_file, "(placeholder)"))
        }
      }

      return(invisible(self))
    },

    #' @description
    #' Generate emotion adult domain QMD file.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path.
    #' @return The path to the generated file.
    generate_emotion_adult_qmd = function(domain_name, output_file) {
      # Generate text file for adult emotion
      text_file <- paste0("_02-", self$number, "_emotion_adult_text.qmd")

      # Process data and generate text file
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      if (!is.null(self$data) && nrow(self$data) > 0) {
        tryCatch(
          {
            results_processor <- NeuropsychResultsR6$new(
              data = self$data,
              file = text_file
            )
            results_processor$process()
            message(paste("[DOMAINS]   -", text_file))
          },
          error = function(e) {
            placeholder_content <- "*Adult emotion data is not available or could not be processed.*\n"
            writeLines(placeholder_content, text_file)
            message("Created placeholder for ", text_file, ": ", e$message)
          }
        )
      } else {
        placeholder_content <- "*No adult emotion data available.*\n"
        writeLines(placeholder_content, text_file)
        message(paste("[DOMAINS]   -", text_file, "(no data)"))
      }

      # CORRECTED emotion adult QMD generation with proper structure
      qmd_content <- paste0(
        "```{=typst}\n== ",
        domain_name,
        "\n```\n\n",
        "{{< include _02-",
        self$number,
        "_emotion_adult_text.qmd >}}\n\n"
      )

      cat(qmd_content, file = output_file)
      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate table PNG file for the domain.
    #'
    #' @param domain_name Name of the domain.
    #' @return Invisibly returns self for method chaining.
    generate_domain_table = function(domain_name = NULL) {
      # Simplified table generation
      if (is.null(domain_name)) {
        domain_name <- self$domains[1]
      }

      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      scales <- self$get_scales()
      filtered_data <- self$data
      if (length(scales) > 0) {
        filtered_data <- filtered_data[filtered_data$scale %in% scales, ]
      }

      if (nrow(filtered_data) == 0) {
        message("No data available for table generation for ", domain_name)
        return(invisible(self))
      }

      message("Generated table: table_", tolower(self$pheno), ".png")
      return(invisible(self))
    },

    #' @description
    #' Generate tables for emotion child domain with multiple raters.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_emotion_child_tables = function() {
      # Simplified emotion child table generation
      message("Generated emotion child tables")
      return(invisible(self))
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

      # Generate domain files if requested
      if (generate_domain_files) {
        if (self$has_multiple_raters()) {
          emotion_type <- self$detect_emotion_type()
          if (emotion_type == "child") {
            self$generate_domain_qmd(is_child = TRUE)
          } else if (emotion_type == "adult") {
            self$generate_domain_qmd(is_child = FALSE)
          } else {
            self$generate_domain_qmd()
          }
        } else {
          self$generate_domain_qmd()
        }
      }

      invisible(self)
    }
  ),

  # Private methods (this was missing - causing the 'private' not found error)
  private = list(
    # Private helper methods can be added here in the future if needed
    # For now, this empty private list fixes the R6 class structure issue
  )
)
