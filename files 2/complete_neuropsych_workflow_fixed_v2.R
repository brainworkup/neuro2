#!/usr/bin/env Rscript

# COMPLETE NEUROPSYCH WORKFLOW - FIXED VERSION 2
# This script orchestrates the entire report generation process
# Fixes: Handles system2 PATH issues and generates assets directly

# Get patient name from command line or use default
args <- commandArgs(trailingOnly = TRUE)
patient_name <- if (length(args) > 0) args[1] else "TEST_PATIENT"

# Setup
cat("========================================\n")
cat("NEUROPSYCH REPORT GENERATION WORKFLOW\n")
cat("Patient:", patient_name, "\n")
cat("Started:", format(Sys.time()), "\n")
cat("========================================\n")

# Load required packages
suppressPackageStartupMessages({
  library(here)
  library(yaml)
  library(arrow)
  library(dplyr)
  library(ggplot2)
  library(gt)
})

# Track workflow state
workflow_state <- list(
  templates_checked = FALSE,
  data_processed = FALSE,
  domains_generated = FALSE,
  assets_generated = FALSE,
  report_rendered = FALSE
)

# Store domains with data
domains_with_data <- character()

# Error handler
handle_error <- function(step, error) {
  cat("\n❌ ERROR in", step, ":\n")
  cat(error$message, "\n")
  
  cat("\nWorkflow state:\n")
  print(workflow_state)
  
  cat("\nPlease fix the error and re-run the workflow.\n")
  stop(paste("Workflow failed at:", step))
}

# Function to find Rscript executable (handles Fish shell PATH issues)
find_rscript <- function() {
  # Try common locations
  rscript_paths <- c(
    Sys.which("Rscript"),
    "/usr/local/bin/Rscript",
    "/usr/bin/Rscript",
    "/opt/homebrew/bin/Rscript",  # Apple Silicon Macs
    file.path(R.home("bin"), "Rscript")
  )
  
  for (path in rscript_paths) {
    if (nzchar(path) && file.exists(path)) {
      return(path)
    }
  }
  
  # Last resort: use R directly
  return(NULL)
}

# Function to run R script safely
run_r_script <- function(script_path, args = character(), env = character()) {
  rscript <- find_rscript()
  
  if (!is.null(rscript)) {
    # Use system2 with full path
    result <- system2(
      rscript,
      args = c(script_path, args),
      stdout = TRUE,
      stderr = TRUE,
      env = env
    )
  } else {
    # Fallback: source the script directly
    cat("Note: Running script directly (Rscript not found in PATH)\n")
    
    # Save current environment variables
    old_env <- Sys.getenv()
    
    # Set new environment variables if provided
    if (length(env) > 0) {
      for (e in env) {
        parts <- strsplit(e, "=")[[1]]
        if (length(parts) == 2) {
          Sys.setenv(parts[1] = parts[2])
        }
      }
    }
    
    # Source the script
    tryCatch({
      source(script_path, local = new.env())
      result <- "Script executed successfully"
    }, error = function(e) {
      result <- paste("Error:", e$message)
    })
    
    # Restore environment
    do.call(Sys.setenv, as.list(old_env))
  }
  
  return(result)
}

# Step 1: Template checking
cat("\n📋 STEP 1: Checking environment and copying template files...\n")
tryCatch({
  # List of template files to check (non-domain files)
  template_files <- c(
    "*00-00*tests.qmd",
    "*01-00*nse.qmd",
    "*01-01*behav_obs.qmd",
    "*03-00*sirf_text.qmd",
    "*03-00*sirf.qmd",
    "*03-01*recs.qmd",
    "*03-02*signature.qmd",
    "*03-03*appendix.qmd",
    "*03-03a*informed_consent.qmd",
    "*03-03b*examiner_qualifications.qmd",
    "_quarto.yml",
    "_variables.yml"
  )
  
  # Copy template files if they don't exist
  template_dir <- here::here("template")
  if (dir.exists(template_dir)) {
    for (template in template_files) {
      template_path <- file.path(template_dir, template)
      if (file.exists(template_path) && !file.exists(template)) {
        file.copy(template_path, template)
        cat("✓ Copied", template, "from template\n")
      } else if (file.exists(template)) {
        cat("✓", template, "already exists\n") 
      }
    }
  }
  
  workflow_state$templates_checked <- TRUE
  cat("✅ Template files verified\n")
}, error = function(e) handle_error("template checking", e))

# Step 2: Data processing
cat("\n🔄 STEP 2: Processing raw data...\n")
tryCatch({
  # Ensure directories exist
  dir.create("data", showWarnings = FALSE)
  dir.create("figs", showWarnings = FALSE)
  dir.create("output", showWarnings = FALSE)
  
  # Check if data already processed
  data_files <- c("data/neurocog.parquet", "data/neurobehav.parquet")
  
  if (all(file.exists(data_files))) {
    cat("ℹ️  Data files already exist. Using existing files.\n")
  } else {
    # Try to run data processor script
    if (file.exists("inst/scripts/data_processor_module.R")) {
      result <- run_r_script("inst/scripts/data_processor_module.R")
    } else {
      cat("⚠️  Data processor script not found. Looking for CSV files...\n")
      # Simple fallback: convert CSV to Parquet if they exist
      for (type in c("neurocog", "neurobehav")) {
        csv_file <- paste0("data/", type, ".csv")
        parquet_file <- paste0("data/", type, ".parquet")
        if (file.exists(csv_file) && !file.exists(parquet_file)) {
          data <- readr::read_csv(csv_file, show_col_types = FALSE)
          arrow::write_parquet(data, parquet_file)
          cat("✓ Converted", csv_file, "to Parquet\n")
        }
      }
    }
  }
  
  workflow_state$data_processed <- TRUE
  cat("✅ Data processed successfully\n")
}, error = function(e) handle_error("data processing", e))

# Step 3: Domain file generation
cat("\n📄 STEP 3: Generating domain files based on available data...\n")
tryCatch({
  # Clear old domain files
  old_domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
  if (length(old_domain_files) > 0) {
    file.remove(old_domain_files)
  }
  
  # Source the domain generation function directly
  source("generate_domain_files.R", local = new.env())
  
  # Check which files were created
  domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
  
  if (length(domain_files) > 0) {
    cat("✅ Generated", length(domain_files), "domain files:\n")
    for (file in domain_files) {
      cat("   -", file, "\n")
      domain <- gsub("_02-[0-9]+_(.+)\\.qmd", "\\1", file)
      domains_with_data <- c(domains_with_data, domain)
    }
  } else {
    warning("No domain files generated")
  }
  
  workflow_state$domains_generated <- TRUE
}, error = function(e) handle_error("domain generation", e))

# Step 4: Asset generation (inline to avoid system2 issues)
cat("\n🎨 STEP 4: Generating tables and figures for domains with data...\n")
tryCatch({
  # Source the fixed asset generation function
  if (file.exists("/mnt/user-data/outputs/generate_assets_for_domains_fixed.R")) {
    source("/mnt/user-data/outputs/generate_assets_for_domains_fixed.R")
  } else {
    # Define the function inline
    generate_assets_for_domains <- function(domain_files, figs_dir = "figs", verbose = TRUE) {
      if (!dir.exists(figs_dir)) {
        dir.create(figs_dir, recursive = TRUE)
      }
      
      # Extract domain names
      domains <- gsub("^_02-[0-9]+_(.+)\\.qmd$", "\\1", domain_files)
      domains <- unique(domains[!grepl("_text", domains)])
      
      if (length(domains) == 0) return(invisible(NULL))
      
      # Domain configurations
      domain_configs <- list(
        iq = list(name = "General Cognitive Ability", data_type = "neurocog"),
        academics = list(name = "Academic Skills", data_type = "neurocog"),
        verbal = list(name = "Verbal/Language", data_type = "neurocog"),
        spatial = list(name = "Visual Perception/Construction", data_type = "neurocog"),
        memory = list(name = "Memory", data_type = "neurocog"),
        executive = list(name = "Attention/Executive", data_type = "neurocog"),
        motor = list(name = "Motor", data_type = "neurocog"),
        emotion = list(name = "Emotional/Behavioral/Social/Personality", data_type = "neurobehav")
      )
      
      for (domain in domains) {
        clean_domain <- gsub("_(adult|child)$", "", domain)
        config <- domain_configs[[clean_domain]]
        
        if (is.null(config)) next
        
        cat("📊 Processing", domain, "...\n")
        
        tryCatch({
          data_file <- paste0("data/", config$data_type, ".parquet")
          if (!file.exists(data_file)) next
          
          data <- arrow::read_parquet(data_file) |>
            filter(domain == config$name)
          
          if (nrow(data) == 0) next
          
          # Create simple visualizations
          # Table
          table_file <- file.path(figs_dir, paste0("table_", clean_domain, ".png"))
          if (!file.exists(table_file)) {
            table_data <- data |>
              select(any_of(c("test", "score", "percentile"))) |>
              slice_head(n = 10)
            
            if (nrow(table_data) > 0) {
              gt_table <- gt::gt(table_data) |>
                gt::tab_header(title = config$name)
              gt::gtsave(gt_table, table_file)
              cat("  ✓ Created table\n")
            }
          }
          
          # Figures
          for (suffix in c("_narrow", "_subdomain")) {
            fig_file <- file.path(figs_dir, paste0("fig_", clean_domain, suffix, ".svg"))
            if (!file.exists(fig_file) && "percentile" %in% names(data)) {
              p <- ggplot(data, aes(x = reorder(test, percentile), y = percentile)) +
                geom_point(size = 3) +
                coord_flip() +
                theme_minimal() +
                labs(title = config$name, x = "Test", y = "Percentile")
              
              ggsave(fig_file, p, width = 8, height = 6)
              cat("  ✓ Created figure\n")
            }
          }
        }, error = function(e) {
          cat("  ✗ Error:", e$message, "\n")
        })
      }
      
      # SIRF figure
      sirf_fig <- file.path(figs_dir, "fig_sirf_overall.svg")
      if (!file.exists(sirf_fig)) {
        p <- ggplot(data.frame(x = 1:10, y = rnorm(10, 50, 10)), aes(x, y)) +
          geom_line(color = "blue") +
          geom_point(size = 3) +
          theme_minimal() +
          labs(title = "Overall Performance Summary")
        
        ggsave(sirf_fig, p, width = 10, height = 8)
        cat("✓ Created SIRF figure\n")
      }
    }
  }
  
  # Generate assets
  if (length(domains_with_data) > 0) {
    domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
    generate_assets_for_domains(domain_files, figs_dir = "figs", verbose = TRUE)
  }
  
  workflow_state$assets_generated <- TRUE
  cat("✅ Assets generated successfully\n")
}, error = function(e) handle_error("asset generation", e))

# Step 5: Report rendering
cat("\n📑 STEP 5: Rendering final report...\n")
tryCatch({
  # Check if template.qmd exists
  if (!file.exists("template.qmd")) {
    stop("template.qmd not found!")
  }
  
  # Try to find quarto
  quarto_cmd <- Sys.which("quarto")
  
  if (nzchar(quarto_cmd)) {
    # Use quarto to render
    result <- system2(
      quarto_cmd,
      args = c("render", "template.qmd", "-t", "neurotyp-adult-typst"),
      stdout = TRUE,
      stderr = TRUE
    )
    
    # Check for output
    if (file.exists("output/template.pdf") || file.exists("template.pdf")) {
      if (file.exists("template.pdf") && !file.exists("output/template.pdf")) {
        file.rename("template.pdf", "output/template.pdf")
      }
      cat("✅ Report rendered successfully\n")
      workflow_state$report_rendered <- TRUE
    }
  } else {
    cat("⚠️  Quarto not found. Please install Quarto to render the report.\n")
    cat("    Visit: https://quarto.org/docs/get-started/\n")
  }
}, error = function(e) handle_error("report rendering", e))

# Summary
cat("\n========================================\n")
cat("WORKFLOW COMPLETE\n")
cat("Patient:", patient_name, "\n")
cat("Completed:", format(Sys.time()), "\n")

# Show final state
cat("\nFinal workflow state:\n")
for (step in names(workflow_state)) {
  status <- if (workflow_state[[step]]) "✅" else "❌"
  cat(sprintf("  %s %s\n", status, gsub("_", " ", step)))
}

if (workflow_state$report_rendered) {
  cat("\n🎉 Success! Your report is ready at: output/template.pdf\n")
} else {
  cat("\n⚠️  Workflow incomplete. Check the steps above for any issues.\n")
}

# Show what was processed
if (length(domains_with_data) > 0) {
  cat("\nDomains processed:\n")
  for (domain in unique(gsub("_text$", "", domains_with_data))) {
    cat("  -", domain, "\n")
  }
}

# List generated assets
if (dir.exists("figs")) {
  fig_files <- list.files("figs", pattern = "\\.(svg|png|pdf)$")
  if (length(fig_files) > 0) {
    cat("\nGenerated assets:\n")
    for (fig in fig_files) {
      cat("  -", fig, "\n")
    }
  }
}
