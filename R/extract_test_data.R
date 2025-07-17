#' Extract and Process Neuropsychological Test Data from PDF Files (Legacy)
#'
#' This function extracts tables from PDF files containing neuropsychological test results,
#' processes the data, merges with a lookup table, and calculates score ranges and text descriptions.
#' This is a legacy version being phased out in favor of the unified extraction system.
#'
#' @importFrom utils write.csv
#' @param patient Character string with patient name
#' @param test Character string identifying the test type (e.g., "wisc5", "wais5")
#' @param test_name Character string with the full test name (e.g., "WISC-V", "WAIS-5")
#' @param file Character string with the path to the PDF file, or NULL to prompt for file selection
#' @param pages Numeric vector specifying which pages to extract from the PDF
#' @param extract_columns Numeric vector specifying which columns to extract
#' @param score_type Character string indicating the score type (e.g., "scaled_score", "standard_score")
#' @param variables Character vector with names for the extracted columns
#' @param lookup_table_path Character string with path to the lookup table CSV file
#' @param write_output Logical indicating whether to write output files
#' @param output_dir Character string with directory to write output files to. Default uses here::here("data", "csv") if available, otherwise file.path("data", "csv")
#' @param write_to_g Logical indicating whether to append results to g2.csv
#' @param g_filename Character string with name of the g-file to write to (without extension)
#'
#' @return A data frame with the processed test data
#' @export
#'
#' @examples
#' \dontrun{
#' # Extract WISC-V subtest data
#' wisc5_data <- extract_test_data_legacy(
#'   patient = "Biggie",
#'   test = "wisc5",
#'   test_name = "WISC-V",
#'   pages = c(30),
#'   extract_columns = c(2, 4, 5, 6),
#'   variables = c("scale", "raw_score", "score", "percentile"),
#'   score_type = "scaled_score"
#' )
#' }
extract_test_data_legacy <- function(
  patient,
  test,
  test_name,
  file = NULL,
  pages,
  extract_columns,
  score_type,
  variables,
  lookup_table_path = "~/Dropbox/neuropsych_lookup_table.csv",
  write_output = TRUE,
  output_dir = if (requireNamespace("here", quietly = TRUE)) {
    here::here("data", "csv")
  } else {
    file.path("data", "csv")
  },
  write_to_g = TRUE,
  g_filename = "g"
) {
  # Check if required packages are installed
  if (!requireNamespace("tabulapdf", quietly = TRUE)) {
    stop("Package 'tabulapdf' must be installed to use this function.")
  }
  # File path -------------------------------------------------------------
  if (is.null(file)) {
    file <- file.path(file.choose())
    saveRDS(file, paste0(test, "_path.rds"))
  }

  # Parameters -------------------------------------------------------------
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

  # Extract Areas function --------------------------------------------------
  extracted_areas <- tabulapdf::extract_areas(
    file = file,
    pages = pages,
    method = "decide",
    output = "matrix",
    copy = TRUE
  )

  # Loop and Save ---------------------------------------------------------
  if (write_output) {
    # Create output directory if it doesn't exist
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }

    # Loop over the list and write each matrix to a CSV file
    for (i in seq_along(extracted_areas)) {
      write.csv(
        extracted_areas[[i]],
        file = file.path(output_dir, paste0(test, "_", i, ".csv")),
        row.names = FALSE
      )
    }

    # Save the entire list to an R data file
    save(
      extracted_areas,
      file = file.path(output_dir, paste0(test, "_extracted_areas.rds"))
    )
  }

  # Check the extracted areas
  message("Structure of extracted areas:")
  str(extracted_areas)

  # To convert a single test using extracted areas into a single data frame
  df <- data.frame(extracted_areas)

  # Remove asterisks from the first column (wisc5)
  if (!is.null(df[, 2])) {
    df[, 2] <- gsub("\\*", "", df[, 2])
  }

  # Extract columns by position------------------------------------------------------
  extract_columns_by_position <- function(df, positions) {
    df[, positions]
  }

  # Filter dataframe to desired columns
  filtered_df <- extract_columns_by_position(df, extract_columns)
  df <- filtered_df

  # Rename the variables
  colnames(df) <- variables

  # Clean up the data
  # Step 1: Replace "-" with NA in the entire dataframe
  df[df == "-"] <- NA

  # Step 2: Convert 'raw score' 'score' and 'percentile' to numeric
  if ("raw_score" %in% colnames(df)) {
    df$raw_score <- as.numeric(df$raw_score)
  }
  if ("score" %in% colnames(df)) {
    df$score <- as.numeric(df$score)
  }
  if ("percentile" %in% colnames(df)) {
    df$percentile <- as.numeric(df$percentile)
  }

  # Step 3: Remove rows where 'score' or 'percentile' are missing
  if (all(c("score", "percentile") %in% colnames(df))) {
    df <- df[!is.na(df$score) & !is.na(df$percentile), ]
  }

  # Function to calculate 95% CI if needed ----------------------------------
  if (all(c("score") %in% colnames(df))) {
    # Determine mean and standard deviation based on score_type
    mean_val <- if (score_type == "scaled_score") 10 else 100
    sd_val <- if (score_type == "scaled_score") 3 else 15

    for (i in seq_len(nrow(df))) {
      ci_values <- calc_ci_95(
        ability_score = df$score[i],
        mean = mean_val,
        standard_deviation = sd_val,
        reliability = .90
      )
      df$true_score[i] <- ci_values["true_score"]
      df$ci_lo[i] <- ci_values["lower_ci_95"]
      df$ci_hi[i] <- ci_values["upper_ci_95"]
      df$ci_95[i] <- paste0(
        ci_values["lower_ci_95"],
        "-",
        ci_values["upper_ci_95"]
      )
    }

    df <- df |>
      dplyr::select(-c(true_score, ci_lo, ci_hi)) |>
      dplyr::relocate(ci_95, .after = score)
  }

  # Lookup Table Match ------------------------------------------------------
  # Load the lookup table
  lookup_table <- readr::read_csv(lookup_table_path)

  # Merge the data with the lookup table
  df_merged <- dplyr::mutate(df, test = test) |>
    dplyr::left_join(
      lookup_table,
      by = c("test" = "test", "scale" = "scale")
    ) |>
    dplyr::relocate(c(test, test_name), .before = scale)

  # Add missing columns
  df_mutated <- gpluck_make_columns(
    df_merged,
    range = "",
    result = "",
    absort = NULL
  )

  # Test score ranges -------------------------------------------------------
  df_mutated <- df_mutated |>
    dplyr::mutate(range = NULL) |>
    gpluck_make_score_ranges(table = df_mutated, test_type = "npsych_test") |>
    dplyr::relocate(c(range), .after = percentile)

  # Glue results for each scale ---------------------------------------------
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
    dplyr::relocate(absort, .after = result)

  # Write out final csv --------------------------------------------------
  if (write_output) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
    readr::write_excel_csv(
      df,
      file.path(output_dir, paste0(test, ".csv")),
      col_names = TRUE
    )
  }

  # Write to "g2.csv" file --------------------------------------------------
  if (write_to_g) {
    has_headers <- function(file_path) {
      if (!file.exists(file_path)) {
        return(FALSE) # File doesn't exist, headers are needed
      }
      # Check if the file has at least one line (header)
      return(length(readLines(file_path, n = 1)) > 0)
    }

    csv_file <- df
    file_path <- here::here("data", paste0(g_filename, ".csv"))

    # Create parent directory if it doesn't exist
    if (!dir.exists(dirname(file_path))) {
      dir.create(dirname(file_path), recursive = TRUE)
    }

    readr::write_excel_csv(
      csv_file,
      file_path,
      append = TRUE,
      col_names = !has_headers(file_path),
      quote = "all"
    )
  }

  # Return the final data frame
  return(df)
}
