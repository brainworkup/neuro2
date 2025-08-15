#' Domain Processor Utility Functions - Fixed Version
#'
#' @description High-level utility functions for domain processing with
#'   improved error handling and validation
#'
#' @import dplyr
#' @import readr

# Null coalesce operator if not already defined
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Create a domain processor with smart defaults and validation
#'
#' @param domain_name The domain name (e.g., "ADHD", "Behavioral/Emotional/Social")
#' @param data_file Path to your neurobehavioral data file
#' @param age_group Either "adult" or "child"
#' @param test_lookup_file Path to the test lookup CSV
#' @param config Optional configuration list
#' @param validate Whether to validate inputs before creation
#' @return A DomainProcessorR6 object or NULL on error
#' @export
create_domain_processor <- function(
  domain_name,
  data_file,
  age_group = "adult",
  test_lookup_file = NULL,
  config = NULL,
  validate = TRUE
) {
  # Input validation
  if (validate) {
    validation <- validate_processor_inputs(
      domain_name,
      data_file,
      age_group,
      test_lookup_file
    )

    if (!validation$valid) {
      warning(paste(
        "Validation failed:",
        paste(validation$errors, collapse = "; ")
      ))
      return(NULL)
    }
  }

  # Create clean phenotype name
  pheno <- clean_phenotype_name(domain_name)

  # Create processor with error handling
  processor <- tryCatch(
    {
      DomainProcessorR6$new(
        domains = domain_name,
        pheno = pheno,
        input_file = data_file,
        config = config
      )
    },
    error = function(e) {
      warning(paste("Failed to create processor:", e$message))
      NULL
    }
  )

  # Set additional metadata if processor created successfully
  if (!is.null(processor)) {
    processor$age_group <- age_group

    if (!is.null(test_lookup_file) && file.exists(test_lookup_file)) {
      processor$test_lookup <- load_test_lookup(test_lookup_file)
    }
  }

  return(processor)
}

#' Process a simple single-rater domain
#'
#' @param domain_name Domain name
#' @param data_file Path to data file
#' @param age_group Age group ("adult" or "child")
#' @param output_dir Output directory for generated files
#' @param config Optional configuration
#' @return A DomainProcessorR6 object or NULL on error
#' @export
process_simple_domain <- function(
  domain_name,
  data_file,
  age_group = "adult",
  output_dir = "output",
  config = NULL
) {
  # Create processor
  processor <- create_domain_processor(
    domain_name,
    data_file,
    age_group,
    config = config
  )

  if (is.null(processor)) {
    return(NULL)
  }

  # Check if it's actually simple (single-rater)
  if (processor$has_multiple_raters()) {
    message(paste(
      "Note: Domain",
      domain_name,
      "has multiple raters.",
      "Consider using process_multi_rater_domain() for better results."
    ))
  }

  # Process with error handling
  tryCatch(
    {
      processor$process(generate_domain_files = TRUE)
      message(paste(
        "Successfully processed",
        domain_name,
        "for",
        age_group,
        "age group"
      ))
    },
    error = function(e) {
      warning(paste("Processing failed:", e$message))
      return(NULL)
    }
  )

  return(processor)
}

#' Process a multi-rater domain
#'
#' @param domain_name Domain name
#' @param data_file Path to data file
#' @param age_group Age group ("adult" or "child")
#' @param raters Specific raters to process (NULL for all available)
#' @param config Optional configuration
#' @return A list of DomainProcessorR6 objects by rater
#' @export
process_multi_rater_domain <- function(
  domain_name,
  data_file,
  age_group = "adult",
  raters = NULL,
  config = NULL
) {
  # Create base processor
  processor <- create_domain_processor(
    domain_name,
    data_file,
    age_group,
    config = config
  )

  if (is.null(processor)) {
    return(NULL)
  }

  # Get available raters
  available_raters <- processor$get_rater_types()

  if (is.null(available_raters)) {
    message(paste(domain_name, "does not have multiple raters"))
    return(list(self = processor))
  }

  # Filter to requested raters if specified
  if (!is.null(raters)) {
    available_raters <- intersect(available_raters, raters)

    if (length(available_raters) == 0) {
      warning(paste(
        "No valid raters found. Requested:",
        paste(raters, collapse = ", "),
        "Available:",
        paste(processor$get_rater_types(), collapse = ", ")
      ))
      return(NULL)
    }
  }

  message(paste(
    "Processing",
    domain_name,
    "for",
    age_group,
    "with raters:",
    paste(available_raters, collapse = ", ")
  ))

  # Process each rater
  processors <- list()

  for (rater in available_raters) {
    tryCatch(
      {
        # Clone processor for this rater
        rater_processor <- processor$clone(deep = TRUE)
        rater_processor$rater <- rater

        # Process
        rater_processor$process(generate_domain_files = TRUE)
        processors[[rater]] <- rater_processor

        message(paste("  ✓", rater, "processed successfully"))
      },
      error = function(e) {
        warning(paste("  ✗", rater, "failed:", e$message))
      }
    )
  }

  return(processors)
}

#' Get domain information from test lookup or registry
#'
#' @param test_lookup_file Path to test lookup file (optional)
#' @param use_factory Whether to use factory registry
#' @return A data frame with domain summary information
#' @export
get_domain_info <- function(test_lookup_file = NULL, use_factory = TRUE) {
  # Try factory registry first if available
  if (use_factory && exists("DomainProcessorFactoryR6")) {
    tryCatch({
      factory <- DomainProcessorFactoryR6$new()
      return(factory$get_registry_info())
    }, error = function(e) {
      message("Factory registry not available, trying test lookup file")
    })
  }

  # Fall back to test lookup file
  if (!is.null(test_lookup_file) && file.exists(test_lookup_file)) {
    return(summarize_test_lookup(test_lookup_file))
  }

  # Return empty data frame if no source available
  warning("No domain information source available")
  return(data.frame())
}

#' Check available raters for a domain and age group
#'
#' @param domain_name Domain name
#' @param age_group Age group
#' @param test_lookup_file Path to test lookup file (optional)
#' @return A data frame with rater information
#' @export
check_domain_raters <- function(
  domain_name,
  age_group = "adult",
  test_lookup_file = NULL
) {
  # Try factory first if available
  if (exists("DomainProcessorFactoryR6")) {
    tryCatch({
      factory <- DomainProcessorFactoryR6$new()
      
      # Try to get from registry
      config <- factory$get_processor_config(get_domain_key(domain_name))
      
      if (!is.null(config) && !is.null(config$available_raters)) {
        raters <- if (is.list(config$available_raters)) {
          config$available_raters[[age_group]] %||% character()
        } else {
          config$available_raters
        }
        
        result <- data.frame(
          rater = raters,
          age_group = age_group,
          domain = domain_name,
          stringsAsFactors = FALSE
        )
        
        message(paste(
          "Available raters for",
          domain_name,
          "(",
          age_group,
          "):",
          paste(raters, collapse = ", ")
        ))
        
        return(result)
      }
    }, error = function(e) {
      message("Factory not available, trying test lookup file")
    })
  }

  # Fall back to test lookup if available
  if (!is.null(test_lookup_file) && file.exists(test_lookup_file)) {
    return(get_raters_from_lookup(test_lookup_file, domain_name, age_group))
  }

  warning("Could not determine available raters")
  return(data.frame())
}

#' Batch process multiple domains with progress reporting
#'
#' @param domains Vector of domain names or keys
#' @param data_file Path to data file
#' @param age_group Age group
#' @param parallel Whether to process in parallel
#' @param progress Whether to show progress
#' @param config Optional configuration
#' @return A list of processor results
#' @export
batch_process_domains <- function(
  domains,
  data_file,
  age_group = "adult",
  parallel = FALSE,
  progress = TRUE,
  config = NULL
) {
  if (length(domains) == 0) {
    warning("No domains specified")
    return(list())
  }

  # Initialize progress tracking
  if (progress) {
    message(paste(
      "\n========================================",
      "\nBatch processing",
      length(domains),
      "domains",
      "\n========================================"
    ))
  }

  results <- list()
  success_count <- 0
  failed_domains <- character()

  # Process each domain
  for (i in seq_along(domains)) {
    domain <- domains[i]

    if (progress) {
      message(paste("\n[", i, "/", length(domains), "] Processing:", domain))
    }

    # Process domain with error handling
    result <- tryCatch(
      {
        # Determine if multi-rater
        processor <- create_domain_processor(
          domain,
          data_file,
          age_group,
          config = config
        )

        if (!is.null(processor) && processor$has_multiple_raters()) {
          process_multi_rater_domain(
            domain,
            data_file,
            age_group,
            config = config
          )
        } else {
          process_simple_domain(domain, data_file, age_group, config = config)
        }
      },
      error = function(e) {
        message(paste("  ✗ Error:", e$message))
        failed_domains <- c(failed_domains, domain)
        NULL
      }
    )

    # Store result
    if (!is.null(result)) {
      results[[domain]] <- result
      success_count <- success_count + 1
      if (progress) message("  ✓ Complete")
    }
  }

  # Report summary
  if (progress) {
    message(paste(
      "\n========================================",
      "\nBatch Processing Complete",
      "\n  Success:",
      success_count,
      "/",
      length(domains),
      if (length(failed_domains) > 0) {
        paste("\n  Failed:", paste(failed_domains, collapse = ", "))
      } else {
        ""
      },
      "\n========================================"
    ))
  }

  return(results)
}

#' Validate processor creation inputs
#'
#' @param domain_name Domain name
#' @param data_file Data file path
#' @param age_group Age group
#' @param test_lookup_file Test lookup file path
#' @return List with validation results
#' @export
validate_processor_inputs <- function(
  domain_name,
  data_file,
  age_group,
  test_lookup_file = NULL
) {
  validation <- list(valid = TRUE, errors = character())

  # Check domain name
  if (is.null(domain_name) || nchar(domain_name) == 0) {
    validation$valid <- FALSE
    validation$errors <- c(validation$errors, "Domain name is required")
  }

  # Check data file
  if (is.null(data_file)) {
    validation$valid <- FALSE
    validation$errors <- c(validation$errors, "Data file is required")
  } else if (!file.exists(data_file)) {
    validation$valid <- FALSE
    validation$errors <- c(
      validation$errors,
      paste("Data file not found:", data_file)
    )
  }

  # Check age group
  valid_age_groups <- c("adult", "child")
  if (!age_group %in% valid_age_groups) {
    validation$valid <- FALSE
    validation$errors <- c(
      validation$errors,
      paste(
        "Invalid age group. Must be one of:",
        paste(valid_age_groups, collapse = ", ")
      )
    )
  }

  # Check test lookup file if provided
  if (!is.null(test_lookup_file) && !file.exists(test_lookup_file)) {
    validation$valid <- FALSE
    validation$errors <- c(
      validation$errors,
      paste("Test lookup file not found:", test_lookup_file)
    )
  }

  return(validation)
}

# ---- Helper Functions ----

#' Clean a domain name to create a valid phenotype identifier
#' @noRd
clean_phenotype_name <- function(domain_name) {
  pheno <- tolower(gsub("[^A-Za-z0-9]", "_", domain_name))
  pheno <- gsub("_+", "_", pheno) # Remove multiple underscores
  pheno <- gsub("^_|_$", "", pheno) # Remove leading/trailing underscores
  return(pheno)
}

#' Get domain key from domain name
#' @noRd
get_domain_key <- function(domain_name) {
  # Map common domain names to keys
  domain_map <- list(
    "General Cognitive Ability" = "iq",
    "Academic Skills" = "academics",
    "Verbal/Language" = "verbal",
    "Visual Perception/Construction" = "spatial",
    "Memory" = "memory",
    "Attention/Executive" = "executive",
    "Motor" = "motor",
    "Social Cognition" = "social",
    "ADHD" = "adhd",
    "Emotional/Behavioral/Personality" = "emotion",
    "Behavioral/Emotional/Social" = "emotion",
    "Adaptive Functioning" = "adaptive",
    "Daily Living" = "daily_living",
    "Performance Validity" = "validity",
    "Symptom Validity" = "validity"
  )

  # Try exact match first
  if (domain_name %in% names(domain_map)) {
    return(domain_map[[domain_name]])
  }

  # Try case-insensitive match
  for (name in names(domain_map)) {
    if (tolower(name) == tolower(domain_name)) {
      return(domain_map[[name]])
    }
  }

  # Return cleaned version as fallback
  return(clean_phenotype_name(domain_name))
}

#' Load test lookup file
#' @noRd
load_test_lookup <- function(file_path) {
  if (!file.exists(file_path)) {
    return(NULL)
  }

  tryCatch(
    readr::read_csv(file_path, show_col_types = FALSE),
    error = function(e) {
      warning(paste("Failed to load test lookup:", e$message))
      NULL
    }
  )
}

#' Summarize test lookup file
#' @noRd
summarize_test_lookup <- function(test_lookup_file) {
  lookup <- load_test_lookup(test_lookup_file)

  if (is.null(lookup)) {
    return(data.frame())
  }

  # Ensure required columns exist
  required_cols <- c("domain", "rater", "age_group", "test")
  if (!all(required_cols %in% names(lookup))) {
    missing <- setdiff(required_cols, names(lookup))
    warning(paste(
      "Test lookup missing columns:",
      paste(missing, collapse = ", ")
    ))
    return(data.frame())
  }

  # Summarize by domain
  summary <- lookup %>%
    dplyr::group_by(domain) %>%
    dplyr::summarize(
      raters = paste(unique(rater), collapse = ", "),
      age_groups = paste(unique(age_group), collapse = ", "),
      test_count = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::arrange(domain)

  return(summary)
}

#' Get raters from test lookup
#' @noRd
get_raters_from_lookup <- function(test_lookup_file, domain_name, age_group) {
  lookup <- load_test_lookup(test_lookup_file)

  if (is.null(lookup)) {
    return(data.frame())
  }

  # Filter for domain and age group
  available_tests <- lookup %>%
    dplyr::filter(
      domain == domain_name,
      age_group %in% c(!!age_group, "child/adult", "all")
    )

  if (nrow(available_tests) == 0) {
    return(data.frame())
  }

  # Summarize by rater
  rater_summary <- available_tests %>%
    dplyr::group_by(rater) %>%
    dplyr::summarize(
      tests = paste(unique(test), collapse = ", "),
      test_count = dplyr::n(),
      .groups = "drop"
    )

  return(rater_summary)
}