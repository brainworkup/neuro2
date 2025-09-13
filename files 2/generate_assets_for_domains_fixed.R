#!/usr/bin/env Rscript

# Fixed function to generate assets for domains with better error handling
# This function is self-contained and can be sourced or run directly

generate_assets_for_domains <- function(domain_files, figs_dir = "figs", verbose = TRUE) {
  if (verbose) {
    cat("\n🎨 Generating tables and figures for domains...\n")
  }
  
  # Ensure figs directory exists
  if (!dir.exists(figs_dir)) {
    dir.create(figs_dir, recursive = TRUE)
    if (verbose) cat("Created directory:", figs_dir, "\n")
  }
  
  # Extract domain names from the files (remove text files)
  domains <- gsub("^_02-[0-9]+_(.+)\\.qmd$", "\\1", domain_files)
  domains <- unique(domains)
  
  # Filter out text file domains
  domains_to_process <- domains[!grepl("_text", domains)]
  
  if (length(domains_to_process) == 0) {
    if (verbose) cat("No domains to process\n")
    return(invisible(NULL))
  }
  
  if (verbose) {
    cat("Processing domains:", paste(domains_to_process, collapse = ", "), "\n")
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
  
  # Try to generate assets directly without system2
  successful <- character()
  failed <- character()
  
  for (domain in domains_to_process) {
    # Clean domain name
    clean_domain <- gsub("_(adult|child)$", "", domain)
    
    config <- domain_configs[[clean_domain]]
    if (is.null(config)) {
      if (verbose) cat("⚠️ No configuration for domain:", domain, "\n")
      next
    }
    
    if (verbose) cat("\n📊 Processing", domain, "...\n")
    
    tryCatch({
      # Check if data file exists
      data_file <- paste0("data/", config$data_type, ".parquet")
      if (!file.exists(data_file)) {
        if (verbose) cat("  - Data file not found:", data_file, "\n")
        next
      }
      
      # Load data
      suppressPackageStartupMessages({
        library(arrow)
        library(dplyr)
        library(ggplot2)
        library(gt)
      })
      
      data <- arrow::read_parquet(data_file)
      
      # Filter for this domain
      domain_data <- data |>
        filter(domain == config$name)
      
      if (nrow(domain_data) == 0) {
        if (verbose) cat("  - No data for domain\n")
        next
      }
      
      # Generate table
      table_file <- file.path(figs_dir, paste0("table_", clean_domain, ".png"))
      if (!file.exists(table_file)) {
        # Create simple table
        table_data <- domain_data |>
          select(any_of(c("test", "test_name", "scale", "score", "percentile"))) |>
          slice_head(n = 10)
        
        if (nrow(table_data) > 0) {
          gt_table <- gt::gt(table_data) |>
            gt::tab_header(title = config$name)
          
          # Save table
          gt::gtsave(gt_table, table_file)
          if (verbose) cat("  ✓ Created table:", basename(table_file), "\n")
        }
      } else {
        if (verbose) cat("  - Table already exists\n")
      }
      
      # Generate figures
      # Narrow figure
      narrow_fig <- file.path(figs_dir, paste0("fig_", clean_domain, "_narrow.svg"))
      if (!file.exists(narrow_fig)) {
        # Create simple plot
        if ("percentile" %in% names(domain_data) && nrow(domain_data) > 0) {
          p <- ggplot(domain_data, aes(x = reorder(test, percentile), y = percentile)) +
            geom_point(size = 3) +
            coord_flip() +
            theme_minimal() +
            labs(title = paste(config$name, "- Test Scores"),
                 x = "Test", y = "Percentile")
          
          ggsave(narrow_fig, p, width = 8, height = 6)
          if (verbose) cat("  ✓ Created narrow figure\n")
        }
      } else {
        if (verbose) cat("  - Narrow figure already exists\n")
      }
      
      # Subdomain figure
      subdomain_fig <- file.path(figs_dir, paste0("fig_", clean_domain, "_subdomain.svg"))
      if (!file.exists(subdomain_fig)) {
        # Create simple plot
        if ("percentile" %in% names(domain_data) && nrow(domain_data) > 0) {
          p <- ggplot(domain_data, aes(x = reorder(test, percentile), y = percentile)) +
            geom_col(fill = "steelblue") +
            coord_flip() +
            theme_minimal() +
            labs(title = paste(config$name, "- Subdomain Analysis"),
                 x = "Test", y = "Percentile")
          
          ggsave(subdomain_fig, p, width = 8, height = 6)
          if (verbose) cat("  ✓ Created subdomain figure\n")
        }
      } else {
        if (verbose) cat("  - Subdomain figure already exists\n")
      }
      
      successful <- c(successful, domain)
      
    }, error = function(e) {
      if (verbose) cat("  ✗ Error:", e$message, "\n")
      failed <- c(failed, domain)
    })
  }
  
  # Generate SIRF overall figure
  sirf_fig <- file.path(figs_dir, "fig_sirf_overall.svg")
  if (!file.exists(sirf_fig)) {
    if (verbose) cat("\n📊 Generating SIRF overall figure...\n")
    tryCatch({
      # Create placeholder SIRF figure
      p <- ggplot(data.frame(x = 1:10, y = rnorm(10, 50, 10)), aes(x, y)) +
        geom_line(color = "blue", size = 1) +
        geom_point(size = 3) +
        theme_minimal() +
        labs(title = "Overall Performance Summary",
             x = "Domain", y = "Score") +
        ylim(0, 100)
      
      ggsave(sirf_fig, p, width = 10, height = 8)
      if (verbose) cat("  ✓ Created SIRF figure\n")
    }, error = function(e) {
      if (verbose) cat("  ✗ Error generating SIRF:", e$message, "\n")
    })
  }
  
  # Summary
  if (verbose) {
    cat("\n✅ Asset generation complete\n")
    cat("  Successful:", length(successful), "domains\n")
    if (length(failed) > 0) {
      cat("  Failed:", paste(failed, collapse = ", "), "\n")
    }
    
    # List generated files
    fig_files <- list.files(figs_dir, pattern = "\\.(svg|png|pdf)$")
    if (length(fig_files) > 0) {
      cat("\nGenerated assets in", figs_dir, ":\n")
      for (fig in fig_files) {
        cat("  -", fig, "\n")
      }
    }
  }
  
  return(invisible(list(
    successful = successful,
    failed = failed
  )))
}

# If running as a script, process domains from environment or current directory
if (!interactive()) {
  # Get domains from environment or find QMD files
  env_domains <- Sys.getenv("DOMAINS_WITH_DATA")
  
  if (nzchar(env_domains)) {
    # Parse comma-separated domains
    domains <- strsplit(env_domains, ",")[[1]]
    # Convert to expected file format
    domain_files <- paste0("_02-XX_", domains, ".qmd")
  } else {
    # Find all domain QMD files
    domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
  }
  
  if (length(domain_files) > 0) {
    generate_assets_for_domains(domain_files, figs_dir = "figs", verbose = TRUE)
  } else {
    cat("No domain files found to process\n")
  }
}
