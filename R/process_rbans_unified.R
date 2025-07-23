#' Process RBANS Data with Unified Approach
#'
#' A comprehensive function that processes RBANS Q-interactive exports, combining
#' the best features of both existing approaches. It supports internal lookup tables,
#' manual overrides, summary reporting, and detailed debugging.
#'
#' @param input_file Path to the UTF-16 CSV export from Q-interactive.
#' @param test_prefix Prefix used for Subtest names in the export (default: "RBANS Update Form A ").
#' @param output_file Optional path to write the processed data as CSV.
#' @param summary_file Optional path to write a summary report as CSV.
#' @param manual_percentiles Named list of manual percentile overrides (e.g., list("Line Orientation" = 75)).
#' @param manual_entries Optional tibble of manual entries for missing subtests.
#' @param debug Logical, if TRUE shows detailed extraction information.
#' @return A list containing two data frames: 'data' (processed data) and 'summary' (performance summary).
#' @export
process_rbans_unified <- function(
  input_file,
  test_prefix = "RBANS Update Form A ",
  output_file = NULL,
  summary_file = NULL,
  manual_percentiles = NULL,
  manual_entries = NULL,
  debug = FALSE
) {
  # Check required packages
  required_packages <- c("dplyr", "readr", "tidyr", "stringr", "purrr")
  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(paste0(
        "Package '",
        pkg,
        "' is required but not installed. Please install it."
      ))
    }
  }

  # Import required packages
  `%>%` <- dplyr::`%>%`

  # Print debug info
  if (debug) {
    cat("=== RBANS Unified Processor ===\n")
    cat("Processing file:", input_file, "\n")
    cat("Test prefix:", test_prefix, "\n")
    cat("Using internal lookup table: lookup_neuropsych_scales\n")
  }

  # Load the internal lookup table
  # This is already loaded in the R/sysdata.rda file

  # 1) Read the Q-interactive export
  tryCatch(
    {
      if (debug) {
        cat("Reading CSV file with UTF-16LE encoding...\n")
      }
      df <- readr::read_csv(
        input_file,
        col_names = FALSE,
        col_types = readr::cols(.default = "c"),
        show_col_types = FALSE,
        locale = readr::locale(encoding = "UTF-16LE"),
        skip_empty_rows = TRUE,
        trim_ws = TRUE,
        na = c("", "NA", "N/A", "-")
      )
    },
    error = function(e) {
      # If read_csv fails with UTF-16LE, try with default encoding
      df <- readr::read_csv(
        input_file,
        col_names = FALSE,
        col_types = readr::cols(.default = "c"),
        show_col_types = FALSE,
        skip_empty_rows = TRUE,
        trim_ws = TRUE,
        na = c("", "NA", "N/A", "-")
      )
    }
  )

  # 2) Generic helper to pluck any section
  pluck_section <- function(df, start_pattern, end_pattern, col_names) {
    start_row <- which(stringr::str_detect(
      df$X1,
      stringr::regex(start_pattern, ignore_case = TRUE)
    ))
    start <- if (length(start_row)) start_row[1] + 1 else 1
    if (!is.null(end_pattern)) {
      end_row <- which(stringr::str_detect(
        df$X1,
        stringr::regex(end_pattern, ignore_case = TRUE)
      ))
      stop <- if (length(end_row)) end_row[1] - 1 else nrow(df)
    } else {
      stop <- nrow(df)
    }

    # Create a filtered data frame with the rows we want
    filtered_df <- df %>%
      dplyr::slice(start:stop) %>%
      dplyr::filter(stringr::str_detect(X1, fixed(test_prefix)))

    # Create a temporary column for separation
    filtered_df <- filtered_df %>%
      dplyr::mutate(tmp = X1) %>%
      tidyr::separate(
        .data$tmp,
        into = col_names,
        sep = ",",
        fill = "right"
      ) %>%
      dplyr::select(dplyr::all_of(col_names)) %>%
      # Clean up whitespace in columns
      dplyr::mutate(across(everything(), ~ stringr::str_trim(.)))

    return(filtered_df)
  }

  # 3) Extract raw scores, scaled scores, completion times, and composites
  if (debug) {
    cat("Extracting data sections...\n")
  }

  # Extract raw scores
  if (debug) {
    cat("Extracting raw scores...\n")
  }

  # Find the start and end of the raw scores section
  raw_scores_section <- which(df$X1 == "RAW SCORES")
  scaled_scores_section <- which(df$X1 == "SCALED SCORES")

  if (length(raw_scores_section) > 0 && length(scaled_scores_section) > 0) {
    # Get the raw scores section
    start_line <- raw_scores_section[1] + 1
    stop_line <- scaled_scores_section[1] - 1

    # Extract the raw scores section
    raw_scores_df <- df %>%
      dplyr::slice(start_line:stop_line) %>%
      dplyr::rename(Subtest = X1, dummy = X2, raw_score = X3) %>%
      dplyr::select(Subtest, raw_score)

    # Filter for RBANS entries
    raw_scores <- raw_scores_df %>%
      dplyr::filter(stringr::str_starts(Subtest, fixed(test_prefix))) %>%
      dplyr::rename(scale = Subtest) %>%
      dplyr::mutate(
        scale = stringr::str_remove(scale, fixed(test_prefix)),
        scale = stringr::str_trim(scale),
        raw_score = as.character(raw_score)
      )
  } else {
    raw_scores <- tibble::tibble(scale = character(), raw_score = character())
  }

  if (debug) {
    cat("Extracted", nrow(raw_scores), "raw scores\n")
  }

  # Extract scaled scores
  if (debug) {
    cat("Extracting scaled scores...\n")
  }

  # Find the start and end of the scaled scores section
  contextual_events_section <- which(df$X1 == "CONTEXTUAL EVENTS")

  if (
    length(scaled_scores_section) > 0 && length(contextual_events_section) > 0
  ) {
    # Get the scaled scores section
    start_line <- scaled_scores_section[1] + 1
    stop_line <- contextual_events_section[1] - 1

    # Extract the scaled scores section
    scaled_scores_df <- df %>%
      dplyr::slice(start_line:stop_line) %>%
      dplyr::rename(Subtest = X1, dummy = X2, score = X3) %>%
      dplyr::select(Subtest, score)

    # Filter for RBANS entries
    scaled_scores <- scaled_scores_df %>%
      dplyr::filter(stringr::str_starts(Subtest, fixed(test_prefix))) %>%
      dplyr::rename(scale = Subtest) %>%
      dplyr::mutate(
        scale = stringr::str_remove(scale, fixed(test_prefix)),
        scale = stringr::str_trim(scale),
        score = as.character(score)
      )
  } else {
    scaled_scores <- tibble::tibble(scale = character(), score = character())
  }

  if (debug) {
    cat("Extracted", nrow(scaled_scores), "scaled scores\n")
  }

  # Extract completion times
  if (debug) {
    cat("Extracting completion times...\n")
  }

  # Find the start and end of the completion times section
  subtest_completion_times_section <- which(df$X1 == "SUBTEST COMPLETION TIMES")
  rules_triggered_section <- which(df$X1 == "RULES TRIGGERED")

  if (
    length(subtest_completion_times_section) > 0 &&
      length(rules_triggered_section) > 0
  ) {
    # Get the completion times section
    start_line <- subtest_completion_times_section[1] + 1
    stop_line <- rules_triggered_section[1] - 1

    # Extract the completion times section
    times_df <- df %>%
      dplyr::slice(start_line:stop_line) %>%
      dplyr::rename(Subtest = X1, dummy = X2, completion_time = X3) %>%
      dplyr::select(Subtest, completion_time)

    # Filter for RBANS entries
    times <- times_df %>%
      dplyr::filter(stringr::str_starts(Subtest, fixed(test_prefix))) %>%
      dplyr::rename(scale = Subtest) %>%
      dplyr::mutate(
        scale = stringr::str_remove(scale, fixed(test_prefix)),
        scale = stringr::str_trim(scale),
        completion_time = as.character(completion_time)
      )
  } else {
    times <- tibble::tibble(scale = character(), completion_time = character())
  }

  if (debug) {
    cat("Extracted", nrow(times), "completion times\n")
  }

  # Extract composite scores
  if (debug) {
    cat("Extracting composite scores...\n")
  }

  # Find the start of the composite scores section
  composite_score_section <- which(df$X1 == "Composite Score")

  if (length(composite_score_section) > 0) {
    # Get the header row and find the rows after it
    start_line <- composite_score_section[1]

    if (debug) {
      cat("Composite score section found at row:", start_line, "\n")
    }

    # Extract the composite scores section - skip the header row (start_line + 2)
    composites_df <- df %>%
      dplyr::slice((start_line + 2):nrow(df)) %>%
      dplyr::filter(stringr::str_starts(X1, fixed(test_prefix)))

    if (debug) {
      cat("Found", nrow(composites_df), "composite score rows\n")
      if (nrow(composites_df) > 0) {
        cat("First few composite score rows:\n")
        print(head(composites_df))
      }
    }

    if (nrow(composites_df) > 0) {
      # Extract the composite scores correctly based on the file format
      # The X3 column contains comma-separated values: percentile,ci_90_lo,ci_90_up,ci_95_lower,ci_95_upper
      composites <- composites_df %>%
        dplyr::rename(scale = X1, score = X2) %>%
        tidyr::separate(
          X3,
          sep = ",",
          into = c(
            "percentile",
            "ci_90_lo",
            "ci_90_up",
            "ci_95_lower",
            "ci_95_upper"
          ),
          fill = "right"
        ) %>%
        dplyr::select(scale, score, percentile, ci_95_lower, ci_95_upper) %>%
        dplyr::mutate(
          scale = stringr::str_remove(scale, fixed(test_prefix)),
          scale = stringr::str_trim(scale),
          score = as.character(score),
          percentile = as.character(percentile),
          ci_95_lower = as.character(ci_95_lower),
          ci_95_upper = as.character(ci_95_upper)
        )
    } else {
      composites <- tibble::tibble(
        scale = character(),
        score = character(),
        percentile = character(),
        ci_95_lower = character(),
        ci_95_upper = character()
      )
    }
  } else {
    # Fallback to searching for Index or Total Scale in the entire file
    composites_df <- df %>%
      dplyr::filter(
        stringr::str_starts(X1, fixed(test_prefix)) &
          stringr::str_detect(X1, "Index|Total Scale")
      )

    if (debug) {
      cat("Fallback: Found", nrow(composites_df), "composite score rows\n")
      if (nrow(composites_df) > 0) {
        cat("Fallback: First few composite score rows:\n")
        print(head(composites_df))
      }
    }

    if (nrow(composites_df) > 0) {
      # Extract the composite scores using the same approach
      # The X3 column contains comma-separated values: percentile,ci_90_lo,ci_90_up,ci_95_lower,ci_95_upper
      composites <- composites_df %>%
        dplyr::rename(scale = X1, score = X2) %>%
        tidyr::separate(
          X3,
          sep = ",",
          into = c(
            "percentile",
            "ci_90_lo",
            "ci_90_up",
            "ci_95_lower",
            "ci_95_upper"
          ),
          fill = "right"
        ) %>%
        dplyr::select(scale, score, percentile, ci_95_lower, ci_95_upper) %>%
        dplyr::mutate(
          scale = stringr::str_remove(scale, fixed(test_prefix)),
          scale = stringr::str_trim(scale),
          score = as.character(score),
          percentile = as.character(percentile),
          ci_95_lower = as.character(ci_95_lower),
          ci_95_upper = as.character(ci_95_upper)
        )
    } else {
      composites <- tibble::tibble(
        scale = character(),
        score = character(),
        percentile = character(),
        ci_95_lower = character(),
        ci_95_upper = character()
      )
    }
  }

  if (debug) {
    cat("Extracted", nrow(composites), "composite scores\n")
  }

  # 4) Combine extracted data and any manual entries
  # First combine raw_scores, scaled_scores, and times
  combined <- raw_scores %>%
    dplyr::full_join(scaled_scores, by = "scale") %>%
    dplyr::full_join(times, by = "scale")

  if (debug) {
    cat("\n=== BEFORE JOINING COMPOSITES ===\n")
    cat("Combined data has", nrow(combined), "rows\n")
    cat("Composites data has", nrow(composites), "rows\n")

    if (nrow(composites) > 0) {
      cat("Composite scales:\n")
      print(composites$scale)

      cat("\nComposite scores:\n")
      print(composites$score)

      cat("\nComposite percentiles:\n")
      print(composites$percentile)
    }
  }

  # Then join with composites, coalescing the score columns
  # Make sure we're joining on the correct scale names
  combined <- combined %>%
    dplyr::full_join(composites, by = "scale") %>%
    dplyr::mutate(score = dplyr::coalesce(score.x, score.y)) %>%
    dplyr::select(-dplyr::any_of(c("score.x", "score.y")))

  if (debug) {
    cat("\n=== AFTER JOINING COMPOSITES ===\n")
    cat("Combined data has", nrow(combined), "rows\n")

    # Check if composite scores are in the combined data
    composite_rows <- combined %>%
      dplyr::filter(stringr::str_detect(scale, "Index|Total Scale"))

    cat("Found", nrow(composite_rows), "composite rows in combined data\n")

    if (nrow(composite_rows) > 0) {
      cat("Composite scales in combined data:\n")
      print(composite_rows$scale)

      cat("\nComposite scores in combined data:\n")
      print(composite_rows$score)

      cat("\nComposite percentiles in combined data:\n")
      print(composite_rows$percentile)
    }
  }

  # Add manual entries if provided
  if (!is.null(manual_entries)) {
    combined <- combined %>%
      dplyr::bind_rows(manual_entries) %>%
      dplyr::distinct(scale, .keep_all = TRUE)
  }

  # 5) Clean up scale names to match metadata
  combined <- combined %>%
    dplyr::mutate(
      original_scale_name = scale,
      scale = stringr::str_remove(scale, fixed(test_prefix)),
      scale = stringr::str_trim(scale),
      # Add absort values based on the mapping
      absort = dplyr::case_when(
        scale == "List Learning" ~ "rbans_01",
        scale == "Story Memory" ~ "rbans_02",
        scale == "Figure Copy" ~ "rbans_03",
        scale == "Line Orientation" ~ "rbans_04",
        scale == "Picture Naming" ~ "rbans_05",
        scale == "Semantic Fluency" ~ "rbans_06",
        scale == "Digit Span" ~ "rbans_07",
        scale == "Coding" ~ "rbans_08",
        scale == "List Recall" ~ "rbans_09",
        scale == "List Recognition" ~ "rbans_10",
        scale == "Story Recall" ~ "rbans_11",
        scale == "Figure Recall" ~ "rbans_12",
        scale == "Immediate Memory Index (IMI)" ~ "rbans_13",
        scale == "Visuospatial/ Constructional Index (VCI)" ~ "rbans_14",
        scale == "Language Index (LGI)" ~ "rbans_15",
        scale == "Attention Index (ATI)" ~ "rbans_16",
        scale == "Delayed Memory Index (DMI)" ~ "rbans_17",
        scale == "Total Scale (TOT)" ~ "rbans_18",
        TRUE ~ NA_character_
      )
    )

  # 6) Recompute missing percentiles from scaled_score (z = (x - 10) / 3)
  combined <- combined %>%
    dplyr::mutate(
      z = (as.numeric(score) - 10) / 3,
      percentile = dplyr::coalesce(
        as.numeric(percentile),
        round(pnorm(z) * 100)
      )
    ) %>%
    dplyr::select(-z)

  # 7) Apply manual percentile overrides
  if (!is.null(manual_percentiles)) {
    for (scale_name in names(manual_percentiles)) {
      combined <- combined %>%
        dplyr::mutate(
          percentile = dplyr::if_else(
            scale == scale_name,
            as.numeric(manual_percentiles[[scale_name]]),
            percentile
          )
        )
    }
  }

  # 8) Get metadata from internal lookup table
  if (debug) {
    cat("Using internal lookup table: lookup_neuropsych_scales\n")
  }

  # Load the internal lookup table from sysdata.rda
  # This is a workaround to access the internal data
  sysdata_path <- system.file("R", "sysdata.rda", package = "neuro2")
  if (file.exists(sysdata_path)) {
    # If the package is installed, load from the package
    load(sysdata_path)
  } else {
    # If working in development mode, load from the local path
    load("R/sysdata.rda")
  }

  # Filter the lookup table for RBANS entries and rename scales according to the provided mapping
  metadata <- lookup_neuropsych_scales %>%
    dplyr::filter(test == "rbans") %>%
    # Rename scales to match the expected names in the input file
    dplyr::mutate(
      scale = dplyr::case_when(
        scale == "RBANS Total" ~ "Total Scale (TOT)",
        scale == "Attention Index" ~ "Attention Index (ATI)",
        scale == "Immediate Memory Index" ~ "Immediate Memory Index (IMI)",
        scale == "Language Index" ~ "Language Index (LGI)",
        scale == "Visuospatial Index" ~
          "Visuospatial/ Constructional Index (VCI)",
        scale == "Delayed Memory Index" ~ "Delayed Memory Index (DMI)",
        scale == "Digit Span" ~ "Digit Span",
        scale == "Coding" ~ "Coding",
        scale == "List Learning" ~ "List Learning",
        scale == "Story Memory" ~ "Story Memory",
        scale == "Picture Naming" ~ "Picture Naming",
        scale == "Semantic Fluency" ~ "Semantic Fluency",
        scale == "Figure Copy" ~ "Figure Copy",
        scale == "Line Orientation" ~ "Line Orientation",
        scale == "List Recall" ~ "List Recall",
        scale == "List Recognition" ~ "List Recognition",
        scale == "Story Recall" ~ "Story Recall",
        scale == "Figure Recall" ~ "Figure Recall",
        TRUE ~ scale
      )
    )

  # 9) Ensure metadata has unique scale values
  metadata <- metadata %>%
    dplyr::group_by(scale) %>%
    dplyr::slice(1) %>%
    dplyr::ungroup()

  combined <- combined %>%
    dplyr::left_join(metadata, by = "scale") %>%
    # Ensure we have unique rows after joining
    dplyr::distinct(scale, .keep_all = TRUE) %>%
    # Fix absort column duplication
    dplyr::mutate(absort = dplyr::coalesce(absort.x, absort.y)) %>%
    dplyr::select(-dplyr::any_of(c("absort.x", "absort.y")))

  # 10) Add test metadata columns and fix test_type and score_type for composite scores
  combined <- combined %>%
    dplyr::mutate(
      test = "rbans",
      test_name = "RBANS Update Form A",
      # Set test_type and score_type for composite scores
      test_type = dplyr::case_when(
        stringr::str_detect(scale, "Index|Total Scale") ~ "composite",
        TRUE ~ test_type
      ),
      score_type = dplyr::case_when(
        stringr::str_detect(scale, "Index|Total Scale") ~ "standard_score",
        TRUE ~ score_type
      )
    )

  # 11) Create a summary with performance levels
  summary_data <- combined %>%
    dplyr::mutate(
      performance_level = dplyr::case_when(
        # For standard scores (indices)
        score_type == "standard_score" & as.numeric(score) >= 130 ~
          "Exceptionally High",
        score_type == "standard_score" & as.numeric(score) >= 120 ~
          "Above Average",
        score_type == "standard_score" & as.numeric(score) >= 110 ~
          "High Average",
        score_type == "standard_score" & as.numeric(score) >= 90 ~ "Average",
        score_type == "standard_score" & as.numeric(score) >= 80 ~
          "Low Average",
        score_type == "standard_score" & as.numeric(score) >= 70 ~
          "Below Average",
        score_type == "standard_score" & as.numeric(score) < 70 ~
          "Exceptionally Low",

        # For scaled scores (subtests)
        score_type == "scaled_score" & as.numeric(score) >= 16 ~
          "Exceptionally High",
        score_type == "scaled_score" & as.numeric(score) >= 14 ~
          "Above Average",
        score_type == "scaled_score" & as.numeric(score) >= 12 ~ "High Average",
        score_type == "scaled_score" & as.numeric(score) >= 9 ~ "Average",
        score_type == "scaled_score" & as.numeric(score) >= 7 ~ "Low Average",
        score_type == "scaled_score" & as.numeric(score) >= 4 ~ "Below Average",
        score_type == "scaled_score" & as.numeric(score) < 4 ~
          "Exceptionally Low",

        # For percentiles
        score_type == "percentile" & as.numeric(percentile) >= 98 ~
          "Exceptionally High",
        score_type == "percentile" & as.numeric(percentile) >= 91 ~
          "Above Average",
        score_type == "percentile" & as.numeric(percentile) >= 75 ~
          "High Average",
        score_type == "percentile" & as.numeric(percentile) >= 25 ~ "Average",
        score_type == "percentile" & as.numeric(percentile) >= 9 ~
          "Low Average",
        score_type == "percentile" & as.numeric(percentile) >= 2 ~
          "Below Average",
        score_type == "percentile" & as.numeric(percentile) < 2 ~
          "Exceptionally Low",

        TRUE ~ "Not Available"
      )
    ) %>%
    dplyr::select(
      scale,
      test_name,
      domain,
      subdomain,
      test_type,
      score_type,
      raw_score,
      score,
      percentile,
      performance_level,
      description
    )

  # 12) Optionally write output files
  if (!is.null(output_file)) {
    if (debug) {
      cat("Writing processed data to:", output_file, "\n")
    }
    readr::write_csv(combined, output_file)
  }

  if (!is.null(summary_file)) {
    if (debug) {
      cat("Writing summary report to:", summary_file, "\n")
    }
    readr::write_csv(summary_data, summary_file)
  }

  # 13) Print summary if debug is TRUE
  if (debug) {
    cat("\n=== EXTRACTION SUMMARY ===\n")
    cat(
      "Subtests extracted:",
      sum(!is.na(combined$raw_score[combined$test_type == "subtest"])),
      "of",
      sum(combined$test_type == "subtest", na.rm = TRUE),
      "\n"
    )
    cat(
      "Composites extracted:",
      sum(!is.na(combined$score[combined$test_type == "composite"])),
      "of",
      sum(combined$test_type == "composite", na.rm = TRUE),
      "\n"
    )
    if (!is.null(output_file)) {
      cat("Output file:", output_file, "\n")
    }
    if (!is.null(summary_file)) {
      cat("Summary file:", summary_file, "\n")
    }
    cat("Rows in final dataset:", nrow(combined), "\n")
  }

  # Return both the processed data and summary
  return(list(data = combined, summary = summary_data))
}

#' Create a standalone summary report from RBANS processed data
#'
#' @param rbans_data Data frame from process_rbans_unified()$data
#' @param output_file Path for the summary report CSV
#' @return A data frame containing the summary report
#' @export
create_rbans_summary <- function(rbans_data, output_file = NULL) {
  # Ensure we have unique rows by scale before creating summary
  rbans_data <- rbans_data %>% dplyr::distinct(scale, .keep_all = TRUE)

  # Create summary with performance levels
  summary_report <- rbans_data %>%
    dplyr::mutate(
      performance_level = dplyr::case_when(
        # For standard scores (indices)
        score_type == "standard_score" & as.numeric(score) >= 130 ~
          "Exceptionally High",
        score_type == "standard_score" & as.numeric(score) >= 120 ~
          "Above Average",
        score_type == "standard_score" & as.numeric(score) >= 110 ~
          "High Average",
        score_type == "standard_score" & as.numeric(score) >= 90 ~ "Average",
        score_type == "standard_score" & as.numeric(score) >= 80 ~
          "Low Average",
        score_type == "standard_score" & as.numeric(score) >= 70 ~
          "Below Average",
        score_type == "standard_score" & as.numeric(score) < 70 ~
          "Exceptionally Low",

        # For scaled scores (subtests)
        score_type == "scaled_score" & as.numeric(score) >= 16 ~
          "Exceptionally High",
        score_type == "scaled_score" & as.numeric(score) >= 14 ~
          "Above Average",
        score_type == "scaled_score" & as.numeric(score) >= 12 ~ "High Average",
        score_type == "scaled_score" & as.numeric(score) >= 9 ~ "Average",
        score_type == "scaled_score" & as.numeric(score) >= 7 ~ "Low Average",
        score_type == "scaled_score" & as.numeric(score) >= 4 ~ "Below Average",
        score_type == "scaled_score" & as.numeric(score) < 4 ~
          "Exceptionally Low",

        # For percentiles
        score_type == "percentile" & as.numeric(percentile) >= 98 ~
          "Exceptionally High",
        score_type == "percentile" & as.numeric(percentile) >= 91 ~
          "Above Average",
        score_type == "percentile" & as.numeric(percentile) >= 75 ~
          "High Average",
        score_type == "percentile" & as.numeric(percentile) >= 25 ~ "Average",
        score_type == "percentile" & as.numeric(percentile) >= 9 ~
          "Low Average",
        score_type == "percentile" & as.numeric(percentile) >= 2 ~
          "Below Average",
        score_type == "percentile" & as.numeric(percentile) < 2 ~
          "Exceptionally Low",

        TRUE ~ "Not Available"
      )
    ) %>%
    dplyr::select(
      scale,
      test_name,
      domain,
      subdomain,
      test_type,
      score_type,
      raw_score,
      score,
      percentile,
      performance_level,
      description
    )

  if (!is.null(output_file)) {
    readr::write_csv(summary_report, output_file, na = "")
    cat("Summary report written to:", output_file, "\n")
  }

  return(summary_report)
}

#' Example usage of the unified RBANS processing function
#'
#' @examples
#' \dontrun{
#' # Basic usage with built-in metadata
#'   input_file = "patient_rbans.csv",
#'   patient_id = "Patient001",
#'   output_file = "rbans_processed.csv",
#'   summary_file = "rbans_summary.csv",
#'   debug = TRUE
#' )
#'
#' # Using custom lookup file and manual percentile overrides
#' results <- process_rbans_unified(
#'   input_file = "patient_rbans.csv",
#'   patient_id = "Patient001",
#'   lookup_file = "custom_rbans_lookup.csv",
#'   manual_percentiles = list(
#'     "Line Orientation" = 75,
#'     "Picture Naming" = 80,
#'     "List Recall" = 65,
#'     "List Recognition" = 70
#'   )
#' )
#'
#' # Access the processed data and summary
#' processed_data <- results$data
#' summary_data <- results$summary
#' }
