#' Process RBANS Q-interactive Export with Embedded Lookup and Manual Overrides
#'
#' Reads a UTF-16 CSV export from Q-interactive and extracts raw scores,
#' scaled scores, completion times, and composite scores. It then merges in
#' detailed metadata from an external RBANS lookup table CSV and allows
#' manual entry of four percentile ranks.
#'
#' @param input_file Path to the UTF-16 CSV export from Q-interactive.
#' @param test_prefix Prefix used for Subtest names in the export (e.g., "RBANS Update Form A ").
#' @param patient_id Identifier for the patient (e.g., "Patient001").
#' @param lookup_file Path to the RBANS lookup table CSV containing metadata columns:
#'   scale, domain, subdomain, narrow, pass, verbal, timed, score_type, description.
#' @param line_orientation_pct_rank Numeric. Manual percentile for "Line Orientation".
#' @param picture_naming_pct_rank Numeric. Manual percentile for "Picture Naming".
#' @param list_recall_pct_rank Numeric. Manual percentile for "List Recall".
#' @param list_recognition_pct_rank Numeric. Manual percentile for "List Recognition".
#' @param manual_entries Optional tibble of manual entries for missing subtests.
#' @param output_file Optional path to write the combined, processed data as CSV.
#' @return A data.frame with one row per RBANS subtest, including scores, times,
#'   composite values, metadata, and manual percentile overrides.
#' @export
process_rbans_data <- function(
  input_file,
  test_prefix,
  patient_id,
  lookup_file,
  line_orientation_pct_rank = NULL,
  picture_naming_pct_rank = NULL,
  list_recall_pct_rank = NULL,
  list_recognition_pct_rank = NULL,
  manual_entries = NULL,
  output_file = NULL
) {
  # Use requireNamespace instead of library
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("Package 'dplyr' is required but not installed. Please install it.")
  }
  if (!requireNamespace("stringr", quietly = TRUE)) {
    stop("Package 'stringr' is required but not installed. Please install it.")
  }
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    stop("Package 'tidyr' is required but not installed. Please install it.")
  }
  if (!requireNamespace("readr", quietly = TRUE)) {
    stop("Package 'readr' is required but not installed. Please install it.")
  }

  # 1) Read the Q-interactive export once
  df <- read_csv(
    input_file,
    col_names = FALSE,
    show_col_types = FALSE,
    locale = locale(encoding = "UTF-16LE")
  )

  # 2) Generic helper to pluck any section
  pluck_section <- function(df, start_pattern, end_pattern, col_names) {
    start_row <- which(str_detect(
      df$X1,
      regex(start_pattern, ignore_case = TRUE)
    ))
    start <- if (length(start_row)) start_row[1] + 1 else 1
    if (!is.null(end_pattern)) {
      end_row <- which(str_detect(
        df$X1,
        regex(end_pattern, ignore_case = TRUE)
      ))
      stop <- if (length(end_row)) end_row[1] - 1 else nrow(df)
    } else {
      stop <- nrow(df)
    }
    # Create a filtered data frame with the rows we want
    filtered_df <- df %>%
      slice(start:stop) %>%
      filter(stringr::str_starts(X1, fixed(test_prefix)))

    # Create a temporary column for separation
    filtered_df <- filtered_df %>%
      mutate(tmp = X1) %>%
      tidyr::separate(.data$tmp, into = col_names, sep = ",", fill = "right") %>%
      select(all_of(col_names))

    return(filtered_df)
  }

  # 3) Extract raw scores, scaled scores, completion times, and composites
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

  # 4) Combine extracted data and any manual entries using base Reduce
  combined <- Reduce(
    function(x, y) dplyr::full_join(x, y, by = "scale"),
    list(raw_scores, scaled_scores, times, composites)
  )
  if (!is.null(manual_entries)) {
    combined <- combined %>%
      bind_rows(manual_entries) %>%
      distinct(scale, .keep_all = TRUE)
  }

  # 5) Recompute missing percentiles from scaled_score (z = (x - 10) / 3)
  combined <- combined %>%
    mutate(
      z = (as.numeric(scaled_score) - 10) / 3,
      percentile = coalesce(as.numeric(percentile), round(pnorm(z) * 100))
    ) %>%
    select(-z)

  # 6) Apply manual percentile overrides for specific scales
  combined <- combined %>%
    mutate(
      percentile = case_when(
        scale == "Line Orientation" & !is.null(line_orientation_pct_rank) ~
          line_orientation_pct_rank,
        scale == "Picture Naming" & !is.null(picture_naming_pct_rank) ~
          picture_naming_pct_rank,
        scale == "List Recall" & !is.null(list_recall_pct_rank) ~
          list_recall_pct_rank,
        scale == "List Recognition" & !is.null(list_recognition_pct_rank) ~
          list_recognition_pct_rank,
        TRUE ~ percentile
      )
    )

  # 7) Merge in metadata from the external lookup table
  lookup <- read_csv(lookup_file, show_col_types = FALSE)
  combined <- combined %>% left_join(lookup, by = "scale")

  # 8) Add patient/test metadata columns
  combined <- combined %>%
    mutate(patient = patient_id, test = test_prefix, test_type = "npsych_test")

  # 9) Optionally write the combined data to CSV
  if (!is.null(output_file)) {
    write_csv(combined, output_file)
  }

  return(combined)
}
