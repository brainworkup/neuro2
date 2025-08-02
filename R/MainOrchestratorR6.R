#' Neuro2MainR6 Class
#'
#' Streamlined main orchestrator for neuropsychological report generation
#' Provides a simple, user-friendly interface that handles complexity internally
#'
#' @field config Configuration manager object
#' @field error_handler Error handler object
#' @field factory Domain processor factory object
#' @field processors List of domain processors
#' @field status Status tracking list
#'
#' @export
Neuro2MainR6 <- R6::R6Class(
  classname = "Neuro2MainR6",
  public = list(
    #' @field config Configuration manager object
    config = NULL,
    #' @field error_handler Error handler object
    error_handler = NULL,
    #' @field factory Domain processor factory object
    factory = NULL,
    #' @field processors List of domain processors
    processors = NULL,
    #' @field status Status tracking list
    status = NULL,
    
    #' Initialize main orchestrator
    #' @param config_file Path to configuration file
    #' @param variables_file Path to variables file
    #' @param verbose Whether to show verbose output
    initialize = function(config_file = "config.yml", 
                         variables_file = "_variables.yml",
                         verbose = NULL) {
      
      # Initialize configuration
      self$config <- ConfigManagerR6$new(config_file, variables_file)
      
      # Override verbosity if specified
      if (!is.null(verbose)) {
        self$config$set("processing.verbose", verbose)
      }
      
      # Initialize error handler
      self$error_handler <- ErrorHandlerR6$new(self$config)
      
      # Initialize factory
      self$factory <- DomainProcessorFactoryR6$new(self$config, self$error_handler)
      
      # Initialize status tracking
      self$status <- list(
        data_loaded = FALSE,
        domains_processed = FALSE,
        report_generated = FALSE,
        errors = 0,
        warnings = 0
      )
      
      # Initial setup
      self$setup()
    },
    
    #' Set up the orchestrator environment
    #' @return Invisibly returns self
    setup = function() {
      if (self$config$get("processing.verbose", TRUE)) {
        cli::cli_h1("Neuro2 Report System")
        cli::cli_alert_info("Patient: {self$config$get('variables.patient', 'Unknown')}")
        cli::cli_alert_info("Configuration loaded successfully")
      }
      
      # Check required directories and files
      self$check_environment()
      
      invisible(self)
    },
    
    #' Check and set up required directories
    #' @return TRUE if environment is ready
    check_environment = function() {
      checks <- list(
        data_dir = self$config$get("data.input_dir"),
        output_dir = self$config$get("data.output_dir"),
        report_dir = self$config$get("report.output_dir")
      )
      
      all_good <- TRUE
      
      for (name in names(checks)) {
        dir <- checks[[name]]
        if (!dir.exists(dir)) {
          if (self$config$get("processing.verbose", TRUE)) {
            cli::cli_alert_warning("Creating missing directory: {dir}")
          }
          dir.create(dir, recursive = TRUE, showWarnings = FALSE)
        }
      }
      
      # Check for data files
      data_files <- list(
        neurocog = file.path(self$config$get("data.input_dir"), "neurocog.csv"),
        neurobehav = file.path(self$config$get("data.input_dir"), "neurobehav.csv")
      )
      
      missing_files <- character()
      for (file in data_files) {
        if (!file.exists(file)) {
          missing_files <- c(missing_files, basename(file))
        }
      }
      
      if (length(missing_files) > 0) {
        cli::cli_alert_warning("Missing data files: {paste(missing_files, collapse = ', ')}")
        cli::cli_alert_info("You can load data using load_data() method")
      }
      
      invisible(all_good)
    },
    
    #' Load neuropsychological data
    #' @param data_dir Directory containing data files
    #' @param use_duckdb Whether to use DuckDB for data loading
    #' @param output_format Output format for processed data
    #' @return Invisibly returns self
    load_data = function(data_dir = NULL, use_duckdb = NULL, 
                        output_format = NULL) {
      
      # Use config defaults if not specified
      data_dir <- data_dir %||% self$config$get("data.input_dir")
      use_duckdb <- use_duckdb %||% self$config$get("data.use_duckdb", TRUE)
      output_format <- output_format %||% self$config$get("data.formats", "csv")
      
      if (self$config$get("processing.verbose", TRUE)) {
        cli::cli_h2("Loading Data")
        cli::cli_alert_info("Data directory: {data_dir}")
        cli::cli_alert_info("Using DuckDB: {use_duckdb}")
      }
      
      # Use DuckDB loader if enabled
      if (use_duckdb) {
        result <- self$error_handler$safe_execute({
          load_data_duckdb(
            file_path = data_dir,
            output_dir = self$config$get("data.output_dir"),
            return_data = FALSE,
            use_duckdb = TRUE,
            output_format = output_format,
            patient = self$config$get("variables.patient")
          )
        }, "data_loading")
        
        if (!is.null(result)) {
          self$status$data_loaded <- TRUE
          if (self$config$get("processing.verbose", TRUE)) {
            cli::cli_alert_success("Data loaded successfully")
          }
        }
      } else {
        # Fallback to traditional CSV loading
        self$error_handler$handle_warning(
          simpleWarning("Traditional CSV loading not yet implemented in this version"),
          "data_loading"
        )
      }
      
      invisible(self)
    },
    
    process_domains = function(domains = NULL, age_group = NULL, 
                              include_multi_rater = NULL) {
      
      # Use config defaults if not specified
      domains <- domains %||% self$config$get("domains.enabled")
      age_group <- age_group %||% self$detect_age_group()
      include_multi_rater <- include_multi_rater %||% TRUE
      
      if (self$config$get("processing.verbose", TRUE)) {
        cli::cli_h2("Processing Domains")
        cli::cli_alert_info("Age group: {age_group}")
        cli::cli_alert_info("Domains: {paste(domains, collapse = ', ')}")
      }
      
      # Validate domains exist in data
      valid_domains <- self$validate_domains(domains)
      
      if (length(valid_domains) == 0) {
        self$error_handler$handle_error(
          simpleError("No valid domains found in data"),
          "domain_processing"
        )
        return(invisible(self))
      }
      
      if (length(valid_domains) < length(domains)) {
        missing <- setdiff(domains, valid_domains)
        cli::cli_alert_warning("Skipping domains not found in data: {paste(missing, collapse = ', ')}")
      }
      
      # Create processors
      self$processors <- self$factory$batch_create(
        valid_domains, 
        age_group, 
        include_multi_rater
      )
      
      if (length(self$processors) == 0) {
        self$error_handler$handle_error(
          simpleError("Failed to create any domain processors"),
          "domain_processing"
        )
        return(invisible(self))
      }
      
      # Process each domain
      for (domain_key in names(self$processors)) {
        processor_item <- self$processors[[domain_key]]
        
        if (self$config$get("processing.verbose", TRUE)) {
          cli::cli_alert_info("Processing domain: {domain_key}")
        }
        
        # Handle multi-rater processors
        if (is.list(processor_item) && !inherits(processor_item, "R6")) {
          for (rater in names(processor_item)) {
            self$process_single_domain(processor_item[[rater]], domain_key, rater)
          }
        } else {
          self$process_single_domain(processor_item, domain_key)
        }
      }
      
      self$status$domains_processed <- TRUE
      
      if (self$config$get("processing.verbose", TRUE)) {
        cli::cli_alert_success("Domain processing completed")
      }
      
      invisible(self)
    },
    
    process_single_domain = function(processor, domain_key, rater = "self") {
      self$error_handler$safe_execute({
        # Load and process data
        processor$load_data()
        processor$filter_by_domain()
        processor$select_columns()
        processor$save_data()
        
        # Generate QMD files if enabled
        if (self$config$get("report.generate_qmd", TRUE)) {
          if (processor$has_multiple_raters()) {
            processor$generate_emotion_child_qmd()
          } else {
            processor$generate_domain_qmd()
          }
        }
      }, paste("processing", domain_key, rater))
    },
    
    generate_report = function(template = NULL, output_file = NULL, 
                              format = NULL) {
      
      # Use config defaults if not specified
      template <- template %||% self$config$get("report.template", "template.qmd")
      format <- format %||% self$config$get("report.format", "neurotyp-adult-typst")
      
      # Generate output filename if not specified
      if (is.null(output_file)) {
        patient_name <- self$config$get("variables.patient", "unknown")
        date_str <- format(Sys.Date(), "%Y-%m-%d")
        output_file <- paste0(gsub("[^A-Za-z0-9]", "_", patient_name), 
                             "_neuropsych_report_", date_str, ".pdf")
      }
      
      if (self$config$get("processing.verbose", TRUE)) {
        cli::cli_h2("Generating Report")
        cli::cli_alert_info("Template: {template}")
        cli::cli_alert_info("Format: {format}")
        cli::cli_alert_info("Output: {output_file}")
      }
      
      # Create report generator
      report_generator <- self$error_handler$safe_execute({
        ReportTemplateR6$new(
          variables = self$config$config$variables,
          template_dir = self$config$get("report.template_dir"),
          output_dir = self$config$get("report.output_dir")
        )
      }, "report_initialization")
      
      if (is.null(report_generator)) {
        return(invisible(self))
      }
      
      # Generate template
      self$error_handler$safe_execute({
        report_generator$generate_template(template)
      }, "template_generation")
      
      # Render report
      self$error_handler$safe_execute({
        report_generator$render_report(
          input_file = file.path(self$config$get("report.output_dir"), template),
          output_format = format,
          output_file = output_file
        )
      }, "report_rendering")
      
      self$status$report_generated <- TRUE
      
      if (self$config$get("processing.verbose", TRUE)) {
        cli::cli_alert_success("Report generated: {output_file}")
      }
      
      invisible(self)
    },
    
    run_full_workflow = function(domains = NULL, age_group = NULL, 
                                load_data = TRUE, generate_report = TRUE) {
      
      if (self$config$get("processing.verbose", TRUE)) {
        cli::cli_h1("Running Full Workflow")
      }
      
      # Load data if requested
      if (load_data) {
        self$load_data()
      }
      
      # Process domains
      self$process_domains(domains, age_group)
      
      # Generate report if requested
      if (generate_report) {
        self$generate_report()
      }
      
      # Show summary
      self$show_summary()
      
      invisible(self)
    },
    
    detect_age_group = function() {
      # Try to detect age group from patient age
      age <- self$config$get("variables.age")
      if (!is.null(age) && is.numeric(age)) {
        return(if (age < 18) "child" else "adult")
      }
      
      # Default to adult
      return("adult")
    },
    
    validate_domains = function(domains) {
      valid_domains <- character()
      
      for (domain in domains) {
        if (self$factory$validate_domain_data(domain)) {
          valid_domains <- c(valid_domains, domain)
        }
      }
      
      return(valid_domains)
    },
    
    show_summary = function() {
      if (!self$config$get("processing.verbose", TRUE)) {
        return(invisible(self))
      }
      
      cli::cli_h2("Workflow Summary")
      
      # Status indicators
      status_icons <- list(
        data_loaded = if (self$status$data_loaded) cli::col_green("✓") else cli::col_red("✗"),
        domains_processed = if (self$status$domains_processed) cli::col_green("✓") else cli::col_red("✗"),
        report_generated = if (self$status$report_generated) cli::col_green("✓") else cli::col_red("✗")
      )
      
      cli::cli_li("{status_icons$data_loaded} Data Loading")
      cli::cli_li("{status_icons$domains_processed} Domain Processing")
      cli::cli_li("{status_icons$report_generated} Report Generation")
      
      # Error/warning summary
      error_count <- length(self$error_handler$error_log)
      if (error_count > 0) {
        cli::cli_alert_warning("Total errors/warnings: {error_count}")
        cli::cli_alert_info("Use neuro2$error_handler$get_recent_errors() to see details")
      } else {
        cli::cli_alert_success("No errors detected")
      }
      
      invisible(self)
    },
    
    get_available_domains = function() {
      self$factory$get_registry_info()
    },
    
    get_status = function() {
      return(self$status)
    }
  )
)

# Main convenience function
#' Create and run neuropsychological report workflow
#'
#' @param config_file Path to configuration file
#' @param variables_file Path to variables file
#' @param domains Vector of domains to process
#' @param age_group Age group ("adult" or "child")
#' @param load_data Whether to load data
#' @param generate_report Whether to generate report
#' @param verbose Whether to show progress messages
#' @export
neuro2_workflow <- function(config_file = "config.yml",
                           variables_file = "_variables.yml", 
                           domains = NULL,
                           age_group = NULL,
                           load_data = TRUE,
                           generate_report = TRUE,
                           verbose = TRUE) {
  
  # Create main orchestrator
  neuro2 <- Neuro2MainR6$new(config_file, variables_file, verbose)
  
  # Run workflow
  neuro2$run_full_workflow(domains, age_group, load_data, generate_report)
  
  return(neuro2)
}

#' Quick start function for new users
#' @param patient_name Patient name
#' @param age Patient age
#' @param data_dir Directory containing CSV data files
#' @export
neuro2_quick_start <- function(patient_name, age, data_dir = "data-raw/csv") {
  
  # Create basic configuration
  config <- list(
    data = list(input_dir = data_dir),
    variables = list(
      patient = patient_name,
      age = age,
      first_name = strsplit(patient_name, " ")[[1]][1],
      last_name = strsplit(patient_name, " ")[[1]][2] %||% "",
      date_of_report = format(Sys.Date(), "%Y-%m-%d")
    )
  )
  
  # Write temporary config
  yaml::write_yaml(config, "temp_config.yml")
  
  # Run workflow
  result <- neuro2_workflow(
    config_file = "temp_config.yml",
    age_group = if (age < 18) "child" else "adult"
  )
  
  # Clean up
  file.remove("temp_config.yml")
  
  return(result)
}