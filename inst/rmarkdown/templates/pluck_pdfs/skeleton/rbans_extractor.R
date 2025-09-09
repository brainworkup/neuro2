library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)

#' Extract and Tidy RBANS Update Form A Data
#'
#' This function reads a CSV file with UTF-16LE encoding and extracts
#' RBANS Update Form A subtest and composite score data, then exports
#' it as a clean CSV file.
#'
#' @param input_file Path to the input CSV file with UTF-16LE encoding
#' @param output_file Path for the output CSV file (default: "rbans_data_tidy.csv")
#' @param patient_id Optional patient identifier to include in output
#' @param debug Logical, if TRUE shows detailed column matching information
#'
#' @return A tibble containing the extracted and tidied RBANS data
#'
#' @examples
#' rbans_data <- extract_rbans_data("raw_data.csv", "rbans_tidy.csv", "Patient_001")
#'
extract_rbans_data <- function(
  input_file,
  output_file = "rbans_data_tidy.csv",
  patient_id = NULL
) {
  # Define RBANS subtest names
  subtest_names <- c(
    "RBANS Update Form A List Learning",
    "RBANS Update Form A Story Memory",
    "RBANS Update Form A Figure Copy",
    "RBANS Update Form A Line Orientation",
    "RBANS Update Form A Picture Naming",
    "RBANS Update Form A Semantic Fluency",
    "RBANS Update Form A Digit Span",
    "RBANS Update Form A Coding",
    "RBANS Update Form A List Recall",
    "RBANS Update Form A List Recognition",
    "RBANS Update Form A Story Recall",
    "RBANS Update Form A Figure Recall"
  )

  # Define composite score names
  composite_names <- c(
    "RBANS Update Form A Immediate Memory Index (IMI)",
    "RBANS Update Form A Visuospatial/ Constructional Index (VCI)",
    "RBANS Update Form A Language Index (LGI)",
    "RBANS Update Form A Attention Index (ATI)",
    "RBANS Update Form A Delayed Memory Index (DRI)",
    "RBANS Update Form A Total Scale (TOT)"
  )

  # Read the CSV file with UTF-16LE encoding
  cat("Reading CSV file with UTF-16LE encoding...\n")

  tryCatch(
    {
      raw_data <- read_csv(
        input_file,
        locale = locale(encoding = "UTF-16LE"),
        col_types = cols(.default = "c")
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

  cat("File read successfully. Extracting RBANS data...\n")

  # Function to safely extract data by column name pattern
  extract_score_data <- function(data, test_name, score_type) {
    # Create pattern to match column names
    pattern <- paste0("^", str_replace_all(test_name, "([\\(\\)])", "\\\\\\1"))

    # Find columns that match the pattern and score type
    matching_cols <- grep(
      paste(pattern, ".*", score_type, sep = ""),
      names(data),
      value = TRUE,
      ignore.case = TRUE
    )

    if (length(matching_cols) > 0) {
      # Get the first matching column (assuming one score per type per test)
      col_name <- matching_cols[1]
      score_value <- data[[col_name]][1] # Assuming data is in first row

      # Clean the score value
      if (!is.na(score_value) && score_value != "") {
        # Remove any non-numeric characters except decimal points and minus signs
        cleaned_score <- str_extract(score_value, "-?\\d+\\.?\\d*")
        return(as.numeric(cleaned_score))
      }
    }
    return(NA)
  }

  # Function to extract composite score data with multiple metrics
  extract_composite_data <- function(data, test_name) {
    pattern <- paste0("^", str_replace_all(test_name, "([\\(\\)])", "\\\\\\1"))

    # Extract different metrics for composite scores
    index_score <- extract_score_data(data, test_name, "Index|Standard|Score")
    percentile <- extract_score_data(data, test_name, "Percentile")
    ci_low <- extract_score_data(
      data,
      test_name,
      "Confidence.*Low|CI.*Low|95.*Low"
    )
    ci_high <- extract_score_data(
      data,
      test_name,
      "Confidence.*High|CI.*High|95.*High"
    )

    return(tibble(
      composite_name = test_name,
      index_score = index_score,
      percentile_rank = percentile,
      ci_95_low = ci_low,
      ci_95_high = ci_high
    ))
  }

  # Extract subtest data
  cat("Extracting subtest scores...\n")

  subtest_data <- map_dfr(subtest_names, function(test_name) {
    raw_score <- extract_score_data(raw_data, test_name, "Raw")
    scaled_score <- extract_score_data(
      raw_data,
      test_name,
      "Scaled|Standard|T.Score"
    )

    tibble(
      subtest_name = test_name,
      raw_score = raw_score,
      scaled_score = scaled_score
    )
  }) %>%
    # Clean subtest names for better readability
    mutate(
      subtest_short = str_remove(subtest_name, "RBANS Update Form A "),
      subtest_short = str_trim(subtest_short)
    )

  # Extract composite data
  cat("Extracting composite scores...\n")

  composite_data <- map_dfr(composite_names, function(test_name) {
    extract_composite_data(raw_data, test_name)
  }) %>%
    # Clean composite names
    mutate(
      composite_short = str_extract(composite_name, "\\(([^)]+)\\)"),
      composite_short = str_remove_all(composite_short, "[\\(\\)]"),
      composite_short = if_else(
        is.na(composite_short),
        str_remove(composite_name, "RBANS Update Form A "),
        composite_short
      )
    )

  # Create final tidy dataset
  cat("Creating tidy dataset...\n")

  # Combine subtest and composite data
  final_data <- bind_rows(
    # Subtest data
    subtest_data %>%
      select(test_name = subtest_short, raw_score, scaled_score) %>%
      mutate(test_type = "Subtest"),

    # Composite data (reshape to match subtest format for some analyses)
    composite_data %>%
      select(
        test_name = composite_short,
        index_score,
        percentile_rank,
        ci_95_low,
        ci_95_high
      ) %>%
      mutate(test_type = "Composite")
  )

  # Add patient ID if provided
  if (!is.null(patient_id)) {
    final_data <- final_data %>% mutate(patient_id = patient_id, .before = 1)
  }

  # Add assessment info
  final_data <- final_data %>%
    mutate(
      assessment = "RBANS Update Form A",
      date_extracted = Sys.Date(),
      .before = if (!is.null(patient_id)) 2 else 1
    )

  # Write the tidy data to CSV
  cat("Writing tidy data to:", output_file, "\n")

  write_csv(final_data, output_file, na = "")

  # Print summary
  cat("\n=== EXTRACTION SUMMARY ===\n")
  cat(
    "Subtests extracted:",
    sum(!is.na(subtest_data$raw_score)),
    "of",
    nrow(subtest_data),
    "\n"
  )
  cat(
    "Composites extracted:",
    sum(!is.na(composite_data$index_score)),
    "of",
    nrow(composite_data),
    "\n"
  )
  cat("Output file:", output_file, "\n")
  cat("Rows in final dataset:", nrow(final_data), "\n")

  # Return the data for further analysis
  return(final_data)
}

#' Helper function to create a detailed RBANS report
#'
#' @param rbans_data Tibble from extract_rbans_data()
#' @param output_file Path for detailed report CSV
#'
create_rbans_detailed_report <- function(
  rbans_data,
  output_file = "rbans_detailed_report.csv"
) {
  # Separate subtests and composites
  subtests <- rbans_data %>%
    filter(test_type == "Subtest") %>%
    select(-test_type, -index_score, -percentile_rank, -ci_95_low, -ci_95_high)

  composites <- rbans_data %>%
    filter(test_type == "Composite") %>%
    select(-test_type, -raw_score, -scaled_score)

  # Create detailed report with domain mapping
  detailed_report <- subtests %>%
    mutate(
      domain = case_when(
        str_detect(test_name, "List Learning|Story Memory") ~
          "Immediate Memory",
        str_detect(test_name, "Figure Copy|Line Orientation") ~
          "Visuospatial/Constructional",
        str_detect(test_name, "Picture Naming|Semantic Fluency") ~ "Language",
        str_detect(test_name, "Digit Span|Coding") ~ "Attention",
        str_detect(
          test_name,
          "List Recall|List Recognition|Story Recall|Figure Recall"
        ) ~
          "Delayed Memory",
        TRUE ~ "Unknown"
      ),
      performance_level = case_when(
        scaled_score >= 13 ~ "Above Average",
        scaled_score >= 8 ~ "Average",
        scaled_score >= 5 ~ "Below Average",
        scaled_score < 5 ~ "Impaired",
        TRUE ~ "Not Available"
      )
    )

  write_csv(detailed_report, output_file, na = "")
  cat("Detailed report written to:", output_file, "\n")

  return(detailed_report)
}

# Example usage:

# For debugging column matching issues:
# rbans_data <- extract_rbans_data("your_file.csv", debug = TRUE)

# Basic usage:
# rbans_data <- extract_rbans_data("your_file.csv", "rbans_tidy.csv", "Patient_001")

# With debugging enabled:
# rbans_data <- extract_rbans_data("your_file.csv", "rbans_tidy.csv", "Patient_001", debug = TRUE)

# detailed_report <- create_rbans_detailed_report(rbans_data)
