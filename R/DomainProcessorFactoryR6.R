#' DomainProcessorFactoryR6 Class
#'
#' Factory class for creating domain processors with smart defaults
#' Simplifies initialization and reduces code duplication
#'
#' @export
DomainProcessorFactoryR6 <- R6::R6Class(
  classname = "DomainProcessorFactoryR6",
  public = list(
    config = NULL,
    error_handler = NULL,
    registry = NULL,
    
    initialize = function(config = NULL, error_handler = NULL) {
      self$config <- config %||% get_config()
      self$error_handler <- error_handler %||% get_error_handler(self$config)
      self$registry <- self$build_domain_registry()
    },
    
    build_domain_registry = function() {
      list(
        # Cognitive domains - use neurocog data
        iq = list(
          domains = "General Cognitive Ability",
          pheno = "iq",
          data_source = "neurocog",
          number = "01",
          has_narrow = TRUE,
          score_types = c("standard_score", "scaled_score")
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
          score_types = c("standard_score", "scaled_score")
        ),
        
        spatial = list(
          domains = "Visual Perception/Construction",
          pheno = "spatial",
          data_source = "neurocog", 
          number = "04",
          score_types = c("standard_score", "scaled_score")
        ),
        
        memory = list(
          domains = "Memory",
          pheno = "memory",
          data_source = "neurocog",
          number = "05", 
          score_types = c("standard_score", "scaled_score")
        ),
        
        executive = list(
          domains = "Attention/Executive",
          pheno = "executive",
          data_source = "neurocog",
          number = "06",
          score_types = c("standard_score", "scaled_score")
        ),
        
        motor = list(
          domains = "Motor", 
          pheno = "motor",
          data_source = "neurocog",
          number = "07",
          score_types = c("standard_score")
        ),
        
        social = list(
          domains = "Social Cognition",
          pheno = "social",
          data_source = "neurocog",  # Could be neurobehav for some tests
          number = "08",
          score_types = c("standard_score", "t_score")
        ),
        
        # Behavioral domains - use neurobehav data
        adhd = list(
          domains = "ADHD",
          pheno = "adhd", 
          data_source = "neurobehav",
          number = "09",
          multi_rater = TRUE,
          age_variants = c("adult", "child"),
          raters = c("self", "observer"),
          score_types = c("t_score")
        ),
        
        emotion = list(
          domains = c("Emotional/Behavioral/Personality", 
                     "Behavioral/Emotional/Social",
                     "Psychiatric Disorders",
                     "Personality Disorders"),
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
          score_types = c("standard_score")
        ),
        
        daily_living = list(
          domains = "Daily Living",
          pheno = "daily_living", 
          data_source = "neurobehav",
          number = "12",
          score_types = c("standard_score")
        ),
        
        # Validity domains
        validity = list(
          domains = c("Performance Validity", "Symptom Validity"),
          pheno = "validity",
          data_source = "validity",
          number = "13",
          score_types = c("t_score", "base_rate")
        )
      )
    },
    
    create_processor = function(domain_key, age_group = "adult", 
                               rater = "self", custom_config = NULL) {
      
      # Validate domain key
      if (!domain_key %in% names(self$registry)) {
        available <- paste(names(self$registry), collapse = ", ")
        self$error_handler$handle_error(
          simpleError(paste("Unknown domain:", domain_key, 
                           ". Available:", available)),
          "domain_factory"
        )
        return(NULL)
      }
      
      domain_info <- self$registry[[domain_key]]
      
      # Override with custom config if provided
      if (!is.null(custom_config)) {
        domain_info <- modifyList(domain_info, custom_config)
      }
      
      # Determine input file
      input_file <- self$get_input_file(domain_info$data_source)
      
      # Handle age variants
      pheno <- domain_info$pheno
      if (!is.null(domain_info$age_variants) && age_group %in% domain_info$age_variants) {
        pheno <- paste0(pheno, "_", age_group)
      }
      
      # Create the processor
      processor <- self$error_handler$safe_execute({
        DomainProcessorR6$new(
          domains = domain_info$domains,
          pheno = pheno,
          input_file = input_file,
          output_dir = self$config$get("data.output_dir", "data")
        )
      }, "domain_processor_creation")
      
      if (is.null(processor)) {
        return(NULL)
      }
      
      # Set additional metadata
      processor$domain_info <- domain_info
      processor$age_group <- age_group
      processor$rater <- rater
      
      return(processor)
    },
    
    create_multi_processor = function(domain_key, age_group = "adult") {
      domain_info <- self$registry[[domain_key]]
      
      if (is.null(domain_info$multi_rater) || !domain_info$multi_rater) {
        self$error_handler$handle_warning(
          simpleWarning(paste("Domain", domain_key, "is not multi-rater")),
          "multi_processor_creation"
        )
        return(self$create_processor(domain_key, age_group))
      }
      
      # Get available raters for this domain and age group
      raters <- self$get_available_raters(domain_info, age_group)
      
      # Create processors for each rater
      processors <- list()
      for (rater in raters) {
        processors[[rater]] <- self$create_processor(domain_key, age_group, rater)
      }
      
      # Filter out any NULL processors
      processors <- Filter(Negate(is.null), processors)
      
      if (length(processors) == 0) {
        self$error_handler$handle_error(
          simpleError(paste("Failed to create any processors for", domain_key)),
          "multi_processor_creation"
        )
        return(NULL)
      }
      
      return(processors)
    },
    
    get_available_raters = function(domain_info, age_group) {
      if (is.null(domain_info$raters)) {
        return("self")  # Default
      }
      
      # Handle age-specific raters
      if (is.list(domain_info$raters) && age_group %in% names(domain_info$raters)) {
        return(domain_info$raters[[age_group]])
      }
      
      # Handle simple rater list
      if (is.character(domain_info$raters)) {
        return(domain_info$raters)
      }
      
      return("self")
    },
    
    get_input_file = function(data_source) {
      # Map data source to file path
      data_paths <- self$config$get("data", list())
      
      file_mapping <- list(
        neurocog = data_paths$neurocog %||% "data/neurocog.csv",
        neurobehav = data_paths$neurobehav %||% "data/neurobehav.csv", 
        validity = data_paths$validity %||% "data/validity.csv",
        neuropsych = data_paths$neuropsych %||% "data/neuropsych.csv"
      )
      
      file_path <- file_mapping[[data_source]]
      if (is.null(file_path)) {
        file_path <- file_mapping$neuropsych  # Default fallback
      }
      
      return(file_path)
    },
    
    batch_create = function(domain_keys, age_group = "adult", 
                           include_multi_rater = TRUE) {
      
      if (self$config$get("processing.verbose", TRUE)) {
        message("Creating processors for domains: ", 
                paste(domain_keys, collapse = ", "))
      }
      
      processors <- list()
      
      for (domain_key in domain_keys) {
        domain_info <- self$registry[[domain_key]]
        
        if (is.null(domain_info)) {
          self$error_handler$handle_warning(
            simpleWarning(paste("Unknown domain:", domain_key)),
            "batch_creation"
          )
          next
        }
        
        # Check if multi-rater and handle appropriately
        if (include_multi_rater && 
            !is.null(domain_info$multi_rater) && 
            domain_info$multi_rater) {
          
          processors[[domain_key]] <- self$create_multi_processor(domain_key, age_group)
        } else {
          processors[[domain_key]] <- self$create_processor(domain_key, age_group)
        }
      }
      
      # Filter out NULL results
      processors <- Filter(Negate(is.null), processors)
      
      if (self$config$get("processing.verbose", TRUE)) {
        success_count <- length(processors)
        total_count <- length(domain_keys)
        message(sprintf("Successfully created %d/%d processors", 
                       success_count, total_count))
      }
      
      return(processors)
    },
    
    get_registry_info = function() {
      # Return summary of available domains
      info <- data.frame(
        domain_key = names(self$registry),
        pheno = sapply(self$registry, function(x) x$pheno),
        data_source = sapply(self$registry, function(x) x$data_source),
        multi_rater = sapply(self$registry, function(x) !is.null(x$multi_rater) && x$multi_rater),
        age_variants = sapply(self$registry, function(x) {
          if (is.null(x$age_variants)) "" else paste(x$age_variants, collapse = ", ")
        }),
        stringsAsFactors = FALSE
      )
      
      return(info)
    },
    
    validate_domain_data = function(domain_key) {
      domain_info <- self$registry[[domain_key]]
      if (is.null(domain_info)) {
        return(FALSE)
      }
      
      # Check if input file exists
      input_file <- self$get_input_file(domain_info$data_source)
      if (!file.exists(input_file)) {
        self$error_handler$handle_error(
          simpleError(paste("Input file not found:", input_file)),
          "domain_validation"
        )
        return(FALSE)
      }
      
      # Try to load and check for domain
      data <- self$error_handler$safe_execute({
        readr::read_csv(input_file, show_col_types = FALSE)
      }, "data_loading")
      
      if (is.null(data)) {
        return(FALSE)
      }
      
      # Check if domain exists in data
      available_domains <- unique(data$domain)
      domain_matches <- any(domain_info$domains %in% available_domains)
      
      if (!domain_matches) {
        self$error_handler$handle_warning(
          simpleWarning(paste("Domain not found in data:", 
                             paste(domain_info$domains, collapse = ", "),
                             "\nAvailable:", paste(available_domains, collapse = ", "))),
          "domain_validation"
        )
        return(FALSE)
      }
      
      return(TRUE)
    }
  )
)

# Convenience functions for common use cases
#' Create domain processor with smart defaults
#' @param domain_key Domain identifier
#' @param age_group Age group ("adult" or "child")
#' @param rater Rater type ("self", "observer", "parent", "teacher")
#' @param config Optional configuration
#' @export
create_domain_processor <- function(domain_key, age_group = "adult", 
                                   rater = "self", config = NULL) {
  factory <- DomainProcessorFactoryR6$new(config)
  factory$create_processor(domain_key, age_group, rater)
}

#' Create multiple domain processors
#' @param domain_keys Vector of domain identifiers
#' @param age_group Age group ("adult" or "child")
#' @param include_multi_rater Whether to create multi-rater processors
#' @param config Optional configuration
#' @export
create_domain_processors <- function(domain_keys, age_group = "adult",
                                     include_multi_rater = TRUE, config = NULL) {
  factory <- DomainProcessorFactoryR6$new(config)
  factory$batch_create(domain_keys, age_group, include_multi_rater)
}