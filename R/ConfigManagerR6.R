#' ConfigManagerR6 Class
#'
#' Centralized configuration management for neuro2 package
#' Consolidates settings from YAML files, environment variables, and defaults
#'
#' @export
ConfigManagerR6 <- R6::R6Class(
  classname = "ConfigManagerR6",
  public = list(
    config = NULL,
    
    initialize = function(config_file = NULL, variables_file = "_variables.yml") {
      # Load base configuration
      self$config <- self$load_default_config()
      
      # Override with YAML files if they exist
      if (!is.null(config_file) && file.exists(config_file)) {
        user_config <- yaml::read_yaml(config_file)
        self$config <- self$merge_configs(self$config, user_config)
      }
      
      if (file.exists(variables_file)) {
        variables <- yaml::read_yaml(variables_file)
        self$config$variables <- variables
      }
      
      # Override with environment variables
      self$apply_env_overrides()
      
      # Validate configuration
      self$validate_config()
    },
    
    load_default_config = function() {
      list(
        # Data processing
        data = list(
          input_dir = "data-raw/csv",
          output_dir = "data", 
          formats = c("csv", "parquet"),
          use_duckdb = TRUE
        ),
        
        # Report generation  
        report = list(
          template_dir = "inst/quarto/_extensions/brainworkup",
          output_dir = "output",
          format = "neurotyp-adult-typst",
          include_validity = TRUE,
          include_plots = TRUE
        ),
        
        # Domain configuration
        domains = list(
          enabled = c("iq", "academics", "verbal", "spatial", "memory", 
                     "executive", "motor", "social", "adhd", "emotion"),
          multi_rater = c("adhd", "emotion"),
          age_variants = c("adhd", "emotion")
        ),
        
        # Processing options
        processing = list(
          parallel = FALSE,
          cache_enabled = TRUE,
          verbose = TRUE,
          error_on_missing = FALSE
        ),
        
        # Default variables
        variables = list(
          patient = "Unknown",
          age = 18,
          date_of_report = format(Sys.Date(), "%Y-%m-%d")
        )
      )
    },
    
    merge_configs = function(base, override) {
      # Deep merge of nested lists
      modifyList(base, override, keep.null = TRUE)
    },
    
    apply_env_overrides = function() {
      # Check for common environment variables
      env_vars <- list(
        PATIENT = "variables.patient",
        NEURO2_DATA_DIR = "data.input_dir",
        NEURO2_OUTPUT_DIR = "data.output_dir",
        NEURO2_VERBOSE = "processing.verbose"
      )
      
      for (env_var in names(env_vars)) {
        value <- Sys.getenv(env_var)
        if (nchar(value) > 0) {
          self$set_nested_value(env_vars[[env_var]], value)
        }
      }
    },
    
    set_nested_value = function(path, value) {
      path_parts <- strsplit(path, "\\.")[[1]]
      current <- self$config
      
      # Navigate to parent
      for (i in seq_len(length(path_parts) - 1)) {
        if (!path_parts[i] %in% names(current)) {
          current[[path_parts[i]]] <- list()
        }
        current <- current[[path_parts[i]]]
      }
      
      # Set value (with type conversion)
      final_key <- path_parts[length(path_parts)]
      if (value %in% c("TRUE", "true")) {
        current[[final_key]] <- TRUE
      } else if (value %in% c("FALSE", "false")) {
        current[[final_key]] <- FALSE
      } else if (grepl("^\\d+$", value)) {
        current[[final_key]] <- as.integer(value)
      } else {
        current[[final_key]] <- value
      }
    },
    
    validate_config = function() {
      # Check required directories exist or can be created
      dirs_to_check <- c(
        self$config$data$input_dir,
        self$config$data$output_dir,
        self$config$report$output_dir
      )
      
      for (dir in dirs_to_check) {
        if (!dir.exists(dir)) {
          if (self$config$processing$verbose) {
            message("Creating directory: ", dir)
          }
          dir.create(dir, recursive = TRUE, showWarnings = FALSE)
        }
      }
      
      # Validate patient information
      if (is.null(self$config$variables$patient) || 
          self$config$variables$patient == "Unknown") {
        warning("Patient name not set. Using 'Unknown'.")
      }
    },
    
    get = function(path, default = NULL) {
      path_parts <- strsplit(path, "\\.")[[1]]
      current <- self$config
      
      for (part in path_parts) {
        if (part %in% names(current)) {
          current <- current[[part]]
        } else {
          return(default)
        }
      }
      
      current
    },
    
    set = function(path, value) {
      self$set_nested_value(path, value)
      invisible(self)
    },
    
    save_config = function(file = "neuro2_config.yml") {
      yaml::write_yaml(self$config, file)
      if (self$config$processing$verbose) {
        message("Configuration saved to: ", file)
      }
      invisible(self)
    }
  )
)