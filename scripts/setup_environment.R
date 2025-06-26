#!/usr/bin/env Rscript

# This script runs the setup code from template.qmd to prepare the environment
# before processing domains and rendering the report

message("Setting up R environment and loading data...")

packages <- c(
  "dplyr",
  "glue",
  "gt",
  "here",
  "janitor",
  "knitr",
  "purrr",
  "quarto",
  "readr",
  "readxl",
  "rmarkdown",
  "snakecase",
  "stringr",
  "tidytable",
  "vroom",
  "xfun",
  "NeurotypR",
  "NeurotypR"
)

# Function to load packages one by one
load_packages <- function(packages) {
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE)) {
      install.packages(pkg)
      library(pkg, character.only = TRUE)
    }
    message(paste("Loaded package:", pkg))
  }
}

# Call the function to load packages
load_packages(packages)

# Set knitr options
knitr::opts_knit$set(
  width = 80,
  digits = 2,
  warnPartialMatchArgs = FALSE,
  crop = knitr::hook_pdfcrop,
  optipng = knitr::hook_optipng
)

# Set environment variables with default values
Sys.setenv(PATIENT = "{{< var patient >}}")
patient <- Sys.getenv("PATIENT")

# Load data
path_csv <- here::here("data", "csv")
if (dir.exists(path_csv)) {
  message("Loading data from: ", path_csv)

  # Source the local data.R file to get the load_data function
  # source(here::here("data.R"))

  # Call the local load_data function
  load_data(path_csv)

  # Create symbolic links to CSV files in the qmd directory
  path_data <- here::here("data")
  if (!dir.exists(path_data)) {
    dir.create(path_data, recursive = TRUE)
  }

  # The load_data function should have created these files in the data directory
  # Check if they exist and report status
  for (file in c(
    "neurocog.csv",
    "neurobehav.csv",
    "neuropsych.csv",
    "validity.csv"
  )) {
    target_file <- file.path(path_data, file)

    if (file.exists(target_file)) {
      message("Generated file found: ", target_file)
    } else {
      message("Warning: Generated file not found: ", target_file)
    }
  }
} else {
  message("Warning: Data directory not found: ", path_csv)
}

# Create a stamp file to signal completion
stamp_file <- here::here("output", "setup_completed.stamp")
dir.create(dirname(stamp_file), recursive = TRUE, showWarnings = FALSE)
file.create(stamp_file)
message("Environment setup completed. Stamp file created: ", stamp_file)
