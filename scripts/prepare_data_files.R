#!/usr/bin/env Rscript

# This script prepares the required data files for the report generation
# It creates neurocog.csv, neurobehav.csv, neuropsych.csv, and validity.csv from existing data

library(dplyr)
library(readr)
library(purrr)
library(tidyr)
library(here)

message("Preparing necessary data files...")

# Create output directories
execute_dir <- here::here("execute")
if (!dir.exists(execute_dir)) {
  dir.create(execute_dir, recursive = TRUE)
}

# Path to CSV files
data_csv_dir <- here::here("data", "csv")

# Check if data directory exists
if (!dir.exists(data_csv_dir)) {
  stop("Data directory not found: ", data_csv_dir)
}

# List all CSV files
csv_files <- list.files(
  path = data_csv_dir,
  pattern = "\\.csv$",
  full.names = TRUE
)

if (length(csv_files) == 0) {
  stop("No CSV files found in: ", data_csv_dir)
}

# Read all CSV files into a list of data frames
csv_data <- purrr::map(csv_files, function(file) {
  message("Reading: ", basename(file))
  tryCatch(
    {
      data <- readr::read_csv(file, show_col_types = FALSE)
      data$source_file <- basename(file)
      return(data)
    },
    error = function(e) {
      message("Error reading ", basename(file), ": ", e$message)
      return(NULL)
    }
  )
})

# Remove NULL entries
csv_data <- purrr::compact(csv_data)

# Check if we have any data
if (length(csv_data) == 0) {
  stop("No valid CSV data found in: ", data_csv_dir)
}

# Combine all data
all_data <- dplyr::bind_rows(csv_data)

# Create neuropsych.csv - all test data
neuropsych <- all_data |>
  dplyr::mutate(
    # Ensure all required columns exist
    test = if ("test" %in% names(.)) test else NA_character_,
    test_name = if ("test_name" %in% names(.)) test_name else NA_character_,
    test_type = if ("test_type" %in% names(.)) test_type else "npsych_test",
    scale = if ("scale" %in% names(.)) scale else NA_character_,
    score = if ("score" %in% names(.)) score else NA_real_,
    percentile = if ("percentile" %in% names(.)) percentile else NA_real_,
    domain = if ("domain" %in% names(.)) domain else NA_character_,
    subdomain = if ("subdomain" %in% names(.)) subdomain else NA_character_,
    narrow = if ("narrow" %in% names(.)) narrow else NA_character_,
    z = if ("z" %in% names(.)) z else NA_real_,
    pass = if ("pass" %in% names(.)) pass else NA_character_,
    verbal = if ("verbal" %in% names(.)) verbal else NA_character_,
    timed = if ("timed" %in% names(.)) timed else NA_character_
  )

# Create neurocog.csv - cognitive tests
neurocog <- neuropsych |>
  dplyr::filter(
    !is.na(test_type) &
      (test_type == "npsych_test" |
        grepl(
          "cognitive|intelligence|memory|attention|executive|processing|motor|visual|spatial|verbal|language",
          tolower(domain),
          ignore.case = TRUE
        ))
  ) |>
  # Calculate z-scores if percentile is available but z is not
  dplyr::mutate(
    z = ifelse(
      !is.na(percentile) & (is.na(z) | z == 0),
      qnorm(percentile / 100),
      z
    )
  ) |>
  # Force character columns to be character
  dplyr::mutate(
    domain = as.character(domain),
    subdomain = as.character(subdomain),
    narrow = as.character(narrow),
    pass = as.character(pass),
    verbal = as.character(verbal),
    timed = as.character(timed)
  )

# Calculate domain, subdomain, and narrow means and SDs
neurocog <- neurocog |>
  # domain
  dplyr::group_by(domain) |>
  dplyr::mutate(
    z_mean_domain = mean(z, na.rm = TRUE),
    z_sd_domain = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # subdomain
  dplyr::group_by(subdomain) |>
  dplyr::mutate(
    z_mean_subdomain = mean(z, na.rm = TRUE),
    z_sd_subdomain = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # narrow
  dplyr::group_by(narrow) |>
  dplyr::mutate(
    z_mean_narrow = mean(z, na.rm = TRUE),
    z_sd_narrow = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # pass
  dplyr::group_by(pass) |>
  dplyr::mutate(
    z_mean_pass = mean(z, na.rm = TRUE),
    z_sd_pass = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # verbal
  dplyr::group_by(verbal) |>
  dplyr::mutate(
    z_mean_verbal = mean(z, na.rm = TRUE),
    z_sd_verbal = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # timed
  dplyr::group_by(timed) |>
  dplyr::mutate(
    z_mean_timed = mean(z, na.rm = TRUE),
    z_sd_timed = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup()

# Create neurobehav.csv - behavioral/rating scales
neurobehav <- neuropsych |>
  dplyr::filter(
    !is.na(test_type) &
      (test_type == "rating_scale" |
        grepl(
          "emotional|behavior|social|adaptive|personality|psychiatric",
          tolower(domain),
          ignore.case = TRUE
        ))
  ) |>
  # Calculate z-scores if percentile is available but z is not
  dplyr::mutate(
    z = ifelse(
      !is.na(percentile) & (is.na(z) | z == 0),
      qnorm(percentile / 100),
      z
    )
  ) |>
  # Force character columns to be character
  dplyr::mutate(
    domain = as.character(domain),
    subdomain = as.character(subdomain),
    narrow = as.character(narrow),
    pass = as.character(pass),
    verbal = as.character(verbal),
    timed = as.character(timed)
  )

# Calculate domain, subdomain, and narrow means and SDs for neurobehav
neurobehav <- neurobehav |>
  # domain
  dplyr::group_by(domain) |>
  dplyr::mutate(
    z_mean_domain = mean(z, na.rm = TRUE),
    z_sd_domain = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # subdomain
  dplyr::group_by(subdomain) |>
  dplyr::mutate(
    z_mean_subdomain = mean(z, na.rm = TRUE),
    z_sd_subdomain = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # narrow
  dplyr::group_by(narrow) |>
  dplyr::mutate(
    z_mean_narrow = mean(z, na.rm = TRUE),
    z_sd_narrow = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup()

# Create validity.csv - validity measures
validity <- neuropsych |>
  dplyr::filter(
    !is.na(test_type) &
      (test_type %in%
        c("performance_validity", "symptom_validity") |
        grepl(
          "validity|effort|response|consistency",
          tolower(test_name),
          ignore.case = TRUE
        ) |
        grepl(
          "validity|effort|response|consistency",
          tolower(scale),
          ignore.case = TRUE
        ))
  ) |>
  # Calculate z-scores if percentile is available but z is not
  dplyr::mutate(
    z = ifelse(
      !is.na(percentile) & (is.na(z) | z == 0),
      qnorm(percentile / 100),
      z
    )
  ) |>
  # Force character columns to be character
  dplyr::mutate(
    domain = as.character(domain),
    subdomain = as.character(subdomain),
    narrow = as.character(narrow),
    pass = as.character(pass),
    verbal = as.character(verbal),
    timed = as.character(timed)
  ) |>
  # domain
  dplyr::group_by(domain) |>
  dplyr::mutate(
    z_mean_domain = mean(z, na.rm = TRUE),
    z_sd_domain = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # subdomain
  dplyr::group_by(subdomain) |>
  dplyr::mutate(
    z_mean_subdomain = mean(z, na.rm = TRUE),
    z_sd_subdomain = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # narrow
  dplyr::group_by(narrow) |>
  dplyr::mutate(
    z_mean_narrow = mean(z, na.rm = TRUE),
    z_sd_narrow = sd(z, na.rm = TRUE)
  ) |>
  dplyr::ungroup()

# Write the files to the execute directory
readr::write_csv(neuropsych, file.path(execute_dir, "neuropsych.csv"))
readr::write_csv(neurocog, file.path(execute_dir, "neurocog.csv"))
readr::write_csv(neurobehav, file.path(execute_dir, "neurobehav.csv"))
readr::write_csv(validity, file.path(execute_dir, "validity.csv"))

# If index_scores.xlsx exists, copy it to the execute directory
index_scores_path <- here::here("data", "index_scores.xlsx")
if (file.exists(index_scores_path)) {
  file.copy(
    index_scores_path,
    file.path(execute_dir, "index_scores.xlsx"),
    overwrite = TRUE
  )
  message("Copied index_scores.xlsx to execute directory")
} else {
  message("Warning: index_scores.xlsx not found at: ", index_scores_path)
}

message("Data preparation complete - files written to: ", execute_dir)
