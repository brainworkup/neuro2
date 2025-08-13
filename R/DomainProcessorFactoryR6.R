#' DomainProcessorFactoryR6 Class
#'
#' @title Factory for Creating Domain Processors with Enhanced Error Handling
#' @description Factory class for creating domain processors with smart defaults,
#'   validation, and comprehensive error handling.
#'
#' @field config Configuration object for the factory
#' @field error_handler Error handler instance for managing errors
#' @field registry Registry of available domain configurations
#' @field logger Logger instance for logging messages
#' @field validators Validators for input validation
#'
#' @importFrom R6 R6Class
#' @export
DomainProcessorFactoryR6 <- R6::R6Class(
  classname = "DomainProcessorFactoryR6",
  public = list(
    config = NULL,
    error_handler = NULL,
    registry = NULL,
    logger = NULL,
    validators = NULL,

    #' @description
    #' Initialize factory with configuration
    #' @param config Configuration object (optional)
    #' @param error_handler Error handler instance (optional)
    #' @param logger Logger instance (optional)
    #' @return A new DomainProcessorFactoryR6 object
    initialize = function(config = NULL, error_handler = NULL, logger = NULL) {
      self$config <- config %||% private$get_default_config()
      self$logger <- logger %||% private$create_logger()
      self$error_handler <- error_handler %||% private$create_error_handler()
      self$validators <- private$create_validators()
      self$registry <- private$build_domain_registry()

      self$logger$info("Initialized DomainProcessorFactoryR6")
    },

    #' @description
    #' Create a domain processor with validation
    #' @param domain_key Domain identifier (e.g., "iq", "academics")
    #' @param age_group Age group ("adult" or "child")
    #' @param rater Rater type ("self", "observer", "parent", "teacher")
    #' @param custom_config Custom configuration to override defaults
    #' @return A DomainProcessorR6 object or NULL on error
    create_processor = function(
      domain_key,
      age_group = "adult",
      rater = "self",
      custom_config = NULL
    ) {
      # Validate inputs
      validation_result <- self$validators$validate_processor_params(
        domain_key,
        age_group,
        rater
      )

      if (!validation_result$valid) {
        self$error_handler$handle_error(
          validation_result$error,
          context = "create_processor"
        )
        return(NULL)
      }

      # Get domain configuration
      domain_info <- private$get_domain_info(domain_key, custom_config)

      # Create processor with error handling
      processor <- self$error_handler$safe_execute(
        function() {
          private$build_processor(domain_info, age_group, rater)
        },
        context = "processor_creation",
        fallback = NULL
      )

      if (!is.null(processor)) {
        self$logger$info(paste(
          "Created processor for",
          domain_key,
          "(",
          age_group,
          "/",
          rater,
          ")"
        ))
      }

      return(processor)
    },

    #' @description
    #' Create multi-rater processor
    #' @param domain_key Domain identifier
    #' @param age_group Age group ("adult" or "child")
    #' @return A list of DomainProcessorR6 objects by rater
    create_multi_processor = function(domain_key, age_group = "adult") {
      domain_info <- self$registry[[domain_key]]

      # Validate multi-rater capability
      if (!private$is_multi_rater(domain_info)) {
        self$logger$warn(paste(domain_key, "is not a multi-rater domain"))
        return(self$create_processor(domain_key, age_group))
      }

      # Get available raters
      raters <- private$get_available_raters(domain_info, age_group)
      self$logger$info(paste(
        "Creating multi-rater processors for",
        domain_key,
        "- raters:",
        paste(raters, collapse = ", ")
      ))

      # Create processor for each rater
      processors <- private$create_rater_processors(
        domain_key,
        age_group,
        raters
      )

      # Validate results
      if (length(processors) == 0) {
        self$error_handler$handle_error(
          simpleError(paste("Failed to create any processors for", domain_key)),
          context = "multi_processor_creation"
        )
        return(NULL)
      }

      return(processors)
    },

    #' @description
    #' Batch create processors
    #' @param domain_keys Vector of domain identifiers
    #' @param age_group Age group ("adult" or "child")
    #' @param include_multi_rater Whether to create multi-rater processors
    #' @param parallel Whether to process in parallel (not yet implemented)
    #' @return A list of processors
    batch_create = function(
      domain_keys,
      age_group = "adult",
      include_multi_rater = TRUE,
      parallel = FALSE
    ) {
      self$logger$info(paste(
        "Batch creating processors for",
        length(domain_keys),
        "domains"
      ))

      # Validate all domain keys first
      invalid_keys <- private$validate_domain_keys(domain_keys)
      if (length(invalid_keys) > 0) {
        self$logger$warn(paste(
          "Invalid domain keys:",
          paste(invalid_keys, collapse = ", ")
        ))
        domain_keys <- setdiff(domain_keys, invalid_keys)
      }

      # Create processors (with optional parallelization)
      if (parallel && requireNamespace("future", quietly = TRUE)) {
        processors <- private$batch_create_parallel(
          domain_keys,
          age_group,
          include_multi_rater
        )
      } else {
        processors <- private$batch_create_sequential(
          domain_keys,
          age_group,
          include_multi_rater
        )
      }

      # Report results
      private$report_batch_results(processors, domain_keys)

      return(processors)
    },

    #' @description
    #' Validate domain data availability
    #' @param domain_key Domain identifier
    #' @param detailed Whether to perform detailed validation
    #' @return A list with validation results
    validate_domain_data = function(domain_key, detailed = FALSE) {
      validation_result <- list(
        valid = FALSE,
        domain_exists = FALSE,
        file_exists = FALSE,
        data_available = FALSE,
        details = list()
      )

      # Check domain exists in registry
      domain_info <- self$registry[[domain_key]]
      if (is.null(domain_info)) {
        validation_result$details$error <- "Domain not in registry"
        return(validation_result)
      }
      validation_result$domain_exists <- TRUE

      # Check input file exists
      input_file <- private$get_input_file(domain_info$data_source)
      if (!file.exists(input_file)) {
        validation_result$details$error <- paste("File not found:", input_file)
        return(validation_result)
      }
      validation_result$file_exists <- TRUE

      # Optionally check data content
      if (detailed) {
        data_check <- private$check_domain_in_data(domain_info, input_file)
        validation_result$data_available <- data_check$available
        validation_result$details <- c(
          validation_result$details,
          data_check$details
        )
      } else {
        validation_result$data_available <- TRUE
      }

      validation_result$valid <- all(
        validation_result$domain_exists,
        validation_result$file_exists,
        validation_result$data_available
      )

      return(validation_result)
    },

    #' @description
    #' Get registry information as data frame
    #' @param format Output format ("data.frame", "list", or "json")
    #' @return Registry information in requested format
    get_registry_info = function(format = "data.frame") {
      info <- private$extract_registry_info()

      if (format == "data.frame") {
        return(info)
      } else if (format == "list") {
        return(split(info, seq_len(nrow(info))))
      } else if (
        format == "json" && requireNamespace("jsonlite", quietly = TRUE)
      ) {
        return(jsonlite::toJSON(info, pretty = TRUE))
      }

      return(info)
    },

    #' @description
    #' Get processor configuration template
    #' @param domain_key Domain identifier
    #' @return Configuration template list
    get_processor_config = function(domain_key) {
      domain_info <- self$registry[[domain_key]]
      if (is.null(domain_info)) {
        self$logger$warn(paste("Unknown domain:", domain_key))
        return(NULL)
      }

      config <- list(
        domain = domain_info$domains,
        pheno = domain_info$pheno,
        data_source = domain_info$data_source,
        input_file = private$get_input_file(domain_info$data_source),
        number = domain_info$number,
        score_types = domain_info$score_types,
        multi_rater = private$is_multi_rater(domain_info),
        age_variants = domain_info$age_variants,
        available_raters = if (private$is_multi_rater(domain_info)) {
          domain_info$raters
        } else {
          NULL
        }
      )

      return(config)
    }
  ),

  private = list(
    # Create default configuration
    get_default_config = function() {
      list(
        data = list(
          neurocog = "data/neurocog.parquet",
          neurobehav = "data/neurobehav.parquet",
          validity = "data/validity.parquet",
          neuropsych = "data/neuropsych.parquet"
        ),
        processing = list(verbose = TRUE, parallel = FALSE, max_workers = 4),
        validation = list(strict = FALSE, check_data_content = FALSE)
      )
    },

    # Create logger
    create_logger = function() {
      list(
        info = function(msg) {
          if (isTRUE(self$config$processing$verbose)) {
            message("[INFO] ", Sys.time(), " - ", msg)
          }
        },
        warn = function(msg) {
          warning("[WARN] ", msg, call. = FALSE)
        },
        error = function(msg) {
          stop("[ERROR] ", msg, call. = FALSE)
        },
        debug = function(msg) {
          if (getOption("debug", FALSE)) {
            message("[DEBUG] ", msg)
          }
        }
      )
    },

    # Create error handler
    create_error_handler = function() {
      list(
        handle_error = function(error, context = NULL) {
          msg <- if (!is.null(context)) {
            paste0("[", context, "] ", error$message)
          } else {
            error$message
          }
          self$logger$error(msg)
        },

        handle_warning = function(warning, context = NULL) {
          msg <- if (!is.null(context)) {
            paste0("[", context, "] ", warning$message)
          } else {
            warning$message
          }
          self$logger$warn(msg)
        },

        safe_execute = function(expr, context = NULL, fallback = NULL) {
          tryCatch(
            expr(),
            error = function(e) {
              private$create_error_handler()$handle_error(e, context)
              return(fallback)
            },
            warning = function(w) {
              private$create_error_handler()$handle_warning(w, context)
              invokeRestart("muffleWarning")
            }
          )
        }
      )
    },

    # Create validators
    create_validators = function() {
      list(validate_processor_params = function(domain_key, age_group, rater) {
        result <- list(valid = TRUE, error = NULL)

        # Check domain key
        if (!domain_key %in% names(self$registry)) {
          result$valid <- FALSE
          result$error <- simpleError(paste(
            "Unknown domain:",
            domain_key,
            "\nAvailable:",
            paste(names(self$registry), collapse = ", ")
          ))
          return(result)
        }

        # Check age group
        valid_age_groups <- c("adult", "child")
        if (!age_group %in% valid_age_groups) {
          result$valid <- FALSE
          result$error <- simpleError(paste(
            "Invalid age group:",
            age_group,
            "\nMust be one of:",
            paste(valid_age_groups, collapse = ", ")
          ))
          return(result)
        }

        # Check rater
        valid_raters <- c("self", "observer", "parent", "teacher")
        if (!rater %in% valid_raters) {
          result$valid <- FALSE
          result$error <- simpleError(paste(
            "Invalid rater:",
            rater,
            "\nMust be one of:",
            paste(valid_raters, collapse = ", ")
          ))
          return(result)
        }

        return(result)
      })
    },

    # Build domain registry
    build_domain_registry = function() {
      list(
        # Cognitive domains
        iq = list(
          domains = "General Cognitive Ability",
          pheno = "iq",
          data_source = "neurocog",
          number = "01",
          has_narrow = TRUE,
          score_types = c("standard_score")
        ),

        academics = list(
          domains = "Academic Skills",
          pheno = "academics",
          data_source = "neurocog",
          number = "02",
          score_types = c("standard_score")
        ),

        verbal = list(
          domains = "Verbal/Language",
          pheno = "verbal",
          data_source = "neurocog",
          number = "03",
          score_types = c("standard_score", "scaled_score", "t_score")
        ),

        spatial = list(
          domains = "Visual Perception/Construction",
          pheno = "spatial",
          data_source = "neurocog",
          number = "04",
          score_types = c(
            "standard_score",
            "scaled_score",
            "t_score",
            "t_score"
          )
        ),

        memory = list(
          domains = "Memory",
          pheno = "memory",
          data_source = "neurocog",
          number = "05",
          score_types = c("standard_score", "scaled_score", "t_score")
        ),

        executive = list(
          domains = "Attention/Executive",
          pheno = "executive",
          data_source = "neurocog",
          number = "06",
          score_types = c("standard_score", "scaled_score", "t_score")
        ),

        motor = list(
          domains = "Motor",
          pheno = "motor",
          data_source = "neurocog",
          number = "07",
          score_types = c("scaled_score", "t_score")
        ),

        social = list(
          domains = "Social Cognition",
          pheno = "social",
          data_source = "neurocog",
          number = "08",
          score_types = c("standard_score", "t_score", "scaled_score")
        ),

        # Behavioral domains
        adhd = list(
          domains = "ADHD",
          pheno = "adhd",
          data_source = "neurobehav",
          number = "09",
          multi_rater = TRUE,
          age_variants = c("adult", "child"),
          raters = list(
            adult = c("self", "observer"),
            child = c("self", "parent", "teacher")
          ),
          score_types = c("t_score")
        ),

        emotion = list(
          domains = c(
            "Emotional/Behavioral/Personality",
            "Behavioral/Emotional/Social"
          ),
          pheno = "emotion",
          data_source = "neurobehav",
          number = "10",
          multi_rater = TRUE,
          age_variants = c("adult", "child"),
          raters = list(
            adult = c("self"),
            child = c("self", "parent", "teacher")
          ),
          score_types = c("t_score")
        ),

        adaptive = list(
          domains = "Adaptive Functioning",
          pheno = "adaptive",
          data_source = "neurobehav",
          number = "11",
          score_types = c("standard_score", "scaled_score")
        ),

        daily_living = list(
          domains = "Daily Living",
          pheno = "daily_living",
          data_source = "neurocog",
          number = "12",
          score_types = c("t_score")
        ),

        # Validity
        validity = list(
          domains = c("Performance Validity", "Symptom Validity"),
          pheno = "validity",
          data_source = "validity",
          number = "13",
          score_types = c("t_score", "base_rate", "raw_score")
        )
      )
    },

    # Get domain info with custom config
    get_domain_info = function(domain_key, custom_config = NULL) {
      domain_info <- self$registry[[domain_key]]

      if (is.null(domain_info)) {
        stop(paste("Domain not found:", domain_key), call. = FALSE)
      }

      # Merge with custom config if provided
      if (!is.null(custom_config)) {
        domain_info <- modifyList(domain_info, custom_config)
      }

      return(domain_info)
    },

    # Build processor instance
    build_processor = function(domain_info, age_group, rater) {
      # Determine input file
      input_file <- private$get_input_file(domain_info$data_source)

      # Adjust pheno for age variants
      pheno <- private$adjust_pheno_for_age(
        domain_info$pheno,
        domain_info$age_variants,
        age_group
      )

      # Create processor
      processor <- DomainProcessorR6$new(
        domains = domain_info$domains,
        pheno = pheno,
        input_file = input_file,
        output_dir = self$config$data$output_dir %||% "data",
        config = list(
          age_group = age_group,
          rater = rater,
          domain_info = domain_info
        )
      )

      return(processor)
    },

    # Check if domain is multi-rater
    is_multi_rater = function(domain_info) {
      !is.null(domain_info$multi_rater) && domain_info$multi_rater
    },

    # Get available raters for domain and age
    get_available_raters = function(domain_info, age_group) {
      if (!private$is_multi_rater(domain_info)) {
        return("self")
      }

      raters <- domain_info$raters

      # Handle age-specific raters
      if (is.list(raters) && age_group %in% names(raters)) {
        return(raters[[age_group]])
      }

      # Handle simple rater list
      if (is.character(raters)) {
        return(raters)
      }

      return("self")
    },

    # Get input file path
    get_input_file = function(data_source) {
      data_paths <- self$config$data %||% list()

      # Try to get from config
      if (data_source %in% names(data_paths)) {
        return(data_paths[[data_source]])
      }

      # Use defaults
      default_paths <- list(
        neurocog = "data/neurocog.parquet",
        neurobehav = "data/neurobehav.parquet",
        validity = "data/validity.parquet",
        neuropsych = "data/neuropsych.parquet"
      )

      return(default_paths[[data_source]] %||% default_paths$neuropsych)
    },

    # Adjust phenotype for age group
    adjust_pheno_for_age = function(pheno, age_variants, age_group) {
      if (!is.null(age_variants) && age_group %in% age_variants) {
        return(paste0(pheno, "_", age_group))
      }
      return(pheno)
    },

    # Create processors for each rater
    create_rater_processors = function(domain_key, age_group, raters) {
      processors <- list()

      for (rater in raters) {
        processor <- tryCatch(
          self$create_processor(domain_key, age_group, rater),
          error = function(e) {
            self$logger$warn(paste(
              "Failed to create processor for",
              domain_key,
              "/",
              rater,
              ":",
              e$message
            ))
            NULL
          }
        )

        if (!is.null(processor)) {
          processors[[rater]] <- processor
        }
      }

      return(processors)
    },

    # Validate domain keys
    validate_domain_keys = function(domain_keys) {
      invalid_keys <- character()

      for (key in domain_keys) {
        if (!key %in% names(self$registry)) {
          invalid_keys <- c(invalid_keys, key)
        }
      }

      return(invalid_keys)
    },

    # Batch create processors sequentially
    batch_create_sequential = function(
      domain_keys,
      age_group,
      include_multi_rater
    ) {
      processors <- list()

      for (domain_key in domain_keys) {
        domain_info <- self$registry[[domain_key]]

        if (is.null(domain_info)) {
          next
        }

        processor <- if (
          include_multi_rater && private$is_multi_rater(domain_info)
        ) {
          self$create_multi_processor(domain_key, age_group)
        } else {
          self$create_processor(domain_key, age_group)
        }

        if (!is.null(processor)) {
          processors[[domain_key]] <- processor
        }
      }

      return(processors)
    },

    # Batch create processors in parallel
    batch_create_parallel = function(
      domain_keys,
      age_group,
      include_multi_rater
    ) {
      # This would implement parallel processing using future package
      # For now, fall back to sequential
      self$logger$info("Parallel processing not implemented, using sequential")
      return(private$batch_create_sequential(
        domain_keys,
        age_group,
        include_multi_rater
      ))
    },

    # Report batch creation results
    report_batch_results = function(processors, domain_keys) {
      success_count <- length(processors)
      total_count <- length(domain_keys)

      self$logger$info(sprintf(
        "Successfully created %d/%d processors (%.1f%% success rate)",
        success_count,
        total_count,
        100 * success_count / total_count
      ))

      if (success_count < total_count) {
        failed <- setdiff(domain_keys, names(processors))
        self$logger$warn(paste(
          "Failed domains:",
          paste(failed, collapse = ", ")
        ))
      }
    },

    # Check if domain exists in data
    check_domain_in_data = function(domain_info, input_file) {
      result <- list(available = FALSE, details = list())

      # Try to read a sample of the data
      data_sample <- tryCatch(
        {
          if (tools::file_ext(input_file) == "parquet") {
            if (requireNamespace("arrow", quietly = TRUE)) {
              # Read just the domain column
              arrow::read_parquet(input_file, col_select = "domain")
            } else {
              NULL
            }
          } else {
            readr::read_csv(input_file, n_max = 1000, show_col_types = FALSE)
          }
        },
        error = function(e) {
          result$details$read_error <- e$message
          NULL
        }
      )

      if (!is.null(data_sample)) {
        available_domains <- unique(data_sample$domain)
        domain_matches <- any(domain_info$domains %in% available_domains)

        result$available <- domain_matches
        result$details$available_domains <- available_domains
        result$details$requested_domains <- domain_info$domains
      }

      return(result)
    },

    # Extract registry info as data frame
    extract_registry_info = function() {
      info_list <- lapply(names(self$registry), function(key) {
        domain <- self$registry[[key]]
        data.frame(
          domain_key = key,
          pheno = domain$pheno,
          data_source = domain$data_source,
          number = domain$number %||% NA,
          multi_rater = private$is_multi_rater(domain),
          age_variants = if (!is.null(domain$age_variants)) {
            paste(domain$age_variants, collapse = ", ")
          } else {
            ""
          },
          score_types = paste(domain$score_types, collapse = ", "),
          stringsAsFactors = FALSE
        )
      })

      do.call(rbind, info_list)
    }
  )
)
