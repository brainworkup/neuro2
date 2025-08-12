#!/usr/bin/env Rscript

# Script to generate table PNG files before rendering the template

# Load required packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(gt)
  library(readr)
})

# Load sysdata.rda to get domain objects
load("R/sysdata.rda")

# Source the modified TableGT class
source("R/TableGTR6.R")
source("R/score_type_utils.R")

# Create a simple function to generate table for a domain
generate_domain_table <- function(pheno, domain_name) {
  message(paste0("\nGenerating table for ", domain_name, "..."))

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
    data <- read_csv(data_file, show_col_types = FALSE)
  }

  if (nrow(data) == 0) {
    message(paste0("  - No data available for ", pheno))
    return(NULL)
  }

  # Table parameters
  table_name <- paste0("table_", pheno)
  vertical_padding <- 0
  multiline <- TRUE

  # Get score types from the lookup table
  score_type_map <- get_score_types_from_lookup(data)

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

  # Define which groups support which score types (for dynamic footnotes)
  dynamic_grp <- score_types_list

  # Default source note if no score types are found
  if (length(fn_list) == 0) {
    # Determine default based on pheno
    source_note <- "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]"
  } else {
    source_note <- NULL # No general source note when using footnotes
  }

  # Create table using our modified TableGTR6 R6 class
  table_gt <- TableGTR6$new(
    data = data,
    pheno = pheno,
    table_name = table_name,
    vertical_padding = vertical_padding,
    source_note = source_note,
    multiline = multiline,
    fn_list = fn_list,
    grp_list = grp_list,
    dynamic_grp = dynamic_grp
  )

  # Get the table object
  tbl <- table_gt$build_table()

  # Save the table
  table_gt$save_table(tbl, dir = here())

  message(paste0("  - Created ", table_name, ".png"))
  return(table_name)
}

# Generate tables for each domain
domains_to_process <- list(
  list(pheno = "iq", domain = "General Cognitive Ability"),
  list(pheno = "academics", domain = "Academic Skills"),
  list(pheno = "verbal", domain = "Verbal/Language"),
  list(pheno = "spatial", domain = "Visual Perception/Construction"),
  list(pheno = "memory", domain = "Memory"),
  list(pheno = "executive", domain = "Attention/Executive"),
  list(pheno = "motor", domain = "Motor")
)

message("Generating tables for all domains...")
generated_tables <- list()

for (domain_info in domains_to_process) {
  table_name <- generate_domain_table(domain_info$pheno, domain_info$domain)
  if (!is.null(table_name)) {
    generated_tables[[domain_info$pheno]] <- table_name
  }
}

# List generated files
message("\n✅ Table generation complete!")
message("\nGenerated files:")
table_files <- list.files(pattern = "^table_.*\\.png$", full.names = FALSE)
for (file in table_files) {
  message(paste0("  - ", file))
}

message("\nYou can now run the template rendering.")
