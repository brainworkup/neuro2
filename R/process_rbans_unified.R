#' Process RBANS Data with Unified Approach
#'
#' A comprehensive function that processes RBANS Q-interactive exports, combining
#' the best features of both existing approaches. It supports built-in metadata,
#' manual overrides, summary reporting, and detailed debugging.
#'
#' @param input_file Path to the UTF-16 CSV export from Q-interactive.
#' @param patient_id Identifier for the patient (e.g., "Patient001").
#' @param test_prefix Prefix used for Subtest names in the export (default: "RBANS Update Form A ").
#' @param lookup_file Optional path to a custom RBANS lookup table CSV. If NULL, uses built-in metadata.
#' @param output_file Optional path to write the processed data as CSV.
#' @param summary_file Optional path to write a summary report as CSV.
#' @param manual_percentiles Named list of manual percentile overrides (e.g., list("Line Orientation" = 75)).
#' @param manual_entries Optional tibble of manual entries for missing subtests.
#' @param debug Logical, if TRUE shows detailed extraction information.
#' @return A list containing two data frames: 'data' (processed data) and 'summary' (performance summary).
#' @export
process_rbans_unified <- function(
  input_file,
  patient_id,
  test_prefix = "RBANS Update Form A ",
  lookup_file = NULL,
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
    cat("Patient ID:", patient_id, "\n")
    cat("Test prefix:", test_prefix, "\n")
    if (!is.null(lookup_file)) {
      cat("Using custom lookup file:", lookup_file, "\n")
    } else {
      cat("Using built-in metadata\n")
    }
  }

  # Built-in RBANS metadata
  rbans_metadata <- dplyr::tribble(
    ~scale,
    ~domain,
    ~subdomain,
    ~narrow,
    ~pass,
    ~verbal,
    ~timed,
    ~score_type,
    ~test_type,
    ~description,
    # Composite Scores (Indices)
    "Total Scale",
    "General Cognitive Ability",
    "Neurocognition",
    "General Ability",
    NA,
    NA,
    NA,
    "standard_score",
    "composite",
    "Composite indicator of overall neurocognitive functioning",
    "Attention Index",
    "Attention/Executive",
    "Attention",
    "Attention Index",
    NA,
    NA,
    NA,
    "standard_score",
    "composite",
    "General attentional and executive functioning",
    "Immediate Memory Index",
    "Memory",
    "Learning Efficiency",
    "Immediate Memory",
    NA,
    NA,
    NA,
    "standard_score",
    "composite",
    "Composite verbal learning of a word list and a logical story",
    "Language Index",
    "Verbal/Language",
    "Language",
    "Language Index",
    NA,
    NA,
    NA,
    "standard_score",
    "composite",
    "General language processing",
    "Visuospatial/ Constructional Index",
    "Visual Perception/Construction",
    "Spatial",
    "Visuospatial Index",
    NA,
    NA,
    NA,
    "standard_score",
    "composite",
    "Broadband index of visuospatial processing and construction",
    "Delayed Memory Index",
    "Memory",
    "Delayed Recall",
    "Delayed Memory",
    NA,
    NA,
    NA,
    "standard_score",
    "composite",
    "Long-term recall of verbal and nonverbal material",

    # Subtests
    "Digit Span",
    "Attention/Executive",
    "Attention",
    "Attention Span",
    "Sequential",
    "Verbal",
    "Untimed",
    "scaled_score",
    "subtest",
    "Attention span and auditory attention",
    "Coding",
    "Attention/Executive",
    "Processing Speed",
    "Cognitive Efficiency",
    "Planning",
    "Nonverbal",
    "Timed",
    "scaled_score",
    "subtest",
    "Efficiency of psychomotor speed, visual scanning ability, and visual-motor coordination",
    "List Learning",
    "Memory",
    "Learning Efficiency",
    "Verbal Learning",
    "Sequential",
    "Verbal",
    "Untimed",
    "scaled_score",
    "subtest",
    "Word list learning",
    "Story Memory",
    "Memory",
    "Learning Efficiency",
    "Verbal Learning",
    "Sequential",
    "Verbal",
    "Untimed",
    "scaled_score",
    "subtest",
    "Expository story learning",
    "Picture Naming",
    "Verbal/Language",
    "Word Retrieval",
    "Naming",
    "Sequential",
    "Verbal",
    "Untimed",
    "percentile",
    "subtest",
    "Confrontation naming/expressive vocabulary",
    "Semantic Fluency",
    "Verbal/Language",
    "Fluency",
    "Verbal Fluency",
    "Sequential",
    "Verbal",
    "Timed",
    "scaled_score",
    "subtest",
    "Semantic word fluency/generativity",
    "Figure Copy",
    "Visual Perception/Construction",
    "Organization",
    "Construction",
    "Simultaneous",
    "Nonverbal",
    "Untimed",
    "scaled_score",
    "subtest",
    "The accuracy of copying a figure from a model",
    "Line Orientation",
    "Visual Perception/Construction",
    "Perception",
    "Spatial Perception",
    "Simultaneous",
    "Nonverbal",
    "Untimed",
    "percentile",
    "subtest",
    "Basic perception of visual stimuli",
    "List Recall",
    "Memory",
    "Delayed Recall",
    "Verbal Memory",
    "Sequential",
    "Verbal",
    "Untimed",
    "percentile",
    "subtest",
    "Long-term recall of a word list",
    "List Recognition",
    "Memory",
    "Recognition Memory",
    "Verbal Memory",
    "Sequential",
    "Verbal",
    "Untimed",
    "percentile",
    "subtest",
    "Delayed recognition of a word list",
    "Story Recall",
    "Memory",
    "Delayed Recall",
    "Verbal Memory",
    "Sequential",
    "Verbal",
    "Untimed",
    "scaled_score",
    "subtest",
    "Long-term recall of a detailed story",
    "Figure Recall",
    "Memory",
    "Delayed Recall",
    "Visual Memory",
    "Simultaneous",
    "Nonverbal",
    "Untimed",
    "scaled_score",
    "subtest",
    "Long-term recall and reconstruction of a complex abstract figure"
  )

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

  raw_scores <- pluck_section(
    df,
    "RAW SCORES",
    "SCALED SCORES",
    c("scale", "raw_score")
  )
  scaled_scores <- pluck_section(
    df,
    "SCALED SCORES",
    "SUBTEST COMPLETION TIMES",
    c("scale", "scaled_score")
  )
  times <- pluck_section(
    df,
    "SUBTEST COMPLETION TIMES",
    "RULES TRIGGERED",
    c("scale", "completion_time")
  )
  composites <- pluck_section(
    df,
    "Composite Score",
    NULL,
    c("scale", "composite_score", "percentile", "ci_95_lower", "ci_95_upper")
  )

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

  # 8) Get metadata (either from lookup file or built-in)
  if (!is.null(lookup_file)) {
    if (debug) {
      cat("Using custom lookup file:", lookup_file, "\n")
    }
    metadata <- readr::read_csv(lookup_file, show_col_types = FALSE)
  } else {
    if (debug) {
      cat("Using built-in metadata\n")
    }
    metadata <- rbans_metadata
  }

  # 9) Merge in metadata
  combined <- combined %>% dplyr::left_join(metadata, by = "scale")

  # 10) Add patient/test metadata columns
  combined <- combined %>%
    dplyr::mutate(
      patient = patient_id,
      test = "rbans",
      test_name = "RBANS Update Form A"
    )

  # 11) Create a summary with performance levels
  summary_data <- combined %>%
    dplyr::mutate(
      performance_level = dplyr::case_when(
        # For standard scores (indices)
        score_type == "standard_score" & as.numeric(composite_score) >= 115 ~
          "Superior",
        score_type == "standard_score" & as.numeric(composite_score) >= 108 ~
          "Above Average",
        score_type == "standard_score" & as.numeric(composite_score) >= 92 ~
          "Average",
        score_type == "standard_score" & as.numeric(composite_score) >= 85 ~
          "Low Average",
        score_type == "standard_score" & as.numeric(composite_score) >= 70 ~
          "Borderline",
        score_type == "standard_score" & as.numeric(composite_score) < 70 ~
          "Impaired",

        # For scaled scores (subtests)
        score_type == "scaled_score" & as.numeric(scaled_score) >= 13 ~
          "Above Average",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 8 ~
          "Average",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 5 ~
          "Below Average",
        score_type == "scaled_score" & as.numeric(scaled_score) < 5 ~
          "Impaired",

        # For percentiles
        score_type == "percentile" & as.numeric(percentile) >= 75 ~
          "Above Average",
        score_type == "percentile" & as.numeric(percentile) >= 25 ~ "Average",
        score_type == "percentile" & as.numeric(percentile) >= 9 ~
          "Below Average",
        score_type == "percentile" & as.numeric(percentile) < 9 ~ "Impaired",

        TRUE ~ "Not Available"
      )
    ) %>%
    dplyr::select(
      patient,
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
  # Create summary with performance levels
  summary_report <- rbans_data %>%
    dplyr::mutate(
      performance_level = dplyr::case_when(
        # For standard scores (indices)
        score_type == "standard_score" & as.numeric(composite_score) >= 115 ~
          "Superior",
        score_type == "standard_score" & as.numeric(composite_score) >= 108 ~
          "Above Average",
        score_type == "standard_score" & as.numeric(composite_score) >= 92 ~
          "Average",
        score_type == "standard_score" & as.numeric(composite_score) >= 85 ~
          "Low Average",
        score_type == "standard_score" & as.numeric(composite_score) >= 70 ~
          "Borderline",
        score_type == "standard_score" & as.numeric(composite_score) < 70 ~
          "Impaired",

        # For scaled scores (subtests)
        score_type == "scaled_score" & as.numeric(scaled_score) >= 13 ~
          "Above Average",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 8 ~
          "Average",
        score_type == "scaled_score" & as.numeric(scaled_score) >= 5 ~
          "Below Average",
        score_type == "scaled_score" & as.numeric(scaled_score) < 5 ~
          "Impaired",

        # For percentiles
        score_type == "percentile" & as.numeric(percentile) >= 75 ~
          "Above Average",
        score_type == "percentile" & as.numeric(percentile) >= 25 ~ "Average",
        score_type == "percentile" & as.numeric(percentile) >= 9 ~
          "Below Average",
        score_type == "percentile" & as.numeric(percentile) < 9 ~ "Impaired",

        TRUE ~ "Not Available"
      )
    ) %>%
    dplyr::select(
      dplyr::any_of(c("patient")),
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
