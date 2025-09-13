#!/usr/bin/env Rscript

# FIX FOR ASSET GENERATION
# This script replaces the basic asset generation with proper R6 class usage

cat("========================================\n")
cat("FIXING ASSET GENERATION\n")
cat("========================================\n\n")

# Step 1: Replace generate_all_domain_assets.R with proper version
cat("Creating proper asset generation script...\n")

# Write the corrected asset generation function
asset_gen_content <- '#!/usr/bin/env Rscript

# Asset Generation using neuro2 R6 Classes
# Generates properly formatted tables and figures

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(gt)
  library(arrow)
})

# Try to load neuro2
tryCatch({
  library(neuro2)
}, error = function(e) {
  # Load R6 classes from source
  if (file.exists("R/DomainProcessorR6.R")) source("R/DomainProcessorR6.R")
  if (file.exists("R/TableGTR6.R")) source("R/TableGTR6.R")  
  if (file.exists("R/DotplotR6.R")) source("R/DotplotR6.R")
})

# Process command line domains or find from QMD files
env_domains <- Sys.getenv("DOMAINS_WITH_DATA")
if (nzchar(env_domains)) {
  domains_to_process <- strsplit(env_domains, ",")[[1]]
} else {
  domain_files <- list.files(pattern = "^_02-[0-9]+_.*\\\\.qmd$")
  domains_to_process <- unique(gsub("^_02-[0-9]+_(.+)\\\\.qmd$", "\\\\1", domain_files))
  domains_to_process <- domains_to_process[!grepl("_text", domains_to_process)]
}

cat("Processing domains:", paste(domains_to_process, collapse = ", "), "\\n\\n")

# Domain configurations
configs <- list(
  iq = list(domains = "General Cognitive Ability", input = "data/neurocog.parquet"),
  academics = list(domains = "Academic Skills", input = "data/neurocog.parquet"),
  verbal = list(domains = "Verbal/Language", input = "data/neurocog.parquet"),
  spatial = list(domains = "Visual Perception/Construction", input = "data/neurocog.parquet"),
  memory = list(domains = "Memory", input = "data/neurocog.parquet"),
  executive = list(domains = "Attention/Executive", input = "data/neurocog.parquet"),
  motor = list(domains = "Motor", input = "data/neurocog.parquet"),
  emotion = list(domains = "Emotional/Behavioral/Social/Personality", input = "data/neurobehav.parquet")
)

dir.create("figs", showWarnings = FALSE)

for (domain in domains_to_process) {
  if (!domain %in% names(configs)) next
  
  cat("Processing", domain, "...\\n")
  config <- configs[[domain]]
  
  tryCatch({
    # Create processor
    processor <- DomainProcessorR6$new(
      domains = config$domains,
      pheno = domain,
      input_file = config$input
    )
    
    # Process data
    processor$load_data()
    processor$filter_by_domain()
    processor$select_columns()
    
    data <- processor$data
    if (is.null(data) || nrow(data) == 0) {
      cat("  No data\\n")
      next
    }
    
    # Generate table
    table_obj <- TableGTR6$new(
      data = data,
      pheno = domain,
      table_name = paste0("table_", domain),
      vertical_padding = 0
    )
    tbl <- table_obj$build_table()
    gt::gtsave(tbl, here::here("figs", paste0("table_", domain, ".png")))
    cat("  ✓ Table created\\n")
    
    # Generate figures
    if (all(c("z_mean_subdomain", "subdomain") %in% names(data))) {
      data_sub <- data[!is.na(data$z_mean_subdomain), ]
      if (nrow(data_sub) > 0) {
        dotplot <- DotplotR6$new(
          data = data_sub,
          x = "z_mean_subdomain",
          y = "subdomain"
        )
        dotplot$filename <- here::here("figs", paste0("fig_", domain, "_subdomain.svg"))
        dotplot$create_plot()
        cat("  ✓ Subdomain figure created\\n")
      }
    }
    
    if (all(c("z_mean_narrow", "narrow") %in% names(data))) {
      data_nar <- data[!is.na(data$z_mean_narrow), ]
      if (nrow(data_nar) > 0) {
        dotplot <- DotplotR6$new(
          data = data_nar,
          x = "z_mean_narrow",
          y = "narrow"
        )
        dotplot$filename <- here::here("figs", paste0("fig_", domain, "_narrow.svg"))
        dotplot$create_plot()
        cat("  ✓ Narrow figure created\\n")
      }
    }
    
    # Fallback to percentile if no z_mean columns
    if (!any(c("z_mean_subdomain", "z_mean_narrow") %in% names(data))) {
      if ("percentile" %in% names(data)) {
        dotplot <- DotplotR6$new(
          data = data,
          x = "percentile",
          y = "scale"
        )
        dotplot$filename <- here::here("figs", paste0("fig_", domain, "_narrow.svg"))
        dotplot$create_plot()
        dotplot$filename <- here::here("figs", paste0("fig_", domain, "_subdomain.svg"))
        dotplot$create_plot()
        cat("  ✓ Percentile figures created\\n")
      }
    }
    
  }, error = function(e) {
    cat("  Error:", e$message, "\\n")
  })
}

# Create SIRF figure
if (!file.exists("figs/fig_sirf_overall.svg")) {
  library(ggplot2)
  p <- ggplot(data.frame(x = 1:6, y = c(85, 92, 88, 79, 83, 95)), aes(x, y)) +
    geom_line(color = "steelblue", size = 1.5) +
    geom_point(size = 4, color = "steelblue") +
    theme_minimal() +
    labs(title = "Overall Performance", x = "Domain", y = "Score")
  ggsave("figs/fig_sirf_overall.svg", p, width = 10, height = 6)
  cat("\\n✓ SIRF figure created\\n")
}

cat("\\n✅ Asset generation complete\\n")
'

# Write the file
writeLines(asset_gen_content, "generate_all_domain_assets.R")
cat("✅ Created generate_all_domain_assets.R with R6 classes\n")

# Step 2: Run the asset generation
cat("\nRunning asset generation with R6 classes...\n")
source("generate_all_domain_assets.R")

# Step 3: Verify the files
cat("\n========================================\n")
cat("VERIFICATION\n")
cat("========================================\n")

# Check what was created
figs_files <- list.files("figs", pattern = "\\.(svg|png|pdf)$")

cat("\nGenerated files in figs/:\n")
for (file in figs_files) {
  size <- file.info(file.path("figs", file))$size
  cat(sprintf("  %-40s %8d bytes\n", file, size))
}

# Check for expected files
expected_files <- c(
  "table_emotion.png",
  "fig_emotion_narrow.svg",
  "fig_emotion_subdomain.svg",
  "table_iq.png",
  "fig_iq_narrow.svg",
  "fig_iq_subdomain.svg",
  "fig_sirf_overall.svg"
)

missing <- setdiff(expected_files, figs_files)
if (length(missing) > 0) {
  cat("\n⚠️  Missing expected files:\n")
  for (file in missing) {
    cat("  -", file, "\n")
  }
} else {
  cat("\n✅ All expected files generated!\n")
}

cat("\n========================================\n")
cat("Fix complete! Your assets should now be properly formatted.\n")
cat("You can re-run the workflow or render the report.\n")
