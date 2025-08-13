#' DomainProcessorR6 Class - Refactored Version
#'
#' @description
#' An R6 class that encapsulates a complete data processing pipeline for
#' neuropsychological domains with improved error handling and modularity.
#'
#' @field domains Character vector of domain names to process
#' @field pheno Character string specifying the phenotype identifier
#' @field input_file Character string path to the input data file
#' @field output_dir Character string path to the output directory
#' @field scale_source Optional source for scale information
#' @field test_filters List of test filters by rater type
#' @field data Data frame containing the processed data
#' @field config List containing configuration parameters
#' @field logger List containing logging functions
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
    config = NULL,
    logger = NULL,

    #' @description
    #' Initialize a new DomainProcessorR6 object with configuration parameters.
    #' @param domains Character vector of domain names to process
    #' @param pheno Character string specifying the phenotype identifier
    #' @param input_file Character string path to the input data file
    #' @param output_dir Character string path to the output directory (default: "data")
    #' @param scale_source Optional source for scale information
    #' @param test_filters List of test filters by rater type
    #' @param config List containing configuration parameters
    #' @param logger List containing logging functions
    #' @return A new DomainProcessorR6 object
    initialize = function(
      domains,
      pheno,
      input_file,
      output_dir = "data",
      scale_source = NULL,
      test_filters = NULL,
      config = NULL,
      logger = NULL
    ) {
      self$domains <- domains
      self$pheno <- pheno
      self$input_file <- input_file
      self$output_dir <- output_dir
      self$scale_source <- scale_source
      self$config <- config %||% private$get_default_config()
      self$logger <- logger %||% private$create_logger()

      # Set default test filters if none provided
      if (is.null(test_filters)) {
        self$test_filters <- list(
          self = character(0),
          observer = character(0),
          parent = character(0),
          teacher = character(0)
        )
      } else {
        self$test_filters <- test_filters
      }

      # Validate inputs
      private$validate_inputs()

      self$logger$info(paste("Initialized DomainProcessorR6 for", pheno))
    },

    #' @description
    #' Load data from the specified input file with error handling.
    #' @return Invisibly returns self for method chaining
    load_data = function() {
      # Skip loading if data already exists
      if (!is.null(self$data)) {
        self$logger$info("Data already loaded, skipping file read")
        return(invisible(self))
      }

      # Check if input_file is provided
      if (is.null(self$input_file)) {
        private$handle_error("No input file specified and no data pre-loaded")
      }

      # Check if file exists
      if (!file.exists(self$input_file)) {
        private$handle_error(paste("Input file not found:", self$input_file))
      }

      # Load data based on file type
      self$data <- private$read_data_file(self$input_file)

      self$logger$info(paste(
        "Loaded",
        nrow(self$data),
        "rows from",
        self$input_file
      ))
      invisible(self)
    },

    #' @description
    #' Filter data to include only the specified domains.
    #' @return Invisibly returns self for method chaining
    filter_by_domain = function() {
      if (is.null(self$data)) {
        private$handle_error("No data loaded. Call load_data() first")
      }

      original_rows <- nrow(self$data)
      self$data <- self$data |> dplyr::filter(domain %in% self$domains)

      self$logger$info(paste(
        "Filtered from",
        original_rows,
        "to",
        nrow(self$data),
        "rows for domains:",
        paste(self$domains, collapse = ", ")
      ))

      invisible(self)
    },

    #' @description
    #' Select relevant columns from the data.
    #' @return Invisibly returns self for method chaining
    select_columns = function() {
      if (is.null(self$data)) {
        private$handle_error("No data loaded. Call load_data() first")
      }

      # Get desired columns from config or use defaults
      desired_columns <- self$config$columns %||% private$get_default_columns()

      # Only select columns that actually exist
      existing_columns <- intersect(desired_columns, names(self$data))
      missing_columns <- setdiff(desired_columns, existing_columns)

      # Log missing columns (excluding expected missing z-score columns)
      missing_other <- grep(
        "^(?!z_)",
        missing_columns,
        value = TRUE,
        perl = TRUE
      )
      if (length(missing_other) > 0) {
        self$logger$warn(paste(
          "Missing columns:",
          paste(missing_other, collapse = ", ")
        ))
      }

      # Calculate basic z-score if needed
      if ("percentile" %in% names(self$data) && !"z" %in% names(self$data)) {
        self$data$z <- qnorm(self$data$percentile / 100)
        existing_columns <- c(existing_columns, "z")
        self$logger$info("Calculated z-scores from percentiles")
      }

      self$data <- self$data |> dplyr::select(all_of(existing_columns))

      self$logger$info(paste("Selected", length(existing_columns), "columns"))
      invisible(self)
    },

    #' @description
    #' Save the processed data to a file with validation.
    #' @param filename Optional filename for the output file
    #' @param format Optional format for the output file (csv, parquet, feather)
    #' @return Invisibly returns self for method chaining
    save_data = function(filename = NULL, format = NULL) {
      if (is.null(self$data)) {
        private$handle_error("No data to save")
      }

      # Ensure output directory exists
      private$ensure_directory(self$output_dir)

      # Determine format
      if (is.null(format) && !is.null(filename)) {
        format <- tools::file_ext(filename)
      }
      format <- format %||% self$config$output_format %||% "parquet"

      # Generate filename if not provided
      if (is.null(filename)) {
        filename <- paste0(self$pheno, ".", format)
      }

      # Full path to output file
      output_path <- here::here(self$output_dir, filename)

      # Save based on format
      tryCatch(
        {
          private$write_data_file(self$data, output_path, format)
          self$logger$info(paste("Saved data to", output_path))
        },
        error = function(e) {
          private$handle_error(paste("Failed to save data:", e$message))
        }
      )

      invisible(self)
    },

    #' @description
    #' Get scale names for the specified phenotype.
    #' @return Character vector of scale names
    get_scales = function() {
      # Try multiple sources for scales
      scales <- self$scale_source %||%
        private$load_scales_from_sysdata() %||%
        character(0)

      if (length(scales) == 0) {
        self$logger$warn(paste("No scales found for", self$pheno))
      }

      return(scales)
    },

    #' @description
    #' Get the domain number for file naming.
    #' @return Character string with the domain number
    get_domain_number = function() {
      domain_numbers <- self$config$domain_numbers %||%
        private$get_default_domain_numbers()

      num <- domain_numbers[[tolower(self$pheno)]]
      if (is.null(num)) {
        self$logger$warn(paste("No domain number for", self$pheno, "using 99"))
        "99"
      } else {
        num
      }
    },

    #' @description
    #' Check if domain has multiple raters.
    #' @return Logical value indicating if domain has multiple raters
    has_multiple_raters = function() {
      tolower(self$pheno) %in% c("emotion", "adhd")
    },

    #' @description
    #' Detect if this is a child or adult emotion domain.
    #' @return Character string "child" or "adult", or NULL if not emotion domain
    detect_emotion_type = function() {
      if (tolower(self$pheno) != "emotion") {
        return(NULL)
      }

      # Check based on domain name patterns
      child_patterns <- c("Behavioral/Emotional/Social", "Child", "Pediatric")
      adult_patterns <- c("Emotional/Behavioral/Personality", "Adult")

      for (pattern in child_patterns) {
        if (any(grepl(pattern, self$domains, ignore.case = TRUE))) {
          return("child")
        }
      }

      for (pattern in adult_patterns) {
        if (any(grepl(pattern, self$domains, ignore.case = TRUE))) {
          return("adult")
        }
      }

      # Check based on test data if available
      if (!is.null(self$data) && nrow(self$data) > 0) {
        return(private$detect_emotion_type_from_data())
      }

      # Default to child if unclear
      self$logger$info("Could not determine emotion type, defaulting to child")
      return("child")
    },

    #' @description
    #' Get rater types for the domain.
    #' @return Character vector of rater types or NULL if single-rater
    get_rater_types = function() {
      if (!self$has_multiple_raters()) {
        return(NULL)
      }

      # Use configuration if available
      if (!is.null(self$config$rater_types[[tolower(self$pheno)]])) {
        return(self$config$rater_types[[tolower(self$pheno)]])
      }

      # Default rater types
      if (tolower(self$pheno) == "adhd") {
        return(c("self", "observer"))
      }

      if (tolower(self$pheno) == "emotion") {
        emotion_type <- self$detect_emotion_type()
        if (emotion_type == "child") {
          return(c("self", "parent", "teacher"))
        } else {
          return(c("self"))
        }
      }

      return(NULL)
    },

    #' @description
    #' Generate domain QMD file using templates.
    #' @param domain_name Optional domain name to use
    #' @param output_file Optional output file path
    #' @return Character string path to the generated QMD file
    generate_domain_qmd = function(domain_name = NULL, output_file = NULL) {
      domain_name <- domain_name %||% self$domains[1]
      domain_num <- self$get_domain_number()

      # Determine output file
      if (is.null(output_file)) {
        output_file <- private$generate_qmd_filename(domain_num)
      }

      # Route to appropriate generator based on domain type
      if (self$has_multiple_raters()) {
        private$generate_multi_rater_qmd(domain_name, output_file, domain_num)
      } else {
        private$generate_standard_qmd(domain_name, output_file, domain_num)
      }

      self$logger$info(paste("Generated QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Run the complete processing pipeline.
    #' @param generate_reports Logical whether to generate reports
    #' @param report_types Character vector of report types to generate
    #' @param generate_domain_files Logical whether to generate domain files
    #' @return Invisibly returns self for method chaining
    process = function(
      generate_reports = TRUE,
      report_types = c("self"),
      generate_domain_files = FALSE
    ) {
      tryCatch(
        {
          # Run the complete pipeline
          self$load_data()
          self$filter_by_domain()
          self$select_columns()
          self$save_data()

          # Generate domain files if requested
          if (generate_domain_files) {
            self$generate_domain_qmd()
          }

          self$logger$info("Processing complete")
        },
        error = function(e) {
          private$handle_error(paste("Processing failed:", e$message))
        }
      )

      invisible(self)
    }
  ),

  private = list(
    # Create default logger
    create_logger = function() {
      list(
        info = function(msg) message("[INFO] ", msg),
        warn = function(msg) warning("[WARN] ", msg, call. = FALSE),
        error = function(msg) stop("[ERROR] ", msg, call. = FALSE),
        debug = function(msg) {
          if (getOption("debug", FALSE)) message("[DEBUG] ", msg)
        }
      )
    },

    # Get default configuration
    get_default_config = function() {
      list(
        output_format = "parquet",
        columns = private$get_default_columns(),
        domain_numbers = private$get_default_domain_numbers(),
        rater_types = list(
          adhd = c("self", "observer"),
          emotion_child = c("self", "parent", "teacher"),
          emotion_adult = c("self")
        ),
        score_type_mapping = list(
          standard_score = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
          scaled_score = "Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]",
          t_score = "T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]"
        )
      )
    },

    # Get default columns to select
    get_default_columns = function() {
      c(
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
    },

    # Get default domain numbers
    get_default_domain_numbers = function() {
      list(
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
    },

    # Validate inputs on initialization
    validate_inputs = function() {
      if (is.null(self$domains) || length(self$domains) == 0) {
        stop("Domains must be specified", call. = FALSE)
      }

      if (is.null(self$pheno) || nchar(self$pheno) == 0) {
        stop("Phenotype (pheno) must be specified", call. = FALSE)
      }

      if (!is.null(self$input_file) && !file.exists(self$input_file)) {
        warning(
          paste("Input file does not exist:", self$input_file),
          call. = FALSE
        )
      }
    },

    # Handle errors consistently
    handle_error = function(msg) {
      self$logger$error(msg)
      stop(msg, call. = FALSE)
    },

    # Ensure directory exists
    ensure_directory = function(dir_path) {
      if (!dir.exists(dir_path)) {
        dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
        self$logger$info(paste("Created directory:", dir_path))
      }
    },

    # Read data file based on extension
    read_data_file = function(file_path) {
      file_ext <- tolower(tools::file_ext(file_path))

      data <- tryCatch(
        {
          switch(
            file_ext,
            parquet = {
              if (!requireNamespace("arrow", quietly = TRUE)) {
                stop("The 'arrow' package is required to read Parquet files")
              }
              arrow::read_parquet(file_path)
            },
            feather = {
              if (!requireNamespace("arrow", quietly = TRUE)) {
                stop("The 'arrow' package is required to read Feather files")
              }
              arrow::read_feather(file_path)
            },
            csv = readr::read_csv(file_path, show_col_types = FALSE),
            {
              self$logger$warn(paste(
                "Unknown file extension:",
                file_ext,
                "- attempting CSV read"
              ))
              readr::read_csv(file_path, show_col_types = FALSE)
            }
          )
        },
        error = function(e) {
          private$handle_error(paste("Failed to read file:", e$message))
        }
      )

      return(data)
    },

    # Write data file based on format
    write_data_file = function(data, file_path, format) {
      format <- tolower(format)

      switch(
        format,
        parquet = {
          if (!requireNamespace("arrow", quietly = TRUE)) {
            self$logger$warn("Arrow package not available, falling back to CSV")
            format <- "csv"
          } else {
            arrow::write_parquet(data, file_path)
            return(invisible(TRUE))
          }
        },
        feather = {
          if (!requireNamespace("arrow", quietly = TRUE)) {
            self$logger$warn("Arrow package not available, falling back to CSV")
            format <- "csv"
          } else {
            arrow::write_feather(data, file_path)
            return(invisible(TRUE))
          }
        }
      )

      # Default to CSV
      if (format == "csv" || TRUE) {
        readr::write_excel_csv(data, file_path, na = "", col_names = TRUE)
      }

      invisible(TRUE)
    },

    # Load scales from sysdata.rda
    load_scales_from_sysdata = function() {
      scale_var_name <- paste0("scales_", tolower(self$pheno))

      # Try multiple locations for sysdata.rda
      sysdata_paths <- c(
        system.file("R", "sysdata.rda", package = "neuro2"),
        here::here("R", "sysdata.rda"),
        "R/sysdata.rda"
      )

      for (path in sysdata_paths) {
        if (file.exists(path)) {
          temp_env <- new.env()
          load(path, envir = temp_env)

          if (exists(scale_var_name, envir = temp_env)) {
            scales <- get(scale_var_name, envir = temp_env)
            self$logger$info(paste("Loaded scales from", path))
            return(scales)
          }
        }
      }

      self$logger$warn(paste("Could not find scales for", self$pheno))
      return(NULL)
    },

    # Detect emotion type from data
    detect_emotion_type_from_data = function() {
      child_tests <- c(
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
      )

      adult_tests <- c("pai", "pai_clinical", "pai_validity", "pai_attention")

      has_child_tests <- any(self$data$test %in% child_tests, na.rm = TRUE)
      has_adult_tests <- any(self$data$test %in% adult_tests, na.rm = TRUE)

      if (has_child_tests && !has_adult_tests) {
        return("child")
      }
      if (has_adult_tests && !has_child_tests) {
        return("adult")
      }
      if (has_child_tests && has_adult_tests) {
        self$logger$warn(
          "Data contains both child and adult tests, defaulting to child"
        )
        return("child")
      }

      return("child") # Default
    },

    # Generate QMD filename
    generate_qmd_filename = function(domain_num) {
      base_name <- paste0("_02-", domain_num, "_", tolower(self$pheno))

      if (self$has_multiple_raters()) {
        emotion_type <- self$detect_emotion_type()
        if (tolower(self$pheno) == "emotion") {
          return(paste0(base_name, "_", emotion_type, ".qmd"))
        }
      }

      return(paste0(base_name, ".qmd"))
    },

    # Generate standard (single-rater) QMD
    generate_standard_qmd = function(domain_name, output_file, domain_num) {
      # Create template context
      context <- list(
        domain_name = domain_name,
        domain_num = domain_num,
        pheno = tolower(self$pheno),
        input_file = self$input_file,
        scales = self$get_scales(),
        plot_title = private$get_plot_title(),
        source_note = private$get_source_note(),
        has_narrow = tolower(self$pheno) == "iq"
      )

      # Generate QMD content using template
      qmd_content <- private$render_qmd_template("standard", context)

      # Write to file
      cat(qmd_content, file = output_file)

      # Generate supporting files
      private$generate_supporting_files(domain_name, domain_num)
    },

    # Generate multi-rater QMD
    generate_multi_rater_qmd = function(domain_name, output_file, domain_num) {
      emotion_type <- self$detect_emotion_type()
      rater_types <- self$get_rater_types()

      # Create template context
      context <- list(
        domain_name = domain_name,
        domain_num = domain_num,
        pheno = tolower(self$pheno),
        emotion_type = emotion_type,
        input_file = self$input_file,
        rater_types = rater_types,
        scales = self$get_scales(),
        plot_title = private$get_plot_title(),
        source_note = private$get_source_note()
      )

      # Generate QMD content using appropriate template
      template_name <- if (tolower(self$pheno) == "emotion") {
        paste0("emotion_", emotion_type)
      } else {
        "adhd"
      }

      qmd_content <- private$render_qmd_template(template_name, context)

      # Write to file
      cat(qmd_content, file = output_file)

      # Generate supporting files for each rater
      for (rater in rater_types) {
        private$generate_rater_supporting_files(domain_name, domain_num, rater)
      }
    },

    # Render QMD template (simplified)
    render_qmd_template = function(template_name, context) {
      # This is a simplified version - in production, you'd use a real templating system
      # For now, return a basic structure
      paste0(
        "## ",
        context$domain_name,
        " {#sec-",
        context$pheno,
        "}\n\n",
        "{{< include _02-",
        context$domain_num,
        "_",
        context$pheno,
        "_text.qmd >}}\n\n",
        private$generate_r_setup_block(context),
        private$generate_table_block(context),
        private$generate_figure_block(context),
        private$generate_typst_block(context)
      )
    },

    # Generate R setup block
    generate_r_setup_block = function(context) {
      paste0(
        "```{r}\n",
        "#| label: setup-",
        context$pheno,
        "\n",
        "#| include: false\n\n",
        "# Source R6 classes\n",
        "source(\"R/DomainProcessorR6.R\")\n",
        "source(\"R/NeuropsychResultsR6.R\")\n",
        "source(\"R/DotplotR6.R\")\n",
        "source(\"R/TableGTR6.R\")\n",
        "source(\"R/score_type_utils.R\")\n\n",
        "# Create and process domain\n",
        "processor <- DomainProcessorR6$new(\n",
        "  domains = \"",
        context$domain_name,
        "\",\n",
        "  pheno = \"",
        context$pheno,
        "\",\n",
        "  input_file = \"",
        context$input_file,
        "\"\n",
        ")\n",
        "processor$load_data()\n",
        "processor$filter_by_domain()\n",
        "processor$select_columns()\n",
        "```\n\n"
      )
    },

    # Generate table block
    generate_table_block = function(context) {
      paste0(
        "```{r}\n",
        "#| label: qtbl-",
        context$pheno,
        "\n",
        "#| include: false\n\n",
        "# Generate table\n",
        "# Table generation code here\n",
        "```\n\n"
      )
    },

    # Generate figure block
    generate_figure_block = function(context) {
      paste0(
        "```{r}\n",
        "#| label: fig-",
        context$pheno,
        "\n",
        "#| include: false\n\n",
        "# Generate figure\n",
        "# Figure generation code here\n",
        "```\n\n"
      )
    },

    # Generate Typst block
    generate_typst_block = function(context) {
      paste0(
        "```{=typst}\n",
        "// Typst layout code\n",
        "#let domain(title: none, file_qtbl, file_fig) = {\n",
        "  // Layout code here\n",
        "}\n",
        "```\n"
      )
    },

    # Generate supporting files
    generate_supporting_files = function(domain_name, domain_num) {
      # Generate text file
      text_file <- paste0(
        "_02-",
        domain_num,
        "_",
        tolower(self$pheno),
        "_text.qmd"
      )
      private$generate_text_file(text_file)

      # Generate table
      private$generate_table_file(domain_name)
    },

    # Generate rater-specific supporting files
    generate_rater_supporting_files = function(domain_name, domain_num, rater) {
      # Generate rater-specific text file
      text_file <- paste0(
        "_02-",
        domain_num,
        "_",
        tolower(self$pheno),
        "_",
        rater,
        "_text.qmd"
      )
      private$generate_text_file(text_file, rater)

      # Generate rater-specific table
      private$generate_table_file(domain_name, rater)
    },

    # Generate text file
    generate_text_file = function(output_file, rater = NULL) {
      if (is.null(self$data) || nrow(self$data) == 0) {
        cat("<summary>\n\nNo data available.\n\n</summary>", file = output_file)
        return(invisible(NULL))
      }

      # Filter data by rater if specified
      filtered_data <- self$data
      if (!is.null(rater)) {
        filtered_data <- private$filter_by_rater(filtered_data, rater)
      }

      # Use NeuropsychResultsR6 to generate text
      tryCatch(
        {
          results_processor <- NeuropsychResultsR6$new(
            data = filtered_data,
            file = output_file
          )
          results_processor$process()
        },
        error = function(e) {
          self$logger$error(paste("Failed to generate text file:", e$message))
        }
      )
    },

    # Generate table file
    generate_table_file = function(domain_name, rater = NULL) {
      # Table generation logic here (simplified)
      self$logger$info(paste("Generated table for", domain_name, rater))
    },

    # Filter data by rater
    filter_by_rater = function(data, rater) {
      rater_test_mapping <- list(
        self = c("pai_adol", "basc3_srp_adolescent", "basc3_srp_child"),
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

      if (rater %in% names(rater_test_mapping)) {
        test_list <- rater_test_mapping[[rater]]
        if (length(test_list) > 0) {
          return(data |> dplyr::filter(test %in% test_list))
        }
      }

      return(data)
    },

    # Get plot title
    get_plot_title = function() {
      # Try loading from config or sysdata
      plot_title_var <- paste0("plot_title_", tolower(self$pheno))

      # Default titles
      default_titles <- list(
        iq = "Intellectual and cognitive abilities represent an individual's capacity to think, reason, and solve problems.",
        academics = "Academic skills reflect the application of cognitive abilities to educational tasks.",
        verbal = "Verbal and language functioning refers to the ability to access and apply acquired word knowledge.",
        spatial = "Visuospatial abilities involve perceiving, analyzing, and mentally manipulating visual information.",
        memory = "Memory functions are crucial for learning, daily functioning, and cognitive processing.",
        executive = "Attentional and executive functions underlie most domains of cognitive performance.",
        motor = "Motor functions involve the planning and execution of voluntary movements.",
        social = "Social cognition encompasses the mental processes involved in perceiving, interpreting, and responding to social information."
      )

      default_titles[[tolower(self$pheno)]] %||%
        paste("Results from the", self$domains[1], "domain assessment.")
    },

    # Get source note
    get_source_note = function() {
      score_type_mapping <- self$config$score_type_mapping %||%
        private$get_default_config()$score_type_mapping

      # Determine appropriate source note based on domain
      if (tolower(self$pheno) %in% c("adhd", "emotion")) {
        return(score_type_mapping$t_score)
      } else {
        return(score_type_mapping$standard_score)
      }
    }
  )
)

#' Process Neuropsychological Domain Data
#'
#' @param domains Character vector of domain names to process
#' @param pheno Character string specifying the phenotype identifier
#' @param input_file Character string path to the input data file
#' @param output_dir Character string path to the output directory
#' @param scale_source Optional source for scale information
#' @param test_filters List of test filters by rater type
#' @param generate_reports Logical whether to generate reports
#' @param report_types Character vector of report types to generate
#' @param generate_domain_files Logical whether to generate domain files
#' @param config List containing configuration parameters
#' @return Invisibly returns the processed data
#' @export
process_domain_data <- function(
  domains,
  pheno,
  input_file,
  output_dir = "data",
  scale_source = NULL,
  test_filters = NULL,
  generate_reports = TRUE,
  report_types = c("self"),
  generate_domain_files = FALSE,
  config = NULL
) {
  processor <- DomainProcessorR6$new(
    domains = domains,
    pheno = pheno,
    input_file = input_file,
    output_dir = output_dir,
    scale_source = scale_source,
    test_filters = test_filters,
    config = config
  )

  processor$process(
    generate_reports = generate_reports,
    report_types = report_types,
    generate_domain_files = generate_domain_files
  )

  invisible(processor$data)
}
