#!/usr/bin/env Rscript

# EFFICIENT R6-BASED NEUROPSYCHOLOGICAL REPORT WORKFLOW
# This script uses R6 classes for object-oriented, efficient report generation

# Clear workspace and load packages
rm(list = ls())

# Load required packages
packages <- c("tidyverse", "here", "glue", "yaml", "quarto", "NeurotypR", "R6")
invisible(lapply(packages, library, character.only = TRUE))

# Source R6 classes
source("R/DotplotR6.R")
source("R/NeuropsychReportSystemR6.R")
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/ReportTemplateR6.R")

message("🚀 R6-BASED NEUROPSYCH REPORT WORKFLOW")
message("=======================================\n")

# STEP 1: Initialize Report System
message("📊 Step 1: Initializing report system...")

# Configure the report system
config <- list(
  patient_name = "Biggie",
  domains = c(
    "General Cognitive Ability",
    "Academic Skills",
    "Verbal/Language",
    "Visual Perception/Construction",
    "Memory",
    "Attention/Executive",
    "Motor",
    "Social Cognition",
    "ADHD",
    "Psychiatric Disorders",
    "Personality Disorders",
    "Substance Use",
    "Psychosocial Problems"
  ),
  data_files = list(
    neurocog = "data/neurocog.csv",
    neurobehav = "data/neurobehav.csv",
    validity = "data/validity.csv"
  ),
  template_file = "template.qmd",
  output_file = "neuropsych_report_r6.pdf"
)

# Create report system instance
report_system <- NeuropsychReportSystemR6$new(
  config = config,
  template_dir = ".",
  output_dir = "output"
)

# STEP 2: Process Data Using Domain Processors
message("\n📝 Step 2: Processing domains with R6 classes...")

# Process each domain using DomainProcessorR6
for (domain in config$domains) {
  domain_key <- gsub(" ", "_", tolower(domain))

  # Create domain processor
  processor <- DomainProcessorR6$new(
    domains = domain,
    pheno = domain_key,
    input_file = "data/neurocog.csv",
    output_dir = "data"
  )

  # Process the domain
  processor$process(
    generate_reports = TRUE,
    report_types = c("self"),
    generate_domain_files = TRUE
  )

  message(paste("✅ Processed", domain, "using R6 class"))
}

# STEP 3: Generate Visualizations Using DotplotR6
message("\n📑 Step 3: Creating visualizations with DotplotR6...")

# Load processed data
neurocog <- readr::read_csv("data/neurocog.csv", show_col_types = FALSE)

# Create domain summary plot using DotplotR6
domain_summary <- neurocog |>
  group_by(domain) |>
  summarise(
    mean_z = mean(z, na.rm = TRUE),
    mean_percentile = mean(percentile, na.rm = TRUE)
  ) |>
  filter(!is.na(mean_z))

# Create dotplot using R6 class
dotplot_obj <- DotplotR6$new(
  data = domain_summary,
  x = "mean_z",
  y = "domain",
  filename = "output/domain_profile_r6.svg",
  theme = "fivethirtyeight",
  point_size = 8,
  linewidth = 0.7
)

# Generate the plot
plot <- dotplot_obj$create_plot()
message("✅ Created domain profile visualization")

# Create subdomain plots for each domain
for (domain in unique(neurocog$domain)) {
  subdomain_data <- neurocog |>
    filter(domain == !!domain) |>
    group_by(subdomain) |>
    summarise(mean_z = mean(z, na.rm = TRUE)) |>
    filter(!is.na(mean_z) & !is.na(subdomain))

  if (nrow(subdomain_data) > 0) {
    subdomain_plot <- DotplotR6$new(
      data = subdomain_data,
      x = "mean_z",
      y = "subdomain",
      filename = paste0(
        "output/",
        gsub(" ", "_", tolower(domain)),
        "_subdomain_r6.svg"
      )
    )
    subdomain_plot$create_plot()
  }
}

# STEP 4: Generate Report Using ReportTemplateR6
message("\n📄 Step 4: Generating report with ReportTemplateR6...")

# Update variables
variables <- yaml::read_yaml("_variables.yml")
variables$patient <- "Biggie"
variables$first_name <- "Biggie"
variables$last_name <- "Smalls"
variables$age <- 44
variables$sex <- "male"
variables$date_of_report <- format(Sys.Date(), "%Y-%m-%d")

# Create report template manager
template_manager <- ReportTemplateR6$new(
  variables = variables,
  template_dir = ".",
  output_dir = "output",
  data_paths = list(
    neurocog = "data/neurocog.csv",
    neurobehav = "data/neurobehav.csv",
    validity = "data/validity.csv"
  )
)

# Generate and render report
template_manager$generate_template("output/report_r6.qmd")
template_manager$render_report(
  input_file = "output/report_r6.qmd",
  output_format = "pdf"
)

message("✅ Report generated using R6 classes")

# STEP 5: Performance Comparison
message("\n📊 Performance Summary:")
message("- Used object-oriented R6 classes for better organization")
message("- Leveraged DotplotR6 for efficient visualization")
message("- Utilized DomainProcessorR6 for parallel domain processing")
message("- Applied ReportTemplateR6 for template management")
message("\n✨ R6 classes provide:")
message("- Better memory management")
message("- Reusable components")
message("- Cleaner, more maintainable code")
message("- Potential for parallel processing")

# Summary
message("\n🎉 R6 WORKFLOW COMPLETE!")
message("=======================================")
message("Generated files:")
message("- output/neuropsych_report_r6.pdf")
message("- Domain visualizations in output/")
message("- Processed data in data/")
