#!/usr/bin/env Rscript

#' Complete Neuropsychological Report Workflow
#'
#' This script provides a unified entry point for the entire neuropsych report
#' generation process, from raw data to final PDF output.
#'
#' Usage:
#'   Rscript inst/scripts/00_complete_neuropsych_workflow.R [patient_name]
#'
#' Example:
#'   Rscript inst/scripts/00_complete_neuropsych_workflow.R "John Doe"

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
patient_name <- if (length(args) > 0) args[1] else "Patient"

# Set up logging
log_file <- paste0("workflow_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
sink(log_file, split = TRUE)

cat("========================================\n")
cat("NEUROPSYCH REPORT GENERATION WORKFLOW\n")
cat("Patient:", patient_name, "\n")
cat("Started:", format(Sys.time()), "\n")
cat("========================================\n\n")

# Track workflow state
workflow_state <- list(
  templates_checked = FALSE,
  data_processed = FALSE,
  domains_generated = FALSE,
  assets_generated = FALSE,
  report_rendered = FALSE
)

report_output_file <- NULL

# Error handler
handle_error <- function(step, e) {
  cat("\n❌ ERROR in", step, ":\n")
  cat(e$message, "\n")
  cat("\nWorkflow state:\n")
  print(workflow_state)
  cat("\nPlease fix the error and re-run the workflow.\n")
  sink()
  stop(paste("Workflow failed at:", step))
}

# Step 1: Environment setup
cat("\n📋 STEP 1: Checking environment and templates...\n")
tryCatch(
  {
    # Load the package
    if (file.exists("DESCRIPTION")) {
      suppressMessages(devtools::load_all("."))
    } else {
      library(neuro2)
    }

    # Check templates
    system2(
      "Rscript",
      "inst/scripts/01_check_all_templates.R",
      stdout = TRUE,
      stderr = TRUE
    )
    workflow_state$templates_checked <- TRUE
    cat("✅ Templates verified\n")
  },
  error = function(e) handle_error("template checking", e)
)

# Step 2: Data processing
cat("\n🔄 STEP 2: Processing raw data...\n")
tryCatch(
  {
    # Check if data already processed
    data_files <- c(
      "data/neurocog.parquet",
      "data/neurobehav.parquet",
      "data/validity.parquet"
    )
    if (all(file.exists(data_files))) {
      cat("ℹ️  Data files already exist. Skipping processing.\n")
      cat("   Delete files in data/ to reprocess.\n")
    } else {
      result <- system2(
        "Rscript",
        "inst/scripts/02_data_processor_module.R",
        stdout = TRUE,
        stderr = TRUE
      )
      if (!all(file.exists(data_files))) {
        stop("Data processing failed - output files not created")
      }
    }
    workflow_state$data_processed <- TRUE
    cat("✅ Data processed successfully\n")
  },
  error = function(e) handle_error("data processing", e)
)

# Step 3: Domain file generation
cat("\n📄 STEP 3: Generating domain files...\n")
tryCatch(
  {
    # Generate domain QMD files
    result <- system2(
      "Rscript",
      "inst/scripts/03_generate_domain_files.R",
      stdout = TRUE,
      stderr = TRUE
    )

    # Check if any domain files were created
    domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
    if (length(domain_files) == 0) {
      warning(
        "No domain files generated - check if data contains valid domains"
      )
    } else {
      cat("✅ Generated", length(domain_files), "domain files\n")
    }
    workflow_state$domains_generated <- TRUE
  },
  error = function(e) handle_error("domain generation", e)
)

# Step 4: Asset generation
cat("\n🎨 STEP 4: Generating tables and figures...\n")
tryCatch(
  {
    result <- system2(
      "Rscript",
      "inst/scripts/04_generate_all_domain_assets.R",
      stdout = TRUE,
      stderr = TRUE
    )

    # Verify critical assets exist
    critical_assets <- c("figs/fig_sirf_overall.svg")
    if (!all(file.exists(critical_assets))) {
      warning("Some critical assets missing - report may have errors")
    }

    workflow_state$assets_generated <- TRUE
    cat("✅ Assets generated successfully\n")
  },
  error = function(e) handle_error("asset generation", e)
)

# Step 5: Report rendering
cat("\n📑 STEP 5: Rendering final report...\n")
tryCatch(
  {
    # Determine report settings from config
    template_file <- "template.qmd"
    output_dir <- "output"
    format <- "neurotyp-pediatric-typst"

    if (file.exists("config.yml")) {
      config <- yaml::read_yaml("config.yml")
      format <- config$report$format %||% format
      template_file <- config$report$template %||% template_file
      output_dir <- config$report$output_dir %||% output_dir
    }

    if (is.null(output_dir) || !nzchar(output_dir)) {
      output_dir <- "."
    }

    output_name <- sub("\\.[^.]+$", ".pdf", basename(template_file))
    if (identical(output_name, basename(template_file))) {
      output_name <- paste0(basename(template_file), ".pdf")
    }

    output_file <- if (identical(output_dir, ".")) {
      output_name
    } else {
      file.path(output_dir, output_name)
    }

    cat("Using format:", format, "\n")
    cat("Using template:", template_file, "\n")
    cat("Saving report to:", output_file, "\n")

    if (!identical(output_dir, ".") && !dir.exists(output_dir)) {
      if (!dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)) {
        stop("Failed to create report output directory: ", output_dir)
      }
    }

    quarto_args <- c("render", template_file, "-t", format)
    if (!identical(output_dir, ".")) {
      quarto_args <- c(quarto_args, "--output-dir", output_dir)
    }

    # Render with Quarto
    result <- system2(
      "quarto",
      args = quarto_args,
      stdout = TRUE,
      stderr = TRUE
    )

    status <- attr(result, "status") %||% 0
    if (status != 0) {
      stop(
        paste0(
          "Quarto render failed with status ",
          status,
          ":\n",
          paste(result, collapse = "\n")
        )
      )
    }

    if (file.exists(output_file)) {
      cat("✅ Report rendered successfully:", output_file, "\n")
      workflow_state$report_rendered <- TRUE
      report_output_file <- output_file
    } else {
      stop("Report rendering failed - no output file created")
    }
  },
  error = function(e) handle_error("report rendering", e)
)

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
  cat("\n🎉 Success! Your report is ready at:", report_output_file, "\n")
} else {
  cat("\n⚠️  Workflow incomplete. Check the log for errors.\n")
}

cat("========================================\n")

# Close log
sink()
cat("\nWorkflow log saved to:", log_file, "\n")
