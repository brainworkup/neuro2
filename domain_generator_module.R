#!/usr/bin/env Rscript

# DOMAIN GENERATOR MODULE
# This module generates domain-specific files for the neuropsychological report

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry)
}

log_message("Starting domain generation module", "DOMAINS")

# Load required packages
required_packages <- c("dplyr", "readr", "arrow", "yaml")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    log_message(paste("Installing package:", pkg), "DOMAINS")
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE, quietly = TRUE)
}

# Load configuration
config <- yaml::read_yaml("config.yml")
data_dir <- config$data$output_dir
data_format <- config$data$format

# Function to read data based on format
read_data_file <- function(base_name, format = data_format) {
  if (format == "all" || format == "parquet") {
    file_path <- file.path(data_dir, paste0(base_name, ".parquet"))
    if (file.exists(file_path)) {
      log_message(paste("Reading", file_path), "DOMAINS")
      return(arrow::read_parquet(file_path))
    }
  }

  if (format == "all" || format == "feather") {
    file_path <- file.path(data_dir, paste0(base_name, ".feather"))
    if (file.exists(file_path)) {
      log_message(paste("Reading", file_path), "DOMAINS")
      return(arrow::read_feather(file_path))
    }
  }

  if (format == "all" || format == "csv") {
    file_path <- file.path(data_dir, paste0(base_name, ".csv"))
    if (file.exists(file_path)) {
      log_message(paste("Reading", file_path), "DOMAINS")
      return(readr::read_csv(file_path, show_col_types = FALSE))
    }
  }

  log_message(paste("Could not find data file for", base_name), "ERROR")
  return(NULL)
}

# Read the neurocog and neurobehav data
neurocog_data <- read_data_file("neurocog")
neurobehav_data <- read_data_file("neurobehav")

if (is.null(neurocog_data) && is.null(neurobehav_data)) {
  log_message("No data available for domain generation", "ERROR")
  return(FALSE)
}

# Get unique domains
domains <- character()
if (!is.null(neurocog_data) && "domain" %in% names(neurocog_data)) {
  cog_domains <- unique(neurocog_data$domain)
  cog_domains <- cog_domains[!is.na(cog_domains)]
  domains <- c(domains, cog_domains)
}

if (!is.null(neurobehav_data) && "domain" %in% names(neurobehav_data)) {
  behav_domains <- unique(neurobehav_data$domain)
  behav_domains <- behav_domains[!is.na(behav_domains)]
  domains <- c(domains, behav_domains)
}

domains <- unique(domains)
log_message(paste("Found", length(domains), "unique domains"), "DOMAINS")

# Function to determine patient type (adult or child) based on age
determine_patient_type <- function() {
  # Read config to get patient age
  config <- yaml::read_yaml("config.yml")
  age <- config$patient$age
  
  # Default to child if age is not specified
  if (is.null(age)) {
    return("child")
  }
  
  # Determine type based on age
  if (age >= 18) {
    return("adult")
  } else {
    return("child")
  }
}

# Get patient type
patient_type <- determine_patient_type()
log_message(paste("Determined patient type:", patient_type), "DOMAINS")

# Map domains to file names based on patient type
domain_files <- list(
  "General Cognitive Ability" = "_02-01_iq.qmd",
  "Academic Skills" = "_02-02_academics.qmd",
  "Verbal/Language" = "_02-03_verbal.qmd",
  "Visual Perception/Construction" = "_02-04_spatial.qmd",
  "Memory" = "_02-05_memory.qmd",
  "Attention/Executive" = "_02-06_executive.qmd",
  "Motor" = "_02-07_motor.qmd",
  "Social Cognition" = "_02-08_social.qmd"
)

# Add ADHD domain file based on patient type
if (patient_type == "adult") {
  domain_files[["ADHD"]] <- "_02-09_adhd_adult.qmd"
} else {
  domain_files[["ADHD"]] <- "_02-09_adhd_child.qmd"
}

# Add emotion domain file based on patient type
emotion_file <- if (patient_type == "adult") "_02-10_emotion_adult.qmd" else "_02-10_emotion_child.qmd"
domain_files[["Behavioral/Emotional/Social"]] <- emotion_file

# Add other domains
domain_files[["Adaptive Functioning"]] <- "_02-11_adaptive.qmd"
domain_files[["Daily Living"]] <- "_02-12_daily_living.qmd"

# Map all behavioral domains to the emotion file
domain_files[["Psychiatric Disorders"]] <- emotion_file
domain_files[["Psychosocial Problems"]] <- emotion_file
domain_files[["Substance Use"]] <- emotion_file
domain_files[["Personality Disorders"]] <- emotion_file

# Create a basic template for each domain
domain_template <- '---
title: "{domain}"
---

# {domain}

```{r}
#| label: {label}-setup
#| include: false

# Load domain data
domain_data <- NULL
if (file.exists("data/neurocog.parquet")) {
  neurocog <- arrow::read_parquet("data/neurocog.parquet")
  domain_data <- neurocog |> dplyr::filter(domain == "{domain}")
} else if (file.exists("data/neurocog.feather")) {
  neurocog <- arrow::read_feather("data/neurocog.feather")
  domain_data <- neurocog |> dplyr::filter(domain == "{domain}")
} else if (file.exists("data/neurocog.csv")) {
  neurocog <- readr::read_csv("data/neurocog.csv", show_col_types = FALSE)
  domain_data <- neurocog |> dplyr::filter(domain == "{domain}")
}

# Check if we have behavioral data
behav_data <- NULL
if (file.exists("data/neurobehav.parquet")) {
  neurobehav <- arrow::read_parquet("data/neurobehav.parquet")
  behav_data <- neurobehav |> dplyr::filter(domain == "{domain}")
} else if (file.exists("data/neurobehav.feather")) {
  neurobehav <- arrow::read_feather("data/neurobehav.feather")
  behav_data <- neurobehav |> dplyr::filter(domain == "{domain}")
} else if (file.exists("data/neurobehav.csv")) {
  neurobehav <- readr::read_csv("data/neurobehav.csv", show_col_types = FALSE)
  behav_data <- neurobehav |> dplyr::filter(domain == "{domain}")
}
```

## Summary

This section provides a summary of {domain} assessment results.

```{r}
#| label: {label}-table
#| echo: false

if (!is.null(domain_data) && nrow(domain_data) > 0) {
  domain_data |>
    dplyr::select(test, scale, score, percentile, range) |>
    knitr::kable()
}

if (!is.null(behav_data) && nrow(behav_data) > 0) {
  behav_data |>
    dplyr::select(test, scale, score, percentile, range) |>
    knitr::kable()
}
```

## Interpretation

The {domain} assessment results indicate...

'

# Generate domain files
for (domain in domains) {
  # Get the file name for this domain
  file_name <- domain_files[[domain]]

  # If no specific file name is defined, create a generic one
  if (is.null(file_name)) {
    # Create a safe file name from the domain
    safe_name <- tolower(gsub("[^a-zA-Z0-9]", "_", domain))
    file_name <- paste0("_02-", safe_name, ".qmd")
  }

  # Create a label from the domain
  label <- tolower(gsub("[^a-zA-Z0-9]", "_", domain))

  # Fill in the template
  content <- gsub("\\{domain\\}", domain, domain_template)
  content <- gsub("\\{label\\}", label, content)

  # Write the file
  if (!file.exists(file_name)) {
    log_message(paste("Creating domain file:", file_name), "DOMAINS")
    writeLines(content, file_name)
  } else {
    log_message(paste("Domain file already exists:", file_name), "DOMAINS")
  }
}

log_message("Domain generation complete", "DOMAINS")
return(TRUE)
