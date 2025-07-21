#!/usr/bin/env Rscript

# Demonstrate how dynamic domain generation works based on test data

library(dplyr)
library(readr)
library(purrr)

# Function to extract unique domains from CSV files
extract_domains_from_data <- function(data_dir = "data-raw/csv/") {
  # Get all CSV files
  csv_files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)

  # Read all CSV files and extract unique domains
  all_domains <- map_dfr(csv_files, function(file) {
    cat("Reading:", basename(file), "\n")
    data <- read_csv(file, show_col_types = FALSE)

    # Debug output
    cat(
      "Column names in",
      basename(file),
      ":",
      paste(names(data), collapse = ", "),
      "\n"
    )
    cat("Has 'domain' column:", "domain" %in% names(data), "\n")

    if ("domain" %in% names(data)) {
      result <- tibble(file = basename(file), domain = unique(data$domain))
      cat("Found domains:", paste(unique(data$domain), collapse = ", "), "\n")
      return(result)
    } else {
      cat("No domain column found in", basename(file), "\n")
      return(tibble(file = basename(file), domain = character()))
    }
  })

  # Get unique domains across all files
  unique_domains <- sort(unique(all_domains$domain))

  # Debug output
  cat("\nAll domains data frame structure:\n")
  str(all_domains)
  cat("\nUnique domains:", paste(unique_domains, collapse = ", "), "\n")

  # Show which files contain which domains
  cat("\n--- Domains by file ---\n")
  # Check if 'file' column exists
  if (!"file" %in% names(all_domains)) {
    cat("ERROR: 'file' column is missing from all_domains data frame\n")
    print(all_domains)
    return(list(domains = character(), domain_files = all_domains))
  }

  domains_by_file <- all_domains %>%
    group_by(file) %>%
    summarise(domains = paste(domain, collapse = ", "))

  print(domains_by_file)

  cat("\n--- All unique domains found ---\n")
  print(unique_domains)

  return(list(domains = unique_domains, domain_files = all_domains))
}

# Function to generate domain files dynamically
generate_dynamic_domain_files <- function(domains, domain_order = NULL) {
  # Define the canonical order of domains (can be customized)
  if (is.null(domain_order)) {
    domain_order <- c(
      "General Cognitive Ability", # 01 - IQ
      "Academic Skills", # 02 - Academics
      "Verbal/Language", # 03 - Verbal
      "Visual Perception/Construction", # 04 - Spatial
      "Memory", # 05 - Memory
      "Attention/Executive", # 06 - Executive
      "Motor", # 07 - Motor
      "Social Cognition", # 08 - Social
      "ADHD", # 09 - ADHD
      "Emotional/Behavioral/Personality", # 10 - Emotion
      "Behavioral/Emotional/Social", # 10 - Emotion (alt)
      "Psychiatric Disorders", # 10 - Emotion (alt)
      "Personality Disorders", # 10 - Emotion (alt)
      "Substance Use", # 10 - Emotion (alt)
      "Psychosocial Problems", # 10 - Emotion (alt)
      "Adaptive Functioning", # 11 - Adaptive
      "Daily Living" # 12 - Daily Living
    )
  }

  # Map domains to phenotypes
  domain_to_pheno <- list(
    "General Cognitive Ability" = "iq",
    "Academic Skills" = "academics",
    "Verbal/Language" = "verbal",
    "Visual Perception/Construction" = "spatial",
    "Memory" = "memory",
    "Attention/Executive" = "executive",
    "Motor" = "motor",
    "Social Cognition" = "social",
    "ADHD" = "adhd",
    "Emotional/Behavioral/Personality" = "emotion",
    "Behavioral/Emotional/Social" = "emotion",
    "Psychiatric Disorders" = "emotion",
    "Personality Disorders" = "emotion",
    "Substance Use" = "emotion",
    "Psychosocial Problems" = "emotion",
    "Adaptive Functioning" = "adaptive",
    "Daily Living" = "daily_living"
  )

  # Filter to only domains that exist in the data
  existing_domains <- intersect(domain_order, domains)

  cat("\n--- Domain files to be generated ---\n")

  # Generate file names based on order
  domain_files <- tibble(
    domain = existing_domains,
    pheno = map_chr(existing_domains, ~ domain_to_pheno[[.x]] %||% "unknown"),
    order = seq_along(existing_domains),
    domain_file = sprintf(
      "_02-%02d_%s.qmd",
      seq_along(existing_domains),
      pheno
    ),
    text_file = sprintf(
      "_02-%02d_%s_text.qmd",
      seq_along(existing_domains),
      pheno
    )
  )

  print(domain_files)

  return(domain_files)
}

# Main execution
cat("=== Dynamic Domain Generation Demo ===\n\n")

# Extract domains from actual data
domain_info <- extract_domains_from_data()

# Generate domain files based on what's in the data
domain_files <- generate_dynamic_domain_files(domain_info$domains)

cat("\n=== Summary ===\n")
cat("Total unique domains found:", length(domain_info$domains), "\n")
cat("Domain files to generate:", nrow(domain_files), "\n")
cat("\nThis demonstrates how domain files are generated dynamically based on\n")
cat(
  "the actual test data present in the CSV files, maintaining the canonical\n"
)
cat("order while only including domains that have data.\n")
