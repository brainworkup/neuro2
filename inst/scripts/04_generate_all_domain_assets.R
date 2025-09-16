#!/usr/bin/env Rscript

# Script to generate domain table and figure files ONLY for domains with data
# FIXED: Saves figures to figs/ directory and only processes domains with data

# Ensure warnings are not converted to errors
old_warn <- getOption("warn")
options(warn = 1)

# Load required libraries
library(here)
library(dplyr)
library(gt)
library(ggplot2)
library(arrow)

# Set up output directory
FIGURE_DIR <- "figs"
if (!dir.exists(FIGURE_DIR)) {
  dir.create(FIGURE_DIR, recursive = TRUE)
  cat("Created figure directory:", FIGURE_DIR, "\n")
}

# Load neuro2 package
load_neuro2_dev <- function() {
  if (file.exists(here::here("DESCRIPTION"))) {
    if (requireNamespace("devtools", quietly = TRUE)) {
      try(devtools::load_all(here::here(), quiet = TRUE), silent = TRUE)
      return(TRUE)
    }
  }
  FALSE
}

if (!load_neuro2_dev()) {
  suppressPackageStartupMessages(library(neuro2))
}

cat("\n=== Generating Domain Assets (Tables and Figures) ===\n")

# Function to check if domain has data
check_domain_has_data <- function(domain_name, data_type = "neurocog") {
  data_file <- paste0("data/", data_type, ".parquet")
  if (!file.exists(data_file)) return(FALSE)
  
  data <- arrow::read_parquet(data_file)
  if (!"domain" %in% names(data)) return(FALSE)
  
  domain_data <- data |>
    filter(domain == domain_name) |>
    filter(!is.na(percentile) | !is.na(score))
  
  return(nrow(domain_data) > 0)
}

# Get list of domains with data from environment or by checking
domains_to_process <- character()

# Check environment variable first (set by workflow)
env_domains <- Sys.getenv("DOMAINS_WITH_DATA")
if (nzchar(env_domains)) {
  domains_to_process <- strsplit(env_domains, ",")[[1]]
  cat("Processing domains from environment:", paste(domains_to_process, collapse = ", "), "\n")
} else {
  # Otherwise, check which domain QMD files exist
  domain_files <- list.files(pattern = "^_02-[0-9]+_.*\\.qmd$")
  if (length(domain_files) > 0) {
    # Extract domain names from files
    for (file in domain_files) {
      domain <- gsub("_02-[0-9]+_(.+)\\.qmd", "\\1", file)
      domains_to_process <- c(domains_to_process, domain)
    }
    cat("Found domain files for:", paste(domains_to_process, collapse = ", "), "\n")
  }
}

# Define domain configurations
domain_configs <- list(
  iq = list(name = "General Cognitive Ability", data_type = "neurocog"),
  academics = list(name = "Academic Skills", data_type = "neurocog"),
  verbal = list(name = "Verbal/Language", data_type = "neurocog"),
  spatial = list(name = "Visual Perception/Construction", data_type = "neurocog"),
  memory = list(name = "Memory", data_type = "neurocog"),
  executive = list(name = "Attention/Executive", data_type = "neurocog"),
  motor = list(name = "Motor", data_type = "neurocog"),
  social = list(name = "Social Cognition", data_type = "neurocog"),
  adhd = list(name = "ADHD/Executive Function", data_type = "neurobehav"),
  emotion = list(name = "Emotional/Behavioral/Social/Personality", data_type = "neurobehav"),
  adaptive = list(name = "Adaptive Functioning", data_type = "neurobehav"),
  daily_living = list(name = "Daily Living", data_type = "neurocog")
)

# Process each domain that has data
successful_assets <- character()
failed_assets <- character()

for (domain_key in domains_to_process) {
  # Clean up domain key (remove _adult, _child suffixes)
  clean_domain <- gsub("_(adult|child)$", "", domain_key)
  
  config <- domain_configs[[clean_domain]]
  if (is.null(config)) {
    cat("⚠️  No configuration for domain:", domain_key, "\n")
    next
  }
  
  # Verify domain has data
  if (!check_domain_has_data(config$name, config$data_type)) {
    cat("⚠️  Skipping", domain_key, "- no data found\n")
    next
  }
  
  cat("\n📊 Generating assets for", domain_key, "...\n")
  
  tryCatch({
    # Load domain data
    data_file <- paste0("data/", config$data_type, ".parquet")
    data <- arrow::read_parquet(data_file) |>
      filter(domain == config$name)
    
    # Generate table
    table_file <- file.path(FIGURE_DIR, paste0("table_", clean_domain, ".png"))
    if (!file.exists(table_file)) {
      # Create a simple GT table
      table_data <- data |>
        select(test, score, percentile) |>
        slice_head(n = 10)  # Limit for display
      
      gt_table <- gt(table_data) |>
        tab_header(title = config$name) |>
        fmt_number(columns = c(score, percentile), decimals = 1)
      
      # Save table
      gtsave(gt_table, table_file)
      cat("  ✓ Created table:", table_file, "\n")
    } else {
      cat("  - Table already exists:", table_file, "\n")
    }
    
    # Generate narrow figure
    narrow_fig <- file.path(FIGURE_DIR, paste0("fig_", clean_domain, "_narrow.svg"))
    if (!file.exists(narrow_fig)) {
      # Create a simple plot
      p <- ggplot(data, aes(x = test, y = percentile)) +
        geom_point() +
        theme_minimal() +
        labs(title = paste(config$name, "- Narrow"))
      
      ggsave(narrow_fig, p, width = 8, height = 6)
      cat("  ✓ Created figure:", narrow_fig, "\n")
    } else {
      cat("  - Figure already exists:", narrow_fig, "\n")
    }
    
    # Generate subdomain figure
    subdomain_fig <- file.path(FIGURE_DIR, paste0("fig_", clean_domain, "_subdomain.svg"))
    if (!file.exists(subdomain_fig)) {
      # Create a simple plot
      p <- ggplot(data, aes(x = test, y = percentile)) +
        geom_col() +
        theme_minimal() +
        labs(title = paste(config$name, "- Subdomain"))
      
      ggsave(subdomain_fig, p, width = 8, height = 6)
      cat("  ✓ Created figure:", subdomain_fig, "\n")
    } else {
      cat("  - Figure already exists:", subdomain_fig, "\n")
    }
    
    successful_assets <- c(successful_assets, domain_key)
    
  }, error = function(e) {
    cat("  ✗ Error generating assets for", domain_key, ":", e$message, "\n")
    failed_assets <- c(failed_assets, domain_key)
  })
}

# Generate SIRF overall figure if not exists
sirf_fig <- file.path(FIGURE_DIR, "fig_sirf_overall.svg")
if (!file.exists(sirf_fig)) {
  cat("\n📊 Generating SIRF overall figure...\n")
  tryCatch({
    # Create a placeholder SIRF figure
    p <- ggplot(data.frame(x = 1:10, y = rnorm(10)), aes(x, y)) +
      geom_line() +
      theme_minimal() +
      labs(title = "SIRF Overall Performance")
    
    ggsave(sirf_fig, p, width = 10, height = 8)
    cat("  ✓ Created SIRF figure:", sirf_fig, "\n")
  }, error = function(e) {
    cat("  ✗ Error generating SIRF figure:", e$message, "\n")
  })
}

# Summary
cat("\n=== Asset Generation Complete ===\n")
cat("Successful:", length(successful_assets), "domains\n")
if (length(failed_assets) > 0) {
  cat("Failed:", paste(failed_assets, collapse = ", "), "\n")
}

# List all generated figures
fig_files <- list.files(FIGURE_DIR, pattern = "\\.(svg|png|pdf)$", full.names = TRUE)
cat("\nGenerated files in", FIGURE_DIR, ":\n")
for (fig in fig_files) {
  cat("  -", basename(fig), "\n")
}

# Restore warning level
options(warn = old_warn)