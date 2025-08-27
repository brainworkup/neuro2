# R/domain_processing_utils.R
# Complete utility functions for neuropsychological domain processing

# ============================================================================
# HIGH-LEVEL WORKFLOW FUNCTIONS
# ============================================================================

#' Create a domain processor with smart defaults and validation
#'
#' @param domain_name The domain name
#'  (e.g., "ADHD", "Behavioral/Emotional/Social")
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

# ============================================================================
# CORE DATA PROCESSING FUNCTIONS
# ============================================================================

#' Process domain data (main processing pipeline)
#' Process Domain Data
#' 
#' @param pheno Phenotype identifier for the domain
#' @param domains Domain names to process
#' @return Processed data
#' @export
process_domain_data <- function(pheno, domains) {
  # Load and process data
  processor <- DomainProcessorR6$new(
    domains = domains,
    pheno = pheno,
    input_file = determine_input_file(pheno)
  )

  processor$load_data()
  processor$filter_by_domain()
  processor$select_columns()

  data <- processor$data

  # Generate outputs
  generate_text_results(data, pheno)
  generate_domain_table(data, pheno)
  generate_domain_figures(data, pheno)

  return(data)
}

#' Generate text results for all rater types
generate_text_results <- function(data, pheno) {
  if (pheno %in% c("emotion", "adhd")) {
    # Multi-rater processing
    raters <- get_available_raters(data)
    for (rater in raters) {
      rater_data <- filter_by_rater(data, rater)
      if (nrow(rater_data) > 0) {
        text_file <- get_text_filename(pheno, rater)
        results_processor <- NeuropsychResultsR6$new(
          data = rater_data,
          file = text_file
        )
        results_processor$process()
      }
    }
  } else {
    # Single rater
    text_file <- get_text_filename(pheno)
    results_processor <- NeuropsychResultsR6$new(data = data, file = text_file)
    results_processor$process()
  }
}

# ============================================================================
# DATA MANIPULATION HELPERS
# ============================================================================

#' Get available raters from data
# get_available_raters <- function(data) {
#   if ("rater" %in% names(data)) {
#     return(unique(data$rater[!is.na(data$rater)]))
#   }
#   return("self") # Default fallback
# }

# #' Filter data by specific rater
# filter_by_rater <- function(data, rater) {
#   if ("rater" %in% names(data)) {
#     return(data[data$rater == rater & !is.na(data$rater), ])
#   }
#   return(data) # Return all data if no rater column
# }

#' Determine input file based on phenotype
determine_input_file <- function(pheno) {
  behavioral_phenos <- c("adhd", "emotion", "adaptive")
  if (pheno %in% behavioral_phenos) {
    return("data/neurobehav.parquet")
  }
  return("data/neurocog.parquet")
}

# ============================================================================
# FILE NAMING FUNCTIONS
# ============================================================================

#' Get text filename for domain and rater
# get_text_filename <- function(pheno, rater = NULL) {
#   # Get domain number
#   domain_numbers <- c(
#     iq = "01",
#     academics = "02",
#     verbal = "03",
#     spatial = "04",
#     memory = "05",
#     executive = "06",
#     motor = "07",
#     social = "08",
#     adhd = "09",
#     emotion = "10",
#     adaptive = "11",
#     daily_living = "12"
#   )

#   number <- domain_numbers[pheno] %||% "99"

#   if (is.null(rater)) {
#     return(paste0("_02-", number, "_", pheno, "_text.qmd"))
#   } else {
#     # Handle age-specific emotion domains
#     if (pheno == "emotion") {
#       return(paste0("_02-", number, "_emotion_child_text_", rater, ".qmd"))
#     }
#     return(paste0("_02-", number, "_", pheno, "_text_", rater, ".qmd"))
#   }
# }

# ============================================================================
# TABLE AND FIGURE GENERATION
# ============================================================================

#' Generate domain table
# generate_domain_table <- function(data, pheno) {
#   if (nrow(data) == 0) {
#     return(NULL)
#   }

#   # Get score types and create table
#   score_type_map <- get_score_types_from_lookup(data)

#   # Create table using TableGTR6
#   table_name <- paste0("table_", pheno)
#   table_gt <- TableGTR6$new(
#     data = data,
#     pheno = pheno,
#     table_name = table_name,
#     vertical_padding = 0,
#     multiline = TRUE
#   )

#   tbl <- table_gt$build_table()
#   table_gt$save_table(tbl, dir = here::here())

#   return(tbl)
# }

#' Generate domain figures
# generate_domain_figures <- function(data, pheno) {
#   if (nrow(data) == 0) {
#     return(NULL)
#   }

#   # Generate subdomain plot if possible
#   if ("z_mean_subdomain" %in% names(data) && "subdomain" %in% names(data)) {
#     dotplot_subdomain <- DotplotR6$new(
#       data = data,
#       x = "z_mean_subdomain",
#       y = "subdomain",
#       filename = here::here(paste0("fig_", pheno, "_subdomain.svg"))
#     )
#     dotplot_subdomain$create_plot()
#   }

#   # Generate narrow plot if possible
#   if ("z_mean_narrow" %in% names(data) && "narrow" %in% names(data)) {
#     dotplot_narrow <- DotplotR6$new(
#       data = data,
#       x = "z_mean_narrow",
#       y = "narrow",
#       filename = here::here(paste0("fig_", pheno, "_narrow.svg"))
#     )
#     dotplot_narrow$create_plot()
#   }
# }

# ============================================================================
# MISSING FUNCTIONS - CORE DATA HELPERS
# ============================================================================

#' Get available raters from data
#'
#' @description This function looks at your data and figures out which types of
#' raters (self, parent, teacher, observer) actually have data. It's like taking
#' attendance - who actually showed up with data?
#'
#' @param data A data frame containing neuropsych test results
#' @return Character vector of available rater types
get_available_raters <- function(data) {
  # First, check if the data even has a rater column
  if (!"rater" %in% names(data)) {
    # If no rater column exists, assume it's self-report data
    return("self")
  }

  # Get unique raters, removing any missing values
  available_raters <- unique(data$rater[!is.na(data$rater)])

  # Clean up the rater names (sometimes they have extra spaces or caps)
  available_raters <- tolower(trimws(available_raters))

  # Return only non-empty rater names
  available_raters <- available_raters[nzchar(available_raters)]

  # If somehow we end up with no raters, default to "self"
  if (length(available_raters) == 0) {
    return("self")
  }

  return(available_raters)
}

#' Filter data by specific rater
#'
#' @description This function takes your big dataset and pulls out only the rows
#' that belong to a specific rater (like just the parent ratings, or just the
#' self-report data). It's like sorting a deck of cards by suit.
#'
#' @param data A data frame containing neuropsych test results
#' @param rater The specific rater to filter for ("self", "parent", "teacher", etc.)
#' @return Data frame containing only rows for the specified rater
filter_by_rater <- function(data, rater) {
  # If there's no rater column, just return all the data
  # This happens with single-rater domains like IQ tests
  if (!"rater" %in% names(data)) {
    return(data)
  }

  # Clean up the rater name we're looking for
  rater <- tolower(trimws(rater))

  # Clean up the rater column in the data for matching
  data$rater_clean <- tolower(trimws(data$rater))

  # Filter to only rows matching our target rater
  filtered_data <- data[data$rater_clean == rater & !is.na(data$rater_clean), ]

  # Remove the temporary cleaning column
  filtered_data$rater_clean <- NULL

  # If we got no data, warn the user but don't crash
  if (nrow(filtered_data) == 0) {
    warning(paste("No data found for rater:", rater))
  }

  return(filtered_data)
}

#' Get text filename for domain and rater
#'
#' @description This function creates the correct filename for where the narrative
#' text should be saved. It follows the naming convention like "_02-05_memory_text.qmd"
#' or "_02-09_adhd_child_text_parent.qmd" for multi-rater domains.
#'
#' @param pheno The phenotype/domain identifier (e.g., "memory", "adhd", "emotion")
#' @param rater The rater type (optional, for multi-rater domains)
#' @return Character string with the appropriate filename
get_text_filename <- function(pheno, rater = NULL) {
  # Map each domain to its number - this keeps files in logical order
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

  # Get the number for this domain, or use "99" if it's not found
  number <- domain_numbers[tolower(pheno)]
  if (is.na(number) || is.null(number)) {
    number <- "99"
  }

  # For single-rater domains (like IQ, memory), create simple filename
  if (is.null(rater)) {
    return(paste0("_02-", number, "_", tolower(pheno), "_text.qmd"))
  }

  # For multi-rater domains, we need more complex naming
  # Clean up the rater name
  rater <- tolower(trimws(rater))

  # Special handling for emotion domain (needs age specification)
  if (tolower(pheno) == "emotion") {
    # Emotion domains need to specify child vs adult
    # For now, assume child (this could be made smarter later)
    return(paste0("_02-", number, "_emotion_child_text_", rater, ".qmd"))
  }

  # For other multi-rater domains (like ADHD)
  return(paste0("_02-", number, "_", tolower(pheno), "_text_", rater, ".qmd"))
}

#' Generate domain table
#'
#' @description This function takes your processed data and creates a formatted
#' table using the TableGTR6 class. It handles all the complex formatting,
#' footnotes, and styling automatically.
#'
#' @param data Processed neuropsych data for a specific domain
#' @param pheno The phenotype/domain identifier
#' @return A gt table object (or NULL if no data)
generate_domain_table <- function(data, pheno) {
  # Don't try to make a table if there's no data
  if (is.null(data) || nrow(data) == 0) {
    warning(paste("No data available to create table for:", pheno))
    return(NULL)
  }

  # Create the table name following the standard convention
  table_name <- paste0("table_", tolower(pheno))

  # Try to get score types - this determines what footnotes to use
  score_type_map <- NULL
  if (exists("get_score_types_from_lookup")) {
    tryCatch(
      {
        score_type_map <- get_score_types_from_lookup(data)
      },
      error = function(e) {
        message("Could not get score types, using defaults")
      }
    )
  }

  # Set up footnotes based on score types found in the data
  fn_list <- list()
  grp_list <- list()

  # Check what score types we actually have in the data
  if (!is.null(score_type_map) && length(score_type_map) > 0) {
    # Process the score type mapping if we have it
    for (test_name in names(score_type_map)) {
      types <- score_type_map[[test_name]]
      for (type in types) {
        if (!type %in% names(grp_list)) {
          grp_list[[type]] <- character(0)
        }
        grp_list[[type]] <- unique(c(grp_list[[type]], test_name))
      }
    }

    # Add appropriate footnotes
    if ("t_score" %in% names(grp_list)) {
      fn_list$t_score <- "T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]"
    }
    if ("scaled_score" %in% names(grp_list)) {
      fn_list$scaled_score <- "Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]"
    }
    if ("standard_score" %in% names(grp_list)) {
      fn_list$standard_score <- "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]"
    }
  }

  # Default source note if we don't have specific footnotes
  source_note <- if (length(fn_list) == 0) {
    "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]"
  } else {
    NULL
  }

  # Create the table using TableGTR6 class
  tryCatch(
    {
      table_gt <- TableGTR6$new(
        data = data,
        pheno = tolower(pheno),
        table_name = table_name,
        vertical_padding = 0,
        multiline = TRUE,
        source_note = source_note,
        fn_list = fn_list,
        grp_list = grp_list,
        dynamic_grp = grp_list
      )

      # Build the actual table
      tbl <- table_gt$build_table()

      # Save it as PNG and PDF files
      table_gt$save_table(tbl, dir = here::here())

      message(paste("Successfully created table for:", pheno))
      return(tbl)
    },
    error = function(e) {
      warning(paste("Failed to create table for", pheno, ":", e$message))
      return(NULL)
    }
  )
}

#' Generate domain figures
#'
#' @description This function creates the dot plots showing test performance
#' across subdomains and narrow abilities. It's like creating a visual report
#' card that shows strengths and weaknesses at a glance.
#'
#' @param data Processed neuropsych data for a specific domain
#' @param pheno The phenotype/domain identifier
#' @return List of created plot objects (or empty list if no plots created)
generate_domain_figures <- function(data, pheno) {
  # Don't try to make plots if there's no data
  if (is.null(data) || nrow(data) == 0) {
    warning(paste("No data available to create figures for:", pheno))
    return(list())
  }

  created_plots <- list()
  pheno_clean <- tolower(pheno)

  # Try to create subdomain plot
  # This shows performance across different subdomains (like different types of memory)
  if ("z_mean_subdomain" %in% names(data) && "subdomain" %in% names(data)) {
    tryCatch(
      {
        # Remove any rows where subdomain data is missing
        subdomain_data <- data[
          !is.na(data$subdomain) & !is.na(data$z_mean_subdomain),
        ]

        if (nrow(subdomain_data) > 0) {
          dotplot_subdomain <- DotplotR6$new(
            data = subdomain_data,
            x = "z_mean_subdomain",
            y = "subdomain",
            filename = here::here(paste0("fig_", pheno_clean, "_subdomain.svg"))
          )
          dotplot_subdomain$create_plot()
          created_plots$subdomain <- dotplot_subdomain
          message(paste("Created subdomain plot for:", pheno))
        }
      },
      error = function(e) {
        warning(paste(
          "Failed to create subdomain plot for",
          pheno,
          ":",
          e$message
        ))
      }
    )
  } else {
    message(paste(
      "Subdomain plot not possible for",
      pheno,
      "- missing required columns"
    ))
  }

  # Try to create narrow abilities plot
  # This shows performance on very specific cognitive abilities
  if ("z_mean_narrow" %in% names(data) && "narrow" %in% names(data)) {
    tryCatch(
      {
        # Remove any rows where narrow ability data is missing
        narrow_data <- data[!is.na(data$narrow) & !is.na(data$z_mean_narrow), ]

        if (nrow(narrow_data) > 0) {
          dotplot_narrow <- DotplotR6$new(
            data = narrow_data,
            x = "z_mean_narrow",
            y = "narrow",
            filename = here::here(paste0("fig_", pheno_clean, "_narrow.svg"))
          )
          dotplot_narrow$create_plot()
          created_plots$narrow <- dotplot_narrow
          message(paste("Created narrow abilities plot for:", pheno))
        }
      },
      error = function(e) {
        warning(paste(
          "Failed to create narrow abilities plot for",
          pheno,
          ":",
          e$message
        ))
      }
    )
  } else {
    message(paste(
      "Narrow abilities plot not possible for",
      pheno,
      "- missing required columns"
    ))
  }

  # If we couldn't create any plots, let the user know
  if (length(created_plots) == 0) {
    message(paste(
      "No plots could be created for",
      pheno,
      "- check if z-score columns exist"
    ))
  }

  return(created_plots)
}

# ============================================================================
# VALIDATION AND HELPER FUNCTIONS
# ============================================================================

# [Include all your existing validation and helper functions from domain_processor_utils.R]

# Rest of your existing functions: validate_processor_inputs(), clean_phenotype_name(),
# get_domain_key(), load_test_lookup(), etc.
#' Get domain information from test lookup or registry
#'
#' @param test_lookup_file Path to test lookup file (optional)
#' @param use_factory Whether to use factory registry
#' @return A data frame with domain summary information
#' @export
get_domain_info <- function(test_lookup_file = NULL, use_factory = TRUE) {
  # Try factory registry first if available
  if (use_factory && exists("DomainProcessorFactoryR6")) {
    tryCatch(
      {
        factory <- DomainProcessorFactoryR6$new()
        return(factory$get_registry_info())
      },
      error = function(e) {
        message("Factory registry not available, trying test lookup file")
      }
    )
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
    tryCatch(
      {
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
      },
      error = function(e) {
        message("Factory not available, trying test lookup file")
      }
    )
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
