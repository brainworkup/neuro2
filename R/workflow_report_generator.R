# Report Generation Module
# Handles report generation for the workflow

generate_workflow_report <- function(config) {
  # Removed: source("R/workflow_utils.R") - not needed in R package

  log_message("Generating report...", "WORKFLOW")

  # Source the report generator module if it exists
  if (file.exists("inst/scripts/report_generator_module.R")) {
    log_message("Running report_generator_module.R", "REPORT")
    source("inst/scripts/report_generator_module.R") # External script, so kept
    return(TRUE)
  }

  # Run default report generation
  template_file <- ensure_template_file("template.qmd")

  if (!file.exists(template_file)) {
    log_message("No template file found", "ERROR")
    return(FALSE)
  }

  # Try to render using quarto if available
  if (requireNamespace("quarto", quietly = TRUE)) {
    tryCatch(
      {
        # Use absolute path to avoid 'invalid file argument' error
        template_abs_path <- normalizePath(template_file)
        quarto::quarto_render(template_abs_path)
        log_message("Report generated successfully", "REPORT")
        return(TRUE)
      },
      error = function(e) {
        log_message(paste("Quarto render failed:", e$message), "ERROR")
        return(FALSE)
      }
    )
  } else {
    log_message("Quarto not available - skipping render", "WARNING")
    return(FALSE)
  }
}

# Print report summary
print_report_summary <- function(config) {
  # Removed: source("R/workflow_utils.R") - not needed in R package

  log_message("Report generation complete", "REPORT")

  # Check for generated files
  output_files <- list.files(
    path = config$output$dir,
    pattern = "\\.(pdf|html)$",
    full.names = TRUE
  )

  if (length(output_files) > 0) {
    message("Generated files:")
    for (file in output_files) {
      message("  - ", file)
    }
  } else {
    message("No output files found")
  }
}

# Ensure template file exists
ensure_template_file <- function(template_file, log_type = "INFO") {
  # Removed: source("R/workflow_utils.R") - not needed in R package

  if (file.exists(template_file)) {
    return(template_file)
  }

  # Try to find template in inst directory
  inst_template <- system.file(
    "quarto",
    "templates",
    "typst-report",
    template_file,
    package = "neuro2"
  )

  if (file.exists(inst_template)) {
    # Copy to working directory
    file.copy(inst_template, template_file)
    log_message(paste("Copied template from:", inst_template), log_type)
    return(template_file)
  }

  # Check in common locations
  common_paths <- c(
    file.path("inst", "quarto", "templates", "typst-report", template_file),
    file.path("templates", template_file),
    file.path(".", template_file)
  )

  for (path in common_paths) {
    if (file.exists(path)) {
      file.copy(path, template_file)
      log_message(paste("Copied template from:", path), log_type)
      return(template_file)
    }
  }

  log_message(paste("Template file not found:", template_file), "ERROR")
  return(NULL)
}
