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
        # Load into a temporary environment to avoid polluting global env
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
      # The calling code should handle this appropriately
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

      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # Generate default output filename if not provided
      if (is.null(output_file)) {
        # Use the proper domain number and simplified naming
        output_file <- paste0("_02-", domain_num, "_", self$pheno, "_text.qmd")
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
      # First try to load from sysdata.rda
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
    #' Check if domain has multiple raters.
    #'
    #' @return Logical indicating if domain has multiple raters.
    has_multiple_raters = function() {
      # Emotion and ADHD domains can have multiple raters
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
        # CHILD MEASURES include:
        # - BASC-3 parent/teacher/self rating scales
        # - PAI adolescent versions (pai_adol*)
        if (
          any(
            self$data$test %in%
              c(
                # BASC-3 measures
                "basc3_prs_child",
                "basc3_prs_adolescent",
                "basc3_srp_child",
                "basc3_srp_adolescent",
                "basc3_trs_child",
                "basc3_trs_adolescent",
                "basc3_prs_preschool",
                "basc3_trs_preschool",
                # PAI adolescent measures (these are CHILD measures)
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
        # ADULT MEASURES include:
        # - Standard PAI (not adolescent versions)
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
        # Check if this is child or adult ADHD
        # This could be determined by domain name or available data
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
          # ADHD child has self, parent, and teacher reports
          return(c("self", "parent", "teacher"))
        } else {
          # ADHD adult has self and observer reports
          return(c("self", "observer"))
        }
      }

      # For emotion domain
      if (tolower(self$pheno) == "emotion") {
        emotion_type <- self$detect_emotion_type()

        if (emotion_type == "child") {
          return(c("self", "parent", "teacher"))
        } else if (emotion_type == "adult") {
          # Adult emotion only uses self-report
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
        observer = character(0) # Observer doesn't have specific CSV files
      )

      # Special case for observer - it's valid for ADHD adult even without specific files
      if (rater_type == "observer" && tolower(self$pheno) == "adhd") {
        # Check if this is adult ADHD (not child)
        if (!any(grepl("child", tolower(self$domains)))) {
          # For ADHD adult, observer is always considered available
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

        # Check each pattern against the CSV files
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

      # Default to FALSE if no matching data found
      return(FALSE)
    },

    #' @description
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

      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # Generate default output filename if not provided
      if (is.null(output_file)) {
        output_file <- paste0(
          "_02-",
          domain_num,
          "_",
          tolower(self$pheno),
          ".qmd"
        )
      }

      # Check if this is ADHD domain
      if (tolower(self$pheno) == "adhd") {
        # Determine if this is child or adult ADHD
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
          # ADHD child
          output_file <- paste0("_02-", domain_num, "_adhd_child.qmd")
          self$generate_adhd_child_qmd(domain_name, output_file)
          return(output_file)
        } else {
          # ADHD adult
          output_file <- paste0("_02-", domain_num, "_adhd_adult.qmd")
          self$generate_adhd_adult_qmd(domain_name, output_file)
          return(output_file)
        }
      }

      # Check if this is emotion domain
      if (tolower(self$pheno) == "emotion") {
        emotion_type <- self$detect_emotion_type()

        if (emotion_type == "child") {
          # Generate child emotion QMD with multiple raters
          output_file <- paste0("_02-", domain_num, "_emotion_child.qmd")
          self$generate_emotion_child_qmd(domain_name, output_file)
          return(output_file)
        } else if (emotion_type == "adult") {
          # Generate adult emotion QMD
          output_file <- paste0("_02-", domain_num, "_emotion_adult.qmd")
          self$generate_emotion_adult_qmd(domain_name, output_file)
          return(output_file)
        }
      }

      # Determine appropriate source note based on domain
      source_notes <- list(
        iq = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        academics = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        verbal = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        spatial = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        memory = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        executive = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        motor = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        social = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        adhd = "T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]",
        emotion = "T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]",
        adaptive = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
        daily_living = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
      )

      source_note <- source_notes[[tolower(self$pheno)]]
      if (is.null(source_note)) {
        source_note <- "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
      }

      # Get the plot title for this domain
      plot_title <- self$get_default_plot_titles()

      # Generate complete QMD content following IQ template
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

        # Setup block
        "```{r}\n",
        "#| label: setup-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n\n",
        "# Source R6 classes\n",
        "source(\"R/DomainProcessorR6.R\")\n",
        "source(\"R/NeuropsychResultsR6.R\")\n",
        "source(\"R/DotplotR6.R\")\n",
        "source(\"R/TableGTR6.R\")\n",
        "source(\"R/score_type_utils.R\")\n\n",
        "# Filter by domain\n",
        "domains <- c(\"",
        domain_name,
        "\")\n\n",
        "# Target phenotype\n",
        "pheno <- \"",
        tolower(self$pheno),
        "\"\n\n",
        "# Create R6 processor\n",
        "processor_",
        tolower(self$pheno),
        " <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        self$input_file,
        "\"\n",
        ")\n\n",
        "# Load and process data\n",
        "processor_",
        tolower(self$pheno),
        "$load_data()\n",
        "processor_",
        tolower(self$pheno),
        "$filter_by_domain()\n\n",
        "# Create the data object with original name for compatibility\n",
        tolower(self$pheno),
        " <- processor_",
        tolower(self$pheno),
        "$data\n\n",
        "# Process and export data using R6\n",
        "processor_",
        tolower(self$pheno),
        "$select_columns()\n",
        "processor_",
        tolower(self$pheno),
        "$save_data()\n\n",
        "# Update the original object\n",
        tolower(self$pheno),
        " <- processor_",
        tolower(self$pheno),
        "$data\n\n",
        "# Load internal data to get standardized scale names\n",
        "scale_var_name <- paste0(\"scales_\", tolower(pheno))\n",
        "if (!exists(scale_var_name)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) { load(sysdata_path, envir = .GlobalEnv) }\n",
        "}\n",
        "if (exists(scale_var_name)) {\n",
        "  scales <- get(scale_var_name)\n",
        "} else {\n",
        "  warning(paste0(\"Scale variable '\", scale_var_name, \"' not found. Using empty vector.\"))\n",
        "  scales <- character(0)\n",
        "}\n\n",
        "# Filter the data directly without using NeurotypR\n",
        "filter_data <- function(data, domain, scale) {\n",
        "  # Filter by domain if provided\n",
        "  if (!is.null(domain)) {\n",
        "    data <- data[data$domain %in% domain, ]\n",
        "  }\n\n",
        "  # Filter by scale if provided\n",
        "  if (!is.null(scale)) {\n",
        "    data <- data[data$scale %in% scale, ]\n",
        "  }\n\n",
        "  return(data)\n",
        "}\n\n",
        "# Apply the filter function\n",
        "data_",
        tolower(self$pheno),
        " <- filter_data(data = ",
        tolower(self$pheno),
        ", domain = domains, scale = scales)\n",
        "```\n",

        # Text generation block
        "```{r}\n",
        "#| label: text-",
        tolower(self$pheno),
        "\n",
        "#| cache: true\n",
        "#| include: false\n\n",
        "# Generate text using R6 class\n",
        "results_processor <- NeuropsychResultsR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  file = \"_02-",
        domain_num,
        "_",
        tolower(self$pheno),
        "_text.qmd\"\n",
        ")\n",
        "results_processor$process()\n",
        "```\n\n",

        # Table block
        "```{r}\n",
        "#| label: qtbl-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n\n",
        "# Table parameters\n",
        "table_name <- \"table_",
        tolower(self$pheno),
        "\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",
        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_",
        tolower(self$pheno),
        ")\n\n",
        "# Create a list of test names grouped by score type\n",
        "score_types_list <- list()\n\n",
        "# Process the score type map to group tests by score type\n",
        "for (test_name in names(score_type_map)) {\n",
        "  types <- score_type_map[[test_name]]\n",
        "  for (type in types) {\n",
        "    if (!type %in% names(score_types_list)) {\n",
        "      score_types_list[[type]] <- character(0)\n",
        "    }\n",
        "    score_types_list[[type]] <- unique(c(score_types_list[[type]], test_name))\n",
        "  }\n",
        "}\n\n",
        "# Get unique score types present\n",
        "unique_score_types <- names(score_types_list)\n\n",
        "# Define the score type footnotes\n",
        "fn_list <- list()\n",
        "if (\"t_score\" %in% unique_score_types) {\n",
        "  fn_list$t_score <- \"T score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"scaled_score\" %in% unique_score_types) {\n",
        "  fn_list$scaled_score <- \"Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]\"\n",
        "}\n\n",
        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",
        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",
        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  # Determine default based on pheno\n",
        "  source_note <- \"",
        source_note,
        "\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",
        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  pheno = pheno,\n",
        "  table_name = table_name,\n",
        "  vertical_padding = vertical_padding,\n",
        "  source_note = source_note,\n",
        "  multiline = multiline,\n",
        "  fn_list = fn_list,\n",
        "  grp_list = grp_list,\n",
        "  dynamic_grp = dynamic_grp\n",
        ")\n\n",
        "# Get the table object without automatic saving\n",
        "tbl <- table_gt$build_table()\n\n",
        "# Save the table using our save_table method\n",
        "table_gt$save_table(tbl, dir = here::here())\n",
        "```\n\n",

        # Figure block (subdomain)
        "```{r}\n",
        "#| label: fig-",
        tolower(self$pheno),
        "-subdomain\n",
        "#| include: false\n\n",
        "# Create subdomain plot using R6 DotplotR6\n",
        "dotplot_subdomain <- DotplotR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  x = \"z_mean_subdomain\",\n",
        "  y = \"subdomain\",\n",
        "  filename = here::here(\"fig_",
        tolower(self$pheno),
        "_subdomain.svg\")\n",
        ")\n",
        "dotplot_subdomain$create_plot()\n\n",
        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_",
        tolower(self$pheno),
        "\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",
        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- \"",
        plot_title,
        "\"\n",
        "}\n",
        "```\n\n",

        # Figure block (narrow) - only add for IQ domain
        if (tolower(self$pheno) == "iq") {
          paste0(
            "```{r}\n",
            "#| label: fig-",
            tolower(self$pheno),
            "-narrow\n",
            "#| include: false\n\n",

            "# Create narrow plot using R6 DotplotR6\n",
            "dotplot_narrow <- DotplotR6$new(\n",
            "  data = data_",
            tolower(self$pheno),
            ",\n",
            "  x = \"z_mean_narrow\",\n",
            "  y = \"narrow\",\n",
            "  filename = here::here(\"fig_",
            tolower(self$pheno),
            "_narrow.svg\")\n",
            ")\n",
            "dotplot_narrow$create_plot()\n\n",
            "# Load plot title from sysdata.rda\n",
            "plot_title_var <- \"plot_title_",
            tolower(self$pheno),
            "\"\n",
            "if (!exists(plot_title_var)) {\n",
            "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
            "  if (file.exists(sysdata_path)) {\n",
            "    load(sysdata_path)\n",
            "  }\n",
            "}\n\n",
            "# Get the plot title or use default\n",
            "if (exists(plot_title_var)) {\n",
            "  plot_title_",
            tolower(self$pheno),
            " <- get(plot_title_var)\n",
            "} else {\n",
            "  plot_title_",
            tolower(self$pheno),
            " <- \"",
            plot_title,
            "\"\n",
            "}\n",
            "```\n\n"
          )
        } else {
          ""
        },

        # Typst layout code
        "```{=typst}\n",
        "// Define a function to create a domain with a title, a table, and a figure\n",
        "#let domain(title: none, file_qtbl, file_fig) = {\n",
        "  let font = (font: \"Roboto Slab\", size: 0.7em)\n",
        "  set text(..font)\n",
        "\n",
        "  // Make all figure labels (Table X:, Figure X:) bold\n",
        "  show figure.caption: it => {\n",
        "    context {\n",
        "      let supplement = it.supplement\n",
        "      let counter = it.counter.display(it.numbering)\n",
        "      block[*#supplement #counter:* #it.body]\n",
        "    }\n",
        "  }\n",
        "\n",
        "  pad(top: 0.5em)[]\n",
        "  grid(\n",
        "    columns: (50%, 50%),\n",
        "    gutter: 8pt,\n",
        "    figure(\n",
        "      [#image(file_qtbl)],\n",
        "      caption: figure.caption(position: top, [#title]),\n",
        "      kind: \"qtbl\",\n",
        "      supplement: [*Table*],\n",
        "    ),\n",
        "    figure(\n",
        "      [#image(file_fig, width: auto)],\n",
        "      caption: figure.caption(\n",
        "        position: bottom,\n",
        "        [`{r} plot_title_",
        tolower(self$pheno),
        "`],\n",
        "      ),\n",
        "      placement: none,\n",
        "      kind: \"image\",\n",
        "      supplement: [*Figure*],\n",
        "      gap: 0.5em,\n",
        "    ),\n",
        "  )\n",
        "}\n",
        "```\n\n",

        "```{=typst}\n",
        "// Define the title of the domain\n",
        "#let title = \"",
        domain_name,
        "\"\n\n",
        "// Define the file name of the table\n",
        "#let file_qtbl = \"table_",
        tolower(self$pheno),
        ".png\"\n\n",
        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_",
        tolower(self$pheno),
        "_subdomain.svg\"\n\n",
        "// The title is appended with ' Scores'\n",
        "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n\n",

        # Second typst section for narrow figure (only for IQ)
        if (tolower(self$pheno) == "iq") {
          paste0(
            "```{=typst}\n",
            "// Define the title of the domain\n",
            "#let title = \"",
            domain_name,
            "\"\n\n",
            "// Define the file name of the table\n",
            "#let file_qtbl = \"table_",
            tolower(self$pheno),
            ".png\"\n\n",
            "// Define the file name of the figure\n",
            "#let file_fig = \"fig_",
            tolower(self$pheno),
            "_narrow.svg\"\n\n",
            "// The title is appended with ' Scores'\n",
            "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
            "```"
          )
        } else {
          ""
        }
      )

      # Write QMD to file
      cat(qmd_content, file = output_file)

      # Generate the text file and table before rendering the main QMD
      self$generate_domain_text_qmd(domain_name)
      self$generate_domain_table(domain_name)

      # Note: Rendering will be done by unified_workflow_runner.R to avoid duplication
      message(paste0(
        "[DOMAINS] Generated ",
        output_file,
        " (rendering deferred to workflow runner)"
      ))

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
        # Check domain type for proper naming
        if (tolower(self$pheno) == "emotion") {
          emotion_type <- self$detect_emotion_type()
          if (emotion_type == "child") {
            output_file <- paste0(
              "_02-",
              domain_num,
              "_emotion_child_text_",
              report_type,
              ".qmd"
            )
          } else {
            output_file <- paste0("_02-", domain_num, "_emotion_adult_text.qmd")
          }
        } else if (tolower(self$pheno) == "adhd") {
          # Determine if this is child or adult ADHD
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
            output_file <- paste0(
              "_02-",
              domain_num,
              "_adhd_child_text_",
              report_type,
              ".qmd"
            )
          } else {
            output_file <- paste0(
              "_02-",
              domain_num,
              "_adhd_adult_text_",
              report_type,
              ".qmd"
            )
          }
        } else {
          # Standard naming for single-rater domains
          output_file <- paste0(
            "_02-",
            domain_num,
            "_",
            tolower(self$pheno),
            "_text.qmd"
          )
        }
      }

      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Use all data for this domain to create text summary
      filtered_data <- self$data

      # If there's no data, create a placeholder
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

      # Generate domain files if requested
      if (generate_domain_files) {
        if (self$has_multiple_raters()) {
          emotion_type <- self$detect_emotion_type()

          if (emotion_type == "child") {
            # Generate child version with multiple raters
            self$generate_domain_qmd(is_child = TRUE)
          } else if (emotion_type == "adult") {
            # Generate adult version
            self$generate_domain_qmd(is_child = FALSE)
          } else {
            # Default to standard version
            self$generate_domain_qmd()
          }
        } else {
          # Generate standard version only
          self$generate_domain_qmd()
        }
      }

      invisible(self)
    },

    #' @description
    #' Generate ADHD adult domain QMD file with self and observer reports.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path.
    #' @return The path to the generated file.
    generate_adhd_adult_qmd = function(domain_name, output_file) {
      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # Generate text files for self and observer
      self$generate_adhd_adult_text_files()

      # Start building QMD content
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-adhd-adult}\n\n",

        "### SELF-REPORT\n\n",
        "{{< include _02-",
        domain_num,
        "_adhd_adult_text_self.qmd >}}\n\n",

        "### OBSERVER RATINGS\n\n",
        "{{< include _02-",
        domain_num,
        "_adhd_adult_text_observer.qmd >}}\n\n",

        # Add R code blocks for processing (simplified version)
        "```{r}\n",
        "#| label: setup-adhd-adult\n",
        "#| include: false\n\n",
        "# Source R6 classes\n",
        "source(\"R/DomainProcessorR6.R\")\n",
        "source(\"R/NeuropsychResultsR6.R\")\n",
        "source(\"R/DotplotR6.R\")\n",
        "source(\"R/TableGTR6.R\")\n",
        "source(\"R/score_type_utils.R\")\n\n",
        "# Filter by domain\n",
        "domains <- c(\"",
        domain_name,
        "\")\n\n",
        "# Target phenotype\n",
        "pheno <- \"adhd\"\n\n",
        "# Create R6 processor\n",
        "processor_adhd <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        self$input_file,
        "\"\n",
        ")\n\n",
        "# Load and process data\n",
        "processor_adhd$load_data()\n",
        "processor_adhd$filter_by_domain()\n",
        "processor_adhd$select_columns()\n",
        "processor_adhd$save_data()\n\n",
        "# Create data objects\n",
        "adhd <- processor_adhd$data\n",
        "```\n"
      )

      # Write QMD to file
      cat(qmd_content, file = output_file)

      # Note: Rendering will be done by unified_workflow_runner.R to avoid duplication
      message(paste0(
        "[DOMAINS] Generated ",
        output_file,
        " (rendering deferred to workflow runner)"
      ))

      return(output_file)
    },

    #' @description
    #' Generate ADHD child domain QMD file with self, parent, and teacher reports.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path.
    #' @return The path to the generated file.
    generate_adhd_child_qmd = function(domain_name, output_file) {
      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # Generate text files for self, parent, and teacher
      self$generate_adhd_child_text_files()

      # Start building QMD content
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-adhd-child}\n\n",

        "### SELF-REPORT\n\n",
        "{{< include _02-",
        domain_num,
        "_adhd_child_text_self.qmd >}}\n\n",

        "### PARENT RATINGS\n\n",
        "{{< include _02-",
        domain_num,
        "_adhd_child_text_parent.qmd >}}\n\n",

        "### TEACHER RATINGS\n\n",
        "{{< include _02-",
        domain_num,
        "_adhd_child_text_teacher.qmd >}}\n\n",

        # Add R code blocks for processing (simplified version)
        "```{r}\n",
        "#| label: setup-adhd-child\n",
        "#| include: false\n\n",
        "# Source R6 classes\n",
        "source(\"R/DomainProcessorR6.R\")\n",
        "source(\"R/NeuropsychResultsR6.R\")\n",
        "source(\"R/DotplotR6.R\")\n",
        "source(\"R/TableGTR6.R\")\n",
        "source(\"R/score_type_utils.R\")\n\n",
        "# Filter by domain\n",
        "domains <- c(\"",
        domain_name,
        "\")\n\n",
        "# Target phenotype\n",
        "pheno <- \"adhd\"\n\n",
        "# Create R6 processor\n",
        "processor_adhd <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        self$input_file,
        "\"\n",
        ")\n\n",
        "# Load and process data\n",
        "processor_adhd$load_data()\n",
        "processor_adhd$filter_by_domain()\n",
        "processor_adhd$select_columns()\n",
        "processor_adhd$save_data()\n\n",
        "# Create data objects\n",
        "adhd <- processor_adhd$data\n",
        "```\n"
      )

      # Write QMD to file
      cat(qmd_content, file = output_file)

      # Note: Rendering will be done by unified_workflow_runner.R to avoid duplication
      message(paste0(
        "[DOMAINS] Generated ",
        output_file,
        " (rendering deferred to workflow runner)"
      ))

      return(output_file)
    },

    #' @description
    #' Generate ADHD adult text files for self and observer reports.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_adhd_adult_text_files = function() {
      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Check if we have data for self-report
      if (self$check_rater_data_exists("self")) {
        self_file <- paste0("_02-", domain_num, "_adhd_adult_text_self.qmd")
        results_processor <- NeuropsychResultsR6$new(
          data = self$data,
          file = self_file
        )
        results_processor$process()
      }

      # Check if we have data for observer report
      if (self$check_rater_data_exists("observer")) {
        observer_file <- paste0(
          "_02-",
          domain_num,
          "_adhd_adult_text_observer.qmd"
        )
        results_processor <- NeuropsychResultsR6$new(
          data = self$data,
          file = observer_file
        )
        results_processor$process()
      }

      return(invisible(self))
    },

    #' @description
    #' Generate ADHD child text files for self, parent, and teacher reports.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_adhd_child_text_files = function() {
      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Check if we have data for self-report
      if (self$check_rater_data_exists("self")) {
        self_file <- paste0("_02-", domain_num, "_adhd_child_text_self.qmd")
        results_processor <- NeuropsychResultsR6$new(
          data = self$data,
          file = self_file
        )
        results_processor$process()
      }

      # Check if we have data for parent report
      if (self$check_rater_data_exists("parent")) {
        parent_file <- paste0("_02-", domain_num, "_adhd_child_text_parent.qmd")
        results_processor <- NeuropsychResultsR6$new(
          data = self$data,
          file = parent_file
        )
        results_processor$process()
      }

      # Check if we have data for teacher report
      if (self$check_rater_data_exists("teacher")) {
        teacher_file <- paste0(
          "_02-",
          domain_num,
          "_adhd_child_text_teacher.qmd"
        )
        results_processor <- NeuropsychResultsR6$new(
          data = self$data,
          file = teacher_file
        )
        results_processor$process()
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
      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # Start building QMD content
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-",
        tolower(self$pheno),
        "-child}\n\n",

        # Setup block
        "```{r}\n",
        "#| label: setup-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n\n",
        "# Source R6 classes\n",
        "source(\"R/DomainProcessorR6.R\")\n",
        "source(\"R/NeuropsychResultsR6.R\")\n",
        "source(\"R/DotplotR6.R\")\n",
        "source(\"R/TableGTR6.R\")\n",
        "source(\"R/score_type_utils.R\")\n\n",
        "# Filter by domain\n",
        "domains <- c(\n",
        paste0("  \"", self$domains, "\"", collapse = ",\n"),
        "\n)\n\n",
        "# Target phenotype\n",
        "pheno <- \"",
        tolower(self$pheno),
        "\"\n\n",
        "# Create R6 processor\n",
        "processor_",
        tolower(self$pheno),
        " <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        self$input_file,
        "\"\n",
        ")\n\n",
        "# Load and process data\n",
        "processor_",
        tolower(self$pheno),
        "$load_data()\n",
        "processor_",
        tolower(self$pheno),
        "$filter_by_domain()\n\n",
        "# Create the data object with original name for compatibility\n",
        tolower(self$pheno),
        " <- processor_",
        tolower(self$pheno),
        "$data\n\n",
        "# Process and export data using R6\n",
        "processor_",
        tolower(self$pheno),
        "$select_columns()\n",
        "processor_",
        tolower(self$pheno),
        "$save_data()\n\n",
        "# Update the original object\n",
        tolower(self$pheno),
        " <- processor_",
        tolower(self$pheno),
        "$data\n\n",
        "# Load internal data to get standardized scale names\n",
        "# Check if this domain uses child/adult suffixes\n",
        "use_child_suffix <- tolower(pheno) %in% c(\"adhd\", \"emotion\")\n",
        "scale_var_name <- if (use_child_suffix) {\n",
        "  paste0(\"scales_\", tolower(pheno), \"_child\")\n",
        "} else {\n",
        "  paste0(\"scales_\", tolower(pheno))\n",
        "}\n\n",
        "if (!exists(scale_var_name)) {\n",
        "  # Load from sysdata.rda\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  } else {\n",
        "    stop(\n",
        "      \"Could not load \", scale_var_name, \" from sysdata.rda. Please ensure the internal data file exists.\"\n",
        "    )\n",
        "  }\n",
        "}\n\n",
        "scales <- get(scale_var_name)\n\n",
        "# Filter the data directly without using NeurotypR\n",
        "filter_data <- function(data, domain, scale) {\n",
        "  # Filter by domain if provided\n",
        "  if (!is.null(domain)) {\n",
        "    data <- data[data$domain %in% domain, ]\n",
        "  }\n\n",
        "  # Filter by scale if provided\n",
        "  if (!is.null(scale)) {\n",
        "    data <- data[data$scale %in% scale, ]\n",
        "  }\n\n",
        "  return(data)\n",
        "}\n\n",
        "# Apply the filter function\n",
        "data_",
        tolower(self$pheno),
        " <- filter_data(data = ",
        tolower(self$pheno),
        ", domain = domains, scale = scales)\n",
        "```\n\n"
      )

      # Add specific rater blocks only if data exists
      # Self report block
      if (self$check_rater_data_exists("self")) {
        qmd_content <- paste0(
          qmd_content,
          "```{r}\n",
          "#| label: text-",
          tolower(self$pheno),
          "-child-self\n",
          "#| cache: true\n",
          "#| include: false\n\n",
          "data_",
          tolower(self$pheno),
          "_self <- data_",
          tolower(self$pheno),
          " |>\n",
          "  dplyr::filter(test %in% c(\"pai_adol\", \"pai_adol_clinical\", \"basc3_srp_adolescent\", \"basc3_srp_child\"))\n\n",
          "# Generate text using R6 class\n",
          "if (nrow(data_",
          tolower(self$pheno),
          "_self) > 0) {\n",
          "  results_processor <- NeuropsychResultsR6$new(\n",
          "    data = data_",
          tolower(self$pheno),
          "_self,\n",
          "    file = \"_02-",
          domain_num,
          "_",
          tolower(self$pheno),
          "_child_text_self.qmd\"\n",
          "  )\n",
          "  results_processor$process()\n",
          "}\n",
          "```\n\n"
        )
      }

      # Parent report block
      if (self$check_rater_data_exists("parent")) {
        qmd_content <- paste0(
          qmd_content,
          "```{r}\n",
          "#| label: text-",
          tolower(self$pheno),
          "-child-parent\n",
          "#| cache: true\n",
          "#| include: false\n\n",
          "data_",
          tolower(self$pheno),
          "_parent <- data_",
          tolower(self$pheno),
          " |>\n",
          "  dplyr::filter(\n",
          "    test %in%\n",
          "      c(\"basc3_prs_adolescent\", \"basc3_prs_child\", \"basc3_prs_preschool\")\n",
          "  )\n\n",
          "# Generate text using R6 class\n",
          "if (nrow(data_",
          tolower(self$pheno),
          "_parent) > 0) {\n",
          "  results_processor <- NeuropsychResultsR6$new(\n",
          "    data = data_",
          tolower(self$pheno),
          "_parent,\n",
          "    file = \"_02-",
          domain_num,
          "_",
          tolower(self$pheno),
          "_child_text_parent.qmd\"\n",
          "  )\n",
          "  results_processor$process()\n",
          "}\n",
          "```\n\n"
        )
      }

      # Teacher report block - only if data exists
      if (self$check_rater_data_exists("teacher")) {
        qmd_content <- paste0(
          qmd_content,
          "```{r}\n",
          "#| label: text-",
          tolower(self$pheno),
          "-child-teacher\n",
          "#| cache: true\n",
          "#| eval: false\n",
          "#| include: false\n\n",
          "data_",
          tolower(self$pheno),
          "_teacher <- data_",
          tolower(self$pheno),
          " |>\n",
          "  dplyr::filter(\n",
          "    test %in%\n",
          "      c(\"basc3_trs_adolescent\", \"basc3_trs_child\", \"basc3_trs_preschool\")\n",
          "  )\n\n",
          "# Generate text using R6 class\n",
          "if (nrow(data_",
          tolower(self$pheno),
          "_teacher) > 0) {\n",
          "  results_processor <- NeuropsychResultsR6$new(\n",
          "    data = data_",
          tolower(self$pheno),
          "_teacher,\n",
          "    file = \"_02-",
          domain_num,
          "_",
          tolower(self$pheno),
          "_child_text_teacher.qmd\"\n",
          "  )\n",
          "  results_processor$process()\n",
          "}\n",
          "```\n\n"
        )
      }

      # Add table blocks for each rater
      # Self report table
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: qtbl-",
        tolower(self$pheno),
        "-self\n",
        "#| include: false\n\n",

        "# Table parameters\n",
        "table_name <- \"table_",
        tolower(self$pheno),
        "_child_self\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",
        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_",
        tolower(self$pheno),
        "_self)\n\n",
        "# Create a list of test names grouped by score type\n",
        "score_types_list <- list()\n\n",
        "# Process the score type map to group tests by score type\n",
        "for (test_name in names(score_type_map)) {\n",
        "  types <- score_type_map[[test_name]]\n",
        "  for (type in types) {\n",
        "    if (!type %in% names(score_types_list)) {\n",
        "      score_types_list[[type]] <- character(0)\n",
        "    }\n",
        "    score_types_list[[type]] <- unique(c(score_types_list[[type]], test_name))\n",
        "  }\n",
        "}\n\n",
        "# Get unique score types present\n",
        "unique_score_types <- names(score_types_list)\n\n",
        "# Define the score type footnotes\n",
        "fn_list <- list()\n",
        "if (\"t_score\" %in% unique_score_types) {\n",
        "  fn_list$t_score <- \"T score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"scaled_score\" %in% unique_score_types) {\n",
        "  fn_list$scaled_score <- \"Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]\"\n",
        "}\n\n",
        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",
        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",
        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  source_note <- \"T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",
        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        "_self,\n",
        "  pheno = pheno,\n",
        "  table_name = table_name,\n",
        "  vertical_padding = vertical_padding,\n",
        "  source_note = source_note,\n",
        "  multiline = multiline,\n",
        "  fn_list = fn_list,\n",
        "  grp_list = grp_list,\n",
        "  dynamic_grp = dynamic_grp\n",
        ")\n\n",
        "# Get the table object without automatic saving\n",
        "tbl <- table_gt$build_table()\n\n",
        "# Save the table using our save_table method\n",
        "table_gt$save_table(tbl, dir = here::here())\n",
        "```\n\n"
      )

      # Parent report table
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: qtbl-",
        tolower(self$pheno),
        "-parent\n",
        "#| include: false\n\n",

        "# Table parameters\n",
        "table_name <- \"table_",
        tolower(self$pheno),
        "_child_parent\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",
        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_",
        tolower(self$pheno),
        "_parent)\n\n",
        "# Create a list of test names grouped by score type\n",
        "score_types_list <- list()\n\n",
        "# Process the score type map to group tests by score type\n",
        "for (test_name in names(score_type_map)) {\n",
        "  types <- score_type_map[[test_name]]\n",
        "  for (type in types) {\n",
        "    if (!type %in% names(score_types_list)) {\n",
        "      score_types_list[[type]] <- character(0)\n",
        "    }\n",
        "    score_types_list[[type]] <- unique(c(score_types_list[[type]], test_name))\n",
        "  }\n",
        "}\n\n",
        "# Get unique score types present\n",
        "unique_score_types <- names(score_types_list)\n\n",
        "# Define the score type footnotes\n",
        "fn_list <- list()\n",
        "if (\"t_score\" %in% unique_score_types) {\n",
        "  fn_list$t_score <- \"T score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"scaled_score\" %in% unique_score_types) {\n",
        "  fn_list$scaled_score <- \"Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]\"\n",
        "}\n\n",
        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",
        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",
        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  source_note <- \"T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",
        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        "_parent,\n",
        "  pheno = pheno,\n",
        "  table_name = table_name,\n",
        "  vertical_padding = vertical_padding,\n",
        "  source_note = source_note,\n",
        "  multiline = multiline,\n",
        "  fn_list = fn_list,\n",
        "  grp_list = grp_list,\n",
        "  dynamic_grp = dynamic_grp\n",
        ")\n\n",
        "# Get the table object without automatic saving\n",
        "tbl <- table_gt$build_table()\n\n",
        "# Save the table using our save_table method\n",
        "table_gt$save_table(tbl, dir = here::here())\n",
        "```\n\n"
      )

      # Teacher report table (commented out by default)
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: qtbl-",
        tolower(self$pheno),
        "-teacher\n",
        "#| include: false\n",
        "#| eval: false\n\n",
        "# Table parameters\n",
        "table_name <- \"table_",
        tolower(self$pheno),
        "_child_teacher\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",
        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_",
        tolower(self$pheno),
        "_teacher)\n\n",
        "# Create a list of test names grouped by score type\n",
        "score_types_list <- list()\n\n",
        "# Process the score type map to group tests by score type\n",
        "for (test_name in names(score_type_map)) {\n",
        "  types <- score_type_map[[test_name]]\n",
        "  for (type in types) {\n",
        "    if (!type %in% names(score_types_list)) {\n",
        "      score_types_list[[type]] <- character(0)\n",
        "    }\n",
        "    score_types_list[[type]] <- unique(c(score_types_list[[type]], test_name))\n",
        "  }\n",
        "}\n\n",
        "# Get unique score types present\n",
        "unique_score_types <- names(score_types_list)\n\n",
        "# Define the score type footnotes\n",
        "fn_list <- list()\n",
        "if (\"t_score\" %in% unique_score_types) {\n",
        "  fn_list$t_score <- \"T score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"scaled_score\" %in% unique_score_types) {\n",
        "  fn_list$scaled_score <- \"Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]\"\n",
        "}\n\n",
        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",
        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",
        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  source_note <- \"T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",
        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        "_teacher,\n",
        "  pheno = pheno,\n",
        "  table_name = table_name,\n",
        "  vertical_padding = vertical_padding,\n",
        "  source_note = source_note,\n",
        "  multiline = multiline,\n",
        "  fn_list = fn_list,\n",
        "  grp_list = grp_list,\n",
        "  dynamic_grp = dynamic_grp\n",
        ")\n\n",
        "# Get the table object without automatic saving\n",
        "tbl <- table_gt$build_table()\n\n",
        "# Save the table using our save_table method\n",
        "table_gt$save_table(tbl, dir = here::here())\n",
        "```\n\n"
      )

      # Add figure blocks for each rater
      # Self report figure
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: fig-",
        tolower(self$pheno),
        "-subdomain-self\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "dotplot_subdomain <- DotplotR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        "_self,\n",
        "  x = \"z_mean_subdomain\",\n",
        "  y = \"subdomain\",\n",
        "  filename = here::here(\"fig_",
        tolower(self$pheno),
        "_subdomain_self.svg\")\n",
        ")\n",
        "dotplot_subdomain$create_plot()\n\n",
        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_",
        tolower(self$pheno),
        "_child_self\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",
        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_",
        tolower(self$pheno),
        "_child_self <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_",
        tolower(self$pheno),
        "_child_self <- \"This section presents results from the ",
        domain_name,
        " domain assessment.\"\n",
        "}\n",
        "```\n\n"
      )

      # Parent report figure
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: fig-",
        tolower(self$pheno),
        "-subdomain-parent\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "dotplot_subdomain <- DotplotR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        "_parent,\n",
        "  x = \"z_mean_subdomain\",\n",
        "  y = \"subdomain\",\n",
        "  filename = here::here(\"fig_",
        tolower(self$pheno),
        "_subdomain_parent.svg\")\n",
        ")\n",
        "dotplot_subdomain$create_plot()\n\n",
        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_",
        tolower(self$pheno),
        "_child_parent\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",
        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_",
        tolower(self$pheno),
        "_child_parent <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_",
        tolower(self$pheno),
        "_child_parent <- \"This section presents parent-rating results from the ",
        domain_name,
        " domain assessment.\"\n",
        "}\n",
        "```\n\n"
      )

      # Teacher report figure (commented out by default)
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: fig-",
        tolower(self$pheno),
        "-subdomain-teacher\n",
        "#| include: false\n\n",
        "#| eval: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "dotplot_subdomain <- DotplotR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        "_teacher,\n",
        "  x = \"z_mean_subdomain\",\n",
        "  y = \"subdomain\",\n",
        "  filename = here::here(\"fig_",
        tolower(self$pheno),
        "_subdomain_teacher.svg\")\n",
        ")\n",
        "dotplot_subdomain$create_plot()\n\n",
        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_",
        tolower(self$pheno),
        "_child_teacher\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",
        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_",
        tolower(self$pheno),
        "_child_teacher <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_",
        tolower(self$pheno),
        "_child_teacher <- \"This section presents teacher-rated results from the ",
        domain_name,
        " domain assessment.\"\n",
        "}\n",
        "```\n\n"
      )

      # Add SELF-REPORT section if data exists
      if (self$check_rater_data_exists("self")) {
        qmd_content <- paste0(
          qmd_content,
          "### SELF-REPORT\n\n",
          "{{< include _02-",
          domain_num,
          "_",
          tolower(self$pheno),
          "_child_text_self.qmd >}}\n\n",
          "```{=typst}\n",
          "// Define a function to create a domain with a title, a table, and a figure\n",
          "#let domain(title: none, file_qtbl, file_fig) = {\n",
          "  let font = (font: \"Roboto Slab\", size: 0.7em)\n",
          "  set text(..font)\n",
          "  // Make all figure labels (Table X:, Figure X:) bold\n",
          "  show figure.caption: it => {\n",
          "    context {\n",
          "      let supplement = it.supplement\n",
          "      let counter = it.counter.display(it.numbering)\n",
          "      block[*#supplement #counter:* #it.body]\n",
          "    }\n",
          "  }\n",
          "  pad(top: 0.5em)[]\n",
          "  grid(\n",
          "    columns: (50%, 50%),\n",
          "    gutter: 8pt,\n",
          "    figure(\n",
          "      [#image(file_qtbl)],\n",
          "      caption: figure.caption(position: top, [#title]),\n",
          "      kind: \"qtbl\",\n",
          "      supplement: [*Table*],\n",
          "    ),\n",
          "    figure(\n",
          "      [#image(file_fig, width: auto)],\n",
          "      caption: figure.caption(\n",
          "        position: bottom,\n",
          "        [`{r} plot_title_",
          tolower(self$pheno),
          "_child_self`],\n",
          "      ),\n",
          "      placement: none,\n",
          "      kind: \"image\",\n",
          "      supplement: [*Figure*],\n",
          "      gap: 0.5em,\n",
          "    ),\n",
          "  )\n",
          "}\n",
          "```\n\n",
          "```{=typst}\n",
          "// Define the title of the domain\n",
          "#let title = \"",
          domain_name,
          "\"\n\n",
          "// Define the file name of the table\n",
          "#let file_qtbl = \"table_",
          tolower(self$pheno),
          "_child_self.png\"\n\n",
          "// Define the file name of the figure\n",
          "#let file_fig = \"fig_",
          tolower(self$pheno),
          "_subdomain_self.svg\"\n\n",
          "// Call the 'domain' function with the specified title, table file name, and figure file name\n",
          "#domain(title: [#title], file_qtbl, file_fig)\n",
          "```\n\n"
        )
      }

      # Add PARENT RATINGS section if data exists
      if (self$check_rater_data_exists("parent")) {
        qmd_content <- paste0(
          qmd_content,
          "### PARENT RATINGS\n\n",
          "{{< include _02-",
          domain_num,
          "_",
          tolower(self$pheno),
          "_child_text_parent.qmd >}}\n\n",
          "```{=typst}\n",
          "// Define a function to create a domain with a title, a table, and a figure\n",
          "#let domain(title: none, file_qtbl, file_fig) = {\n",
          "  let font = (font: \"Roboto Slab\", size: 0.7em)\n",
          "  set text(..font)\n",
          "  // Make all figure labels (Table X:, Figure X:) bold\n",
          "  show figure.caption: it => {\n",
          "    context {\n",
          "      let supplement = it.supplement\n",
          "      let counter = it.counter.display(it.numbering)\n",
          "      block[*#supplement #counter:* #it.body]\n",
          "    }\n",
          "  }\n",
          "  pad(top: 0.5em)[]\n",
          "  grid(\n",
          "    columns: (50%, 50%),\n",
          "    gutter: 8pt,\n",
          "    figure(\n",
          "      [#image(file_qtbl)],\n",
          "      caption: figure.caption(position: top, [#title]),\n",
          "      kind: \"qtbl\",\n",
          "      supplement: [*Table*],\n",
          "    ),\n",
          "    figure(\n",
          "      [#image(file_fig, width: auto)],\n",
          "      caption: figure.caption(\n",
          "        position: bottom,\n",
          "        [`{r} plot_title_",
          tolower(self$pheno),
          "_child_parent`],\n",
          "      ),\n",
          "      placement: none,\n",
          "      kind: \"image\",\n",
          "      supplement: [*Figure*],\n",
          "      gap: 0.5em,\n",
          "    ),\n",
          "  )\n",
          "}\n",
          "```\n\n",
          "```{=typst}\n",
          "// Define the title of the domain\n",
          "#let title = \"",
          domain_name,
          "\"\n\n",
          "// Define the file name of the table\n",
          "#let file_qtbl = \"table_",
          tolower(self$pheno),
          "_child_parent.png\"\n\n",
          "// Define the file name of the figure\n",
          "#let file_fig = \"fig_",
          tolower(self$pheno),
          "_subdomain_parent.svg\"\n\n",
          "// Call the 'domain' function with the specified title, table file name, and figure file name\n",
          "#domain(title: [#title], file_qtbl, file_fig)\n",
          "```\n\n"
        )
      }

      # Add TEACHER RATINGS section if data exists
      if (self$check_rater_data_exists("teacher")) {
        qmd_content <- paste0(
          qmd_content,
          "### TEACHER RATINGS\n\n",
          "{{< include _02-",
          domain_num,
          "_",
          tolower(self$pheno),
          "_child_text_teacher.qmd >}}\n\n",
          "```{=typst}\n",
          "// Define a function to create a domain with a title, a table, and a figure\n",
          "#let domain(title: none, file_qtbl, file_fig) = {\n",
          "  let font = (font: \"Roboto Slab\", size: 0.7em)\n",
          "  set text(..font)\n",
          "  // Make all figure labels (Table X:, Figure X:) bold\n",
          "  show figure.caption: it => {\n",
          "    context {\n",
          "      let supplement = it.supplement\n",
          "      let counter = it.counter.display(it.numbering)\n",
          "      block[*#supplement #counter:* #it.body]\n",
          "    }\n",
          "  }\n",
          "  pad(top: 0.5em)[]\n",
          "  grid(\n",
          "    columns: (50%, 50%),\n",
          "    gutter: 8pt,\n",
          "    figure(\n",
          "      [#image(file_qtbl)],\n",
          "      caption: figure.caption(position: top, [#title]),\n",
          "      kind: \"qtbl\",\n",
          "      supplement: [*Table*],\n",
          "    ),\n",
          "    figure(\n",
          "      [#image(file_fig, width: auto)],\n",
          "      caption: figure.caption(\n",
          "        position: bottom,\n",
          "        [`{r} plot_title_",
          tolower(self$pheno),
          "_child_teacher`],\n",
          "      ),\n",
          "      placement: none,\n",
          "      kind: \"image\",\n",
          "      supplement: [*Figure*],\n",
          "      gap: 0.5em,\n",
          "    ),\n",
          "  )\n",
          "}\n",
          "```\n\n",
          "```{=typst}\n",
          "// Define the title of the domain\n",
          "#let title = \"",
          domain_name,
          "\"\n\n",
          "// Define the file name of the table\n",
          "#let file_qtbl = \"table_",
          tolower(self$pheno),
          "_child_teacher.png\"\n\n",
          "// Define the file name of the figure\n",
          "#let file_fig = \"fig_",
          tolower(self$pheno),
          "_subdomain_teacher.svg\"\n\n",
          "// Call the 'domain' function with the specified title, table file name, and figure file name\n",
          "#domain(title: [#title], file_qtbl, file_fig)\n",
          "```\n\n"
        )
      }

      # Write QMD to file
      cat(qmd_content, file = output_file)

      # Generate tables for each rater type before rendering
      self$generate_emotion_child_tables()

      # Note: Rendering will be done by unified_workflow_runner.R to avoid duplication
      message(paste0(
        "[DOMAINS] Generated ",
        output_file,
        " (rendering deferred to workflow runner)"
      ))

      return(output_file)
    },

    #' @description
    #' Generate emotion adult domain QMD file.
    #'
    #' @param domain_name Name of the domain.
    #' @param output_file Output file path.
    #' @return The path to the generated file.
    generate_emotion_adult_qmd = function(domain_name, output_file) {
      # Get the domain number for file naming
      domain_num <- self$get_domain_number()

      # Start building QMD content
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-",
        tolower(self$pheno),
        "-adult}\n\n",

        "{{< include _02-",
        domain_num,
        "_",
        tolower(self$pheno),
        "_adult_text.qmd >}}\n\n",

        # Setup block
        "```{r}\n",
        "#| label: setup-",
        tolower(self$pheno),
        "-adult\n",
        "#| include: false\n\n",

        "# Source R6 classes\n",
        "source(\"R/DomainProcessorR6.R\")\n",
        "source(\"R/NeuropsychResultsR6.R\")\n",
        "source(\"R/DotplotR6.R\")\n",
        "source(\"R/TableGTR6.R\")\n",
        "source(\"R/score_type_utils.R\")\n\n",
        "# Filter by domain\n",
        "domains <- c(\"",
        domain_name,
        "\")\n\n",
        "# Target phenotype\n",
        "pheno <- \"",
        tolower(self$pheno),
        "\"\n\n",
        "# Create R6 processor\n",
        "processor_",
        tolower(self$pheno),
        " <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        self$input_file,
        "\"\n",
        ")\n\n",
        "# Load and process data\n",
        "processor_",
        tolower(self$pheno),
        "$load_data()\n",
        "processor_",
        tolower(self$pheno),
        "$filter_by_domain()\n\n",
        "# Create the data object with original name for compatibility\n",
        tolower(self$pheno),
        " <- processor_",
        tolower(self$pheno),
        "$data\n",
        "```\n\n",

        # Export block
        "```{r}\n",
        "#| label: export-",
        tolower(self$pheno),
        "-adult\n",
        "#| include: false\n\n",

        "# Process and export data using R6\n",
        "processor_",
        tolower(self$pheno),
        "$select_columns()\n",
        "processor_",
        tolower(self$pheno),
        "$save_data()\n\n",
        "# Update the original object\n",
        tolower(self$pheno),
        " <- processor_",
        tolower(self$pheno),
        "$data\n",
        "```\n\n",

        # Data block
        "```{r}\n",
        "#| label: data-",
        tolower(self$pheno),
        "-adult\n",
        "#| include: false\n\n",

        "# Load internal data to get standardized scale names\n",
        "# The scales_",
        tolower(self$pheno),
        "_adult object is available from the package's internal data\n",
        "if (!exists(\"scales_",
        tolower(self$pheno),
        "_adult\")) {\n",
        "  # Load from sysdata.rda\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  } else {\n",
        "    stop(\n",
        "      \"Could not load scales_",
        tolower(self$pheno),
        "_adult from sysdata.rda. Please ensure the internal data file exists.\"\n",
        "    )\n",
        "  }\n",
        "}\n\n",
        "scales <- scales_",
        tolower(self$pheno),
        "_adult\n\n",
        "# Filter the data directly without using NeurotypR\n",
        "filter_data <- function(data, domain, scale) {\n",
        "  # Filter by domain if provided\n",
        "  if (!is.null(domain)) {\n",
        "    data <- data[data$domain %in% domain, ]\n",
        "  }\n\n",
        "  # Filter by scale if provided\n",
        "  if (!is.null(scale)) {\n",
        "    data <- data[data$scale %in% scale, ]\n",
        "  }\n\n",
        "  return(data)\n",
        "}\n\n",
        "# Apply the filter function\n",
        "data_",
        tolower(self$pheno),
        " <- filter_data(data = ",
        tolower(self$pheno),
        ", domain = domains, scale = scales)\n",
        "```\n\n",

        # Text generation block
        "```{r}\n",
        "#| label: text-",
        tolower(self$pheno),
        "-adult\n",
        "#| cache: true\n",
        "#| include: false\n\n",

        "# Generate text using R6 class\n",
        "results_processor <- NeuropsychResultsR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  file = \"_02-",
        domain_num,
        "_",
        tolower(self$pheno),
        "_adult_text.qmd\"\n",
        ")\n",
        "results_processor$process()\n",
        "```\n\n\n",

        # Table block
        "```{r}\n",
        "#| label: qtbl-",
        tolower(self$pheno),
        "-adult\n",
        "#| include: false\n\n",

        "# Table parameters\n",
        "table_name <- \"table_",
        tolower(self$pheno),
        "_adult\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",
        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_",
        tolower(self$pheno),
        ")\n\n",
        "# Create a list of test names grouped by score type\n",
        "score_types_list <- list()\n\n",
        "# Process the score type map to group tests by score type\n",
        "for (test_name in names(score_type_map)) {\n",
        "  types <- score_type_map[[test_name]]\n",
        "  for (type in types) {\n",
        "    if (!type %in% names(score_types_list)) {\n",
        "      score_types_list[[type]] <- character(0)\n",
        "    }\n",
        "    score_types_list[[type]] <- unique(c(score_types_list[[type]], test_name))\n",
        "  }\n",
        "}\n\n",
        "# Get unique score types present\n",
        "unique_score_types <- names(score_types_list)\n\n",
        "# Define the score type footnotes\n",
        "fn_list <- list()\n",
        "if (\"t_score\" %in% unique_score_types) {\n",
        "  fn_list$t_score <- \"T score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"scaled_score\" %in% unique_score_types) {\n",
        "  fn_list$scaled_score <- \"Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]\"\n",
        "}\n",
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]\"\n",
        "}\n\n",
        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",
        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",
        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  source_note <- \"T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",
        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  pheno = pheno,\n",
        "  table_name = table_name,\n",
        "  vertical_padding = vertical_padding,\n",
        "  source_note = source_note,\n",
        "  multiline = multiline,\n",
        "  fn_list = fn_list,\n",
        "  grp_list = grp_list,\n",
        "  dynamic_grp = dynamic_grp\n",
        ")\n\n",
        "# Get the table object without automatic saving\n",
        "tbl <- table_gt$build_table()\n\n",
        "# Save the table using our save_table method\n",
        "table_gt$save_table(tbl, dir = here::here())\n",
        "```\n\n\n",

        # Figure block
        "```{r}\n",
        "#| label: fig-",
        tolower(self$pheno),
        "-adult-subdomain\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "dotplot_subdomain <- DotplotR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  x = \"z_mean_subdomain\",\n",
        "  y = \"subdomain\",\n",
        "  filename = here::here(\"fig_",
        tolower(self$pheno),
        "_adult_subdomain.svg\")\n",
        ")\n",
        "dotplot_subdomain$create_plot()\n\n",
        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_",
        tolower(self$pheno),
        "_adult\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",
        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- \"This section presents results from the ",
        domain_name,
        " domain assessment.\"\n",
        "}\n",
        "```\n\n",

        # Typst layout code
        "```{=typst}\n",
        "// Define a function to create a domain with a title, a table, and a figure\n",
        "#let domain(title: none, file_qtbl, file_fig) = {\n",
        "  let font = (font: \"Roboto Slab\", size: 0.7em)\n",
        "  set text(..font)\n\n",
        "  // Make all figure labels (Table X:, Figure X:) bold\n",
        "  show figure.caption: it => {\n",
        "    context {\n",
        "      let supplement = it.supplement\n",
        "      let counter = it.counter.display(it.numbering)\n",
        "      block[*#supplement #counter:* #it.body]\n",
        "    }\n",
        "  }\n\n",
        "  pad(top: 0.5em)[]\n",
        "  grid(\n",
        "    columns: (50%, 50%),\n",
        "    gutter: 8pt,\n",
        "    figure(\n",
        "      [#image(file_qtbl)],\n",
        "      caption: figure.caption(position: top, [#title]),\n",
        "      kind: \"qtbl\",\n",
        "      supplement: [*Table*],\n",
        "    ),\n",
        "    figure(\n",
        "      [#image(file_fig, width: auto)],\n",
        "      caption: figure.caption(\n",
        "        position: bottom,\n",
        "        [`{r} plot_title_",
        tolower(self$pheno),
        "_adult`],\n",
        "      ),\n",
        "      placement: none,\n",
        "      kind: \"image\",\n",
        "      supplement: [*Figure*],\n",
        "      gap: 0.5em,\n",
        "    ),\n",
        "  )\n",
        "}\n",
        "```\n\n\n\n",

        # Main domain section
        "```{=typst}\n",
        "// Define the title of the domain\n",
        "#let title = \"",
        domain_name,
        "\"\n\n",
        "// Define the file name of the table\n",
        "#let file_qtbl = \"table_",
        tolower(self$pheno),
        "_adult.png\"\n\n",
        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_",
        tolower(self$pheno),
        "_adult_subdomain.svg\"\n\n",
        "// Call the 'domain' function with the specified title, table file name, and figure file name\n",
        "#domain(title: [#title], file_qtbl, file_fig)\n",
        "```\n",

        # Adult emotion only uses self-report, no observer section
      )

      # Write QMD to file
      cat(qmd_content, file = output_file)

      # Generate text and table files before rendering
      text_file <- paste0(
        "_02-",
        domain_num,
        "_",
        tolower(self$pheno),
        "_adult_text.qmd"
      )

      # Check if we have data before trying to process
      if (!is.null(self$data) && nrow(self$data) > 0) {
        results_processor <- NeuropsychResultsR6$new(
          data = self$data,
          file = text_file
        )
        results_processor$process()
        self$generate_domain_table(domain_name)
      } else {
        # Create a placeholder text file for empty data
        cat(
          "<summary>\n\nNo data available for ",
          domain_name,
          ".\n\n</summary>",
          file = text_file
        )
        message("No data available for ", domain_name, " adult text generation")
      }

      # Note: Rendering will be done by unified_workflow_runner.R to avoid duplication
      message(paste0(
        "[DOMAINS] Generated ",
        output_file,
        " (rendering deferred to workflow runner)"
      ))

      # Adult emotion only uses self-report, no observer text file needed

      return(output_file)
    },

    #' @description
    #' Generate table PNG file for the domain.
    #'
    #' @param domain_name Name of the domain.
    #' @return Invisibly returns self for method chaining.
    generate_domain_table = function(domain_name = NULL) {
      # Use the first domain if domain_name not provided
      if (is.null(domain_name)) {
        domain_name <- self$domains[1]
      }

      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Get scales for filtering
      scales <- self$get_scales()

      # Filter the data
      filtered_data <- self$data
      if (length(scales) > 0) {
        filtered_data <- filtered_data[filtered_data$scale %in% scales, ]
      }

      # Check if we have data
      if (nrow(filtered_data) == 0) {
        message("No data available for table generation for ", domain_name)
        return(invisible(self))
      }

      # Table parameters
      table_name <- paste0("table_", tolower(self$pheno))
      vertical_padding <- 0
      multiline <- TRUE

      tryCatch(
        {
          # Load score type utils
          if (!exists("get_score_types_from_lookup")) {
            source("R/score_type_utils.R")
          }

          # Get score types from the lookup table
          score_type_map <- get_score_types_from_lookup(filtered_data)

          # Create a list of test names grouped by score type
          score_types_list <- list()

          # Process the score type map to group tests by score type
          for (test_name in names(score_type_map)) {
            types <- score_type_map[[test_name]]
            for (type in types) {
              if (!type %in% names(score_types_list)) {
                score_types_list[[type]] <- character(0)
              }
              score_types_list[[type]] <- unique(c(
                score_types_list[[type]],
                test_name
              ))
            }
          }

          # Get unique score types present
          unique_score_types <- names(score_types_list)

          # Define the score type footnotes
          fn_list <- list()
          if ("t_score" %in% unique_score_types) {
            fn_list$t_score <- "T score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]"
          }
          if ("scaled_score" %in% unique_score_types) {
            fn_list$scaled_score <- "Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]"
          }
          if ("standard_score" %in% unique_score_types) {
            fn_list$standard_score <- "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
          }

          # Create groups based on test names that use each score type
          grp_list <- score_types_list

          # Define which groups support which score types (for dynamic footnotes)
          dynamic_grp <- score_types_list

          # Determine source note based on domain
          source_notes <- list(
            iq = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            academics = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            verbal = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            spatial = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            memory = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            executive = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            motor = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            social = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            adhd = "T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]",
            emotion = "T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]",
            adaptive = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]",
            daily_living = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
          )

          # Default source note if no score types are found
          if (length(fn_list) == 0) {
            source_note <- source_notes[[tolower(self$pheno)]]
            if (is.null(source_note)) {
              source_note <- "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
            }
          } else {
            source_note <- NULL # No general source note when using footnotes
          }

          # Create table using our modified TableGTR6 R6 class
          table_gt <- TableGTR6$new(
            data = filtered_data,
            pheno = tolower(self$pheno),
            table_name = table_name,
            vertical_padding = vertical_padding,
            source_note = source_note,
            multiline = multiline,
            fn_list = fn_list,
            grp_list = grp_list,
            dynamic_grp = dynamic_grp
          )

          # Get the table object without automatic saving
          tbl <- table_gt$build_table()

          # Save the table using our save_table method
          table_gt$save_table(tbl, dir = here::here())

          message("Generated table: ", table_name, ".png")
        },
        error = function(e) {
          message("Error generating table for ", domain_name, ": ", e$message)
        }
      )

      return(invisible(self))
    },

    #' @description
    #' Generate tables for emotion child domain with multiple raters.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_emotion_child_tables = function() {
      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Get scales for filtering
      scales <- self$get_scales()

      # Filter the data
      filtered_data <- self$data
      if (length(scales) > 0) {
        filtered_data <- filtered_data[filtered_data$scale %in% scales, ]
      }

      # Check if we have data
      if (nrow(filtered_data) == 0) {
        message("No data available for emotion child table generation")
        return(invisible(self))
      }

      # Generate self-report table
      tryCatch(
        {
          self_data <- filtered_data[
            filtered_data$test %in%
              c("pai_adol", "basc3_srp_adolescent", "basc3_srp_child"),
          ]
          if (nrow(self_data) > 0) {
            self$generate_rater_table(self_data, "self")
          }
        },
        error = function(e) {
          message("Error generating self-report table: ", e$message)
        }
      )

      # Generate parent-report table
      tryCatch(
        {
          parent_data <- filtered_data[
            filtered_data$test %in%
              c(
                "basc3_prs_adolescent",
                "basc3_prs_child",
                "basc3_prs_preschool"
              ),
          ]
          if (nrow(parent_data) > 0) {
            self$generate_rater_table(parent_data, "parent")
          }
        },
        error = function(e) {
          message("Error generating parent-report table: ", e$message)
        }
      )

      # Generate teacher-report table
      tryCatch(
        {
          teacher_data <- filtered_data[
            filtered_data$test %in%
              c(
                "basc3_trs_adolescent",
                "basc3_trs_child",
                "basc3_trs_preschool"
              ),
          ]
          if (nrow(teacher_data) > 0) {
            self$generate_rater_table(teacher_data, "teacher")
          }
        },
        error = function(e) {
          message("Error generating teacher-report table: ", e$message)
        }
      )

      return(invisible(self))
    },

    #' @description
    #' Generate a table for a specific rater type.
    #'
    #' @param data The filtered data for this rater.
    #' @param rater_type The rater type ("self", "parent", "teacher").
    #' @return Invisibly returns self for method chaining.
    generate_rater_table = function(data, rater_type) {
      # Table parameters
      table_name <- paste0("table_", tolower(self$pheno), "_child_", rater_type)
      vertical_padding <- 0
      multiline <- TRUE

      tryCatch(
        {
          # Load score type utils
          if (!exists("get_score_types_from_lookup")) {
            source("R/score_type_utils.R")
          }

          # Get score types from the lookup table
          score_type_map <- get_score_types_from_lookup(data)

          # Create a list of test names grouped by score type
          score_types_list <- list()

          # Process the score type map to group tests by score type
          for (test_name in names(score_type_map)) {
            types <- score_type_map[[test_name]]
            for (type in types) {
              if (!type %in% names(score_types_list)) {
                score_types_list[[type]] <- character(0)
              }
              score_types_list[[type]] <- unique(c(
                score_types_list[[type]],
                test_name
              ))
            }
          }

          # Get unique score types present
          unique_score_types <- names(score_types_list)

          # Define the score type footnotes
          fn_list <- list()
          if ("t_score" %in% unique_score_types) {
            fn_list$t_score <- "T score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]"
          }
          if ("scaled_score" %in% unique_score_types) {
            fn_list$scaled_score <- "Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]"
          }
          if ("standard_score" %in% unique_score_types) {
            fn_list$standard_score <- "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
          }

          # Create groups based on test names that use each score type
          grp_list <- score_types_list

          # Define which groups support which score types (for dynamic footnotes)
          dynamic_grp <- score_types_list

          # Default source note if no score types are found
          if (length(fn_list) == 0) {
            source_note <- "T-score: Mean = 50 [50th\u2030], SD ± 10 [16th\u2030, 84th\u2030]"
          } else {
            source_note <- NULL # No general source note when using footnotes
          }

          # Create table using our modified TableGTR6 R6 class
          table_gt <- TableGTR6$new(
            data = data,
            pheno = tolower(self$pheno),
            table_name = table_name,
            vertical_padding = vertical_padding,
            source_note = source_note,
            multiline = multiline,
            fn_list = fn_list,
            grp_list = grp_list,
            dynamic_grp = dynamic_grp
          )

          # Get the table object without automatic saving
          tbl <- table_gt$build_table()

          # Save the table using our save_table method
          table_gt$save_table(tbl, dir = here::here())

          message("Generated table: ", table_name, ".png")
        },
        error = function(e) {
          message("Error generating table for ", rater_type, ": ", e$message)
        }
      )

      return(invisible(self))
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
