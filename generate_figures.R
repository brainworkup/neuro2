#!/usr/bin/env Rscript

# Script to generate figure SVG files before rendering the template

# Load required packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(ggplot2)
})

# Load sysdata.rda to get domain objects
load("R/sysdata.rda")

# Source the DotplotR6 class
source("R/DotplotR6.R")

# Create a simple function to generate figures for a domain
generate_domain_figures <- function(pheno, domain_name) {
  message(paste0("\nGenerating figures for ", domain_name, "..."))

  # Read the data
  data_file <- paste0("data/", pheno, ".csv")
  if (!file.exists(data_file)) {
    data_file <- paste0("data/", pheno, ".parquet")
    if (file.exists(data_file)) {
      data <- arrow::read_parquet(data_file)
    } else {
      message(paste0("  - No data file found for ", pheno))
      return(NULL)
    }
  } else {
    data <- readr::read_csv(data_file, show_col_types = FALSE)
  }

  if (nrow(data) == 0) {
    message(paste0("  - No data available for ", pheno))
    return(NULL)
  }

  # Check if z-score columns exist, if not add them
  if (!"z_mean_subdomain" %in% names(data)) {
    # Convert percentile to z-scores
    data <- data %>%
      mutate(
        z = qnorm(percentile / 100),
        z_mean_subdomain = z,
        z_mean_narrow = z
      )
  }

  # Create subdomain figure
  subdomain_file <- paste0("fig_", pheno, "_subdomain.svg")

  # Check if subdomain column exists
  if ("subdomain" %in% names(data) && length(unique(data$subdomain)) > 0) {
    dotplot_subdomain <- DotplotR6$new(
      data = data,
      x = "z_mean_subdomain",
      y = "subdomain",
      filename = subdomain_file
    )
    dotplot_subdomain$create_plot()
    message(paste0("  - Created ", subdomain_file))
  } else {
    # Create a simple placeholder figure
    p <- ggplot(data.frame(x = 0, y = 0), aes(x, y)) +
      geom_point(size = 5) +
      theme_minimal() +
      labs(title = paste(domain_name, "Scores"))

    ggsave(subdomain_file, p, width = 8, height = 6, dpi = 300)
    message(paste0("  - Created placeholder ", subdomain_file))
  }

  # Create narrow figure for domains that use it
  if (
    pheno %in% c("iq", "academics", "verbal", "memory", "executive", "motor")
  ) {
    narrow_file <- paste0("fig_", pheno, "_narrow.svg")

    if ("narrow" %in% names(data) && length(unique(data$narrow)) > 0) {
      dotplot_narrow <- DotplotR6$new(
        data = data,
        x = "z_mean_narrow",
        y = "narrow",
        filename = narrow_file
      )
      dotplot_narrow$create_plot()
      message(paste0("  - Created ", narrow_file))
    }
  }

  return(subdomain_file)
}

# Generate figures for each domain
domains_to_process <- list(
  list(pheno = "iq", domain = "General Cognitive Ability"),
  list(pheno = "academics", domain = "Academic Skills"),
  list(pheno = "verbal", domain = "Verbal/Language"),
  list(pheno = "spatial", domain = "Visual Perception/Construction"),
  list(pheno = "memory", domain = "Memory"),
  list(pheno = "executive", domain = "Attention/Executive"),
  list(pheno = "motor", domain = "Motor")
)

message("Generating figures for all domains...")
generated_figures <- list()

for (domain_info in domains_to_process) {
  figure_name <- generate_domain_figures(domain_info$pheno, domain_info$domain)
  if (!is.null(figure_name)) {
    generated_figures[[domain_info$pheno]] <- figure_name
  }
}

# List generated files
message("\n✅ Figure generation complete!")
message("\nGenerated files:")
figure_files <- list.files(pattern = "^fig_.*\\.svg$", full.names = FALSE)
for (file in figure_files) {
  message(paste0("  - ", file))
}

message("\nYou can now run the template rendering.")
