#!/usr/bin/env Rscript

# Script to manually generate missing spatial domain table and figure files

# Load required libraries
library(here)
library(dplyr)
library(gt)
library(ggplot2)

# Source R6 classes
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGT_Modified.R")
source("R/score_type_utils.R")

cat("Generating spatial domain files...\n")

# Filter by domain
domains <- c("Visual Perception/Construction")

# Target phenotype
pheno <- "spatial"

# Create R6 processor
processor_spatial <- DomainProcessorR6$new(
  domains = domains,
  pheno = pheno,
  input_file = "data/neurocog.parquet"
)

# Load and process data
processor_spatial$load_data()
processor_spatial$filter_by_domain()

# Create the data object
spatial <- processor_spatial$data

# Process and export data using R6
processor_spatial$select_columns()
processor_spatial$save_data()

# Update the original object
spatial <- processor_spatial$data

# Load internal data to get standardized scale names
sysdata_path <- here::here("R", "sysdata.rda")
if (file.exists(sysdata_path)) {
  load(sysdata_path)
} else {
  stop("Could not load scales_spatial from sysdata.rda")
}

scales <- scales_spatial

# Filter the data
filter_data <- function(data, domain, scale) {
  if (!is.null(domain)) {
    data <- data[data$domain %in% domain, ]
  }
  if (!is.null(scale)) {
    data <- data[data$scale %in% scale, ]
  }
  return(data)
}

# Apply the filter function
data_spatial <- filter_data(data = spatial, domain = domains, scale = scales)

# Generate the table
cat("Generating table_spatial...\n")

# Table parameters
table_name <- "table_spatial"
vertical_padding <- 0
multiline <- TRUE

# Get score types from the lookup table
score_type_map <- get_score_types_from_lookup(data_spatial)

# Create a list of test names grouped by score type
score_types_list <- list()

# Process the score type map to group tests by score type
for (test_name in names(score_type_map)) {
  types <- score_type_map[[test_name]]
  for (type in types) {
    if (!type %in% names(score_types_list)) {
      score_types_list[[type]] <- character(0)
    }
    score_types_list[[type]] <- unique(c(score_types_list[[type]], test_name))
  }
}

# Get unique score types present
unique_score_types <- names(score_types_list)

# Define the score type footnotes
fn_list <- list()
if ("t_score" %in% unique_score_types) {
  fn_list$t_score <- "T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]"
}
if ("scaled_score" %in% unique_score_types) {
  fn_list$scaled_score <- "Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]"
}
if ("standard_score" %in% unique_score_types) {
  fn_list$standard_score <- "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]"
}

# Create groups based on test names that use each score type
grp_list <- score_types_list
dynamic_grp <- score_types_list

# Default source note if no score types are found
if (length(fn_list) == 0) {
  source_note <- "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]"
} else {
  source_note <- NULL
}

# Create table using our modified TableGT_Modified R6 class
table_gt <- TableGT_Modified$new(
  data = data_spatial,
  pheno = pheno,
  table_name = table_name,
  vertical_padding = vertical_padding,
  source_note = source_note,
  multiline = multiline,
  fn_list = fn_list,
  grp_list = grp_list,
  dynamic_grp = dynamic_grp
)

# Get the table object without automatic saving
tbl <- table_gt$build_table()

# Save the table
table_gt$save_table(tbl, dir = here::here())

if (file.exists("table_spatial.png")) {
  cat("✓ table_spatial.png generated successfully\n")
} else {
  cat("✗ Failed to generate table_spatial.png\n")
}

if (file.exists("table_spatial.pdf")) {
  cat("✓ table_spatial.pdf generated successfully\n")
} else {
  cat("✗ Failed to generate table_spatial.pdf\n")
}

# Generate the figure
cat("Generating fig_spatial_subdomain...\n")

# Create subdomain plot using R6 DotplotR6
dotplot_subdomain <- DotplotR6$new(
  data = data_spatial,
  x = "z_mean_subdomain",
  y = "subdomain",
  filename = here::here("fig_spatial_subdomain.svg")
)

dotplot_subdomain$create_plot()

if (file.exists("fig_spatial_subdomain.svg")) {
  cat("✓ fig_spatial_subdomain.svg generated successfully\n")
} else {
  cat("✗ Failed to generate fig_spatial_subdomain.svg\n")
}

cat("\nDone! Spatial files generation complete.\n")