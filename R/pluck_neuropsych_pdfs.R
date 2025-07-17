#' Extract and Process WISC-V Test Data from PDF
#'
#' This function extracts and processes WISC-V (Wechsler Intelligence Scale for Children, 5th Edition)
#' test data from PDF files. It handles three types of test data: index scores, subtest scores, and
#' process scores. The function extracts raw data from specified PDF pages, processes and cleans the data,
#' calculates additional metrics (confidence intervals, percentiles), and generates interpretive text.
#'
#' @param patient Character string specifying the patient identifier or name
#' @param test_type Character string specifying the type of test data to extract.
#'   Must be one of: "index", "subtest", or "process"
#' @param file_path Character string specifying the path to the PDF file. If NULL,
#'   a file chooser dialog will be opened to select the file
#' @param pages_index Numeric vector specifying the page numbers to extract for index data.
#'   Required when test_type = "index"
#' @param pages_subtest Numeric vector specifying the page numbers to extract for subtest data.
#'   Required when test_type = "subtest"
#' @param pages_process Numeric vector specifying the page numbers to extract for process data.
#'   Required when test_type = "process"
#'
#' @return A data frame containing the processed WISC-V test results with the following columns:
#'   \describe{
#'     \item{test}{Test identifier ("wisc5")}
#'     \item{test_name}{Full test name}
#'     \item{scale}{Name of the test scale or subtest}
#'     \item{raw_score}{Raw score obtained}
#'     \item{score}{Standard score (index) or scaled score (subtest/process)}
#'     \item{ci_95}{95% confidence interval}
#'     \item{percentile}{Percentile rank}
#'     \item{range}{Descriptive performance range}
#'     \item{result}{Interpretive text describing the results}
#'     \item{absort}{Sorting variable for report organization}
#'   }
#'
#' @details
#' The function handles three distinct types of WISC-V data:
#' \itemize{
#'   \item{\strong{Index scores}: Composite scores with standard score metric
#'     (mean=100, SD=15)}
#'   \item{\strong{Subtest scores}: Individual subtest scores with scaled score metric (mean=10, SD=3)}
#'   \item{\strong{Process scores}: Process-based scores with scaled score metric (mean=10, SD=3)}
#' }
#'
#' For subtest and process scores, the function automatically calculates 95% confidence intervals
#' using a reliability coefficient of 0.90. Process scores also have percentiles calculated
#' based on the normal distribution.
#'
#' The function integrates with a neuropsychological lookup table to add descriptive information
#' and generates interpretive text for each score. Results are automatically saved to CSV files
#' in the "data/csv" directory.
#'
#' @importFrom tabulapdf extract_areas
#' @importFrom dplyr mutate filter distinct left_join relocate select across all_of case_when
#' @importFrom tidyr unite
#' @importFrom stringr str_remove_all
#' @importFrom glue glue
#' @importFrom readr read_csv write_excel_csv
#' @importFrom utils write.csv
#'
#' @examples
#' \dontrun{
#' # Extract WISC-V index scores
#' index_data <- extract_wisc5_data(
#'   patient = "Patient001",
#'   test_type = "index",
#'   file_path = "path/to/wisc5_report.pdf",
#'   pages_index = c(32, 35)
#' )
#'
#' # Extract subtest scores with custom page numbers
#' subtest_data <- extract_wisc5_data(
#'   patient = "Patient001",
#'   test_type = "subtest",
#'   pages_subtest = c(30, 31)
#' )
#'
#' # Extract process scores (will prompt for file selection)
#' process_data <- extract_wisc5_data(
#'   patient = "Patient001",
#'   test_type = "process",
#'   pages_process = c(38)
#' )
#' }
#'
#' @export
extract_wisc5_data <- function(
  patient,
  test_type,
  file_path = NULL,
  pages_index = NULL,
  pages_subtest = NULL,
  pages_process = NULL
) {
  # Validate test type
  valid_types <- c("index", "subtest", "process")
  if (!test_type %in% valid_types) {
    stop("Invalid test_type. Use 'index', 'subtest', or 'process'")
  }

  # Validate that required page numbers are provided
  if (test_type == "index" && is.null(pages_index)) {
    stop("pages_index must be provided when test_type = 'index'")
  }
  if (test_type == "subtest" && is.null(pages_subtest)) {
    stop("pages_subtest must be provided when test_type = 'subtest'")
  }
  if (test_type == "process" && is.null(pages_process)) {
    stop("pages_process must be provided when test_type = 'process'")
  }

  # Set parameters based on test type and use dynamic page numbers
  params <- switch(
    test_type,
    "index" = list(
      test = "wisc5_index",
      pages = pages_index,
      extract_columns = c(1, 3, 4, 5, 6),
      variables = c("scale", "raw_score", "score", "percentile", "ci_95"),
      score_type = "standard_score",
      combine_pages = TRUE,
      preprocess = "index"
    ),
    "subtest" = list(
      test = "wisc5_subtest",
      pages = pages_subtest,
      extract_columns = c(2, 4, 5, 6),
      variables = c("scale", "raw_score", "score", "percentile"),
      score_type = "scaled_score",
      combine_pages = FALSE,
      preprocess = "subtest"
    ),
    "process" = list(
      test = "wisc5_process",
      pages = pages_process,
      extract_columns = c(1, 3, 4),
      variables = c("scale", "raw_score", "score"),
      score_type = "scaled_score",
      combine_pages = FALSE,
      preprocess = "process"
    )
  )

  # Select PDF if not provided
  if (is.null(file_path)) {
    file_path <- file.choose()
    saveRDS(file_path, paste0(params$test, "_path.rds"))
  }

  # Extract data from PDF
  extracted_areas <- tabulapdf::extract_areas(
    file = file_path,
    pages = params$pages,
    method = "decide",
    output = "matrix",
    copy = TRUE
  )

  # Save extracted areas
  saveRDS(extracted_areas, paste0(params$test, "_extracted_areas.rds"))

  # Combine pages if needed
  if (params$combine_pages && length(extracted_areas) > 1) {
    df <- do.call(rbind, lapply(extracted_areas, as.data.frame))
  } else {
    df <- as.data.frame(extracted_areas[[1]])
  }

  # Preprocessing
  if (ncol(df) >= 2) {
    df[, 2] <- gsub("\\*", "", df[, 2])
  }

  if (params$preprocess == "index") {
    df <- df |>
      dplyr::mutate(col2_paren = paste0("(", df[[2]], ")")) |>
      tidyr::unite("scale", 1, col2_paren, sep = " ", remove = TRUE)
  } else if (params$preprocess %in% c("subtest", "process")) {
    df <- df |> dplyr::mutate(V2 = stringr::str_remove_all(V2, "\\(|\\)"))
  }

  # Column extraction and renaming
  df <- df[, params$extract_columns, drop = FALSE]
  colnames(df) <- params$variables

  # Data cleaning
  df[df == "-"] <- NA
  df <- df |> dplyr::mutate(across(where(is.character), ~ dplyr::na_if(., "")))

  # Numeric conversions
  num_cols <- intersect(c("raw_score", "score", "percentile"), colnames(df))
  df <- df |> dplyr::mutate(across(all_of(num_cols), as.numeric))

  # Additional processing for specific test types
  if (params$preprocess %in% c("subtest", "process")) {
    # CI Calculation
    ci_params <- list(
      mean = ifelse(params$score_type == "scaled_score", 10, 100),
      sd = ifelse(params$score_type == "scaled_score", 3, 15),
      reliability = 0.90
    )

    for (i in seq_len(nrow(df))) {
      ci_values <- calc_ci_95(
        ability_score = df$score[i],
        mean = ci_params$mean,
        standard_deviation = ci_params$sd,
        reliability = ci_params$reliability
      )
      df$ci_95[i] <- paste(
        ci_values["lower_ci_95"],
        ci_values["upper_ci_95"],
        sep = "-"
      )
    }

    # Percentile calculation for process scores
    if (params$preprocess == "process") {
      df$percentile <- round(
        pnorm((df$score - ci_params$mean) / ci_params$sd) * 100
      )
    }

    # Column reorganization
    df <- df |> dplyr::relocate(ci_95, .after = score)
  }

  # Lookup table integration
  lookup_table <- readr::read_csv("~/Dropbox/neuropsych_lookup_table.csv")

  df_merged <- df |>
    dplyr::mutate(test = "wisc5") |>
    dplyr::left_join(lookup_table, by = c("test", "scale")) |>
    dplyr::relocate(c(test, test_name), .before = scale) |>
    gpluck_make_columns()

  # Initialize range column with empty strings to avoid recycling issues
  df_merged <- df_merged |> dplyr::mutate(range = "")

  # Apply score ranges - using the test_type parameter only
  df_merged <- df_merged |>
    gpluck_make_score_ranges(test_type = "npsych_test") |>
    dplyr::relocate(range, .after = percentile)

  # Generate descriptive text
  df_merged <- df_merged |>
    dplyr::mutate(
      result = dplyr::case_when(
        percentile == 1 ~
          glue::glue(
            "{description} fell within the {range} and ranked at the {percentile}st percentile."
          ),
        percentile == 2 ~
          glue::glue(
            "{description} fell within the {range} and ranked at the {percentile}nd percentile."
          ),
        percentile == 3 ~
          glue::glue(
            "{description} fell within the {range} and ranked at the {percentile}rd percentile."
          ),
        TRUE ~
          glue::glue(
            "{description} fell within the {range} and ranked at the {percentile}th percentile."
          )
      ),
      result = paste0(
        result,
        " This indicates performance as good as or better than ",
        percentile,
        "% of same-age peers from the general population.\n"
      )
    ) |>
    dplyr::select(-description) |>
    dplyr::relocate(absort, .after = result)

  # Filter out rows with missing or incomplete data
  df_merged <- df_merged |>
    dplyr::filter(
      !is.na(scale) & scale != "" & !grepl("^\\s*$", scale), # Remove empty or whitespace-only scales
      !is.na(score), # Remove rows with missing scores
      !is.na(percentile), # Remove rows with missing percentiles
      (!is.na(test_name) & test_name != "") | (test == "wisc5" & !is.na(scale)) # Keep rows with test name or valid WISC-5 scales
    )

  # Save results
  output_dir <- "data/csv"
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  readr::write_excel_csv(
    df_merged,
    file.path(output_dir, paste0(params$test, ".csv"))
  )

  return(df_merged)
}


#' Process WAIS-5 test data from PDF
#'
#' This function extracts and processes WAIS-5 test data from PDF files,
#' handling both subtest and index data types
#'
#' @param patient Character string of patient name
#' @param file_path Character string of PDF file path (if NULL, will prompt)
#' @param test_type Character string: either "subtest" or "index"
#' @param pages Numeric vector of page numbers to extract data from (defaults to 10 for subtest, 12 for index if NULL)
#' @param save_intermediate Logical, whether to save intermediate CSV files
#' @return A processed dataframe with test results
#'
process_wais5_data <- function(
  patient,
  file_path = NULL,
  test_type = c("subtest", "index"),
  pages = NULL,
  save_intermediate = TRUE
) {
  # Validate test_type argument
  test_type <- match.arg(test_type)

  # Set parameters based on test type
  if (test_type == "subtest") {
    test <- "wais5_subtest"
    test_name <- "WAIS-5"
    # Use provided pages parameter or default to 10 if NULL
    if (is.null(pages)) {
      pages <- c(10)
    }
    extract_columns <- c(2, 4, 5, 6)
    variables <- c("scale", "raw_score", "score", "percentile")
    score_type <- "scaled_score"
  } else if (test_type == "index") {
    test <- "wais5_index"
    test_name <- "WAIS-5"
    # Use provided pages parameter or default to 12 if NULL
    if (is.null(pages)) {
      pages <- c(12)
    }
    extract_columns <- c(1, 3, 4, 5, 6)
    variables <- c("scale", "raw_score", "score", "percentile", "ci_95")
    score_type <- "standard_score"
  }

  # Handle file path
  if (is.null(file_path)) {
    file <- file.path(file.choose())
    saveRDS(file, paste0(test, "_path.rds"))
  } else {
    file <- file_path
  }

  # Create parameters list
  params <- list(
    patient = patient,
    test = test,
    test_name = test_name,
    file = file,
    pages = pages,
    extract_columns = extract_columns,
    score_type = score_type,
    variables = variables
  )

  # Extract areas from PDF
  extracted_areas <- tabulapdf::extract_areas(
    file = file,
    pages = pages,
    method = "decide",
    output = "matrix",
    copy = TRUE
  )

  # Save intermediate files if requested
  if (save_intermediate) {
    saveRDS(extracted_areas, file = paste0(test, "_extracted_areas.rds"))

    # Loop over the list and write each matrix to a CSV file
    for (i in seq_along(extracted_areas)) {
      write.csv(
        extracted_areas[[i]],
        file = paste0(test, "_", i, ".csv"),
        row.names = FALSE
      )
    }
  }

  # Convert to dataframe
  df <- as.data.frame(extracted_areas[[1]])

  # Clean data - remove asterisk from first column (if WISC-5)
  df[, 2] <- gsub("\\*", "", df[, 2])

  # Remove parentheses from scale names
  df <- df |> dplyr::mutate(V2 = stringr::str_remove_all(V2, "\\(|\\)"))

  # Special processing for index data - merge columns
  if (test_type == "index") {
    df <- df |>
      dplyr::mutate(col2_paren = paste0("(", df[[2]], ")")) |>
      tidyr::unite("scale", 1, col2_paren, sep = " ", remove = TRUE)
  }

  # Extract only needed columns
  df <- df[, extract_columns]

  # Rename the variables
  colnames(df) <- params$variables

  # Clean and convert data types
  df[df == "-"] <- NA

  df <- df |>
    dplyr::mutate(
      raw_score = as.numeric(raw_score),
      score = as.numeric(score),
      percentile = as.numeric(percentile)
    ) |>
    dplyr::filter(!is.na(score) & !is.na(percentile)) |>
    dplyr::distinct()

  # Calculate 95% CI for subtest data (which doesn't have CI column)
  if (test_type == "subtest") {
    for (i in seq_len(nrow(df))) {
      ci_values <- calc_ci_95(
        ability_score = df$score[i],
        mean = 10, # Subtest mean
        standard_deviation = 3, # Subtest SD
        reliability = .90
      )
      df$true_score[i] <- ci_values["true_score"]
      df$ci_lo[i] <- ci_values["lower_ci_95"]
      df$ci_hi[i] <- ci_values["upper_ci_95"]
      df$ci_95[i] <- paste0(
        ci_values["lower_ci_95"],
        " - ",
        ci_values["upper_ci_95"]
      )
    }

    df <- df |>
      dplyr::select(-c(true_score, ci_lo, ci_hi)) |>
      dplyr::relocate(ci_95, .after = score)
  }

  # Load lookup table and merge
  lookup_table <- readr::read_csv("~/Dropbox/neuropsych_lookup_table.csv")

  df_merged <- dplyr::mutate(df, test = "wais5") |>
    dplyr::left_join(
      lookup_table,
      by = c("test" = "test", "scale" = "scale")
    ) |>
    dplyr::relocate(all_of(c("test", "test_name")), .before = "scale")

  # Add missing columns
  df_mutated <- gpluck_make_columns(
    df_merged,
    range = "",
    result = "",
    absort = NULL
  )

  # Calculate score ranges
  df_mutated <- df_mutated |>
    dplyr::mutate(range = NULL) |>
    gpluck_make_score_ranges(table = df_mutated, test_type = "npsych_test") |>
    dplyr::relocate(c(range), .after = percentile)

  # Generate results text with proper ordinal formatting
  df_final <- df_mutated |>
    dplyr::mutate(
      result = ifelse(
        percentile == 1,
        glue::glue(
          "{description} fell within the {range} and ranked at the {percentile}st percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
        ),
        ifelse(
          percentile == 2,
          glue::glue(
            "{description} fell within the {range} and ranked at the {percentile}nd percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
          ),
          ifelse(
            percentile == 3,
            glue::glue(
              "{description} fell within the {range} and ranked at the {percentile}rd percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
            ),
            glue::glue(
              "{description} fell within the {range} and ranked at the {percentile}th percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
            )
          )
        )
      )
    ) |>
    dplyr::select(-description) |>
    dplyr::relocate(absort, .after = result)

  return(df_final)
}

#' Process complete WAIS-5 data (both subtests and indexes)
#'
#' This function processes both subtest and index data from a WAIS-5 PDF
#' and combines them into a single dataset
#'
#' @param patient Character string of patient name
#' @param file_path Character string of PDF file path (if NULL, will prompt)
#' @param save_to_g Logical, whether to append to g.csv file
#' @return A combined dataframe with both subtest and index results
#'
process_wais5_complete <- function(
  patient,
  file_path = NULL,
  save_to_g = TRUE
) {
  # Process subtests
  message("Processing WAIS-5 subtests...")
  wais5_subtest <- process_wais5_data(
    patient = patient,
    file_path = file_path,
    test_type = "subtest",
    pages = subtest_pages
  )

  # Process indexes (will prompt for file if file_path is NULL)
  message("Processing WAIS-5 indexes...")
  wais5_index <- process_wais5_data(
    patient = patient,
    file_path = file_path,
    test_type = "index",
    pages = index_pages
  )

  # Combine both datasets
  wais5 <- dplyr::bind_rows(wais5_index, wais5_subtest)

  # Save the complete dataset
  test <- "wais5"
  readr::write_excel_csv(
    wais5,
    here::here("data", "csv", paste0(test, ".csv")),
    col_names = TRUE
  )

  # Append to g.csv if requested
  if (save_to_g) {
    # Helper function to check for headers
    has_headers <- function(file_path) {
      if (!file.exists(file_path)) {
        return(FALSE)
      }
      return(length(readLines(file_path, n = 1)) > 0)
    }

    g <- "g"
    g_file_path <- here::here("data", paste0(g, ".csv"))

    readr::write_excel_csv(
      wais5,
      g_file_path,
      append = TRUE,
      col_names = !has_headers(g_file_path),
      quote = "all"
    )

    cat(
      "Data for",
      test,
      "has been successfully processed and saved to",
      g_file_path,
      "\n"
    )
  }

  return(wais5)
}


#' Extract and Process WIAT-4 Test Results
#'
#' This function extracts data from a WIAT-4 (Wechsler Individual Achievement Test, 4th Edition)
#' PDF file, processes the extracted data, and generates formatted results with interpretive text.
#' The function also saves the results to CSV files for further use.
#'
#' @param patient Character string with the patient's name
#' @param file Path to the PDF file. If NULL, a file chooser dialog will be opened.
#' @param pages Vector of page numbers to extract from the PDF
#' @param extract_columns Vector of column positions to extract
#' @param score_type Character string indicating the type of score to use
#' @param variables Vector of variable names for the extracted columns
#' @param lookup_table_path Path to the lookup table CSV file
#' @param output_dir Directory to save output files. Defaults to "data/csv"
#' @param g_file_name Name of the consolidated results file, without extension
#'
#' @return A data frame containing the processed WIAT-4 test results
#'
#' @importFrom dplyr mutate filter distinct left_join relocate select all_of
#' @importFrom readr read_csv write_excel_csv
#' @importFrom tabulapdf extract_areas
#' @importFrom glue glue
#' @importFrom here here
#'
#' @examples
#' \dontrun{
#' # Basic usage with file chooser dialog
#' results <- pluck_wiat4(patient = "Biggie")
#'
#' # Specify file path and other parameters
#' results <- pluck_wiat4(
#'   patient = "Biggie",
#'   file = "path/to/wiat4.pdf",
#'   pages = c(20),
#'   extract_columns = c(1, 2, 3, 4, 5),
#'   variables = c("scale", "raw_score", "score", "ci_95", "percentile")
#' )
#' }
#'
#' @export
pluck_wiat4 <- function(
  patient,
  file = NULL,
  pages = c(20),
  extract_columns = c(1, 2, 3, 4, 5),
  score_type = "standard_score",
  variables = c("scale", "raw_score", "score", "ci_95", "percentile"),
  lookup_table_path = "~/Dropbox/neuropsych_lookup_table_combined.csv",
  output_dir = here::here("data", "csv"),
  g_file_name = "2"
) {
  # WIAT-4 parameters
  test <- "wiat4"
  test_name <- "WIAT-4"

  # File path
  if (is.null(file)) {
    file <- file.path(file.choose())
    saveRDS(file, paste0(test, "_path.rds"))
    file <- readRDS(paste0(test, "_path.rds"))
  }

  # Parameters
  params <- list(
    patient = patient,
    test = test,
    test_name = test_name,
    file = file,
    pages = pages,
    extract_columns = extract_columns,
    score_type = score_type,
    variables = variables
  )

  # Extract Areas function
  extracted_areas <- tabulapdf::extract_areas(
    file = file,
    pages = pages,
    method = "decide",
    output = "matrix",
    copy = TRUE
  )

  # Loop and Save
  # Loop over the list and write each matrix to a CSV file
  for (i in seq_along(extracted_areas)) {
    write.csv(
      extracted_areas[[i]],
      file = paste0(test, "_", i, ".csv"),
      row.names = FALSE
    )
  }

  # Save the entire list to an R data file
  saveRDS(extracted_areas, file = paste0(test, "_extracted_areas.rds"))
  # Load the list from the R data file (if necessary)
  extracted_areas <- readRDS(paste0(test, "_extracted_areas.rds"))

  # Check the extracted areas
  # str(extracted_areas)

  # To convert a single test using extracted areas into a single data frame
  if (length(extracted_areas) > 1) {
    df <- as.data.frame(extracted_areas[[1]])
    df2 <- data.frame(extracted_areas[[2]])
    df <- dplyr::bind_rows(df, df2)
  } else {
    df <- as.data.frame(extracted_areas[[1]])
  }

  # Function to extract columns by position
  extract_columns_by_position <- function(df, positions) {
    df[, positions]
  }

  # Extract columns
  df <- extract_columns_by_position(df, extract_columns)

  # Rename the variables
  colnames(df) <- params$variables

  # Replace "-" with NA in the entire dataframe
  df[df == "-"] <- NA

  # Convert 'raw score' 'score' and 'percentile' to numeric
  df <- df |>
    dplyr::mutate(
      raw_score = as.numeric(raw_score),
      score = as.numeric(score),
      percentile = as.numeric(percentile)
    )

  # Remove rows where 'score' or 'percentile' are missing
  df <- df |>
    dplyr::filter(!is.na(score) & !is.na(percentile)) |>
    dplyr::distinct()

  # Lookup Table Match
  # Load the lookup table
  lookup_table <- readr::read_csv(lookup_table_path)

  # Merge the data with the lookup table
  df_merged <- dplyr::mutate(df, test = test) |>
    dplyr::left_join(
      lookup_table,
      by = c("test" = "test", "scale" = "scale")
    ) |>
    dplyr::relocate(dplyr::all_of(c("test", "test_name")), .before = "scale")

  # add missing columns
  df_mutated <- gpluck_make_columns(
    df_merged,
    range = "",
    result = "",
    absort = NULL
  )

  # Test score ranges
  df_mutated <- df_mutated |>
    dplyr::mutate(range = NULL) |>
    gpluck_make_score_ranges(table = df_mutated, test_type = "npsych_test") |>
    dplyr::relocate(c(range), .after = percentile)

  # Glue results for each scale
  df <- df_mutated |>
    dplyr::mutate(
      result = ifelse(
        percentile == 1,
        glue::glue(
          "{description} fell within the {range} and ranked at the {percentile}st percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
        ),
        ifelse(
          percentile == 2,
          glue::glue(
            "{description} fell within the {range} and ranked at the {percentile}nd percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
          ),
          ifelse(
            percentile == 3,
            glue::glue(
              "{description} fell within the {range} and ranked at the {percentile}rd percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
            ),
            glue::glue(
              "{description} fell within the {range} and ranked at the {percentile}th percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
            )
          )
        )
      )
    ) |>
    dplyr::select(-description) |>
    dplyr::relocate(dplyr::all_of(c("absort", "score_type")), .after = result)

  # Create output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Write separate files for subtest and index scores
  # Extract subtest and index scores separately
  subtest_df <- df[df$score_type == params$subtest_score_type, ]
  index_df <- df[df$score_type == params$index_score_type, ]

  # Write subtest scores
  if (nrow(subtest_df) > 0) {
    readr::write_excel_csv(
      subtest_df,
      file.path(output_dir, paste0(test, "_subtests.csv")),
      col_names = TRUE
    )
  }

  # Write index scores
  if (nrow(index_df) > 0) {
    readr::write_excel_csv(
      index_df,
      file.path(output_dir, paste0(test, "_indexes.csv")),
      col_names = TRUE
    )
  }

  # Write combined scores
  readr::write_excel_csv(
    df,
    file.path(output_dir, paste0(test, ".csv")),
    col_names = TRUE
  )

  # Write to g_file_name.csv file (default: "g.csv")
  has_headers <- function(file_path) {
    if (!file.exists(file_path)) {
      return(FALSE) # File doesn't exist, headers are needed
    }
    # Check if the file has at least one line (header)
    return(length(readLines(file_path, n = 1)) > 0)
  }

  file_path <- here::here("data", paste0(g_file_name, ".csv"))

  readr::write_excel_csv(
    df,
    file_path,
    append = TRUE,
    col_names = !has_headers(file_path),
    quote = "all"
  )

  # Return the final dataframe
  return(df)
}


#' Extract and Process RBANS Data
#'
#' This function processes RBANS (Repeatable Battery for the Assessment of Neuropsychological Status) data
#' from a CSV file exported from Q-interactive. It extracts raw scores, scaled scores, completion times,
#' and composite scores, then combines them into a single dataset with appropriate metadata.
#'
#' @param input_file_path Path to the CSV file containing RBANS data
#' @param test_name_prefix Prefix used in the CSV file for test names (e.g., "RBANS Update Form A ")
#' @param test The test code to use in the output (e.g., "rbans", "rbans_a")
#' @param test_name The full test name to use in the output (e.g., "RBANS", "RBANS Update Form A")
#' @param patient Patient identifier or name
#' @param output_file_path Optional path to save the processed data. If NULL, data is returned but not saved.
#' @importFrom readr read_csv write_excel_csv write_csv locale
#' @import dplyr
#' @import stringr
#' @importFrom stats setNames
#' @importFrom utils write.csv
#'
#' @return A data frame containing the processed RBANS data
#' @export
#'
#' @examples
#' \dontrun{
#' process_rbans_data(
#'   input_file_path = "data/rbans_export.csv",
#'   test_name_prefix = "RBANS Update Form A ",
#'   test = "rbans_a",
#'   test_name = "RBANS Update Form A",
#'   patient = "Patient001",
#'   output_file_path = "data/processed_rbans.csv"
#' )
#' }
process_rbans_data <- function(
  input_file_path,
  test_name_prefix,
  test,
  test_name,
  patient,
  output_file_path = NULL
) {
  # Validate input file
  if (!file.exists(input_file_path)) {
    stop("Input file does not exist: ", input_file_path)
  }

  # Function to extract raw scores
  pluck_rbans_raw <- function(
    input_file_path,
    test_name_prefix,
    output_file_path = NULL
  ) {
    df <- readr::read_csv(
      input_file_path,
      col_names = FALSE,
      show_col_types = FALSE,
      locale = readr::locale(encoding = "UTF-16LE")
    )

    # Rename the columns - make sure we have the right number based on the actual data

    if (ncol(df) >= 3) {
      names(df)[1:3] <- c("Subtest", "NA", "Raw score")
      # Remove the second column
      df <- df |> dplyr::select(Subtest, `Raw score`)
    } else {
      # Handle the case where there might be fewer columns
      names(df) <- c("Subtest", "Raw score")[seq_len(ncol(df))]
    }

    # Find the start of the "Raw Score" section - search the entire dataframe
    start_line <- which(df == "RAW SCORES", arr.ind = TRUE)
    if (length(start_line) > 0) {
      start_line <- start_line[1, "row"] + 1 # Take the first occurrence + 1
    } else {
      # Fallback if "RAW SCORES" not found
      start_line <- which(
        grepl("RAW SCORES", as.matrix(df), ignore.case = TRUE),
        arr.ind = TRUE
      )
      if (length(start_line) > 0) {
        start_line <- start_line[1, "row"] + 1
      } else {
        start_line <- 1 # Default to beginning if not found
      }
    }

    # Find the stop of the "Raw Score" section - similar approach
    stop_line <- which(df == "SCALED SCORES", arr.ind = TRUE)
    if (length(stop_line) > 0) {
      stop_line <- stop_line[1, "row"] - 1 # Take the first occurrence - 1
    } else {
      # Fallback if "SCALED SCORES" not found
      stop_line <- which(
        grepl("SCALED SCORES", as.matrix(df), ignore.case = TRUE),
        arr.ind = TRUE
      )
      if (length(stop_line) > 0) {
        stop_line <- stop_line[1, "row"] - 1
      } else {
        stop_line <- nrow(df) # Default to end if not found
      }
    }

    # Read from the "Raw Score" section
    df_raw <- df |> dplyr::slice(start_line:stop_line)

    # Keep only rows with the specified prefix in the first column
    df_raw <- df_raw |>
      dplyr::filter(stringr::str_starts(Subtest, test_name_prefix))

    # Rename columns - using setNames instead of rename_with to avoid the length error
    df_raw <- df_raw |> setNames(c("scale", "raw_score"))

    df_raw$scale <- as.character(df_raw$scale)
    df_raw$raw_score <- as.numeric(df_raw$raw_score)

    # Write to file if output path is provided
    if (!is.null(output_file_path)) {
      readr::write_excel_csv(df_raw, output_file_path)
    }

    return(df_raw)
  }

  # Function to extract scaled scores
  pluck_rbans_score <- function(
    input_file_path,
    test_name_prefix,
    output_file_path = NULL
  ) {
    df <- readr::read_csv(
      input_file_path,
      col_names = FALSE,
      show_col_types = FALSE,
      locale = readr::locale(encoding = "UTF-16LE")
    )

    # Rename the columns - make sure we have the right number based on the actual data
    if (ncol(df) >= 3) {
      names(df)[1:3] <- c("Subtest", "NA", "Scaled score")
      # Remove the second column
      df <- df |> dplyr::select(Subtest, `Scaled score`)
    } else {
      # Handle the case where there might be fewer columns
      names(df) <- c("Subtest", "Scaled score")[seq_len(ncol(df))]
    }

    # Find the start of the "Scaled Score" section - search the entire dataframe
    start_line <- which(df == "SCALED SCORES", arr.ind = TRUE)
    if (length(start_line) > 0) {
      start_line <- start_line[1, "row"] + 1 # Take the first occurrence + 1
    } else {
      # Fallback if "SCALED SCORES" not found
      start_line <- which(
        grepl("SCALED SCORES", as.matrix(df), ignore.case = TRUE),
        arr.ind = TRUE
      )
      if (length(start_line) > 0) {
        start_line <- start_line[1, "row"] + 1
      } else {
        start_line <- 1 # Default to beginning if not found
      }
    }

    # Find the stop of the "Scaled Score" section - similar approach
    stop_line <- which(df == "CONTEXTUAL EVENTS", arr.ind = TRUE)
    if (length(stop_line) > 0) {
      stop_line <- stop_line[1, "row"] - 1 # Take the first occurrence - 1
    } else {
      # Fallback if "CONTEXTUAL EVENTS" not found
      stop_line <- which(
        grepl("CONTEXTUAL EVENTS", as.matrix(df), ignore.case = TRUE),
        arr.ind = TRUE
      )
      if (length(stop_line) > 0) {
        stop_line <- stop_line[1, "row"] - 1
      } else {
        stop_line <- nrow(df) # Default to end if not found
      }
    }

    # Read from the "score" section
    df_score <- df |> dplyr::slice(start_line:stop_line)

    # Keep only rows with the specified prefix in the first column
    df_score <- df_score |>
      dplyr::filter(stringr::str_starts(Subtest, test_name_prefix))

    # Rename columns - using setNames instead of rename_with to avoid the length error
    df_score <- df_score |> setNames(c("scale", "score"))

    df_score$scale <- as.character(df_score$scale)
    df_score$score <- as.numeric(df_score$score)

    # Write to file if output path is provided
    if (!is.null(output_file_path)) {
      readr::write_excel_csv(df_score, output_file_path)
    }

    return(df_score)
  }

  # Function to extract completion times
  pluck_rbans_completion_times <- function(
    input_file_path,
    test_name_prefix,
    output_file_path = NULL
  ) {
    df <- readr::read_csv(
      input_file_path,
      col_names = FALSE,
      show_col_types = FALSE,
      locale = readr::locale(encoding = "UTF-16LE")
    )

    # Rename the columns - make sure we have the right number based on the actual data
    if (ncol(df) >= 3) {
      names(df)[1:3] <- c("Subtest", "NA", "Completion Time (seconds)")
      # Remove the second column
      df <- df |> dplyr::select(Subtest, `Completion Time (seconds)`)
    } else {
      # Handle the case where there might be fewer columns
      names(df) <- c("Subtest", "Completion Time (seconds)")[seq_len(ncol(df))]
    }

    # Find the start of the "Completion Times" section - search the entire dataframe
    start_line <- which(df == "SUBTEST COMPLETION TIMES", arr.ind = TRUE)
    if (length(start_line) > 0) {
      start_line <- start_line[1, "row"] + 1 # Take the first occurrence + 1
    } else {
      # Fallback if "SUBTEST COMPLETION TIMES" not found
      start_line <- which(
        grepl("SUBTEST COMPLETION TIMES", as.matrix(df), ignore.case = TRUE),
        arr.ind = TRUE
      )
      if (length(start_line) > 0) {
        start_line <- start_line[1, "row"] + 1
      } else {
        start_line <- 1 # Default to beginning if not found
      }
    }

    # Find the stop of the section - similar approach
    stop_line <- which(df == "RULES TRIGGERED", arr.ind = TRUE)
    if (length(stop_line) > 0) {
      stop_line <- stop_line[1, "row"] - 1 # Take the first occurrence - 1
    } else {
      # Fallback if "RULES TRIGGERED" not found
      stop_line <- which(
        grepl("RULES TRIGGERED", as.matrix(df), ignore.case = TRUE),
        arr.ind = TRUE
      )
      if (length(stop_line) > 0) {
        stop_line <- stop_line[1, "row"] - 1
      } else {
        stop_line <- nrow(df) # Default to end if not found
      }
    }

    # Read from the "Completion Time" section
    df_times <- df |> dplyr::slice(start_line:stop_line)

    # Keep only rows with the specified prefix in the first column
    df_times <- df_times |>
      dplyr::filter(stringr::str_starts(Subtest, test_name_prefix))

    # Rename columns - using setNames instead of rename_with to avoid the length error
    df_times <- df_times |> setNames(c("scale", "completion_time_seconds"))

    df_times$scale <- as.character(df_times$scale)
    df_times$completion_time_seconds <- as.numeric(
      df_times$completion_time_seconds
    )

    # Write to file if output path is provided
    if (!is.null(output_file_path)) {
      readr::write_excel_csv(df_times, output_file_path)
    }

    return(df_times)
  }

  # Function to extract composite scores
  pluck_rbans_composite <- function(
    input_file_path,
    test_name_prefix,
    output_file_path = NULL
  ) {
    df <- readr::read_csv(
      input_file_path,
      col_names = FALSE,
      show_col_types = FALSE,
      locale = readr::locale(encoding = "UTF-16LE")
    )

    # Find the start of the "Composite Score" section with more robust approach
    start_line <- which(df == "Composite Score", arr.ind = TRUE)
    if (length(start_line) > 0) {
      start_line <- start_line[1, "row"] # Take the first occurrence
    } else {
      # Try looking for it in the X1 column specifically
      start_line <- which(df$X1 == "Composite Score")
      if (length(start_line) == 0) {
        # Fallback if "Composite Score" not found
        start_line <- which(
          grepl("Composite Score", as.matrix(df), ignore.case = TRUE),
          arr.ind = TRUE
        )
        if (length(start_line) > 0) {
          start_line <- start_line[1, "row"]
        } else {
          # If still not found, return empty data frame
          warning("Composite Score section not found in the file")
          return(data.frame(
            scale = character(),
            score = numeric(),
            percentile = numeric(),
            ci_95_lower = numeric(),
            ci_95_upper = numeric()
          ))
        }
      }
    }

    # Assuming there's no specific end line, use the end of the file
    stop_line <- nrow(df)

    # Safely extract the relevant section with error handling
    tryCatch(
      {
        df_composite <- df |>
          dplyr::slice((start_line + 1):stop_line) |>
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
            fill = "right" # Handle cases with fewer than expected values
          ) |>
          dplyr::slice(-1) |>
          dplyr::rename(scale = X1, score = X2) |>
          # Filter based on the prefix
          dplyr::filter(stringr::str_starts(scale, test_name_prefix)) |>
          dplyr::select(-c(ci_90_lo, ci_90_up)) |>
          dplyr::mutate(
            scale = as.character(.data$scale),
            score = as.numeric(.data$score),
            percentile = as.numeric(.data$percentile),
            ci_95_lower = as.numeric(.data$ci_95_lower),
            ci_95_upper = as.numeric(.data$ci_95_upper)
          )
      },
      error = function(e) {
        warning("Error processing composite scores: ", e$message)
        return(data.frame(
          scale = character(),
          score = numeric(),
          percentile = numeric(),
          ci_95_lower = numeric(),
          ci_95_upper = numeric()
        ))
      }
    )

    # Write to file if output path is provided
    if (
      !is.null(output_file_path) &&
        !is.null(df_composite) &&
        nrow(df_composite) > 0
    ) {
      readr::write_excel_csv(df_composite, output_file_path)
    }

    return(df_composite)
  }

  # Extract data components - pass the output_file_path parameter to intermediate files if desired
  rbans_raw <- pluck_rbans_raw(
    input_file_path,
    test_name_prefix,
    output_file_path = NULL
  )
  rbans_score <- pluck_rbans_score(
    input_file_path,
    test_name_prefix,
    output_file_path = NULL
  )
  rbans_time <- pluck_rbans_completion_times(
    input_file_path,
    test_name_prefix,
    output_file_path = NULL
  )
  rbans_composite <- pluck_rbans_composite(
    input_file_path,
    test_name_prefix,
    output_file_path = NULL
  )

  # Join the data into one dataframe by the test name
  df <- dplyr::left_join(rbans_raw, rbans_score, by = "scale") |>
    dplyr::mutate(percentile = as.numeric(""), range = as.character("")) |>
    dplyr::left_join(rbans_time, by = "scale")

  # Recalculate percentiles based on score
  df <- df |>
    dplyr::mutate(
      z = ifelse(!is.na(.data$score), (.data$score - 10) / 3, NA)
    ) |>
    dplyr::mutate(
      percentile = ifelse(
        is.na(.data$percentile),
        trunc(stats::pnorm(.data$z) * 100),
        .data$percentile
      )
    ) |>
    dplyr::select(-"z")

  # Merge with composite scores
  df <- dplyr::bind_rows(df, rbans_composite) |>
    dplyr::relocate(completion_time_seconds, .after = ci_95_upper)

  # Test score ranges
  df <- gpluck_make_score_ranges(table = df, test_type = "npsych_test")

  # Remove prefix from scale names
  df <- df |>
    dplyr::mutate(scale = stringr::str_remove(scale, test_name_prefix))

  # Rename specific scales
  scales_to_rename <- c(
    "Digit Span" == "RBANS Digit Span",
    "Coding" == "RBANS Coding",
    "Immediate Memory Index (IMI)" = "Immediate Memory Index", # RBANS add
    "Visuospatial/ Constructional Index (VCI)" = "Visuospatial/Constructional Index",
    "Language Index (LGI)" = "Language Index",
    "Attention Index (ATI)" = "Attention Index",
    "Delayed Memory Index (DRI)" = "Delayed Memory Index",
    "Total Scale (TOT)" = "RBANS Total Index"
  )

  df$scale <- purrr::map_chr(
    df$scale,
    ~ ifelse(.x %in% names(scales_to_rename), scales_to_rename[.x], .x)
  )

  # Add additional columns
  df <- add_rbans_metadata(df, test, test_name, patient)

  # Write the combined data to a CSV file if output_file_path is provided
  if (!is.null(output_file_path)) {
    readr::write_excel_csv(df, output_file_path)
  }

  return(df)
}

#' Add RBANS Metadata
#'
#' This function adds domain, subdomain, and other metadata to RBANS test results.
#'
#' @param df A data frame containing RBANS test results
#' @param test The test code (e.g., "rbans", "rbans_a")
#' @param test_name The full test name (e.g., "RBANS", "RBANS Update Form A")
#' @param patient Patient identifier or name
#'
#' @return A data frame with added metadata
#' @keywords internal
add_rbans_metadata <- function(df, test, test_name, patient) {
  # Add basic columns if they don't exist
  df <- gpluck_make_columns(
    data = df,
    test = test,
    test_name = test_name,
    ci_95 = ifelse(
      !is.na(df$ci_95_lower) & !is.na(df$ci_95_upper),
      paste0(df$ci_95_lower, "-", df$ci_95_upper),
      ""
    ),
    domain = "",
    subdomain = "",
    narrow = "",
    pass = "",
    verbal = "",
    timed = "",
    test_type = "npsych_test",
    score_type = "",
    description = "",
    result = ""
  )

  # Add domain information
  df <- df |>
    dplyr::mutate(
      domain = dplyr::case_when(
        scale == "RBANS Total Index" ~ "General Cognitive Ability",
        scale == "Immediate Memory Index" ~ "Memory",
        scale == "List Learning" ~ "Memory",
        scale == "Story Memory" ~ "Memory",
        scale == "Visuospatial/Constructional Index" ~
          "Visual Perception/Construction",
        scale == "Figure Copy" ~ "Visual Perception/Construction",
        scale == "Line Orientation" ~ "Visual Perception/Construction",
        scale == "Language Index" ~ "Verbal/Language",
        scale == "Picture Naming" ~ "Verbal/Language",
        scale == "Semantic Fluency" ~ "Verbal/Language",
        scale == "Attention Index" ~ "Attention/Executive",
        scale == "RBANS Digit Span" ~ "Attention/Executive",
        scale == "RBANS Coding" ~ "Attention/Executive",
        scale == "Delayed Memory Index" ~ "Memory",
        scale == "List Recall" ~ "Memory",
        scale == "List Recognition" ~ "Memory",
        scale == "Story Recall" ~ "Memory",
        scale == "Figure Recall" ~ "Memory",
        TRUE ~ domain
      )
    )

  # Add subdomain information
  df <- df |>
    dplyr::mutate(
      subdomain = dplyr::case_when(
        scale == "RBANS Total Index" ~ "Neuropsychological Functioning",
        scale == "Immediate Memory Index" ~ "Neuropsychological Functioning",
        scale == "List Learning" ~ "Learning Efficiency",
        scale == "Story Memory" ~ "Learning Efficiency",
        scale == "Visuospatial/Constructional Index" ~
          "Neuropsychological Functioning",
        scale == "Figure Copy" ~ "Organization",
        scale == "Line Orientation" ~ "Perception",
        scale == "Language Index" ~ "Neuropsychological Functioning",
        scale == "Picture Naming" ~ "Retrieval",
        scale == "Semantic Fluency" ~ "Fluency",
        scale == "Attention Index" ~ "Neuropsychological Functioning",
        scale == "RBANS Digit Span" ~ "Attention",
        scale == "RBANS Coding" ~ "Processing Speed",
        scale == "Delayed Memory Index" ~ "Neuropsychological Functioning",
        scale == "List Recall" ~ "Delayed Recall",
        scale == "List Recognition" ~ "Recognition Memory",
        scale == "Story Recall" ~ "Delayed Recall",
        scale == "Figure Recall" ~ "Delayed Recall",
        TRUE ~ subdomain
      )
    )

  # Add narrow information
  df <- df |>
    dplyr::mutate(
      narrow = dplyr::case_when(
        scale == "RBANS Total Index" ~ "RBANS Total Index",
        scale == "Immediate Memory Index" ~ "RBANS Memory Index",
        scale == "List Learning" ~ "Word-List Learning",
        scale == "Story Memory" ~ "Story Memory",
        scale == "Visuospatial/Constructional Index" ~
          "RBANS Visuospatial/Constructional Index",
        scale == "Figure Copy" ~ "Figure Copy",
        scale == "Line Orientation" ~ "Visual Perception",
        scale == "Language Index" ~ "RBANS Language Index",
        scale == "Picture Naming" ~ "Naming",
        scale == "Semantic Fluency" ~ "Semantic Fluency",
        scale == "Attention Index" ~ "RBANS Attention Index",
        scale == "RBANS Digit Span" ~ "Attention Span",
        scale == "RBANS Coding" ~ "Cognitive Efficiency",
        scale == "Delayed Memory Index" ~ "RBANS Memory Index",
        scale == "List Recall" ~ "Word-List Learning",
        scale == "List Recognition" ~ "Recognition Memory",
        scale == "Story Recall" ~ "Story Memory",
        scale == "Figure Recall" ~ "Visual Memory",
        TRUE ~ narrow
      )
    )

  # Add timed/untimed information
  df <- df |>
    dplyr::mutate(
      timed = dplyr::case_when(
        scale == "RBANS Total Index" ~ "",
        scale == "Immediate Memory Index" ~ "Untimed",
        scale == "List Learning" ~ "Untimed",
        scale == "Story Memory" ~ "Untimed",
        scale == "Visuospatial/Constructional Index" ~ "Untimed",
        scale == "Figure Copy" ~ "Untimed",
        scale == "Line Orientation" ~ "Untimed",
        scale == "Language Index" ~ "",
        scale == "Picture Naming" ~ "Untimed",
        scale == "Semantic Fluency" ~ "Timed",
        scale == "Attention Index" ~ "",
        scale == "RBANS Digit Span" ~ "Untimed",
        scale == "RBANS Coding" ~ "Timed",
        scale == "Delayed Memory Index" ~ "Untimed",
        scale == "List Recall" ~ "Untimed",
        scale == "List Recognition" ~ "Untimed",
        scale == "Story Recall" ~ "Untimed",
        scale == "Figure Recall" ~ "Untimed",
        TRUE ~ timed
      )
    )

  # Add verbal/nonverbal information
  df <- df |>
    dplyr::mutate(
      verbal = dplyr::case_when(
        scale == "RBANS Total Index" ~ "",
        scale == "Immediate Memory Index" ~ "Verbal",
        scale == "List Learning" ~ "Verbal",
        scale == "Story Memory" ~ "Verbal",
        scale == "Visuospatial/Constructional Index" ~ "Nonverbal",
        scale == "Figure Copy" ~ "Nonverbal",
        scale == "Line Orientation" ~ "Nonverbal",
        scale == "Language Index" ~ "Verbal",
        scale == "Picture Naming" ~ "Verbal",
        scale == "Semantic Fluency" ~ "Verbal",
        scale == "Attention Index" ~ "",
        scale == "RBANS Digit Span" ~ "Verbal",
        scale == "RBANS Coding" ~ "Nonverbal",
        scale == "Delayed Memory Index" ~ "",
        scale == "List Recall" ~ "Verbal",
        scale == "List Recognition" ~ "Verbal",
        scale == "Story Recall" ~ "Verbal",
        scale == "Figure Recall" ~ "Nonverbal",
        TRUE ~ verbal
      )
    )

  # Add PASS information
  df <- df |>
    dplyr::mutate(
      pass = dplyr::case_when(
        scale == "RBANS Total Index" ~ "",
        scale == "Immediate Memory Index" ~ "Sequential",
        scale == "List Learning" ~ "Sequential",
        scale == "Story Memory" ~ "Sequential",
        scale == "Visuospatial/Constructional Index" ~ "Simultaneous",
        scale == "Figure Copy" ~ "Simultaneous",
        scale == "Line Orientation" ~ "Simultaneous",
        scale == "Language Index" ~ "Sequential",
        scale == "Picture Naming" ~ "Knowledge",
        scale == "Semantic Fluency" ~ "Sequential",
        scale == "Attention Index" ~ "Attention",
        scale == "RBANS Digit Span" ~ "Attention",
        scale == "RBANS Coding" ~ "Planning",
        scale == "Delayed Memory Index" ~ "",
        scale == "List Recall" ~ "Sequential",
        scale == "List Recognition" ~ "Sequential",
        scale == "Story Recall" ~ "Sequential",
        scale == "Figure Recall" ~ "Simultaneous",
        TRUE ~ as.character(pass)
      )
    )

  # Add score type information
  df <- df |>
    dplyr::mutate(
      score_type = dplyr::case_when(
        scale == "RBANS Total Index" ~ "standard_score",
        scale == "Immediate Memory Index" ~ "standard_score",
        scale == "List Learning" ~ "scaled_score",
        scale == "Story Memory" ~ "scaled_score",
        scale == "Visuospatial/Constructional Index" ~ "standard_score",
        scale == "Figure Copy" ~ "scaled_score",
        scale == "Line Orientation" ~ "percentile",
        scale == "Language Index" ~ "standard_score",
        scale == "Picture Naming" ~ "percentile",
        scale == "Semantic Fluency" ~ "scaled_score",
        scale == "Attention Index" ~ "standard_score",
        scale == "RBANS Digit Span" ~ "scaled_score",
        scale == "RBANS Coding" ~ "scaled_score",
        scale == "Delayed Memory Index" ~ "standard_score",
        scale == "List Recall" ~ "percentile",
        scale == "List Recognition" ~ "percentile",
        scale == "Story Recall" ~ "scaled_score",
        scale == "Figure Recall" ~ "scaled_score",
        TRUE ~ as.character(score_type)
      )
    )

  # Add descriptions
  df <- df |>
    dplyr::mutate(
      description = dplyr::case_when(
        scale == "RBANS Total Index" ~
          "composite indicator of general cognitive functioning",
        scale == "Immediate Memory Index" ~
          "composite verbal learning of a word list and a logical story",
        scale == "List Learning" ~ "word list learning",
        scale == "Story Memory" ~ "expository story learning",
        scale == "Visuospatial/Constructional Index" ~
          "broad visuospatial processing",
        scale == "Figure Copy" ~ "copy of a complex abstract figure",
        scale == "Line Orientation" ~ "basic perception of visual stimuli",
        scale == "Language Index" ~ "general language processing",
        scale == "Picture Naming" ~
          "confrontation naming/expressive vocabulary",
        scale == "Semantic Fluency" ~ "semantic word fluency/generativity",
        scale == "Attention Index" ~
          "general attentional and executive functioning",
        scale == "RBANS Digit Span" ~ "attention span and auditory attention",
        scale == "RBANS Coding" ~ "speed of information processing",
        scale == "Delayed Memory Index" ~
          "long-term recall of verbal information",
        scale == "List Recall" ~ "long-term recall of a word list",
        scale == "List Recognition" ~ "delayed recognition of a word list",
        scale == "Story Recall" ~ "long-term recall of a detailed story",
        scale == "Figure Recall" ~
          "long-term recall and reconstruction of a complex abstract figure",
        TRUE ~ as.character(description)
      )
    )

  # Add result text
  df <- df |>
    dplyr::mutate(
      result = glue::glue(
        "{patient}'s score on {scale} ({description}) was {range}."
      )
    )

  return(df)
}
