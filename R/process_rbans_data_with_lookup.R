#' Process RBANS Q-interactive Export with Embedded Lookup
#'
#' Reads a UTF-16 CSV export from Q-interactive and extracts raw scores,
#' scaled scores, completion times, and composite scores. It then merges in
#' detailed metadata from an external RBANS lookup table CSV.
#'
#' @param input_file Path to the UTF-16 CSV export from Q-interactive.
#' @param test_prefix Prefix used for Subtest names in the export (e.g., "RBANS Update Form A ").
#' @param patient_id Identifier for the patient (e.g., "Patient001").
#' @param lookup_file Path to the RBANS lookup table CSV containing metadata columns:
#'   scale, domain, subdomain, narrow, pass, verbal, timed, score_type, description.
#' @param manual_entries Optional tibble of manual entries for missing subtests.
#' @param output_file Optional path to write the combined, processed data as CSV.
#' @return A data.frame with one row per RBANS subtest, including scores, times,
#'   composite values, and metadata joined from the lookup table.
#' @export
process_rbans_data <- function(
  input_file,
  test_prefix,
  patient_id,
  lookup_file,
  manual_entries = NULL,
  output_file = NULL
) {
  # Load required packages
  library(dplyr)
  library(stringr)
  library(tidyr)
  library(readr)

  # 1) Read the Q-interactive export once
  df <- readr::read_csv(
    input_file,
    col_names = FALSE,
    show_col_types = FALSE,
    locale = readr::locale(encoding = "UTF-16LE")
  )

  # 2) Generic helper to pluck any section
  pluck_section <- function(df, start_pattern, end_pattern, col_names) {
    start_row <- which(str_detect(df$X1, regex(start_pattern, ignore_case = TRUE)))
    start <- if (length(start_row)) start_row[1] + 1 else 1
    if (!is.null(end_pattern)) {
      end_row <- which(str_detect(df$X1, regex(end_pattern, ignore_case = TRUE)))
      stop <- if (length(end_row)) end_row[1] - 1 else nrow(df)
    } else {
      stop <- nrow(df)
    }
    df %>%
      slice(start:stop) %>%
      filter(str_starts(X1, fixed(test_prefix))) %>%
      mutate(tmp = X1) %>%
      separate(tmp, into = col_names, sep = ",", fill = "right") %>%
      select(all_of(col_names))
  }

  # 3) Extract raw scores, scaled scores, completion times, and composites
  raw_scores    <- pluck_section(df, "RAW SCORES",             "SCALED SCORES",            c("scale", "raw_score"))
  scaled_scores <- pluck_section(df, "SCALED SCORES",          "SUBTEST COMPLETION TIMES", c("scale", "scaled_score"))
  times         <- pluck_section(df, "SUBTEST COMPLETION TIMES","RULES TRIGGERED",           c("scale", "completion_time"))
  composites    <- pluck_section(df, "Composite Score",        NULL,                        c(
    "scale", "composite_score", "percentile",
    "ci_95_lower", "ci_95_upper"
  ))

  # 4) Combine extracted data and any manual entries
  combined <- list(raw_scores, scaled_scores, times, composites) %>%
    reduce(full_join, by = "scale")
  if (!is.null(manual_entries)) {
    combined <- combined %>%
      bind_rows(manual_entries) %>%
      distinct(scale, .keep_all = TRUE)
  }

  # 5) Recompute missing percentiles from scaled_score (z = (x - 10) / 3)
  combined <- combined %>%
    mutate(
      z = (as.numeric(scaled_score) - 10) / 3,
      percentile = coalesce(
        as.numeric(percentile),
        round(pnorm(z) * 100)
      )
    ) %>%
    select(-z)

  # 6) Merge in metadata from the external lookup table
  #    The lookup CSV must include: scale, domain, subdomain, narrow,
  #    pass, verbal, timed, score_type, description
  lookup <- readr::read_csv(
    lookup_file,
    show_col_types = FALSE
  )
  combined <- combined %>%
    left_join(lookup, by = "scale")

  # 7) Add patient/test metadata columns
  combined <- combined %>%
    mutate(
      patient   = patient_id,
      test      = test_prefix,
      test_type = "npsych_test"
    )

  # 8) Optionally write the combined data to CSV
  if (!is.null(output_file)) {
    readr::write_csv(combined, output_file)
  }
  return(combined)
}
