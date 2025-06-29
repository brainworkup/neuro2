# Import and Process Data Files for Biggie's Neuropsych Report
# This script imports individual CSV files and creates neurocog and neurobehav datasets

library(tidyverse)
library(here)
library(readr)
library(dplyr)

# Set patient parameters
patient_name <- "Biggie"
patient_age <- 44
patient_sex <- "Male"
template_type <- "forensic"

# Function to read and standardize CSV files
read_and_standardize <- function(file_path, test_type) {
  data <- read_csv(file_path, show_col_types = FALSE)

  # Add test type column if not present
  if (!"test_type" %in% colnames(data)) {
    data$test_type <- test_type
  }

  # Standardize column names
  data <- data |> janitor::clean_names()

  return(data)
}

# Create output directories if they don't exist
dir.create("data", showWarnings = FALSE)
dir.create("data-raw", showWarnings = FALSE)
dir.create("output", showWarnings = FALSE)

# Import cognitive test data
neurocog_files <- list(
  wais5 = "data-raw/wais5.csv",
  nabs = "data-raw/nabs.csv",
  cvlt3 = "data-raw/cvlt3_brief.csv",
  dkefs = "data-raw/dkefs.csv",
  rocft = "data-raw/rocft.csv",
  wiat4 = "data-raw/wiat4.csv",
  topf = "data-raw/topf.csv",
  examiner = "data-raw/examiner.csv"
)

# Import behavioral/personality data
neurobehav_files <- list(
  caars2_self = "data-raw/caars2_self.csv",
  caars2_observer = "data-raw/caars2_observer.csv",
  cefi_self = "data-raw/cefi_self.csv",
  cefi_observer = "data-raw/cefi_observer.csv",
  pai_clinical = "data-raw/pai_clinical.csv",
  pai_validity = "data-raw/pai_validity.csv",
  pai_inatt = "data-raw/pai_inatt.csv"
)

# Process neurocog data
neurocog_list <- list()
for (test_name in names(neurocog_files)) {
  file_path <- neurocog_files[[test_name]]
  if (file.exists(file_path)) {
    neurocog_list[[test_name]] <- read_and_standardize(file_path, "cognitive")
    message(paste("✓ Loaded", test_name))
  } else {
    warning(paste("File not found:", file_path))
  }
}

# Process neurobehav data
neurobehav_list <- list()
for (test_name in names(neurobehav_files)) {
  file_path <- neurobehav_files[[test_name]]
  if (file.exists(file_path)) {
    neurobehav_list[[test_name]] <- read_and_standardize(
      file_path,
      "behavioral"
    )
    message(paste("✓ Loaded", test_name))
  } else {
    warning(paste("File not found:", file_path))
  }
}

# Combine neurocog data
neurocog <- bind_rows(neurocog_list, .id = "source_test")

# Combine neurobehav data
neurobehav <- bind_rows(neurobehav_list, .id = "source_test")

# Add patient information
neurocog <- neurocog |>
  dplyr::mutate(
    patient_name = patient_name,
    patient_age = patient_age,
    patient_sex = patient_sex,
    date_tested = Sys.Date()
  )

neurobehav <- neurobehav |>
  dplyr::mutate(
    patient_name = patient_name,
    patient_age = patient_age,
    patient_sex = patient_sex,
    date_tested = Sys.Date()
  )

# Compute domain scores if columns exist
compute_domain_scores <- function(data) {
  # Check for required columns
  required_cols <- c("test", "scale", "score", "percentile")
  has_required <- all(required_cols %in% colnames(data))

  if (!has_required) {
    message("Warning: Missing required columns for domain computation")
    return(data)
  }

  # Add z-score calculation if not present
  if (!"z" %in% colnames(data)) {
    data <- data |>
      dplyr::mutate(
        z = case_when(
          !is.na(percentile) ~ qnorm(percentile / 100),
          !is.na(score) & score_type == "t_score" ~ (score - 50) / 10,
          !is.na(score) & score_type == "standard_score" ~ (score - 100) / 15,
          !is.na(score) & score_type == "scaled_score" ~ (score - 10) / 3,
          TRUE ~ NA_real_
        )
      )
  }

  # Compute domain means if domain column exists
  if ("domain" %in% colnames(data)) {
    data <- data |>
      dplyr::group_by(domain) |>
      dplyr::mutate(
        z_mean_domain = mean(z, na.rm = TRUE),
        z_sd_domain = sd(z, na.rm = TRUE)
      ) |>
      ungroup()
  }

  # Compute subdomain means if subdomain column exists
  if ("subdomain" %in% colnames(data)) {
    data <- data |>
      dplyr::group_by(subdomain) |>
      dplyr::mutate(
        z_mean_subdomain = mean(z, na.rm = TRUE),
        z_sd_subdomain = sd(z, na.rm = TRUE)
      ) |>
      ungroup()
  }

  # Compute narrow means if narrow column exists
  if ("narrow" %in% colnames(data)) {
    data <- data |>
      dplyr::group_by(narrow) |>
      dplyr::mutate(
        z_mean_narrow = mean(z, na.rm = TRUE),
        z_sd_narrow = sd(z, na.rm = TRUE)
      ) |>
      ungroup()
  }

  # Compute pass means if pass column exists
  if ("pass" %in% colnames(data)) {
    data <- data |>
      dplyr::group_by(pass) |>
      dplyr::mutate(
        z_mean_pass = mean(z, na.rm = TRUE),
        z_sd_pass = sd(z, na.rm = TRUE)
      ) |>
      ungroup()
  }

  # Compute verbal means if verbal column exists
  if ("verbal" %in% colnames(data)) {
    data <- data |>
      dplyr::group_by(verbal) |>
      dplyr::mutate(
        z_mean_verbal = mean(z, na.rm = TRUE),
        z_sd_verbal = sd(z, na.rm = TRUE)
      ) |>
      ungroup()
  }

  # Compute timed means if timed column exists
  if ("timed" %in% colnames(data)) {
    data <- data |>
      dplyr::group_by(timed) |>
      dplyr::mutate(
        z_mean_timed = mean(z, na.rm = TRUE),
        z_sd_timed = sd(z, na.rm = TRUE)
      ) |>
      ungroup()
  }

  return(data)
}

# Apply domain score computation
neurocog <- compute_domain_scores(neurocog)
neurobehav <- compute_domain_scores(neurobehav)

# Save processed data
write_csv(neurocog, "data/neurocog.csv")
write_csv(neurobehav, "data/neurobehav.csv")

message("\n✅ Data import and processing complete!")
message(paste("Neurocog records:", nrow(neurocog)))
message(paste("Neurobehav records:", nrow(neurobehav)))

# Create a combined neuropsych dataset for some analyses
neuropsych <- bind_rows(
  neurocog |> dplyr::mutate(data_type = "cognitive"),
  neurobehav |> dplyr::mutate(data_type = "behavioral")
)

write_csv(neuropsych, "data/neuropsych.csv")

# Print summary of domains
if ("domain" %in% colnames(neurocog)) {
  message("\nCognitive domains found:")
  print(table(neurocog$domain))
}

if ("domain" %in% colnames(neurobehav)) {
  message("\nBehavioral domains found:")
  print(table(neurobehav$domain))
}
