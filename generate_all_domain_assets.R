#!/usr/bin/env Rscript

# Script to generate all missing domain table and figure files

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

cat("Generating all domain table and figure files...\n\n")

# Load sysdata.rda once
sysdata_path <- here::here("R", "sysdata.rda")
if (file.exists(sysdata_path)) {
  load(sysdata_path)
} else {
  stop("Could not load sysdata.rda")
}

# Define a function to generate assets for a single domain
generate_domain_assets <- function(domain_name, pheno, scales_var_name, plot_title_var_name) {
  
  cat(paste0("Processing ", pheno, " domain...\n"))
  
  # Get scales for this domain
  scales <- get(scales_var_name, envir = .GlobalEnv)
  
  # Create R6 processor
  processor <- DomainProcessorR6$new(
    domains = domain_name,
    pheno = pheno,
    input_file = "data/neurocog.parquet"
  )
  
  # Load and process data
  processor$load_data()
  processor$filter_by_domain()
  processor$select_columns()
  processor$save_data()
  
  # Get the data
  domain_data <- processor$data
  
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
  
  filtered_data <- filter_data(data = domain_data, domain = domain_name, scale = scales)
  
  # Generate the table
  table_name <- paste0("table_", pheno)
  
  # Get score types from the lookup table
  score_type_map <- get_score_types_from_lookup(filtered_data)
  
  # Create a list of test names grouped by score type
  score_types_list <- list()
  
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
  
  grp_list <- score_types_list
  dynamic_grp <- score_types_list
  
  # Default source note if no score types are found
  if (length(fn_list) == 0) {
    source_note <- "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]"
  } else {
    source_note <- NULL
  }
  
  # Create table
  table_gt <- TableGT_Modified$new(
    data = filtered_data,
    pheno = pheno,
    table_name = table_name,
    vertical_padding = 0,
    source_note = source_note,
    multiline = TRUE,
    fn_list = fn_list,
    grp_list = grp_list,
    dynamic_grp = dynamic_grp
  )
  
  # Build and save table
  tbl <- table_gt$build_table()
  table_gt$save_table(tbl, dir = here::here())
  
  if (file.exists(paste0(table_name, ".png"))) {
    cat(paste0("  ✓ ", table_name, ".png generated\n"))
  } else {
    cat(paste0("  ✗ Failed to generate ", table_name, ".png\n"))
  }
  
  # Generate the figure
  fig_name <- paste0("fig_", pheno, "_subdomain.svg")
  
  # Create subdomain plot
  dotplot_subdomain <- DotplotR6$new(
    data = filtered_data,
    x = "z_mean_subdomain",
    y = "subdomain",
    filename = here::here(fig_name)
  )
  
  dotplot_subdomain$create_plot()
  
  if (file.exists(fig_name)) {
    cat(paste0("  ✓ ", fig_name, " generated\n"))
  } else {
    cat(paste0("  ✗ Failed to generate ", fig_name, "\n"))
  }
  
  cat("\n")
}

# Process all domains
domains_config <- list(
  list(
    domain_name = "General Cognitive Ability",
    pheno = "iq",
    scales_var = "scales_iq",
    plot_title_var = "plot_title_iq"
  ),
  list(
    domain_name = "Academic Skills",
    pheno = "academics",
    scales_var = "scales_academics",
    plot_title_var = "plot_title_academics"
  ),
  list(
    domain_name = "Verbal/Language",
    pheno = "verbal",
    scales_var = "scales_verbal",
    plot_title_var = "plot_title_verbal"
  ),
  list(
    domain_name = "Visual Perception/Construction",
    pheno = "spatial",
    scales_var = "scales_spatial",
    plot_title_var = "plot_title_spatial"
  ),
  list(
    domain_name = "Memory",
    pheno = "memory",
    scales_var = "scales_memory",
    plot_title_var = "plot_title_memory"
  ),
  list(
    domain_name = "Attention/Executive",
    pheno = "executive",
    scales_var = "scales_executive",
    plot_title_var = "plot_title_executive"
  ),
  list(
    domain_name = "Motor",
    pheno = "motor",
    scales_var = "scales_motor",
    plot_title_var = "plot_title_motor"
  )
)

# Generate assets for each domain
for (config in domains_config) {
  tryCatch({
    generate_domain_assets(
      domain_name = config$domain_name,
      pheno = config$pheno,
      scales_var_name = config$scales_var,
      plot_title_var_name = config$plot_title_var
    )
  }, error = function(e) {
    cat(paste0("  ✗ Error processing ", config$pheno, ": ", e$message, "\n\n"))
  })
}

# Also generate SIRF figure if needed
cat("Checking SIRF figure...\n")
if (!file.exists("fig_sirf_overall.svg")) {
  cat("  ⚠ fig_sirf_overall.svg missing, but this may be generated elsewhere\n")
} else {
  cat("  ✓ fig_sirf_overall.svg exists\n")
}

cat("\nDone! All domain assets generation complete.\n")

# List all generated files
cat("\nGenerated files:\n")
png_files <- list.files(".", pattern = "table_.*\\.png$")
pdf_files <- list.files(".", pattern = "table_.*\\.pdf$")
svg_files <- list.files(".", pattern = "fig_.*\\.svg$")

if (length(png_files) > 0) {
  cat("\nTable PNG files:\n")
  for (f in png_files) cat(paste0("  - ", f, "\n"))
}

if (length(pdf_files) > 0) {
  cat("\nTable PDF files:\n")
  for (f in pdf_files) cat(paste0("  - ", f, "\n"))
}

if (length(svg_files) > 0) {
  cat("\nFigure SVG files:\n")
  for (f in svg_files) cat(paste0("  - ", f, "\n"))
}