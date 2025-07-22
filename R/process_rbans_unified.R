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
        show_col_types = FALSE,
        locale = readr::locale(encoding = "UTF-16LE")
      )
    },
    error = function(e) {
      stop(
        "Error reading file: ",
        e$message,
        "\nPlease check that the file exists and has UTF-16LE encoding."
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
      dplyr::filter(stringr::str_starts(X1, fixed(test_prefix)))

    # Create a temporary column for separation
    filtered_df <- filtered_df %>%
      dplyr::mutate(tmp = X1) %>%
      tidyr::separate(
        .data$tmp,
        into = col_names,
        sep = ",",
        fill = "right"
      ) %>%
      dplyr::select(dplyr::all_of(col_names))

    return(filtered_df)
  }

  # 3) Extract raw scores, scaled scores, completion times, and composites
  if (debug) {
    cat("Extracting data sections...\n")
  }

  # Improved extraction to handle the specific format of the input file
  raw_scores <- pluck_section(
    df,
    "RAW SCORES",
    "SCALED SCORES",
    c("scale", "raw_score")
  )

  # Filter to keep only RBANS entries
  raw_scores <- raw_scores %>%
    dplyr::filter(stringr::str_detect(scale, fixed(test_prefix)))

  if (debug) {
    cat("Extracted", nrow(raw_scores), "raw scores\n")
  }

  scaled_scores <- pluck_section(
    df,
    "SCALED SCORES",
    "CONTEXTUAL EVENTS",
    c("scale", "scaled_score")
  )

  # Filter to keep only RBANS entries
  scaled_scores <- scaled_scores %>%
    dplyr::filter(stringr::str_detect(scale, fixed(test_prefix)))

  if (debug) {
    cat("Extracted", nrow(scaled_scores), "scaled scores\n")
  }

  times <- pluck_section(
    df,
    "SUBTEST COMPLETION TIMES",
    "RULES TRIGGERED",
    c("scale", "completion_time")
  )

  # Filter to keep only RBANS entries
  times <- times %>%
    dplyr::filter(stringr::str_detect(scale, fixed(test_prefix)))

  if (debug) {
    cat("Extracted", nrow(times), "completion times\n")
  }

  # Extract composites from the Composite Score section
  composites <- df %>%
    dplyr::filter(stringr::str_detect(X1, "RBANS Update Form A")) %>%
    dplyr::filter(stringr::str_detect(X1, "Index|Total Scale")) %>%
    tidyr::separate(
      X1,
      into = c(
        "scale",
        "composite_score",
        "percentile",
        "ci_95_lower",
        "ci_95_upper",
        "ci_95_low2",
        "ci_95_high2"
      ),
      sep = ",",
      fill = "right"
    ) %>%
    dplyr::select(scale, composite_score, percentile, ci_95_lower, ci_95_upper)

  if (debug) {
    cat("Extracted", nrow(composites), "composite scores\n")
  }

  # 4) Combine extracted data and any manual entries
  combined <- Reduce(
    function(x, y) dplyr::full_join(x, y, by = "scale"),
    list(raw_scores, scaled_scores, times, composites)
  )

  # Add manual entries if provided
  if (!is.null(manual_entries)) {
    combined <- combined %>%
      dplyr::bind_rows(manual_entries) %>%
      dplyr::distinct(scale, .keep_all = TRUE)
  }

  # 5) Clean up scale names to match metadata
  combined <- combined %>%
    dplyr::mutate(
      scale = stringr::str_remove(scale, fixed(test_prefix)),
      scale = stringr::str_trim(scale)
    )

  # 6) Recompute missing percentiles from scaled_score (z = (x - 10) / 3)
  combined <- combined %>%
    dplyr::mutate(
      z = (as.numeric(scaled_score) - 10) / 3,
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
        scale == "RBANS Total" ~ "Total Scale",
        scale == "Attention Index" ~ "Attention Index",
        scale == "Immediate Memory Index" ~ "Immediate Memory Index",
        scale == "Language Index" ~ "Language Index",
        scale == "Visuospatial Index" ~ "Visuospatial/ Constructional Index",
        scale == "Delayed Memory Index" ~ "Delayed Memory Index",
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
    dplyr::distinct(scale, .keep_all = TRUE)

  # 10) Add test metadata columns
  combined <- combined %>%
    dplyr::mutate(test = "rbans", test_name = "RBANS Update Form A")

  # 11) Create a summary with performance levels
  summary_data <- combined %>%
    dplyr::mutate(
      performance_level = dplyr::case_when(
        # For standard scores (indices)
        score_type == "standard_score" & as.numeric(composite_score) >= 130 ~
          "Exceptionally high score",
        score_type == "standard_score" & as.numeric(composite_score) >= 120 ~
          "Above average score",
        score_type == "standard_score" & as.numeric(composite_score) >= 110 ~
          "High average score",
        score_type == "standard_score" & as.numeric(composite_score) >= 90 ~
          "Average score",
        score_type == "standard_score" & as.numeric(composite_score) >= 80 ~
          "Low average score",
        score_type == "standard_score" & as.numeric(composite_score) >= 70 ~
          "Below average score",
        score_type == "standard_score" & as.numeric(composite_score) < 70 ~
          "Exceptionally low score",

        # For scaled scores (subtests)
        score_type == "scaled_score" & as.numeric(scaled_score) >= 16 ~
          "Exceptionally high score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 14 ~
          "Above average score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 12 ~
          "High average score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 9 ~
          "Average score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 7 ~
          "Low average score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 4 ~
          "Below average score",
        score_type == "scaled_score" & as.numeric(scaled_score) < 4 ~
          "Exceptionally low score",

        # For percentiles
        score_type == "percentile" & as.numeric(percentile) >= 98 ~
          "Exceptionally high score",
        score_type == "percentile" & as.numeric(percentile) >= 91 ~
          "Above average score",
        score_type == "percentile" & as.numeric(percentile) >= 75 ~
          "High average score",
        score_type == "percentile" & as.numeric(percentile) >= 25 ~
          "Average score",
        score_type == "percentile" & as.numeric(percentile) >= 9 ~
          "Low average score",
        score_type == "percentile" & as.numeric(percentile) >= 2 ~
          "Below average score",
        score_type == "percentile" & as.numeric(percentile) < 2 ~
          "Exceptionally low score",

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
      scaled_score,
      composite_score,
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
      sum(!is.na(combined$composite_score[combined$test_type == "composite"])),
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
        score_type == "standard_score" & as.numeric(composite_score) >= 130 ~
          "Exceptionally high score",
        score_type == "standard_score" & as.numeric(composite_score) >= 120 ~
          "Above average score",
        score_type == "standard_score" & as.numeric(composite_score) >= 110 ~
          "High average score",
        score_type == "standard_score" & as.numeric(composite_score) >= 90 ~
          "Average score",
        score_type == "standard_score" & as.numeric(composite_score) >= 80 ~
          "Low average score",
        score_type == "standard_score" & as.numeric(composite_score) >= 70 ~
          "Below average score",
        score_type == "standard_score" & as.numeric(composite_score) < 70 ~
          "Exceptionally low score",

        # For scaled scores (subtests)
        score_type == "scaled_score" & as.numeric(scaled_score) >= 16 ~
          "Exceptionally high score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 14 ~
          "Above average score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 12 ~
          "High average score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 9 ~
          "Average score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 7 ~
          "Low average score",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 4 ~
          "Below average score",
        score_type == "scaled_score" & as.numeric(scaled_score) < 4 ~
          "Exceptionally low score",

        # For percentiles
        score_type == "percentile" & as.numeric(percentile) >= 98 ~
          "Exceptionally high score",
        score_type == "percentile" & as.numeric(percentile) >= 91 ~
          "Above average score",
        score_type == "percentile" & as.numeric(percentile) >= 75 ~
          "High average score",
        score_type == "percentile" & as.numeric(percentile) >= 25 ~
          "Average score",
        score_type == "percentile" & as.numeric(percentile) >= 9 ~
          "Low average score",
        score_type == "percentile" & as.numeric(percentile) >= 2 ~
          "Below average score",
        score_type == "percentile" & as.numeric(percentile) < 2 ~
          "Exceptionally low score",

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
      scaled_score,
      composite_score,
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
#' results <- process_rbans_unified(
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
