#!/usr/bin/env Rscript

# Script to generate figure SVG files before rendering the template

# Load required packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(ggplot2)
  library(readr)
  library(arrow)
})

# Function to safely load sysdata
load_sysdata <- function() {
  sysdata_path <- "R/sysdata.rda"
  if (file.exists(sysdata_path)) {
    load(sysdata_path, envir = .GlobalEnv)
    message("✓ Loaded sysdata.rda")
  } else {
    message("⚠ Warning: R/sysdata.rda not found")
  }
}

# Load sysdata.rda to get domain objects
load_sysdata()

# Source the required R6 classes
source_required_files <- function() {
  required_files <- c(
    "R/DotplotR6.R"
  )
  
  for (file in required_files) {
    if (file.exists(file)) {
      source(file)
      message(paste("✓ Sourced", file))
    } else {
      warning(paste("⚠ Warning: Required file not found:", file))
    }
  }
}

source_required_files()

# Function to read data file with format fallback
read_data_file <- function(pheno) {
  # Try different file formats in order of preference
  formats <- list(
    list(ext = ".parquet", reader = arrow::read_parquet),
    list(ext = ".feather", reader = arrow::read_feather),
    list(ext = ".csv", reader = function(x) readr::read_csv(x, show_col_types = FALSE))
  )
  
  for (format in formats) {
    file_path <- paste0("data/", pheno, format$ext)
    if (file.exists(file_path)) {
      message(paste("  ✓ Reading", file_path))
      return(format$reader(file_path))
    }
  }
  
  message(paste("  ✗ No data file found for", pheno))
  return(NULL)
}

# Function to add z-scores if missing
add_z_scores <- function(data) {
  # Check if percentile column exists
  if (!"percentile" %in% names(data)) {
    message("  ⚠ Warning: No percentile column found, cannot calculate z-scores")
    return(data)
  }
  
  # Add z-scores if missing
  z_columns <- c("z", "z_mean_subdomain", "z_mean_narrow")
  missing_z_cols <- setdiff(z_columns, names(data))
  
  if (length(missing_z_cols) > 0) {
    message("  ➕ Adding missing z-score columns")
    
    data <- data %>%
      dplyr::mutate(
        z = ifelse(!is.na(percentile) & percentile > 0 & percentile < 100,
                   qnorm(percentile / 100), NA_real_),
        z_mean_subdomain = z,
        z_mean_narrow = z
      )
  }
  
  return(data)
}

# Function to create placeholder figure
create_placeholder_figure <- function(domain_name, filename) {
  tryCatch({
    p <- ggplot(data.frame(x = 0, y = 0), aes(x, y)) +
      geom_point(size = 5, color = "steelblue", alpha = 0.7) +
      theme_minimal() +
      labs(
        title = paste(domain_name, "Scores"),
        subtitle = "No subdomain data available",
        x = "Z-Score",
        y = "Domain"
      ) +
      theme(
        plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
        plot.subtitle = element_text(hjust = 0.5, size = 12, color = "gray60")
      )
    
    ggsave(filename, p, width = 8, height = 6, dpi = 300)
    message(paste0("  ✓ Created placeholder ", filename))
    return(TRUE)
  }, error = function(e) {
    message(paste0("  ✗ Error creating placeholder figure: ", e$message))
    return(FALSE)
  })
}

# Function to create dotplot figure
create_dotplot_figure <- function(data, x_var, y_var, filename, domain_name) {
  tryCatch({
    # Check if DotplotR6 class is available
    if (!exists("DotplotR6")) {
      message("  ⚠ DotplotR6 class not available, creating simple ggplot")
      return(create_simple_dotplot(data, x_var, y_var, filename, domain_name))
    }
    
    # Create dotplot using R6 class
    dotplot <- DotplotR6$new(
      data = data,
      x = x_var,
      y = y_var,
      filename = filename
    )
    
    dotplot$create_plot()
    message(paste0("  ✓ Created ", filename))
    return(TRUE)
    
  }, error = function(e) {
    message(paste0("  ⚠ DotplotR6 failed, creating simple ggplot: ", e$message))
    return(create_simple_dotplot(data, x_var, y_var, filename, domain_name))
  })
}

# Function to create simple ggplot as fallback
create_simple_dotplot <- function(data, x_var, y_var, filename, domain_name) {
  tryCatch({
    # Check if variables exist in data
    if (!x_var %in% names(data) || !y_var %in% names(data)) {
      message(paste0("  ⚠ Required variables not found: ", x_var, ", ", y_var))
      return(create_placeholder_figure(domain_name, filename))
    }
    
    # Filter out missing values
    plot_data <- data %>%
      dplyr::filter(!is.na(.data[[x_var]]), !is.na(.data[[y_var]]))
    
    if (nrow(plot_data) == 0) {
      message("  ⚠ No valid data for plotting")
      return(create_placeholder_figure(domain_name, filename))
    }
    
    # Create simple dotplot
    p <- ggplot(plot_data, aes(x = .data[[x_var]], y = .data[[y_var]])) +
      geom_point(size = 3, color = "steelblue", alpha = 0.7) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
      theme_minimal() +
      labs(
        title = paste(domain_name, "Performance"),
        x = "Z-Score",
        y = stringr::str_to_title(gsub("_", " ", y_var))
      ) +
      theme(
        plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
        axis.text.y = element_text(size = 10),
        axis.text.x = element_text(size = 10)
      )
    
    ggsave(filename, p, width = 8, height = 6, dpi = 300)
    message(paste0("  ✓ Created ", filename))
    return(TRUE)
    
  }, error = function(e) {
    message(paste0("  ✗ Error creating simple dotplot: ", e$message))
    return(create_placeholder_figure(domain_name, filename))
  })
}

# Function to check if data exists for domain
check_data_exists <- function(pheno) {
  formats <- c(".parquet", ".feather", ".csv")
  for (format in formats) {
    file_path <- paste0("data/", pheno, format)
    if (file.exists(file_path)) {
      return(TRUE)
    }
  }
  return(FALSE)
}

# Function to determine which figures to create
get_figure_types <- function(pheno, data) {
  figure_types <- list()
  
  # Subdomain figure (always try to create)
  figure_types$subdomain <- list(
    filename = paste0("fig_", pheno, "_subdomain.svg"),
    x_var = "z_mean_subdomain",
    y_var = "subdomain",
    required = TRUE
  )
  
  # Narrow figure (only for specific domains)
  narrow_domains <- c("iq", "academics", "verbal", "memory", "executive", "motor")
  if (pheno %in% narrow_domains) {
    figure_types$narrow <- list(
      filename = paste0("fig_", pheno, "_narrow.svg"),
      x_var = "z_mean_narrow",
      y_var = "narrow",
      required = FALSE
    )
  }
  
  return(figure_types)
}

# Main function to generate figures for a domain
generate_domain_figures <- function(pheno, domain_name) {
  message(paste0("\n📊 Generating figures for ", domain_name, " (", pheno, ")..."))
  
  # Read the data
  data <- read_data_file(pheno)
  
  if (is.null(data)) {
    message(paste0("  ✗ No data file found for ", pheno))
    return(NULL)
  }
  
  if (nrow(data) == 0) {
    message(paste0("  ✗ No data available for ", pheno))
    return(NULL)
  }
  
  # Add z-scores if missing
  data <- add_z_scores(data)
  
  # Get figure types to create
  figure_types <- get_figure_types(pheno, data)
  
  generated_files <- character()
  
  # Create each figure type
  for (fig_name in names(figure_types)) {
    fig_info <- figure_types[[fig_name]]
    
    # Check if we have the required columns and data
    has_y_var <- fig_info$y_var %in% names(data)
    has_data <- has_y_var && length(unique(data[[fig_info$y_var]])) > 0
    
    if (has_data) {
      success <- create_dotplot_figure(
        data = data,
        x_var = fig_info$x_var,
        y_var = fig_info$y_var,
        filename = fig_info$filename,
        domain_name = domain_name
      )
      
      if (success) {
        generated_files <- c(generated_files, fig_info$filename)
      }
    } else if (fig_info$required) {
      # Create placeholder for required figures
      message(paste0("  ⚠ Missing ", fig_info$y_var, " data, creating placeholder"))
      success <- create_placeholder_figure(domain_name, fig_info$filename)
      
      if (success) {
        generated_files <- c(generated_files, fig_info$filename)
      }
    } else {
      message(paste0("  ⏭️ Skipping ", fig_name, " figure (optional, no data)"))
    }
  }
  
  return(generated_files)
}

# Main processing function
main_processing <- function() {
  message("🚀 Starting figure generation process...")
  
  # Define domains to process
  domains_to_process <- list(
    list(pheno = "iq", domain = "General Cognitive Ability"),
    list(pheno = "academics", domain = "Academic Skills"),
    list(pheno = "verbal", domain = "Verbal/Language"),
    list(pheno = "spatial", domain = "Visual Perception/Construction"),
    list(pheno = "memory", domain = "Memory"),
    list(pheno = "executive", domain = "Attention/Executive"),
    list(pheno = "motor", domain = "Motor"),
    list(pheno = "social", domain = "Social Cognition"),
    list(pheno = "emotion", domain = "Behavioral/Emotional/Social"),
    list(pheno = "adaptive", domain = "Adaptive Functioning"),
    list(pheno = "adhd", domain = "ADHD"),
    list(pheno = "validity", domain = "Performance/Symptom Validity")
  )
  
  generated_figures <- list()
  skipped_domains <- character()
  total_files <- 0
  
  # Process each domain
  for (domain_info in domains_to_process) {
    # Check if data file exists before attempting to generate figures
    if (check_data_exists(domain_info$pheno)) {
      figure_files <- generate_domain_figures(domain_info$pheno, domain_info$domain)
      if (!is.null(figure_files) && length(figure_files) > 0) {
        generated_figures[[domain_info$pheno]] <- figure_files
        total_files <- total_files + length(figure_files)
      }
    } else {
      message(paste0("\n⏭️  Skipping ", domain_info$domain, " - no data file exists"))
      skipped_domains <- c(skipped_domains, domain_info$domain)
    }
  }
  
  # Report results
  report_results(generated_figures, skipped_domains, total_files)
  
  return(generated_figures)
}

# Function to report generation results
report_results <- function(generated_figures, skipped_domains, total_files) {
  message(paste0("\n", paste(rep("=", 50), collapse = "")))
  message("📈 FIGURE GENERATION SUMMARY")
  message(paste(rep("=", 50), collapse = ""))
  
  if (length(generated_figures) > 0) {
    message(paste0("✅ Successfully processed ", length(generated_figures), " domains"))
    message(paste0("📊 Generated ", total_files, " figure files:"))
    
    # List generated files by category
    figure_files <- list.files(pattern = "^fig_.*\\.(svg|png)$", full.names = FALSE)
    
    if (length(figure_files) > 0) {
      for (file in sort(figure_files)) {
        message(paste0("   📊 ", file))
      }
    }
  } else {
    message("❌ No figures were generated")
  }
  
  if (length(skipped_domains) > 0) {
    message(paste0("\n⏭️  Skipped ", length(skipped_domains), " domains (no data):"))
    for (domain in skipped_domains) {
      message(paste0("   ⚪ ", domain))
    }
  }
  
  message("\n🎯 Figure generation complete!")
  if (length(generated_figures) > 0) {
    message("   ➡️  You can now run the template rendering.")
  } else {
    message("   ⚠️  No figures available for template rendering.")
  }
}

# Null coalesce operator if not defined
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Execute main processing
main_processing()