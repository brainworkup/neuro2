# Current R function to load and process data using traditional approach
read_and_combine_files <- function(files) {
  if (length(files) == 0) {
    stop("No CSV files found in the specified directory.")
  }

  # Read files with error handling
  data_list <- purrr::map(files, function(filename) {
    tryCatch(
      {
        data <- readr::read_csv(
          filename,
          na = c("", "NA", "--", "-"),
          show_col_types = FALSE
        )
        data$filename <- basename(filename)
        return(data)
      },
      error = function(e) {
        warning(paste("Failed to read file:", filename, "-", e$message))
        return(NULL)
      }
    )
  })

  # Remove NULL entries (failed reads)
  data_list <- data_list[!sapply(data_list, is.null)]

  if (length(data_list) == 0) {
    stop("No files could be successfully read.")
  }

  # Combine using list_rbind for better performance
  combined_data <- purrr::list_rbind(data_list)

  return(combined_data)
}

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

  # Read and combine files
  neuropsych <- read_and_combine_files(files) |> dplyr::distinct()

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
# Traditional approach - loads everything into memory
neurobehav <- read.csv("data/neurobehav.csv")
neurocog <- read.csv("data/neurocog.csv")
validity <- read.csv("data/validity.csv")

# Then filter for your analysis
adhd <- neurobehav %>% filter(domain == "ADHD")

# Create new duckDB approach

library(duckdb)
library(tidyverse)

# Create a connection - this is like opening a workspace
con <- dbConnect(duckdb())

# Here's the magic - query CSVs directly without loading them
adhd_subset <- dbGetQuery(
  con,
  "
  SELECT 
    d.participant_id,
    d.age,
    d.sex,
    w.fsiq,  -- Full Scale IQ
    w.vci,   -- Verbal Comprehension Index
    w.wmi,   -- Working Memory Index
    dk.trails_switching,
    dk.color_word_interference,
    a.inattention_score,
    a.hyperactivity_score
  FROM 'demographics.csv' d
  LEFT JOIN 'wais_scores.csv' w ON d.participant_id = w.participant_id
  LEFT JOIN 'dkefs_scores.csv' dk ON d.participant_id = dk.participant_id
  LEFT JOIN 'adhd_ratings.csv' a ON d.participant_id = a.participant_id
  WHERE d.adhd_diagnosis = 'Combined' 
    AND d.age >= 8 
    AND d.age <= 12
"
)

# Create a lazy reference to a table
adhd_table <- tbl(con, "adhd_ratings")

# Use familiar dplyr syntax - DuckDB translates this to SQL behind the scenes
symptom_summary <- adhd_table %>%
  group_by(adhd_subtype) %>%
  summarise(
    n = n(),
    mean_inattention = mean(inattention_score, na.rm = TRUE),
    mean_hyperactivity = mean(hyperactivity_score, na.rm = TRUE),
    sd_inattention = sd(inattention_score, na.rm = TRUE)
  ) %>%
  collect() # This brings results into R

# For visualization, you can query directly into ggplot
dbGetQuery(
  con,
  "
  SELECT age, fsiq, adhd_subtype
  FROM demographics d
  JOIN wais_scores w ON d.participant_id = w.participant_id
  WHERE age BETWEEN 6 AND 18
"
) %>%
  ggplot(aes(x = age, y = fsiq, color = adhd_subtype)) +
  geom_point() +
  geom_smooth(method = "lm") +
  theme_minimal()
