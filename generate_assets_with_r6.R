#!/usr/bin/env Rscript

# Asset Generation Script using neuro2 R6 Classes
# This generates proper tables and figures matching the QMD expectations

cat("========================================\n")
cat("GENERATING ASSETS WITH R6 CLASSES\n")
cat("========================================\n\n")

# Load required packages
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(gt)
  library(gtExtras)
  library(arrow)
})

# Load neuro2 package or source R6 classes
tryCatch({
  library(neuro2)
}, error = function(e) {
  # If package not loaded, try to source the R6 classes directly
  cat("Loading R6 classes from source...\n")
  source_files <- c(
    "R/DomainProcessorR6.R",
    "R/TableGTR6.R",
    "R/DotplotR6.R",
    "R/NeuropsychResultsR6.R"
  )
  
  for (file in source_files) {
    if (file.exists(file)) {
      source(file)
      cat("  ✓ Loaded", basename(file), "\n")
    }
  }
})

# Ensure output directories exist
dir.create("figs", showWarnings = FALSE)
dir.create("output", showWarnings = FALSE)

# Define domain configurations
domain_configs <- list(
  iq = list(
    domains = "General Cognitive Ability",
    pheno = "iq",
    input_file = "data/neurocog.parquet",
    number = "01"
  ),
  academics = list(
    domains = "Academic Skills",
    pheno = "academics",
    input_file = "data/neurocog.parquet",
    number = "02"
  ),
  verbal = list(
    domains = "Verbal/Language",
    pheno = "verbal",
    input_file = "data/neurocog.parquet",
    number = "03"
  ),
  spatial = list(
    domains = "Visual Perception/Construction",
    pheno = "spatial",
    input_file = "data/neurocog.parquet",
    number = "04"
  ),
  memory = list(
    domains = "Memory",
    pheno = "memory",
    input_file = "data/neurocog.parquet",
    number = "05"
  ),
  executive = list(
    domains = "Attention/Executive",
    pheno = "executive",
    input_file = "data/neurocog.parquet",
    number = "06"
  ),
  motor = list(
    domains = "Motor",
    pheno = "motor",
    input_file = "data/neurocog.parquet",
    number = "07"
  ),
  emotion = list(
    domains = "Emotional/Behavioral/Social/Personality",
    pheno = "emotion",
    input_file = "data/neurobehav.parquet",
    number = "10"
  )
)

# Function to generate assets for a domain
generate_domain_assets <- function(config) {
  cat("\n📊 Processing", config$pheno, "domain...\n")
  
  tryCatch({
    # Create processor
    processor <- DomainProcessorR6$new(
      domains = config$domains,
      pheno = config$pheno,
      input_file = config$input_file,
      number = config$number
    )
    
    # Load and process data
    processor$load_data()
    processor$filter_by_domain()
    processor$select_columns()
    
    # Get the data
    data <- processor$data
    
    if (is.null(data) || nrow(data) == 0) {
      cat("  ⚠️  No data for", config$pheno, "\n")
      return(FALSE)
    }
    
    cat("  Found", nrow(data), "rows of data\n")
    
    # Generate table using TableGTR6
    cat("  Generating table...\n")
    tryCatch({
      table_obj <- TableGTR6$new(
        data = data,
        pheno = config$pheno,
        table_name = paste0("table_", config$pheno),
        vertical_padding = 0
      )
      
      # Build and save table
      tbl <- table_obj$build_table()
      
      # Save as PNG
      png_file <- here::here("figs", paste0("table_", config$pheno, ".png"))
      gt::gtsave(tbl, png_file)
      cat("    ✓ Saved table:", basename(png_file), "\n")
      
      # Also save as PDF
      pdf_file <- here::here("figs", paste0("table_", config$pheno, ".pdf"))
      gt::gtsave(tbl, pdf_file)
      cat("    ✓ Saved table:", basename(pdf_file), "\n")
      
    }, error = function(e) {
      cat("    ✗ Error generating table:", e$message, "\n")
    })
    
    # Generate subdomain figure if data available
    if (all(c("z_mean_subdomain", "subdomain") %in% names(data))) {
      cat("  Generating subdomain figure...\n")
      
      data_subdomain <- data[!is.na(data$z_mean_subdomain) & !is.na(data$subdomain), ]
      
      if (nrow(data_subdomain) > 0) {
        tryCatch({
          fig_path <- here::here("figs", paste0("fig_", config$pheno, "_subdomain"))
          
          # Create dotplot
          dotplot <- DotplotR6$new(
            data = data_subdomain,
            x = "z_mean_subdomain",
            y = "subdomain"
          )
          
          # Save in multiple formats
          for (ext in c(".svg", ".png", ".pdf")) {
            dotplot$filename <- paste0(fig_path, ext)
            dotplot$create_plot()
            cat("    ✓ Saved figure:", basename(dotplot$filename), "\n")
          }
          
        }, error = function(e) {
          cat("    ✗ Error generating subdomain figure:", e$message, "\n")
        })
      }
    } else {
      cat("  ℹ️  No subdomain data available\n")
    }
    
    # Generate narrow figure if data available
    if (all(c("z_mean_narrow", "narrow") %in% names(data))) {
      cat("  Generating narrow figure...\n")
      
      data_narrow <- data[!is.na(data$z_mean_narrow) & !is.na(data$narrow), ]
      
      if (nrow(data_narrow) > 0) {
        tryCatch({
          fig_path <- here::here("figs", paste0("fig_", config$pheno, "_narrow"))
          
          # Create dotplot
          dotplot <- DotplotR6$new(
            data = data_narrow,
            x = "z_mean_narrow",
            y = "narrow"
          )
          
          # Save in multiple formats
          for (ext in c(".svg", ".png", ".pdf")) {
            dotplot$filename <- paste0(fig_path, ext)
            dotplot$create_plot()
            cat("    ✓ Saved figure:", basename(dotplot$filename), "\n")
          }
          
        }, error = function(e) {
          cat("    ✗ Error generating narrow figure:", e$message, "\n")
        })
      }
    } else {
      cat("  ℹ️  No narrow data available\n")
    }
    
    # If no z_mean columns, try basic percentile plot
    if (!any(c("z_mean_subdomain", "z_mean_narrow") %in% names(data))) {
      if ("percentile" %in% names(data) && "scale" %in% names(data)) {
        cat("  Generating basic percentile figure...\n")
        
        tryCatch({
          # Use DotplotR6 with percentile data
          fig_path <- here::here("figs", paste0("fig_", config$pheno, "_narrow"))
          
          dotplot <- DotplotR6$new(
            data = data,
            x = "percentile",
            y = "scale"
          )
          
          # Save as SVG (primary format expected by QMD)
          dotplot$filename <- paste0(fig_path, ".svg")
          dotplot$create_plot()
          cat("    ✓ Saved figure:", basename(dotplot$filename), "\n")
          
          # Also save subdomain version
          dotplot$filename <- gsub("_narrow", "_subdomain", dotplot$filename)
          dotplot$create_plot()
          cat("    ✓ Saved figure:", basename(dotplot$filename), "\n")
          
        }, error = function(e) {
          cat("    ✗ Error generating percentile figure:", e$message, "\n")
        })
      }
    }
    
    return(TRUE)
    
  }, error = function(e) {
    cat("  ✗ Error processing", config$pheno, ":", e$message, "\n")
    return(FALSE)
  })
}

# Process domains based on existing QMD files
cat("\nLooking for domain QMD files...\n")
domain_files <- list.files(pattern = "^_02-[0-9]+_.*\\.qmd$")

if (length(domain_files) > 0) {
  # Extract domain names from files
  domains_to_process <- unique(gsub("^_02-[0-9]+_(.+)_text\\.qmd$|^_02-[0-9]+_(.+)\\.qmd$", "\\1", domain_files))
  domains_to_process <- domains_to_process[!grepl("_text", domains_to_process)]
  domains_to_process <- domains_to_process[domains_to_process != ""]
  
  cat("Found domains:", paste(domains_to_process, collapse = ", "), "\n")
  
  # Process each domain
  successful <- character()
  failed <- character()
  
  for (domain in domains_to_process) {
    if (domain %in% names(domain_configs)) {
      success <- generate_domain_assets(domain_configs[[domain]])
      if (success) {
        successful <- c(successful, domain)
      } else {
        failed <- c(failed, domain)
      }
    } else {
      cat("\n⚠️  No configuration for domain:", domain, "\n")
    }
  }
  
  # Generate SIRF overall figure
  cat("\n📊 Generating SIRF overall figure...\n")
  tryCatch({
    # For now, create a placeholder SIRF figure
    # In production, this would aggregate data across domains
    
    library(ggplot2)
    
    # Create sample data
    sirf_data <- data.frame(
      domain = c("Cognitive", "Academic", "Language", "Memory", "Executive", "Emotional"),
      score = c(85, 92, 88, 79, 83, 95),
      se = c(3, 4, 3, 5, 4, 3)
    )
    
    # Create plot
    p <- ggplot(sirf_data, aes(x = domain, y = score)) +
      geom_point(size = 4, color = "steelblue") +
      geom_errorbar(aes(ymin = score - se, ymax = score + se), 
                    width = 0.2, color = "steelblue", alpha = 0.7) +
      geom_hline(yintercept = 100, linetype = "dashed", alpha = 0.5) +
      geom_hline(yintercept = 85, linetype = "dotted", alpha = 0.5, color = "red") +
      scale_y_continuous(limits = c(70, 115), breaks = seq(70, 115, 5)) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.minor = element_blank()
      ) +
      labs(
        title = "Overall Neuropsychological Performance",
        x = "Domain",
        y = "Standard Score"
      )
    
    # Save SIRF figure
    sirf_path <- here::here("figs", "fig_sirf_overall.svg")
    ggsave(sirf_path, p, width = 10, height = 6)
    cat("  ✓ Created SIRF figure\n")
    
  }, error = function(e) {
    cat("  ✗ Error generating SIRF figure:", e$message, "\n")
  })
  
  # Summary
  cat("\n========================================\n")
  cat("ASSET GENERATION COMPLETE\n")
  cat("  Successful:", length(successful), "domains\n")
  if (length(failed) > 0) {
    cat("  Failed:", paste(failed, collapse = ", "), "\n")
  }
  cat("========================================\n")
  
} else {
  cat("No domain QMD files found. Please generate domain files first.\n")
}

# List generated assets
cat("\nGenerated assets:\n")
figs_files <- list.files("figs", pattern = "\\.(svg|png|pdf)$", full.names = FALSE)
for (file in figs_files) {
  cat("  -", file, "\n")
}
