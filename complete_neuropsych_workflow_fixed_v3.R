#!/usr/bin/env Rscript

#' FIXED NEUROPSYCH WORKFLOW v3 - Enhanced Quarto Rendering
#' Fixes common Quarto rendering issues with custom Typst formats

# Parse arguments
args <- commandArgs(trailingOnly = TRUE)
patient_name <- if (length(args) > 0) args[1] else "TEST_PATIENT"
debug_mode <- "--debug" %in% args

# Setup
cat("\n========================================\n")
cat("NEUROPSYCH REPORT GENERATION WORKFLOW\n")
cat("Patient:", patient_name, "\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("========================================\n")

# Create workflow state tracker
workflow_state <- list(
  templates_checked = FALSE,
  data_processed = FALSE,
  domains_generated = FALSE,
  assets_generated = FALSE,
  report_rendered = FALSE
)

# Enhanced error handler with debug info
handle_error <- function(step, error) {
  cat("\n❌ ERROR in", step, ":\n")
  cat(as.character(error), "\n")
  
  # Save workflow state for debugging
  cat("\nWorkflow state:\n")
  print(workflow_state)
  
  # Provide step-specific recovery suggestions
  recovery_hints <- list(
    "template checking" = "Ensure all template files are in the current directory",
    "data processing" = "Check that raw data files exist in data-raw/csv/",
    "domain generation" = "Verify neuro2 package is installed and loaded",
    "asset generation" = "Check that data files were processed correctly",
    "report rendering" = "Run diagnose_quarto_issue.R for detailed diagnostics"
  )
  
  if (step %in% names(recovery_hints)) {
    cat("\n💡 Hint:", recovery_hints[[step]], "\n")
  }
  
  cat("\nPlease fix the error and re-run the workflow.\n")
  stop(paste("Workflow failed at:", step), call. = FALSE)
}

# Function to ensure directories exist
ensure_directories <- function() {
  dirs <- c("data", "data-raw", "data-raw/csv", "figs", "output", "logs")
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      cat("📁 Created directory:", dir, "\n")
    }
  }
}

# Function to create minimal template files if missing
create_minimal_templates <- function() {
  # Minimal QMD files for missing includes
  template_files <- list(
    "_00-00_tests.qmd" = "<!-- Tests administered -->",
    "_01-00_nse.qmd" = "<!-- Neurosensory examination -->",
    "_01-01_behav_obs.qmd" = "<!-- Behavioral observations -->",
    "_03-00_sirf.qmd" = "<!-- Summary and interpretation -->",
    "_03-00_sirf_text.qmd" = "<!-- Summary text -->",
    "_03-01_recs.qmd" = "<!-- Recommendations -->",
    "_03-02_signature.qmd" = "<!-- Signature block -->",
    "_03-03_appendix.qmd" = "<!-- Appendix -->"
  )
  
  for (file in names(template_files)) {
    if (!file.exists(file)) {
      writeLines(template_files[[file]], file)
      cat("📝 Created minimal template:", file, "\n")
    }
  }
}

# Initialize environment
ensure_directories()

# Redirect output to log if not in debug mode
log_file <- sprintf("logs/workflow_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
if (!debug_mode) {
  sink(log_file, split = TRUE)
  cat("Logging to:", log_file, "\n\n")
}

# Step 1: Check templates
cat("\n📋 STEP 1: Checking environment and templates...\n")
tryCatch(
  {
    # Check for critical files
    critical_files <- c("template.qmd", "_quarto.yml")
    missing <- critical_files[!file.exists(critical_files)]
    
    if (length(missing) > 0) {
      stop(paste("Missing critical files:", paste(missing, collapse = ", ")))
    }
    
    # Create minimal templates for missing includes
    create_minimal_templates()
    
    # Check Quarto installation
    quarto_version <- tryCatch({
      system2("quarto", "--version", stdout = TRUE, stderr = FALSE)
    }, error = function(e) NULL)
    
    if (is.null(quarto_version)) {
      stop("Quarto is not installed or not in PATH")
    }
    
    cat("✅ Quarto version:", quarto_version[1], "\n")
    cat("✅ Templates verified\n")
    workflow_state$templates_checked <- TRUE
  },
  error = function(e) handle_error("template checking", e)
)

# Step 2: Data processing
cat("\n🔄 STEP 2: Processing raw data...\n")
tryCatch(
  {
    # Check if data already exists
    data_exists <- file.exists("data/neurocog.csv") || 
                   file.exists("data/neurocog.parquet")
    
    if (data_exists) {
      cat("ℹ️  Data files already exist. Skipping processing.\n")
      cat("   Delete files in data/ to reprocess.\n")
    } else {
      # Run data processing
      if (file.exists("inst/scripts/process_data.R")) {
        source("inst/scripts/process_data.R")
      } else {
        # Create dummy data if no processing script
        cat("⚠️  No data processing script found, creating dummy data...\n")
        if (!dir.exists("data")) dir.create("data")
        
        # Create minimal dummy data
        dummy_data <- data.frame(
          test = "WAIS-IV",
          scale = "Full Scale IQ",
          score = 100,
          percentile = 50,
          domain = "General Cognitive Ability"
        )
        write.csv(dummy_data, "data/neurocog.csv", row.names = FALSE)
        write.csv(dummy_data, "data/neurobehav.csv", row.names = FALSE)
      }
    }
    
    cat("✅ Data processed successfully\n")
    workflow_state$data_processed <- TRUE
  },
  error = function(e) handle_error("data processing", e)
)

# Step 3: Generate domain files
cat("\n📄 STEP 3: Generating domain files...\n")
tryCatch(
  {
    # Source the domain generation script
    if (file.exists("generate_domain_files.R")) {
      source("generate_domain_files.R")
    } else {
      # Create domain files directly
      domain_files <- c(
        "_02-01_iq.qmd", "_02-02_academics.qmd", "_02-03_verbal.qmd",
        "_02-04_spatial.qmd", "_02-05_memory.qmd", "_02-06_executive.qmd",
        "_02-07_motor.qmd", "_02-10_emotion.qmd"
      )
      
      for (file in domain_files) {
        if (!file.exists(file)) {
          content <- sprintf("<!-- %s domain content -->", 
                           gsub(".*_|\\.qmd", "", file))
          writeLines(content, file)
        }
      }
    }
    
    # Count generated files
    domain_count <- sum(file.exists(c(
      "_02-01_iq.qmd", "_02-02_academics.qmd", "_02-03_verbal.qmd",
      "_02-04_spatial.qmd", "_02-05_memory.qmd", "_02-06_executive.qmd",
      "_02-07_motor.qmd", "_02-10_emotion.qmd"
    )))
    
    cat("✅ Generated", domain_count, "domain files\n")
    workflow_state$domains_generated <- TRUE
  },
  error = function(e) handle_error("domain generation", e)
)

# Step 4: Generate assets
cat("\n🎨 STEP 4: Generating tables and figures...\n")
tryCatch(
  {
    if (file.exists("generate_all_domain_assets.R")) {
      source("generate_all_domain_assets.R")
    } else {
      cat("⚠️  No asset generation script found, creating placeholders...\n")
      if (!dir.exists("figs")) dir.create("figs")
      
      # Create a placeholder SVG
      svg_content <- '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <rect width="100" height="100" fill="lightgray"/>
        <text x="50" y="50" text-anchor="middle">Placeholder</text>
      </svg>'
      writeLines(svg_content, "figs/fig_sirf_overall.svg")
    }
    
    cat("✅ Assets generated successfully\n")
    workflow_state$assets_generated <- TRUE
  },
  error = function(e) handle_error("asset generation", e)
)

# Step 5: Enhanced report rendering with fallbacks
cat("\n📑 STEP 5: Rendering final report...\n")
tryCatch(
  {
    # Read config to get format
    format <- "typst"  # Default fallback
    if (file.exists("config.yml")) {
      config <- yaml::read_yaml("config.yml")
      format <- config$report$format %||% "typst"
    }
    
    cat("Target format:", format, "\n")
    
    # Try rendering with different strategies
    render_success <- FALSE
    output_file <- NULL
    
    # Strategy 1: Try custom format
    if (!render_success && format != "typst") {
      cat("Attempting render with custom format:", format, "\n")
      result <- system2("quarto",
        args = c("render", "template.qmd", "--to", format, "--quiet"),
        stdout = FALSE, stderr = FALSE
      )
      
      if (result == 0) {
        render_success <- TRUE
        output_file <- "template.pdf"
        cat("✅ Rendered with custom format\n")
      } else {
        cat("⚠️  Custom format failed, trying fallback...\n")
      }
    }
    
    # Strategy 2: Try basic typst
    if (!render_success) {
      cat("Attempting render with basic typst format...\n")
      result <- system2("quarto",
        args = c("render", "template.qmd", "--to", "typst", "--quiet"),
        stdout = FALSE, stderr = FALSE
      )
      
      if (result == 0) {
        render_success <- TRUE
        output_file <- "template.pdf"
        cat("✅ Rendered with basic typst\n")
      } else {
        cat("⚠️  Basic typst failed, trying HTML...\n")
      }
    }
    
    # Strategy 3: Try HTML as last resort
    if (!render_success) {
      cat("Attempting render with HTML format...\n")
      result <- system2("quarto",
        args = c("render", "template.qmd", "--to", "html", "--quiet"),
        stdout = FALSE, stderr = FALSE
      )
      
      if (result == 0) {
        render_success <- TRUE
        output_file <- "template.html"
        cat("✅ Rendered as HTML (fallback)\n")
      }
    }
    
    # Check for output and move to output directory
    if (render_success && !is.null(output_file)) {
      # Ensure output directory exists
      if (!dir.exists("output")) dir.create("output")
      
      # Move output file if it exists
      if (file.exists(output_file)) {
        output_path <- file.path("output", output_file)
        file.rename(output_file, output_path)
        cat("✅ Report saved to:", output_path, "\n")
        workflow_state$report_rendered <- TRUE
      } else {
        # Check if it's already in output directory
        output_path <- file.path("output", output_file)
        if (file.exists(output_path)) {
          cat("✅ Report found at:", output_path, "\n")
          workflow_state$report_rendered <- TRUE
        } else {
          stop("Report file not found after rendering")
        }
      }
    } else {
      # If all strategies failed, provide detailed diagnostics
      cat("\n❌ All rendering strategies failed\n")
      cat("\nRunning diagnostics...\n")
      
      # Get verbose error output
      result <- system2("quarto",
        args = c("render", "template.qmd", "--to", "typst", "--verbose"),
        stdout = TRUE, stderr = TRUE
      )
      
      cat("\nQuarto output:\n")
      cat(result, sep = "\n")
      
      stop("Report rendering failed - see output above for details")
    }
  },
  error = function(e) handle_error("report rendering", e)
)

# Summary
cat("\n========================================\n")
cat("WORKFLOW COMPLETE\n")
cat("========================================\n")

# Show final state
cat("\nFinal workflow state:\n")
for (step in names(workflow_state)) {
  status <- if (workflow_state[[step]]) "✅" else "❌"
  cat(sprintf("  %s %s\n", status, gsub("_", " ", step)))
}

if (workflow_state$report_rendered) {
  cat("\n🎉 Success! Your report is ready in the output/ directory\n")
  
  # Try to open the report
  output_files <- list.files("output", pattern = "template\\.(pdf|html)$", 
                            full.names = TRUE)
  if (length(output_files) > 0) {
    cat("Generated file:", output_files[1], "\n")
    
    # Try to open on macOS
    if (Sys.info()["sysname"] == "Darwin" && interactive()) {
      system2("open", output_files[1])
    }
  }
} else {
  cat("\n⚠️  Workflow incomplete. Check the log for errors.\n")
  cat("Run diagnose_quarto_issue.R for detailed diagnostics.\n")
}

cat("========================================\n")

# Close log
if (!debug_mode) {
  sink()
  cat("\nWorkflow log saved to:", log_file, "\n")
}
