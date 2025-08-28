# R/domain_processing_utils2.R
# Utility functions for domain processing in QMD files

#' Process domain data for a specific phenotype
#'
#' This function handles the complete processing pipeline for a domain,
#' including data loading, filtering, and generating tables/figures
#'
#' @param pheno The phenotype identifier (e.g., "emotion", "adhd")
#' @param domains Character vector of domain names to process
#' @param rater Optional rater specification for multi-rater domains
#' @return Invisibly returns the processed data
#' @export
process_domain_data2 <- function(pheno, domains, rater = NULL) {
  # Removed source() calls - all classes are available from the neuro2 package

  # Determine input file based on phenotype
  input_file <- switch(
    tolower(pheno),
    "emotion" = "data/neurobehav.parquet",
    "adhd" = "data/neurobehav.parquet",
    "iq" = "data/neurocog.parquet",
    "academics" = "data/neurocog.parquet",
    "data/neurocog.parquet" # default
  )

  # Try different file formats if parquet doesn't exist
  if (!file.exists(input_file)) {
    # Try CSV
    csv_file <- gsub("\\.parquet$", ".csv", input_file)
    if (file.exists(csv_file)) {
      input_file <- csv_file
    }
  }

  # Create processor
  processor <- DomainProcessorR6$new(
    domains = domains,
    pheno = pheno,
    input_file = input_file
  )

  # Load and process data
  processor$load_data()
  processor$filter_by_domain()
  processor$select_columns()

  # Get the processed data
  data <- processor$data

  # Filter by rater if specified
  if (!is.null(rater) && "rater" %in% names(data)) {
    data <- data[data$rater == rater, ]
  }

  # Create global variable for the phenotype (needed by other code)
  assign(pheno, data, envir = .GlobalEnv)

  # Also create data_<pheno> variable
  assign(paste0("data_", pheno), data, envir = .GlobalEnv)

  # Generate tables and figures based on available raters
  if (tolower(pheno) == "emotion" && is.null(rater)) {
    # For emotion domain, process each rater separately
    .generate_emotion_rater_outputs(data, processor)
  } else if (tolower(pheno) == "adhd" && is.null(rater)) {
    # For ADHD domain, process each rater separately
    .generate_adhd_rater_outputs(data, processor)
  } else {
    # For single-rater or specified rater
    .generate_standard_outputs(data, pheno, rater)
  }

  invisible(data)
}

#' Generate outputs for emotion domain with multiple raters
.generate_emotion_rater_outputs <- function(data, processor) {
  # Determine if child or adult
  emotion_type <- processor$detect_emotion_type()

  # Get available raters in the data
  available_raters <- if ("rater" %in% names(data)) {
    unique(data$rater)
  } else {
    "self" # default if no rater column
  }

  # Process each rater
  for (rater in available_raters) {
    # Filter data for this rater
    rater_data <- if ("rater" %in% names(data)) {
      data[data$rater == rater, ]
    } else {
      data
    }

    # Skip if no data for this rater
    if (nrow(rater_data) == 0) {
      next
    }

    # Create rater-specific variables
    var_name <- paste0("data_emotion_", emotion_type, "_", rater)
    assign(var_name, rater_data, envir = .GlobalEnv)

    # Generate table
    table_name <- paste0("table_emotion_", emotion_type, "_", rater)
    .generate_table(rater_data, "emotion", table_name)

    # Generate figure
    fig_name <- paste0("fig_emotion_", emotion_type, "_", rater)
    .generate_figure(rater_data, "emotion", fig_name)
  }
}

#' Generate outputs for ADHD domain with multiple raters
.generate_adhd_rater_outputs <- function(data, processor) {
  # Similar structure to emotion but for ADHD
  # Get available raters
  available_raters <- if ("rater" %in% names(data)) {
    unique(data$rater)
  } else {
    "self"
  }

  # Determine age group
  age_type <- if (
    any(grepl("child|adolescent", data$test_name, ignore.case = TRUE))
  ) {
    "child"
  } else {
    "adult"
  }

  # Process each rater
  for (rater in available_raters) {
    # Filter data for this rater
    rater_data <- if ("rater" %in% names(data)) {
      data[data$rater == rater, ]
    } else {
      data
    }

    if (nrow(rater_data) == 0) {
      next
    }

    # Create rater-specific variables
    var_name <- paste0("data_adhd_", age_type, "_", rater)
    assign(var_name, rater_data, envir = .GlobalEnv)

    # Generate outputs
    table_name <- paste0("table_adhd_", age_type, "_", rater)
    .generate_table(rater_data, "adhd", table_name)

    fig_name <- paste0("fig_adhd_", age_type, "_", rater)
    .generate_figure(rater_data, "adhd", fig_name)
  }
}

#' Generate standard outputs for single-rater domains
.generate_standard_outputs <- function(data, pheno, rater = NULL) {
  # Determine table and figure names
  suffix <- if (!is.null(rater)) paste0("_", rater) else ""
  table_name <- paste0("table_", pheno, suffix)
  fig_name <- paste0("fig_", pheno, suffix)

  # Generate table
  .generate_table(data, pheno, table_name)

  # Generate figure
  .generate_figure(data, pheno, fig_name)
}

#' Generate a table using TableGTR6
.generate_table <- function(data, pheno, table_name) {
  # Only generate if we have data
  if (is.null(data) || nrow(data) == 0) {
    warning(paste("No data available for table:", table_name))
    return(NULL)
  }

  tryCatch(
    {
      # Create table using TableGTR6
      table_gt <- TableGTR6$new(
        data = data,
        pheno = pheno,
        table_name = table_name,
        vertical_padding = 0,
        multiline = FALSE
      )

      # Build and save table
      tbl <- table_gt$build_table()
      table_gt$save_table(tbl, dir = here::here())

      message(paste("Generated table:", table_name))
    },
    error = function(e) {
      warning(paste("Failed to generate table", table_name, ":", e$message))
    }
  )
}

#' Generate a figure using DotplotR6
.generate_figure <- function(data, pheno, fig_name) {
  # Only generate if we have required columns
  if (is.null(data) || nrow(data) == 0) {
    warning(paste("No data available for figure:", fig_name))
    return(NULL)
  }

  # Try subdomain plot first
  if (all(c("z_mean_subdomain", "subdomain") %in% names(data))) {
    tryCatch(
      {
        dotplot <- DotplotR6$new(
          data = data,
          x = "z_mean_subdomain",
          y = "subdomain",
          filename = here::here(paste0(fig_name, "_subdomain.svg"))
        )
        dotplot$create_plot()
        message(paste("Generated subdomain figure:", fig_name))
      },
      error = function(e) {
        warning(paste("Failed to generate subdomain figure:", e$message))
      }
    )
  }

  # Try narrow plot
  if (all(c("z_mean_narrow", "narrow") %in% names(data))) {
    tryCatch(
      {
        dotplot <- DotplotR6$new(
          data = data,
          x = "z_mean_narrow",
          y = "narrow",
          filename = here::here(paste0(fig_name, "_narrow.svg"))
        )
        dotplot$create_plot()
        message(paste("Generated narrow figure:", fig_name))
      },
      error = function(e) {
        warning(paste("Failed to generate narrow figure:", e$message))
      }
    )
  }
}

#' Helper function to ensure score_type_utils functions exist
ensure_score_type_utils <- function() {
  if (!exists("get_score_types_from_lookup")) {
    # Create a basic version if it doesn't exist
    get_score_types_from_lookup <<- function(data) {
      # Simple implementation that maps test names to score types
      score_map <- list()
    }
  }
}

# REMOVED: The problematic ensure_score_type_utils function and auto-call
# The get_score_types_from_lookup function should be available from the packageet
#' @param rater Specific rater to process
#' @param output_file Path to output text file
.generate_rater_text <- function(data, rater, output_file) {
  # Filter data for specific rater FIRST
  if ("rater" %in% names(data)) {
    rater_data <- data[tolower(data$rater) == tolower(rater), ]
  } else {
    # If no rater column, assume it's all for the specified rater
    rater_data <- data
  }

  # Check if we have data for this rater
  if (nrow(rater_data) == 0) {
    # Create empty placeholder file
    writeLines(c("<summary>", "", "</summary>"), output_file)
    return(invisible(NULL))
  }

  # Generate text using NeuropsychResultsR6
  results_processor <- NeuropsychResultsR6$new(
    data = rater_data,
    file = output_file
  )

  # Process the results
  results_processor$process()

  message(paste("Generated text for", rater, "->", output_file))
}

#' Regenerate emotion child text files with proper separation
.fix_emotion_child_text_files <- function() {
  # Load the emotion data
  if (file.exists("data/neurobehav.parquet")) {
    data <- arrow::read_parquet("data/neurobehav.parquet")
  } else if (file.exists("data/neurobehav.csv")) {
    data <- readr::read_csv("data/neurobehav.csv", show_col_types = FALSE)
  } else {
    stop("Cannot find neurobehav data file")
  }

  # Filter for emotion domains
  emotion_domains <- c(
    "Behavioral/Emotional/Social",
    "Psychiatric Disorders",
    "Substance Use",
    "Personality Disorders",
    "Psychosocial Problems"
  )

  emotion_data <- data[data$domain %in% emotion_domains, ]

  # Generate text for each rater
  .generate_rater_text(
    emotion_data,
    "self",
    "_02-10_emotion_child_text_self.qmd"
  )

  .generate_rater_text(
    emotion_data,
    "parent",
    "_02-10_emotion_child_text_parent.qmd"
  )

  .generate_rater_text(
    emotion_data,
    "teacher",
    "_02-10_emotion_child_text_teacher.qmd"
  )
}
