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
    df <- dplyr::bind_rows(lapply(extracted_areas, as.data.frame))
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
    dplyr::relocate(absort, .before = result)

  # Filter out rows with missing or incomplete data
  df_merged <- df_merged |>
    dplyr::filter(
      !is.na(scale) & scale != "" & !grepl("^\\s*$", scale), # Remove empty or whitespace-only scales
      !is.na(score), # Remove rows with missing scores
      !is.na(percentile), # Remove rows with missing percentiles
      (!is.na(test_name) & test_name != "") | (test == "wisc5" & !is.na(scale)) # Keep rows with test name or valid WISC-5 scales
    )

  # Save results
  output_dir <- "raw-data/csv"
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
.process_wais5_data <- function(
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
.process_wais5_complete <- function(
  patient,
  file_path = NULL,
  save_to_g = TRUE
) {
  # Process subtests
  message("Processing WAIS-5 subtests...")
  wais5_subtest <- .process_wais5_data(
    patient = patient,
    file_path = file_path,
    test_type = "subtest",
    pages = subtest_pages
  )

  # Process indexes (will prompt for file if file_path is NULL)
  message("Processing WAIS-5 indexes...")
  wais5_index <- .process_wais5_data(
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
    here::here("data-raw", "csv", paste0(test, ".csv")),
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
#' results <- pluck_wiat4(patient = "Isabella")
#'
#' # Specify file path and other parameters
#' results <- pluck_wiat4(
#'   patient = "Isabella",
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
  lookup_table_path = "~/Dropbox/neuropsych_lookup_table.csv",
  output_dir = here::here("data-raw", "csv"),
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
    df1 <- as.data.frame(extracted_areas[[1]])
    df2 <- as.data.frame(extracted_areas[[2]])
    df <- dplyr::bind_rows(df1, df2)
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
    dplyr::relocate(dplyr::all_of(c("absort")), .before = result)

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

  file_path <- here::here("data-raw", paste0(g_file_name, ".csv"))

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


# #' Extract and Process RBANS Data
# #'
# #' This function processes RBANS (Repeatable Battery for the Assessment of Neuropsychological Status) data
# #' from a CSV file exported from Q-interactive. It extracts raw scores, scaled scores, completion times,
# #' and composite scores, then combines them into a single dataset with appropriate metadata.
# #'
# #' @param input_file_path Path to the CSV file containing RBANS data
# #' @param test_name_prefix Prefix used in the CSV file for test names (e.g., "RBANS Update Form A ")
# #' @param test The test code to use in the output (e.g., "rbans", "rbans_a")
# #' @param test_name The full test name to use in the output (e.g., "RBANS", "RBANS Update Form A")
# #' @param patient Patient identifier or name
# #' @param output_file_path Optional path to save the processed data. If NULL, data is returned but not saved.
# #' @importFrom readr read_csv write_excel_csv write_csv locale
# #' @import dplyr
# #' @import stringr
# #' @importFrom stats setNames
# #' @importFrom utils write.csv
# #'
# #' @return A data frame containing the processed RBANS data
# #' @export
# #'
# #' @examples
# #' \dontrun{
# #' process_rbans_data(
# #'   input_file_path = "data/rbans_export.csv",
# #'   test_name_prefix = "RBANS Update Form A ",
# #'   test = "rbans_a",
# #'   test_name = "RBANS Update Form A",
# #'   patient = "Patient001",
# #'   output_file_path = "data/processed_rbans.csv"
# #' )
# #' }
# process_rbans_data <- function(
#   input_file_path,
#   test_name_prefix,
#   test,
#   test_name,
#   patient,
#   output_file_path = NULL
# ) {
#   # Validate input file
#   if (!file.exists(input_file_path)) {
#     stop("Input file does not exist: ", input_file_path)
#   }

#   # Function to extract raw scores
#   pluck_rbans_raw <- function(
#     input_file_path,
#     test_name_prefix,
#     output_file_path = NULL
#   ) {
#     df <- readr::read_csv(
#       input_file_path,
#       col_names = FALSE,
#       show_col_types = FALSE,
#       locale = readr::locale(encoding = "UTF-16LE")
#     )

#     # Rename the columns - make sure we have the right number based on the actual data

#     if (ncol(df) >= 3) {
#       names(df)[1:3] <- c("Subtest", "NA", "Raw score")
#       # Remove the second column
#       df <- df |> dplyr::select(Subtest, `Raw score`)
#     } else {
#       # Handle the case where there might be fewer columns
#       names(df) <- c("Subtest", "Raw score")[seq_len(ncol(df))]
#     }

#     # Find the start of the "Raw Score" section - search the entire dataframe
#     start_line <- which(df == "RAW SCORES", arr.ind = TRUE)
#     if (length(start_line) > 0) {
#       start_line <- start_line[1, "row"] + 1 # Take the first occurrence + 1
#     } else {
#       # Fallback if "RAW SCORES" not found
#       start_line <- which(
#         grepl("RAW SCORES", as.matrix(df), ignore.case = TRUE),
#         arr.ind = TRUE
#       )
#       if (length(start_line) > 0) {
#         start_line <- start_line[1, "row"] + 1
#       } else {
#         start_line <- 1 # Default to beginning if not found
#       }
#     }

#     # Find the stop of the "Raw Score" section - similar approach
#     stop_line <- which(df == "SCALED SCORES", arr.ind = TRUE)
#     if (length(stop_line) > 0) {
#       stop_line <- stop_line[1, "row"] - 1 # Take the first occurrence - 1
#     } else {
#       # Fallback if "SCALED SCORES" not found
#       stop_line <- which(
#         grepl("SCALED SCORES", as.matrix(df), ignore.case = TRUE),
#         arr.ind = TRUE
#       )
#       if (length(stop_line) > 0) {
#         stop_line <- stop_line[1, "row"] - 1
#       } else {
#         stop_line <- nrow(df) # Default to end if not found
#       }
#     }

#     # Read from the "Raw Score" section
#     df_raw <- df |> dplyr::slice(start_line:stop_line)

#     # Keep only rows with the specified prefix in the first column
#     df_raw <- df_raw |>
#       dplyr::filter(stringr::str_starts(Subtest, test_name_prefix))

#     # Rename columns - using setNames instead of rename_with to avoid the length error
#     df_raw <- df_raw |> setNames(c("scale", "raw_score"))

#     df_raw$scale <- as.character(df_raw$scale)
#     df_raw$raw_score <- as.numeric(df_raw$raw_score)

#     # Write to file if output path is provided
#     if (!is.null(output_file_path)) {
#       readr::write_excel_csv(df_raw, output_file_path)
#     }

#     return(df_raw)
#   }

#   # Function to extract scaled scores
#   pluck_rbans_score <- function(
#     input_file_path,
#     test_name_prefix,
#     output_file_path = NULL
#   ) {
#     df <- readr::read_csv(
#       input_file_path,
#       col_names = FALSE,
#       show_col_types = FALSE,
#       locale = readr::locale(encoding = "UTF-16LE")
#     )

#     # Rename the columns - make sure we have the right number based on the actual data
#     if (ncol(df) >= 3) {
#       names(df)[1:3] <- c("Subtest", "NA", "Scaled score")
#       # Remove the second column
#       df <- df |> dplyr::select(Subtest, `Scaled score`)
#     } else {
#       # Handle the case where there might be fewer columns
#       names(df) <- c("Subtest", "Scaled score")[seq_len(ncol(df))]
#     }

#     # Find the start of the "Scaled Score" section - search the entire dataframe
#     start_line <- which(df == "SCALED SCORES", arr.ind = TRUE)
#     if (length(start_line) > 0) {
#       start_line <- start_line[1, "row"] + 1 # Take the first occurrence + 1
#     } else {
#       # Fallback if "SCALED SCORES" not found
#       start_line <- which(
#         grepl("SCALED SCORES", as.matrix(df), ignore.case = TRUE),
#         arr.ind = TRUE
#       )
#       if (length(start_line) > 0) {
#         start_line <- start_line[1, "row"] + 1
#       } else {
#         start_line <- 1 # Default to beginning if not found
#       }
#     }

#     # Find the stop of the "Scaled Score" section - similar approach
#     stop_line <- which(df == "CONTEXTUAL EVENTS", arr.ind = TRUE)
#     if (length(stop_line) > 0) {
#       stop_line <- stop_line[1, "row"] - 1 # Take the first occurrence - 1
#     } else {
#       # Fallback if "CONTEXTUAL EVENTS" not found
#       stop_line <- which(
#         grepl("CONTEXTUAL EVENTS", as.matrix(df), ignore.case = TRUE),
#         arr.ind = TRUE
#       )
#       if (length(stop_line) > 0) {
#         stop_line <- stop_line[1, "row"] - 1
#       } else {
#         stop_line <- nrow(df) # Default to end if not found
#       }
#     }

#     # Read from the "score" section
#     df_score <- df |> dplyr::slice(start_line:stop_line)

#     # Keep only rows with the specified prefix in the first column
#     df_score <- df_score |>
#       dplyr::filter(stringr::str_starts(Subtest, test_name_prefix))

#     # Rename columns - using setNames instead of rename_with to avoid the length error
#     df_score <- df_score |> setNames(c("scale", "score"))

#     df_score$scale <- as.character(df_score$scale)
#     df_score$score <- as.numeric(df_score$score)

#     # Write to file if output path is provided
#     if (!is.null(output_file_path)) {
#       readr::write_excel_csv(df_score, output_file_path)
#     }

#     return(df_score)
#   }

#   # Function to extract completion times
#   pluck_rbans_completion_times <- function(
#     input_file_path,
#     test_name_prefix,
#     output_file_path = NULL
#   ) {
#     df <- readr::read_csv(
#       input_file_path,
#       col_names = FALSE,
#       show_col_types = FALSE,
#       locale = readr::locale(encoding = "UTF-16LE")
#     )

#     # Rename the columns - make sure we have the right number based on the actual data
#     if (ncol(df) >= 3) {
#       names(df)[1:3] <- c("Subtest", "NA", "Completion Time (seconds)")
#       # Remove the second column
#       df <- df |> dplyr::select(Subtest, `Completion Time (seconds)`)
#     } else {
#       # Handle the case where there might be fewer columns
#       names(df) <- c("Subtest", "Completion Time (seconds)")[seq_len(ncol(df))]
#     }

#     # Find the start of the "Completion Times" section - search the entire dataframe
#     start_line <- which(df == "SUBTEST COMPLETION TIMES", arr.ind = TRUE)
#     if (length(start_line) > 0) {
#       start_line <- start_line[1, "row"] + 1 # Take the first occurrence + 1
#     } else {
#       # Fallback if "SUBTEST COMPLETION TIMES" not found
#       start_line <- which(
#         grepl("SUBTEST COMPLETION TIMES", as.matrix(df), ignore.case = TRUE),
#         arr.ind = TRUE
#       )
#       if (length(start_line) > 0) {
#         start_line <- start_line[1, "row"] + 1
#       } else {
#         start_line <- 1 # Default to beginning if not found
#       }
#     }

#     # Find the stop of the section - similar approach
#     stop_line <- which(df == "RULES TRIGGERED", arr.ind = TRUE)
#     if (length(stop_line) > 0) {
#       stop_line <- stop_line[1, "row"] - 1 # Take the first occurrence - 1
#     } else {
#       # Fallback if "RULES TRIGGERED" not found
#       stop_line <- which(
#         grepl("RULES TRIGGERED", as.matrix(df), ignore.case = TRUE),
#         arr.ind = TRUE
#       )
#       if (length(stop_line) > 0) {
#         stop_line <- stop_line[1, "row"] - 1
#       } else {
#         stop_line <- nrow(df) # Default to end if not found
#       }
#     }

#     # Read from the "Completion Time" section
#     df_times <- df |> dplyr::slice(start_line:stop_line)

#     # Keep only rows with the specified prefix in the first column
#     df_times <- df_times |>
#       dplyr::filter(stringr::str_starts(Subtest, test_name_prefix))

#     # Rename columns - using setNames instead of rename_with to avoid the length error
#     df_times <- df_times |> setNames(c("scale", "completion_time_seconds"))

#     df_times$scale <- as.character(df_times$scale)
#     df_times$completion_time_seconds <- as.numeric(
#       df_times$completion_time_seconds
#     )

#     # Write to file if output path is provided
#     if (!is.null(output_file_path)) {
#       readr::write_excel_csv(df_times, output_file_path)
#     }

#     return(df_times)
#   }

#   # Function to extract composite scores
#   pluck_rbans_composite <- function(
#     input_file_path,
#     test_name_prefix,
#     output_file_path = NULL
#   ) {
#     df <- readr::read_csv(
#       input_file_path,
#       col_names = FALSE,
#       show_col_types = FALSE,
#       locale = readr::locale(encoding = "UTF-16LE")
#     )

#     # Find the start of the "Composite Score" section with more robust approach
#     start_line <- which(df == "Composite Score", arr.ind = TRUE)
#     if (length(start_line) > 0) {
#       start_line <- start_line[1, "row"] # Take the first occurrence
#     } else {
#       # Try looking for it in the X1 column specifically
#       start_line <- which(df$X1 == "Composite Score")
#       if (length(start_line) == 0) {
#         # Fallback if "Composite Score" not found
#         start_line <- which(
#           grepl("Composite Score", as.matrix(df), ignore.case = TRUE),
#           arr.ind = TRUE
#         )
#         if (length(start_line) > 0) {
#           start_line <- start_line[1, "row"]
#         } else {
#           # If still not found, return empty data frame
#           warning("Composite Score section not found in the file")
#           return(data.frame(
#             scale = character(),
#             score = numeric(),
#             percentile = numeric(),
#             ci_95_lower = numeric(),
#             ci_95_upper = numeric()
#           ))
#         }
#       }
#     }

#     # Assuming there's no specific end line, use the end of the file
#     stop_line <- nrow(df)

#     # Safely extract the relevant section with error handling
#     tryCatch(
#       {
#         df_composite <- df |>
#           dplyr::slice((start_line + 1):stop_line) |>
#           tidyr::separate(
#             X3,
#             sep = ",",
#             into = c(
#               "percentile",
#               "ci_90_lo",
#               "ci_90_up",
#               "ci_95_lower",
#               "ci_95_upper"
#             ),
#             fill = "right" # Handle cases with fewer than expected values
#           ) |>
#           dplyr::slice(-1) |>
#           dplyr::rename(scale = X1, score = X2) |>
#           # Filter based on the prefix
#           dplyr::filter(stringr::str_starts(scale, test_name_prefix)) |>
#           dplyr::select(-c(ci_90_lo, ci_90_up)) |>
#           dplyr::mutate(
#             scale = as.character(.data$scale),
#             score = as.numeric(.data$score),
#             percentile = as.numeric(.data$percentile),
#             ci_95_lower = as.numeric(.data$ci_95_lower),
#             ci_95_upper = as.numeric(.data$ci_95_upper)
#           )
#       },
#       error = function(e) {
#         warning("Error processing composite scores: ", e$message)
#         return(data.frame(
#           scale = character(),
#           score = numeric(),
#           percentile = numeric(),
#           ci_95_lower = numeric(),
#           ci_95_upper = numeric()
#         ))
#       }
#     )

#     # Write to file if output path is provided
#     if (
#       !is.null(output_file_path) &&
#         !is.null(df_composite) &&
#         nrow(df_composite) > 0
#     ) {
#       readr::write_excel_csv(df_composite, output_file_path)
#     }

#     return(df_composite)
#   }

#   # Extract data components - pass the output_file_path parameter to intermediate files if desired
#   rbans_raw <- pluck_rbans_raw(
#     input_file_path,
#     test_name_prefix,
#     output_file_path = NULL
#   )
#   rbans_score <- pluck_rbans_score(
#     input_file_path,
#     test_name_prefix,
#     output_file_path = NULL
#   )
#   rbans_time <- pluck_rbans_completion_times(
#     input_file_path,
#     test_name_prefix,
#     output_file_path = NULL
#   )
#   rbans_composite <- pluck_rbans_composite(
#     input_file_path,
#     test_name_prefix,
#     output_file_path = NULL
#   )

#   # Join the data into one dataframe by the test name
#   df <- dplyr::left_join(rbans_raw, rbans_score, by = "scale") |>
#     dplyr::mutate(percentile = as.numeric(""), range = as.character("")) |>
#     dplyr::left_join(rbans_time, by = "scale")

#   # Recalculate percentiles based on score
#   df <- df |>
#     dplyr::mutate(
#       z = ifelse(!is.na(.data$score), (.data$score - 10) / 3, NA)
#     ) |>
#     dplyr::mutate(
#       percentile = ifelse(
#         is.na(.data$percentile),
#         trunc(stats::pnorm(.data$z) * 100),
#         .data$percentile
#       )
#     ) |>
#     dplyr::select(-"z")

#   # Merge with composite scores
#   df <- dplyr::bind_rows(df, rbans_composite) |>
#     dplyr::relocate(completion_time_seconds, .after = ci_95_upper)

#   # Test score ranges
#   df <- gpluck_make_score_ranges(table = df, test_type = "npsych_test")

#   # Remove prefix from scale names
#   df <- df |>
#     dplyr::mutate(scale = stringr::str_remove(scale, test_name_prefix))

#   # Rename specific scales
#   scales_to_rename <- c(
#     "Digit Span" == "Digit Span",
#     "Coding" == "Coding",
#     "Immediate Memory Index (IMI)" = "Immediate Memory Index", # RBANS add
#     "Visuospatial/ Constructional Index (VCI)" = "Visuospatial/Constructional Index",
#     "Language Index (LGI)" = "Language Index",
#     "Attention Index (ATI)" = "Attention Index",
#     "Delayed Memory Index (DRI)" = "Delayed Memory Index",
#     "Total Scale (TOT)" = "RBANS Total Index"
#   )

#   df$scale <- purrr::map_chr(
#     df$scale,
#     ~ ifelse(.x %in% names(scales_to_rename), scales_to_rename[.x], .x)
#   )

#   # Add additional columns
#   df <- add_rbans_metadata(df, test, test_name, patient)

#   # Write the combined data to a CSV file if output_file_path is provided
#   if (!is.null(output_file_path)) {
#     readr::write_excel_csv(df, output_file_path)
#   }

#   return(df)
# }

# #' Add RBANS Metadata
# #'
# #' This function adds domain, subdomain, and other metadata to RBANS test results.
# #'
# #' @param df A data frame containing RBANS test results
# #' @param test The test code (e.g., "rbans", "rbans_a")
# #' @param test_name The full test name (e.g., "RBANS", "RBANS Update Form A")
# #' @param patient Patient identifier or name
# #'
# #' @return A data frame with added metadata
# #' @keywords internal
# add_rbans_metadata <- function(df, test, test_name, patient) {
#   # Add basic columns if they don't exist
#   df <- gpluck_make_columns(
#     data = df,
#     test = test,
#     test_name = test_name,
#     ci_95 = ifelse(
#       !is.na(df$ci_95_lower) & !is.na(df$ci_95_upper),
#       paste0(df$ci_95_lower, "-", df$ci_95_upper),
#       ""
#     ),
#     domain = "",
#     subdomain = "",
#     narrow = "",
#     pass = "",
#     verbal = "",
#     timed = "",
#     test_type = "npsych_test",
#     score_type = "",
#     description = "",
#     result = ""
#   )

#   # Add domain information
#   df <- df |>
#     dplyr::mutate(
#       domain = dplyr::case_when(
#         scale == "RBANS Total Index" ~ "General Cognitive Ability",
#         scale == "Immediate Memory Index" ~ "Memory",
#         scale == "List Learning" ~ "Memory",
#         scale == "Story Memory" ~ "Memory",
#         scale == "Visuospatial/Constructional Index" ~
#           "Visual Perception/Construction",
#         scale == "Figure Copy" ~ "Visual Perception/Construction",
#         scale == "Line Orientation" ~ "Visual Perception/Construction",
#         scale == "Language Index" ~ "Verbal/Language",
#         scale == "Picture Naming" ~ "Verbal/Language",
#         scale == "Semantic Fluency" ~ "Verbal/Language",
#         scale == "Attention Index" ~ "Attention/Executive",
#         scale == "Digit Span" ~ "Attention/Executive",
#         scale == "Coding" ~ "Attention/Executive",
#         scale == "Delayed Memory Index" ~ "Memory",
#         scale == "List Recall" ~ "Memory",
#         scale == "List Recognition" ~ "Memory",
#         scale == "Story Recall" ~ "Memory",
#         scale == "Figure Recall" ~ "Memory",
#         TRUE ~ domain
#       )
#     )

#   # Add subdomain information
#   df <- df |>
#     dplyr::mutate(
#       subdomain = dplyr::case_when(
#         scale == "RBANS Total Index" ~ "Neuropsychological Functioning",
#         scale == "Immediate Memory Index" ~ "Neuropsychological Functioning",
#         scale == "List Learning" ~ "Learning Efficiency",
#         scale == "Story Memory" ~ "Learning Efficiency",
#         scale == "Visuospatial/Constructional Index" ~
#           "Neuropsychological Functioning",
#         scale == "Figure Copy" ~ "Organization",
#         scale == "Line Orientation" ~ "Perception",
#         scale == "Language Index" ~ "Neuropsychological Functioning",
#         scale == "Picture Naming" ~ "Retrieval",
#         scale == "Semantic Fluency" ~ "Fluency",
#         scale == "Attention Index" ~ "Neuropsychological Functioning",
#         scale == "Digit Span" ~ "Attention",
#         scale == "Coding" ~ "Processing Speed",
#         scale == "Delayed Memory Index" ~ "Neuropsychological Functioning",
#         scale == "List Recall" ~ "Delayed Recall",
#         scale == "List Recognition" ~ "Recognition Memory",
#         scale == "Story Recall" ~ "Delayed Recall",
#         scale == "Figure Recall" ~ "Delayed Recall",
#         TRUE ~ subdomain
#       )
#     )

#   # Add narrow information
#   df <- df |>
#     dplyr::mutate(
#       narrow = dplyr::case_when(
#         scale == "RBANS Total Index" ~ "RBANS Total Index",
#         scale == "Immediate Memory Index" ~ "RBANS Memory Index",
#         scale == "List Learning" ~ "Word-List Learning",
#         scale == "Story Memory" ~ "Story Memory",
#         scale == "Visuospatial/Constructional Index" ~
#           "RBANS Visuospatial/Constructional Index",
#         scale == "Figure Copy" ~ "Figure Copy",
#         scale == "Line Orientation" ~ "Visual Perception",
#         scale == "Language Index" ~ "RBANS Language Index",
#         scale == "Picture Naming" ~ "Naming",
#         scale == "Semantic Fluency" ~ "Semantic Fluency",
#         scale == "Attention Index" ~ "RBANS Attention Index",
#         scale == "Digit Span" ~ "Attention Span",
#         scale == "Coding" ~ "Cognitive Efficiency",
#         scale == "Delayed Memory Index" ~ "RBANS Memory Index",
#         scale == "List Recall" ~ "Word-List Learning",
#         scale == "List Recognition" ~ "Recognition Memory",
#         scale == "Story Recall" ~ "Story Memory",
#         scale == "Figure Recall" ~ "Visual Memory",
#         TRUE ~ narrow
#       )
#     )

#   # Add timed/untimed information
#   df <- df |>
#     dplyr::mutate(
#       timed = dplyr::case_when(
#         scale == "RBANS Total Index" ~ "",
#         scale == "Immediate Memory Index" ~ "Untimed",
#         scale == "List Learning" ~ "Untimed",
#         scale == "Story Memory" ~ "Untimed",
#         scale == "Visuospatial/Constructional Index" ~ "Untimed",
#         scale == "Figure Copy" ~ "Untimed",
#         scale == "Line Orientation" ~ "Untimed",
#         scale == "Language Index" ~ "",
#         scale == "Picture Naming" ~ "Untimed",
#         scale == "Semantic Fluency" ~ "Timed",
#         scale == "Attention Index" ~ "",
#         scale == "Digit Span" ~ "Untimed",
#         scale == "Coding" ~ "Timed",
#         scale == "Delayed Memory Index" ~ "Untimed",
#         scale == "List Recall" ~ "Untimed",
#         scale == "List Recognition" ~ "Untimed",
#         scale == "Story Recall" ~ "Untimed",
#         scale == "Figure Recall" ~ "Untimed",
#         TRUE ~ timed
#       )
#     )

#   # Add verbal/nonverbal information
#   df <- df |>
#     dplyr::mutate(
#       verbal = dplyr::case_when(
#         scale == "RBANS Total Index" ~ "",
#         scale == "Immediate Memory Index" ~ "Verbal",
#         scale == "List Learning" ~ "Verbal",
#         scale == "Story Memory" ~ "Verbal",
#         scale == "Visuospatial/Constructional Index" ~ "Nonverbal",
#         scale == "Figure Copy" ~ "Nonverbal",
#         scale == "Line Orientation" ~ "Nonverbal",
#         scale == "Language Index" ~ "Verbal",
#         scale == "Picture Naming" ~ "Verbal",
#         scale == "Semantic Fluency" ~ "Verbal",
#         scale == "Attention Index" ~ "",
#         scale == "Digit Span" ~ "Verbal",
#         scale == "Coding" ~ "Nonverbal",
#         scale == "Delayed Memory Index" ~ "",
#         scale == "List Recall" ~ "Verbal",
#         scale == "List Recognition" ~ "Verbal",
#         scale == "Story Recall" ~ "Verbal",
#         scale == "Figure Recall" ~ "Nonverbal",
#         TRUE ~ verbal
#       )
#     )

#   # Add PASS information
#   df <- df |>
#     dplyr::mutate(
#       pass = dplyr::case_when(
#         scale == "RBANS Total Index" ~ "",
#         scale == "Immediate Memory Index" ~ "Sequential",
#         scale == "List Learning" ~ "Sequential",
#         scale == "Story Memory" ~ "Sequential",
#         scale == "Visuospatial/Constructional Index" ~ "Simultaneous",
#         scale == "Figure Copy" ~ "Simultaneous",
#         scale == "Line Orientation" ~ "Simultaneous",
#         scale == "Language Index" ~ "Sequential",
#         scale == "Picture Naming" ~ "Knowledge",
#         scale == "Semantic Fluency" ~ "Sequential",
#         scale == "Attention Index" ~ "Attention",
#         scale == "Digit Span" ~ "Attention",
#         scale == "Coding" ~ "Planning",
#         scale == "Delayed Memory Index" ~ "",
#         scale == "List Recall" ~ "Sequential",
#         scale == "List Recognition" ~ "Sequential",
#         scale == "Story Recall" ~ "Sequential",
#         scale == "Figure Recall" ~ "Simultaneous",
#         TRUE ~ as.character(pass)
#       )
#     )

#   # Add score type information
#   df <- df |>
#     dplyr::mutate(
#       score_type = dplyr::case_when(
#         scale == "RBANS Total Index" ~ "standard_score",
#         scale == "Immediate Memory Index" ~ "standard_score",
#         scale == "List Learning" ~ "scaled_score",
#         scale == "Story Memory" ~ "scaled_score",
#         scale == "Visuospatial/Constructional Index" ~ "standard_score",
#         scale == "Figure Copy" ~ "scaled_score",
#         scale == "Line Orientation" ~ "percentile",
#         scale == "Language Index" ~ "standard_score",
#         scale == "Picture Naming" ~ "percentile",
#         scale == "Semantic Fluency" ~ "scaled_score",
#         scale == "Attention Index" ~ "standard_score",
#         scale == "Digit Span" ~ "scaled_score",
#         scale == "Coding" ~ "scaled_score",
#         scale == "Delayed Memory Index" ~ "standard_score",
#         scale == "List Recall" ~ "percentile",
#         scale == "List Recognition" ~ "percentile",
#         scale == "Story Recall" ~ "scaled_score",
#         scale == "Figure Recall" ~ "scaled_score",
#         TRUE ~ as.character(score_type)
#       )
#     )

#   # Add descriptions
#   df <- df |>
#     dplyr::mutate(
#       description = dplyr::case_when(
#         scale == "RBANS Total Index" ~
#           "composite indicator of general cognitive functioning",
#         scale == "Immediate Memory Index" ~
#           "composite verbal learning of a word list and a logical story",
#         scale == "List Learning" ~ "word list learning",
#         scale == "Story Memory" ~ "expository story learning",
#         scale == "Visuospatial/Constructional Index" ~
#           "broad visuospatial processing",
#         scale == "Figure Copy" ~ "copy of a complex abstract figure",
#         scale == "Line Orientation" ~ "basic perception of visual stimuli",
#         scale == "Language Index" ~ "general language processing",
#         scale == "Picture Naming" ~
#           "confrontation naming/expressive vocabulary",
#         scale == "Semantic Fluency" ~ "semantic word fluency/generativity",
#         scale == "Attention Index" ~
#           "general attentional and executive functioning",
#         scale == "Digit Span" ~ "attention span and auditory attention",
#         scale == "Coding" ~ "speed of information processing",
#         scale == "Delayed Memory Index" ~
#           "long-term recall of verbal information",
#         scale == "List Recall" ~ "long-term recall of a word list",
#         scale == "List Recognition" ~ "delayed recognition of a word list",
#         scale == "Story Recall" ~ "long-term recall of a detailed story",
#         scale == "Figure Recall" ~
#           "long-term recall and reconstruction of a complex abstract figure",
#         TRUE ~ as.character(description)
#       )
#     )

#   # Add result text
#   df <- df |>
#     dplyr::mutate(
#       result = glue::glue(
#         "{patient}'s score on {scale} ({description}) was {range}."
#       )
#     )

#   return(df)
# }

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
    filtered_df <- df |>
      dplyr::slice(start:stop) |>
      dplyr::filter(stringr::str_detect(X1, fixed(test_prefix)))

    # Create a temporary column for separation
    filtered_df <- filtered_df |>
      dplyr::mutate(tmp = X1) |>
      tidyr::separate(.data$tmp, into = col_names, sep = ",", fill = "right") |>
      dplyr::select(dplyr::all_of(col_names)) |>
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
    raw_scores_df <- df |>
      dplyr::slice(start_line:stop_line) |>
      dplyr::rename(Subtest = X1, dummy = X2, raw_score = X3) |>
      dplyr::select(Subtest, raw_score)

    # Filter for RBANS entries
    raw_scores <- raw_scores_df |>
      dplyr::filter(stringr::str_starts(Subtest, fixed(test_prefix))) |>
      dplyr::rename(scale = Subtest) |>
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
    scaled_scores_df <- df |>
      dplyr::slice(start_line:stop_line) |>
      dplyr::rename(Subtest = X1, dummy = X2, score = X3) |>
      dplyr::select(Subtest, score)

    # Filter for RBANS entries
    scaled_scores <- scaled_scores_df |>
      dplyr::filter(stringr::str_starts(Subtest, fixed(test_prefix))) |>
      dplyr::rename(scale = Subtest) |>
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
    times_df <- df |>
      dplyr::slice(start_line:stop_line) |>
      dplyr::rename(Subtest = X1, dummy = X2, completion_time = X3) |>
      dplyr::select(Subtest, completion_time)

    # Filter for RBANS entries
    times <- times_df |>
      dplyr::filter(stringr::str_starts(Subtest, fixed(test_prefix))) |>
      dplyr::rename(scale = Subtest) |>
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
    composites_df <- df |>
      dplyr::slice((start_line + 2):nrow(df)) |>
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
      composites <- composites_df |>
        dplyr::rename(scale = X1, score = X2) |>
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
        ) |>
        dplyr::select(scale, score, percentile, ci_95_lower, ci_95_upper) |>
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
    composites_df <- df |>
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
      composites <- composites_df |>
        dplyr::rename(scale = X1, score = X2) |>
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
        ) |>
        dplyr::select(scale, score, percentile, ci_95_lower, ci_95_upper) |>
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
  combined <- raw_scores |>
    dplyr::full_join(scaled_scores, by = "scale") |>
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
  combined <- combined |>
    dplyr::full_join(composites, by = "scale") |>
    dplyr::mutate(score = dplyr::coalesce(score.x, score.y)) |>
    dplyr::select(-dplyr::any_of(c("score.x", "score.y")))

  if (debug) {
    cat("\n=== AFTER JOINING COMPOSITES ===\n")
    cat("Combined data has", nrow(combined), "rows\n")

    # Check if composite scores are in the combined data
    composite_rows <- combined |>
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
    combined <- combined |>
      dplyr::bind_rows(manual_entries) |>
      dplyr::distinct(scale, .keep_all = TRUE)
  }

  # 5) Clean up scale names to match metadata
  combined <- combined |>
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
  combined <- combined |>
    dplyr::mutate(
      z = (as.numeric(score) - 10) / 3,
      percentile = dplyr::coalesce(
        as.numeric(percentile),
        round(pnorm(z) * 100)
      )
    ) |>
    dplyr::select(-z)

  # 7) Apply manual percentile overrides
  if (!is.null(manual_percentiles)) {
    for (scale_name in names(manual_percentiles)) {
      combined <- combined |>
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
  metadata <- lookup_neuropsych_scales |>
    dplyr::filter(test == "rbans") |>
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
        scale == "RBANS Digit Span" ~ "Digit Span", # Check me
        scale == "RBANS Coding" ~ "Coding", # check me
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
  metadata <- metadata |>
    dplyr::group_by(scale) |>
    dplyr::slice(1) |>
    dplyr::ungroup()

  combined <- combined |>
    dplyr::left_join(metadata, by = "scale") |>
    # Ensure we have unique rows after joining
    dplyr::distinct(scale, .keep_all = TRUE) |>
    # Fix absort column duplication
    dplyr::mutate(absort = dplyr::coalesce(absort.x, absort.y)) |>
    dplyr::select(-dplyr::any_of(c("absort.x", "absort.y")))

  # 10) Add test metadata columns and fix test_type and score_type for composite scores
  combined <- combined |>
    dplyr::mutate(
      test = "rbans",
      test_name = "RBANS",
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
  summary_data <- combined |>
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
    ) |>
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
  rbans_data <- rbans_data |> dplyr::distinct(scale, .keep_all = TRUE)

  # Create summary with performance levels
  summary_report <- rbans_data |>
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
    ) |>
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
