# Report Generation Module
# Handles final report generation using Quarto

generate_workflow_report <- function(config) {
  source("R/workflow_utils.R")

  log_message("Generating final report...", "WORKFLOW")

  # Source the report generator module if it exists
  if (file.exists("scripts/report_generator_module.R")) {
    log_message("Running report_generator_module.R", "REPORT")
    source("scripts/report_generator_module.R")
    return(TRUE)
  }

  # Use Quarto directly
  log_message(
    "report_generator_module.R not found. Using Quarto directly.",
    "REPORT"
  )

  # Ensure template file exists
  template_file <- config$report$template
  if (!ensure_template_file(template_file, "REPORT")) {
    return(FALSE)
  }

  # Render the report
  log_message(
    paste0("Rendering ", config$report$template, " with Quarto"),
    "REPORT"
  )

  tryCatch(
    {
      quarto::quarto_render(
        input = config$report$template,
        output_format = config$report$format
      )
    },
    error = function(e) {
      log_message(paste0("Error rendering report: ", e$message), "ERROR")
      return(FALSE)
    }
  )

  # Verify report was generated
  if (verify_report_output(config$report$template)) {
    log_message("Report generation complete", "REPORT")
    return(TRUE)
  } else {
    log_message("Report generation failed", "ERROR")
    return(FALSE)
  }
}

verify_report_output <- function(template_file) {
  source("R/workflow_utils.R")

  # Check for PDF output
  report_file <- gsub("\\.qmd$", ".pdf", template_file)
  if (file.exists(report_file)) {
    log_message(
      paste0("Report generated successfully: ", report_file),
      "REPORT"
    )
    return(TRUE)
  }

  # Check for HTML output
  report_file <- gsub("\\.qmd$", ".html", template_file)
  if (file.exists(report_file)) {
    log_message(
      paste0("Report generated successfully: ", report_file),
      "REPORT"
    )
    return(TRUE)
  }

  return(FALSE)
}

print_report_summary <- function(config) {
  source("R/workflow_utils.R")

  print_colored("🎉 WORKFLOW COMPLETE!", "green")
  print_colored("Generated files:", "green")

  # List data files
  if (dir.exists(config$data$output_dir)) {
    data_files <- list.files(
      config$data$output_dir,
      pattern = "\\.(csv|parquet|feather|arrow)$"
    )
    for (file in data_files) {
      print_colored(paste0("  📊 ", file), "green")
    }
  }

  # List domain files
  domain_files <- list.files(".", pattern = "_02-.*\\.qmd$")
  if (length(domain_files) > 0) {
    print_colored("\nGenerated domain sections:", "green")
    for (file in domain_files) {
      print_colored(paste0("  📝 ", file), "green")
    }
  }

  # Check for final report
  report_file <- gsub("\\.qmd$", ".pdf", config$report$template)
  if (file.exists(report_file)) {
    print_colored(paste0("\n🎯 Final report: ", report_file), "green")
  } else {
    report_file <- gsub("\\.qmd$", ".html", config$report$template)
    if (file.exists(report_file)) {
      print_colored(paste0("\n🎯 Final report: ", report_file), "green")
    }
  }
}
