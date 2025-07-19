library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)

#' Extract and Tidy RBANS Update Form A Data
#'
#' This function reads a CSV file with UTF-16LE encoding and extracts
#' RBANS Update Form A subtest and composite score data, then exports
#' it as a clean CSV file using standardized variable names.
#'
#' @param input_file Path to the input CSV file with UTF-16LE encoding
#' @param output_file Path for the output CSV file (default: "rbans_data_tidy.csv")
#' @param patient_id Optional patient identifier to include in output
#' @param debug Logical, if TRUE shows detailed extraction information
#'
#' @return A tibble containing the extracted and tidied RBANS data
#'
#' @examples
#' rbans_data <- extract_rbans_data("EF2025_4_17_2025_scores.csv", "rbans_tidy.csv", "Patient_001")
#'
extract_rbans_data <- function(input_file,
                               output_file = "rbans_data_tidy.csv",
                               patient_id = NULL,
                               debug = FALSE) {

  # Define RBANS test metadata with variable names
  rbans_metadata <- tribble(
    ~test_name, ~variable_name, ~test_battery, ~domain, ~subdomain, ~score_type, ~test_type, ~description,
    # Composite Scores (Indices)
    "RBANS Update Form A Total Scale (TOT)", "rbans_01", "rbans", "RBANS General Cognitive Ability", "Neurocognition", "standard_score", "Composite", "Composite indicator of overall neurocognitive functioning",
    "RBANS Update Form A Attention Index (ATI)", "rbans_02", "rbans", "RBANS Attention/Executive", "Attention", "standard_score", "Composite", "General attentional and executive functioning",
    "RBANS Update Form A Immediate Memory Index (IMI)", "rbans_05", "rbans", "RBANS Memory", "Learning Efficiency", "standard_score", "Composite", "Composite verbal learning of a word list and a logical story",
    "RBANS Update Form A Language Index (LGI)", "rbans_08", "rbans", "RBANS Verbal/Language", "Language", "standard_score", "Composite", "General language processing",
    "RBANS Update Form A Visuospatial/ Constructional Index (VCI)", "rbans_11", "rbans", "RBANS Visual Perception/Construction", "Spatial", "standard_score", "Composite", "Broadband index of visuospatial processing and construction",
    "RBANS Update Form A Delayed Memory Index (DRI)", "rbans_14", "rbans", "RBANS Memory", "Delayed Recall", "standard_score", "Composite", "Long-term recall of verbal and nonverbal material",

    # Subtests
    "RBANS Update Form A Digit Span", "rbans_03", "rbans", "RBANS Attention/Executive", "Attention", "scaled_score", "Subtest", "Attention span and auditory attention",
    "RBANS Update Form A Coding", "rbans_04", "rbans", "RBANS Attention/Executive", "Processing Speed", "scaled_score", "Subtest", "Efficiency of psychomotor speed, visual scanning ability, and visual-motor coordination",
    "RBANS Update Form A List Learning", "rbans_06", "rbans", "RBANS Memory", "Learning Efficiency", "scaled_score", "Subtest", "Word list learning",
    "RBANS Update Form A Story Memory", "rbans_07", "rbans", "RBANS Memory", "Learning Efficiency", "scaled_score", "Subtest", "Expository story learning",
    "RBANS Update Form A Picture Naming", "rbans_09", "rbans", "RBANS Verbal/Language", "Word Retrieval", "percentile", "Subtest", "Confrontation naming/expressive vocabulary",
    "RBANS Update Form A Semantic Fluency", "rbans_10", "rbans", "RBANS Verbal/Language", "Fluency", "scaled_score", "Subtest", "Semantic word fluency/generativity",
    "RBANS Update Form A Figure Copy", "rbans_12", "rbans", "RBANS Visual Perception/Construction", "Organization", "scaled_score", "Subtest", "The accuracy of copying a figure from a model",
    "RBANS Update Form A Line Orientation", "rbans_13", "rbans", "RBANS Visual Perception/Construction", "Perception", "percentile", "Subtest", "Basic perception of visual stimuli",
    "RBANS Update Form A List Recall", "rbans_15", "rbans", "RBANS Memory", "Delayed Recall", "percentile", "Subtest", "Long-term recall of a word list",
    "RBANS Update Form A List Recognition", "rbans_16", "rbans", "RBANS Memory", "Recognition Memory", "percentile", "Subtest", "Delayed recognition of a word list",
    "RBANS Update Form A Story Recall", "rbans_17", "rbans", "RBANS Memory", "Delayed Recall", "scaled_score", "Subtest", "Long-term recall of a detailed story",
    "RBANS Update Form A Figure Recall", "rbans_18", "rbans", "RBANS Memory", "Delayed Recall", "scaled_score", "Subtest", "Long-term recall and reconstruction of a complex abstract figure"
  )

  # Read the CSV file with UTF-16LE encoding
  cat("Reading CSV file with UTF-16LE encoding...\n")

  tryCatch({
    raw_data <- read_csv(input_file,
                         locale = locale(encoding = "UTF-16LE"),
                         col_types = cols(.default = "c"),
                         show_col_types = FALSE,
                         name_repair = "unique")
  }, error = function(e) {
    stop("Error reading file: ", e$message,
         "\nPlease check that the file exists and has UTF-16LE encoding.")
  })

  cat("File read successfully. Extracting RBANS data...\n")

  # Get column names - handle the specific structure of this file
  col_names <- names(raw_data)
  test_name_col <- col_names[1]  # First column contains test names
  score_col <- col_names[3]       # Third column contains scores

  if (debug) {
    cat("\nColumn structure detected:\n")
    cat("Test names in column:", test_name_col, "\n")
    cat("Scores in column:", score_col, "\n\n")
  }

  # Create a data frame with test names and scores
  all_data <- raw_data %>%
    select(test_name = 1, score = 3) %>%
    mutate(
      test_name = as.character(test_name),
      score = as.character(score)
    ) %>%
    filter(!is.na(test_name), test_name != "")

  # Find sections
  raw_section_start <- which(str_detect(all_data$test_name, "RAW SCORES"))[1]
  scaled_section_start <- which(str_detect(all_data$test_name, "SCALED SCORES"))[1]
  standard_section_start <- which(str_detect(all_data$test_name, "STANDARD SCORES"))[1]

  if (debug) {
    cat("Section locations:\n")
    cat("Raw scores start at row:", raw_section_start, "\n")
    cat("Scaled scores start at row:", scaled_section_start, "\n")
    cat("Standard scores start at row:", standard_section_start, "\n\n")
  }

  # Helper function to extract scores from a section
  extract_section_data <- function(data, start_row, end_row, score_type) {
    if (is.na(start_row)) return(tibble())

    section_data <- data %>%
      slice(start_row:end_row) %>%
      filter(str_detect(test_name, "RBANS Update Form A")) %>%
      filter(!str_detect(test_name, "SCORES|Subtest"))

    # For raw scores, we need the main test scores (not trials)
    if (score_type == "raw") {
      section_data <- section_data %>%
        filter(!str_detect(test_name, "Trial|Item|Sample"))
    }

    # Clean scores
    section_data <- section_data %>%
      mutate(
        score_clean = case_when(
          score %in% c("-", "–", "—", "-\r", " \r", "") ~ NA_character_,
          TRUE ~ str_extract(score, "-?\\d+\\.?\\d*")
        ),
        score_numeric = as.numeric(score_clean)
      )

    return(section_data)
  }

  # Extract data from each section
  cat("Extracting subtest scores...\n")

  # Determine section boundaries
  end_raw <- ifelse(!is.na(scaled_section_start), scaled_section_start - 1, nrow(all_data))
  end_scaled <- ifelse(!is.na(standard_section_start), standard_section_start - 1, nrow(all_data))

  # Extract raw scores
  raw_scores <- extract_section_data(all_data, raw_section_start, end_raw, "raw")

  # Extract scaled scores
  scaled_scores <- extract_section_data(all_data, scaled_section_start, end_scaled, "scaled") %>%
    # Filter out duplicate entries (keep first occurrence)
    distinct(test_name, .keep_all = TRUE)

  # Extract standard scores (composites)
  cat("Extracting composite scores...\n")

  standard_scores <- all_data %>%
    filter(str_detect(test_name, "Index \\(|Total Scale \\(")) %>%
    mutate(
      score_clean = str_extract(score, "-?\\d+\\.?\\d*"),
      score_numeric = as.numeric(score_clean)
    )

  if (debug) {
    cat("\nExtracted data summary:\n")
    cat("Raw scores found:", nrow(raw_scores), "\n")
    cat("Scaled scores found:", nrow(scaled_scores), "\n")
    cat("Standard scores found:", nrow(standard_scores), "\n")
  }

  # Map to metadata
  results <- list()

  # Process subtests
  for (i in 1:nrow(rbans_metadata)) {
    meta <- rbans_metadata[i, ]

    if (meta$test_type == "Subtest") {
      # Find raw score
      raw_match <- raw_scores %>%
        filter(str_detect(test_name, fixed(meta$test_name))) %>%
        slice(1)

      # Find scaled score
      scaled_match <- scaled_scores %>%
        filter(str_detect(test_name, fixed(meta$test_name))) %>%
        slice(1)

      raw_value <- if(nrow(raw_match) > 0) raw_match$score_numeric else NA_real_
      scaled_value <- if(nrow(scaled_match) > 0) scaled_match$score_numeric else NA_real_

      # For percentile subtests, the scaled score is actually the percentile
      if (meta$score_type == "percentile") {
        percentile_value <- scaled_value
        scaled_value <- NA_real_
      } else {
        percentile_value <- NA_real_
      }

      results[[length(results) + 1]] <- tibble(
        variable_name = meta$variable_name,
        test_name = meta$test_name,
        test_battery = meta$test_battery,
        domain = meta$domain,
        subdomain = meta$subdomain,
        test_type = meta$test_type,
        score_type = meta$score_type,
        raw_score = raw_value,
        score_value = ifelse(meta$score_type == "percentile", percentile_value, scaled_value),
        percentile_rank = percentile_value,
        ci_95_low = NA_real_,
        ci_95_high = NA_real_,
        description = meta$description
      )
    } else {
      # Process composites
      composite_match <- standard_scores %>%
        filter(str_detect(test_name, fixed(str_extract(meta$test_name, ".*\\(")))) %>%
        slice(1)

      standard_value <- if(nrow(composite_match) > 0) composite_match$score_numeric else NA_real_

      results[[length(results) + 1]] <- tibble(
        variable_name = meta$variable_name,
        test_name = meta$test_name,
        test_battery = meta$test_battery,
        domain = meta$domain,
        subdomain = meta$subdomain,
        test_type = meta$test_type,
        score_type = meta$score_type,
        raw_score = NA_real_,
        score_value = standard_value,
        percentile_rank = NA_real_,
        ci_95_low = NA_real_,
        ci_95_high = NA_real_,
        description = meta$description
      )
    }
  }

  # Combine all results
  final_data <- bind_rows(results) %>%
    arrange(variable_name)

  # Add patient ID if provided
  if (!is.null(patient_id)) {
    final_data <- final_data %>%
      mutate(patient_id = patient_id, .before = 1)
  }

  # Add assessment info
  final_data <- final_data %>%
    mutate(
      assessment = "RBANS Update Form A",
      date_extracted = Sys.Date(),
      .before = if(!is.null(patient_id)) 2 else 1
    )

  # Write the tidy data to CSV
  cat("Writing tidy data to:", output_file, "\n")

  write_csv(final_data, output_file, na = "")

  # Print summary
  cat("\n=== EXTRACTION SUMMARY ===\n")

  subtests_extracted <- sum(!is.na(final_data$raw_score[final_data$test_type == "Subtest"]))
  composites_extracted <- sum(!is.na(final_data$score_value[final_data$test_type == "Composite"]))

  cat("Subtests extracted:", subtests_extracted, "of", sum(final_data$test_type == "Subtest"), "\n")
  cat("Composites extracted:", composites_extracted, "of", sum(final_data$test_type == "Composite"), "\n")
  cat("Output file:", output_file, "\n")
  cat("Rows in final dataset:", nrow(final_data), "\n")

  # Return the data for further analysis
  return(final_data)
}

#' Create a summary report of RBANS scores
#'
#' @param rbans_data Tibble from extract_rbans_data()
#' @param output_file Path for summary report CSV
#'
create_rbans_summary_report <- function(rbans_data, output_file = "rbans_summary_report.csv") {

  # Create summary with performance levels
  summary_report <- rbans_data %>%
    mutate(
      performance_level = case_when(
        # For standard scores (indices)
        score_type == "standard_score" & score_value >= 115 ~ "Superior",
        score_type == "standard_score" & score_value >= 108 ~ "Above Average",
        score_type == "standard_score" & score_value >= 92 ~ "Average",
        score_type == "standard_score" & score_value >= 85 ~ "Low Average",
        score_type == "standard_score" & score_value >= 70 ~ "Borderline",
        score_type == "standard_score" & score_value < 70 ~ "Impaired",

        # For scaled scores (subtests)
        score_type == "scaled_score" & score_value >= 13 ~ "Above Average",
        score_type == "scaled_score" & score_value >= 8 ~ "Average",
        score_type == "scaled_score" & score_value >= 5 ~ "Below Average",
        score_type == "scaled_score" & score_value < 5 ~ "Impaired",

        # For percentiles
        score_type == "percentile" & score_value >= 75 ~ "Above Average",
        score_type == "percentile" & score_value >= 25 ~ "Average",
        score_type == "percentile" & score_value >= 9 ~ "Below Average",
        score_type == "percentile" & score_value < 9 ~ "Impaired",

        TRUE ~ "Not Available"
      )
    ) %>%
    select(any_of(c("patient_id")), variable_name, test_name, domain, subdomain, test_type,
           score_type, score_value, percentile_rank, performance_level, description)

  write_csv(summary_report, output_file, na = "")
  cat("Summary report written to:", output_file, "\n")

  return(summary_report)
}

# Example usage: ----------------------------------------------------------

# Basic usage:
rbans_data <- extract_rbans_data("EF2025_4_17_2025_scores.csv", "rbans_tidy.csv", "Patient_001")

# With debugging:
rbans_data2 <- extract_rbans_data("EF2025_4_17_2025_scores.csv", debug = TRUE)

# Create summary report:
summary_report <- create_rbans_summary_report(rbans_data)
