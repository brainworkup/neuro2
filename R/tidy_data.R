#' @title Helper function to calculate z-score statistics by grouping variables
#' @description Efficiently calculates mean and standard deviation of z-scores for specified grouping variables
#' @importFrom dplyr group_by mutate ungroup across all_of
#' @importFrom stats sd
#' @importFrom rlang :=
#' @param data A dataframe containing z-scores
#' @param group_vars Character vector of column names to group by
#' @return Dataframe with added z-score statistics columns
#' @keywords internal
calculate_z_stats <- function(data, group_vars) {
  # Filter out NA group variables to avoid unnecessary computations
  valid_vars <- group_vars[group_vars %in% names(data)]

  if (length(valid_vars) == 0) {
    return(data)
  }

  # Calculate statistics for each grouping variable
  for (var in valid_vars) {
    # Skip if variable is all NA
    if (all(is.na(data[[var]]))) {
      next
    }

    data <- data |>
      dplyr::group_by(dplyr::across(dplyr::all_of(var)), .add = TRUE) |>
      dplyr::mutate(
        !!paste0("z_mean_", var) := mean(z, na.rm = TRUE),
        !!paste0("z_sd_", var) := sd(z, na.rm = TRUE)
      ) |>
      dplyr::ungroup()
  }

  return(data)
}


#' @title Read/Load Neuropsych Eval CSV Files
#' @description This function reads .csv files of patient data and writes four different files of the same data that are categorized by neuropsychological test type.
#' @importFrom here here
#' @importFrom dplyr filter distinct mutate
#' @importFrom stats qnorm
#' @importFrom readr write_excel_csv
#' @param file_path character, Name of patient file path
#' @param output_dir character, Directory to write output files (default: current working directory)
#' @param return_data logical, Whether to return the processed data as a list (default: FALSE)
#' @return If return_data is TRUE, returns a list with 4 elements (neuropsych, neurocog, neurobehav, validity). Otherwise, returns NULL and writes CSV files.
#' @rdname load_data
#' @export
load_data <- function(
  file_path,
  output_dir = here::here("data"),
  return_data = FALSE
) {
  # Input validation
  if (missing(file_path)) {
    stop("Patient/file path must be specified.")
  }

  if (!dir.exists(file_path)) {
    stop("Specified file_path does not exist: ", file_path)
  }

  if (!dir.exists(output_dir)) {
    stop("Specified output_dir does not exist: ", output_dir)
  }

  # Get CSV files
  files <- dir(file_path, pattern = "*.csv", full.names = TRUE)

  # Read and combine files using the utility function
  neuropsych <- read_multiple_csv(files, .id = "filename") |> dplyr::distinct()

  # Validate required columns
  required_cols <- c("test_type")
  missing_cols <- setdiff(required_cols, names(neuropsych))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Process data: calculate z-scores and convert character columns
  neuropsych <- neuropsych |>
    dplyr::mutate(
      # Calculate z-scores if percentile exists
      z = if ("percentile" %in% names(neuropsych)) {
        ifelse(!is.na(percentile), qnorm(percentile / 100), NA_real_)
      } else {
        NA_real_
      },
      # Convert to character (only if columns exist)
      dplyr::across(
        dplyr::any_of(c(
          "domain",
          "subdomain",
          "narrow",
          "pass",
          "verbal",
          "timed"
        )),
        as.character
      )
    )

  # Define grouping variables for different test types
  neurocog_groups <- c(
    "domain",
    "subdomain",
    "narrow",
    "pass",
    "verbal",
    "timed"
  )
  neurobehav_groups <- c("domain", "subdomain", "narrow")
  validity_groups <- c("domain", "subdomain", "narrow")

  # Process neurocognitive data
  neurocog <- neuropsych |>
    dplyr::filter(test_type == "npsych_test") |>
    calculate_z_stats(neurocog_groups)

  # Process neurobehavioral data
  neurobehav <- neuropsych |>
    dplyr::filter(test_type == "rating_scale") |>
    calculate_z_stats(neurobehav_groups)

  # Process validity data
  validity <- neuropsych |>
    dplyr::filter(
      test_type %in% c("performance_validity", "symptom_validity")
    ) |>
    calculate_z_stats(validity_groups)

  # Prepare output
  result_list <- list(
    neuropsych = neuropsych,
    neurocog = neurocog,
    neurobehav = neurobehav,
    validity = validity
  )

  # Write files if not returning data
  if (!return_data) {
    file_paths <- list(
      neuropsych = file.path(output_dir, "neuropsych.csv"),
      neurocog = file.path(output_dir, "neurocog.csv"),
      neurobehav = file.path(output_dir, "neurobehav.csv"),
      validity = file.path(output_dir, "validity.csv")
    )

    # Write files with error handling
    tryCatch(
      {
        readr::write_excel_csv(result_list$neuropsych, file_paths$neuropsych)
        readr::write_excel_csv(result_list$neurocog, file_paths$neurocog)
        readr::write_excel_csv(result_list$neurobehav, file_paths$neurobehav)
        readr::write_excel_csv(result_list$validity, file_paths$validity)

        message("Successfully wrote files to: ", output_dir)
      },
      error = function(e) {
        stop("Failed to write output files: ", e$message)
      }
    )

    return(invisible(NULL))
  }

  return(result_list)
}

#' @title Filters Data by Domain and Scale
#' @description This function filters a dataframe by domain and scale.
#' @importFrom dplyr filter
#' @param data A dataframe or tibble
#' @param domains Character vector of domain names to filter by
#' @param scales Character vector of scale names to filter by
#' @return Returns a filtered data frame
#' @rdname filter_data
#' @export
filter_data <- function(data, domains = NULL, scales = NULL) {
  # Input validation
  if (is.null(data) || nrow(data) == 0) {
    # Silently return an empty data frame with expected columns
    # This avoids warnings that might be converted to errors during report generation
    return(data.frame(
      domain = character(0),
      scale = character(0),
      score = numeric(0),
      percentile = numeric(0),
      z = numeric(0),
      subdomain = character(0),
      narrow = character(0),
      pass = character(0),
      verbal = character(0),
      timed = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Check if required columns exist
  if (!is.null(domains) && !"domain" %in% names(data)) {
    stop("Column 'domain' not found in data")
  }

  if (!is.null(scales) && !"scale" %in% names(data)) {
    stop("Column 'scale' not found in data")
  }

  # Apply filters
  if (!is.null(domains)) {
    data <- data |> dplyr::filter(domain %in% domains)
  }

  if (!is.null(scales)) {
    data <- data |> dplyr::filter(scale %in% scales)
  }

  return(data)
}
