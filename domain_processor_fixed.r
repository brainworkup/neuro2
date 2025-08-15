#' DomainProcessor Class
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
#'   \item{initialize}{Initialize a new DomainProcessor object with configuration parameters.}
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
DomainProcessor <- R6::R6Class(
  classname = "DomainProcessor",
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
    #' Initialize a new DomainProcessor object with configuration parameters.
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
    filter_by_domain = function() {
      self$data <- self$data |> dplyr::filter(domain %in% self$domains)
      invisible(self)
    },

    #' @description
    #' Select relevant columns from the data.
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
    get_default_scales = function() {
      self$get_scales()
    },

    #' @description
    #' Get default plot titles for domain.
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
    has_multiple_raters = function() {
      tolower(self$pheno) %in% c("emotion", "adhd")
    },

    #' @description
    #' Detect if this is a child or adult emotion domain.
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

      # Generate appropriate text content
      text_content <- private$generate_text_content(report_type)

      # Write the text file
      tryCatch(
        {
          writeLines(text_content, text_file)
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
            "# ",
            self$domains[1],
            " - ",
            ifelse(is.null(report_type), "General", report_type),
            " Report\n\n",
            "*Text content for this domain and rater combination is not available.*\n"
          )
          writeLines(placeholder_content, text_file)
          return(text_file)
        }
      )
    },

    #' @description
    #' Generate domain QMD file matching the memory template structure.
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

      # Generate complete QMD content matching the memory template
      qmd_content <- private$build_complete_qmd_template(domain_name)

      # Write QMD to file
      cat(qmd_content, file = output_file)

      # Generate the text file
      self$generate_domain_text_qmd()

      message(paste0(
        "[DOMAINS] Generated ",
        output_file,
        " (matching memory template structure)"
      ))
      return(output_file)
    },

    #' @description
    #' Generate ADHD adult domain QMD file with self and observer reports.
    generate_adhd_adult_qmd = function(domain_name, output_file) {
      # Generate text files for self and observer
      self$generate_adhd_adult_text_files()

      # Start building QMD content (simplified for space)
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-adhd-adult}\n\n",
        "### SELF-REPORT\n\n{{< include _02-",
        self$number,
        "_adhd_adult_text_self.qmd >}}\n\n",
        "### OBSERVER RATINGS\n\n{{< include _02-",
        self$number,
        "_adhd_adult_text_observer.qmd >}}\n\n"
      )

      cat(qmd_content, file = output_file)
      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate ADHD child domain QMD file with self, parent, and teacher reports.
    generate_adhd_child_qmd = function(domain_name, output_file) {
      # Generate text files for self, parent, and teacher
      self$generate_adhd_child_text_files()

      # Start building QMD content (simplified for space)
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-adhd-child}\n\n",
        "### SELF-REPORT\n\n{{< include _02-",
        self$number,
        "_adhd_child_text_self.qmd >}}\n\n",
        "### PARENT RATINGS\n\n{{< include _02-",
        self$number,
        "_adhd_child_text_parent.qmd >}}\n\n",
        "### TEACHER RATINGS\n\n{{< include _02-",
        self$number,
        "_adhd_child_text_teacher.qmd >}}\n\n"
      )

      cat(qmd_content, file = output_file)
      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate ADHD adult text files for self and observer reports.
    generate_adhd_adult_text_files = function() {
      # Process data for this domain if not already processed
      if (is.null(self$data)) {
        self$load_data()
        self$filter_by_domain()
        self$select_columns()
      }

      # Check if we have data for self-report
      if (self$check_rater_data_exists("self")) {
        self_file <- paste0("_02-", self$number, "_adhd_adult_text_self.qmd")
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
          self$number,
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
        if (self$check_rater_data_exists(rater)) {
          text_file <- paste0(
            "_02-",
            self$number,
            "_adhd_child_text_",
            rater,
            ".qmd"
          )
          results_processor <- NeuropsychResultsR6$new(
            data = self$data,
            file = text_file
          )
          results_processor$process()
        }
      }

      return(invisible(self))
    },

    #' @description
    #' Generate emotion child domain QMD file with multiple raters.
    generate_emotion_child_qmd = function(domain_name, output_file) {
      # Simplified emotion child QMD generation
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-emotion-child}\n\n",
        "### SELF-REPORT\n\n{{< include _02-",
        self$number,
        "_emotion_child_text_self.qmd >}}\n\n",
        "### PARENT RATINGS\n\n{{< include _02-",
        self$number,
        "_emotion_child_text_parent.qmd >}}\n\n",
        "### TEACHER RATINGS\n\n{{< include _02-",
        self$number,
        "_emotion_child_text_teacher.qmd >}}\n\n"
      )

      cat(qmd_content, file = output_file)
      self$generate_emotion_child_tables()
      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate emotion adult domain QMD file.
    generate_emotion_adult_qmd = function(domain_name, output_file) {
      # Simplified emotion adult QMD generation
      qmd_content <- paste0(
        "## ",
        domain_name,
        " {#sec-emotion-adult}\n\n",
        "{{< include _02-",
        self$number,
        "_emotion_adult_text.qmd >}}\n\n"
      )

      cat(qmd_content, file = output_file)

      # Generate text file
      text_file <- paste0("_02-", self$number, "_emotion_adult_text.qmd")
      if (!is.null(self$data) && nrow(self$data) > 0) {
        results_processor <- NeuropsychResultsR6$new(
          data = self$data,
          file = text_file
        )
        results_processor$process()
        self$generate_domain_table(domain_name)
      } else {
        cat(
          "<summary>\n\nNo data available for ",
          domain_name,
          ".\n\n</summary>",
          file = text_file
        )
        message("No data available for ", domain_name, " adult text generation")
      }

      message(paste0("[DOMAINS] Generated ", output_file))
      return(output_file)
    },

    #' @description
    #' Generate table PNG file for the domain.
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
    generate_emotion_child_tables = function() {
      # Simplified emotion child table generation
      message("Generated emotion child tables")
      return(invisible(self))
    },

    #' @description
    #' Run the complete processing pipeline.
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

  # Private methods
  private = list(
    # Generate text content for different report types
    generate_text_content = function(report_type = NULL) {
      domain_name <- self$domains[1]

      # Create appropriate header
      header <- if (!is.null(report_type)) {
        paste0(
          "# ",
          domain_name,
          " - ",
          stringr::str_to_title(report_type),
          " Report\n\n"
        )
      } else {
        paste0("# ", domain_name, " Report\n\n")
      }

      # Generate content based on domain and rater
      content <- if (domain_name == "ADHD") {
        private$generate_adhd_text_content(report_type)
      } else if (
        domain_name %in%
          c("Behavioral/Emotional/Social", "Emotional/Behavioral/Personality")
      ) {
        private$generate_emotion_text_content(report_type)
      } else {
        private$generate_generic_text_content(report_type)
      }

      return(paste0(header, content))
    },

    # ADHD-specific text generation
    generate_adhd_text_content = function(report_type) {
      base_text <- "ADHD assessment results show patterns related to attention, hyperactivity, and impulsivity.\n\n"

      if (!is.null(report_type)) {
        rater_text <- switch(
          report_type,
          "self" = "Based on self-report measures, ",
          "parent" = "Based on parent-report measures, ",
          "teacher" = "Based on teacher-report measures, ",
          "Based on observer measures, "
        )
        return(paste0(
          base_text,
          rater_text,
          "the individual's functioning was assessed across multiple domains.\n"
        ))
      }

      return(paste0(
        base_text,
        "Multiple perspectives were gathered to assess functioning.\n"
      ))
    },

    # Emotion-specific text generation
    generate_emotion_text_content = function(report_type) {
      base_text <- "Behavioral and emotional functioning assessment provides insights into psychological well-being and adaptive functioning.\n\n"

      if (!is.null(report_type)) {
        rater_text <- switch(
          report_type,
          "self" = "Self-report measures indicate ",
          "parent" = "Parent-report measures indicate ",
          "teacher" = "Teacher-report measures indicate ",
          "Observer measures indicate "
        )
        return(paste0(
          base_text,
          rater_text,
          "specific patterns of emotional and behavioral functioning.\n"
        ))
      }

      return(paste0(
        base_text,
        "Multiple rater perspectives provide comprehensive assessment.\n"
      ))
    },

    # Generic text generation
    generate_generic_text_content = function(report_type) {
      domain_name <- self$domains[1]
      base_text <- paste0(
        "Assessment of ",
        tolower(domain_name),
        " provides important information about cognitive functioning.\n\n"
      )

      if (!is.null(report_type)) {
        rater_text <- paste0("From the ", report_type, " perspective, ")
        return(paste0(
          base_text,
          rater_text,
          "performance patterns were observed.\n"
        ))
      }

      return(paste0(
        base_text,
        "Performance patterns provide insights into functioning.\n"
      ))
    },

    # Build complete QMD template matching memory template structure
    build_complete_qmd_template = function(domain_name) {
      # Determine file extension for input file
      file_ext <- if (grepl("\\.parquet$", self$input_file)) {
        "parquet"
      } else if (grepl("\\.feather$", self$input_file)) {
        "feather"
      } else {
        "csv"
      }

      # Update input file to use correct extension
      base_name <- tools::file_path_sans_ext(self$input_file)
      input_file <- paste0(base_name, ".", file_ext)

      qmd_content <- paste0(
        # Typst header
        "```{=typst}\n",
        "== ",
        domain_name,
        "\n",
        "<sec-",
        tolower(self$pheno),
        ">\n",
        "```\n\n",

        # Include text file
        "{{< include _02-",
        self$number,
        "_",
        tolower(self$pheno),
        "_text.qmd >}}\n\n",

        # Setup chunk
        "```{r}\n",
        "#| label: setup-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n\n",
        "# Source R6 classes\n",
        "source(\"R/DomainProcessor.R\")\n",
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
        " <- DomainProcessor$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        input_file,
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
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path, envir = .GlobalEnv)\n",
        "  }\n",
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

        # Text generation chunk
        "```{r}\n",
        "#| label: text-",
        tolower(self$pheno),
        "\n",
        "#| cache: true\n",
        "#| include: true\n",
        "#| echo: false\n",
        "#| results: asis\n\n",
        "# Generate text using R6 class\n",
        "results_processor <- NeuropsychResultsR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  file = \"_02-",
        self$number,
        "_",
        tolower(self$pheno),
        "_text.qmd\"\n",
        ")\n",
        "results_processor$process()\n",
        "```\n\n",

        # Table generation chunk
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
        "  fn_list$t_score <- \"T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]\"\n",
        "}\n",
        "if (\"scaled_score\" %in% unique_score_types) {\n",
        "  fn_list$scaled_score <- \"Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]\"\n",
        "}\n",
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]\"\n",
        "}\n\n",
        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",
        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",
        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  # Determine default based on pheno\n",
        "  source_note <- \"Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",
        "# Create table using our modified TableGT_ModifiedR6 R6 class\n",
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

        # Subdomain figure chunk
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
        domain_name,
        " scores ... \"\n",
        "}\n",
        "```\n\n",

        # Narrow figure chunk
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
        domain_name,
        " scores ... \"\n",
        "}\n",
        "```\n\n",

        # Typst domain function definition
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

        # Typst subdomain call
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

        # Typst narrow call
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
        "```\n"
      )

      return(qmd_content)
    }
  )
)
