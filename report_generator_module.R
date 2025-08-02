#!/usr/bin/env Rscript

# REPORT GENERATOR MODULE
# This module handles the final report generation for the neuropsychological workflow
# It renders the Quarto template into the final report format

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry)
}

# Get configuration from the parent environment
# This assumes this script is sourced from the WorkflowRunner
if (exists("self") && inherits(self, "R6")) {
  config <- self$config
} else {
  # Fallback if not called from WorkflowRunner
  if (file.exists("config.yml")) {
    if (!requireNamespace("yaml", quietly = TRUE)) {
      install.packages("yaml")
      library(yaml)
    }
    config <- yaml::read_yaml("config.yml")
  } else {
    stop("Configuration not available")
  }
}

# Load required packages
required_packages <- c("quarto", "yaml")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    log_message(paste("Installing package:", pkg), "REPORT")
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE, quietly = TRUE)
}

# Log the report generation start
log_message("Starting report generation", "REPORT")

# Get template file from config
template_file <- config$report$template
log_message(paste0("Using template file: ", template_file), "REPORT")
log_message(paste0("Current working directory: ", getwd()), "REPORT")

# Check if template file exists
if (file.exists(template_file)) {
  log_message(paste0("Template file found: ", template_file), "REPORT")
  # Get file info for additional verification
  file_info <- file.info(template_file)
  log_message(paste0("File size: ", file_info$size, " bytes"), "REPORT")
  log_message(paste0("Last modified: ", file_info$mtime), "REPORT")
} else {
  # Check if the file exists in the template directory
  template_dir <- "inst/quarto/templates/typst-report"
  alt_template_path <- file.path(template_dir, template_file)
  
  if (file.exists(alt_template_path)) {
    log_message(
      paste0("Template found in template directory: ", alt_template_path),
      "REPORT"
    )
    log_message("Copying template file to working directory...", "REPORT")
    file.copy(alt_template_path, template_file)
    
    if (file.exists(template_file)) {
      log_message("Template file copied successfully", "REPORT")
    } else {
      log_message(
        paste0("Failed to copy template file from: ", alt_template_path),
        "ERROR"
      )
      stop("Template file copy failed")
    }
  } else {
    log_message(paste0("Template file not found: ", template_file), "ERROR")
    log_message(paste0("Also checked: ", alt_template_path), "ERROR")
    stop("Template file not found")
  }
}

# Render the report
log_message(
  paste0("Rendering ", template_file, " with Quarto"),
  "REPORT"
)

tryCatch({
  quarto::quarto_render(
    input = template_file,
    output_format = config$report$format
  )
  log_message("Quarto rendering completed", "REPORT")
}, error = function(e) {
  log_message(paste0("Error during Quarto rendering: ", e$message), "ERROR")
  stop(e)
})

# Check if report was generated
# Handle both .qmd and .typ template files
if (grepl("\\.qmd$", template_file)) {
  report_file <- gsub("\\.qmd$", ".pdf", template_file)
} else if (grepl("\\.typ$", template_file)) {
  report_file <- gsub("\\.typ$", ".pdf", template_file)
} else {
  # For other file types, assume PDF output with same base name
  report_file <- paste0(tools::file_path_sans_ext(template_file), ".pdf")
}

# Check if the PDF was generated
if (file.exists(report_file)) {
  log_message(
    paste0("Report generated successfully: ", report_file),
    "REPORT"
  )
} else {
  # Try other formats
  if (grepl("\\.qmd$", template_file)) {
    report_file <- gsub("\\.qmd$", ".html", template_file)
  } else if (grepl("\\.typ$", template_file)) {
    report_file <- gsub("\\.typ$", ".html", template_file)
  } else {
    report_file <- paste0(tools::file_path_sans_ext(template_file), ".html")
  }
  
  if (file.exists(report_file)) {
    log_message(
      paste0("Report generated successfully: ", report_file),
      "REPORT"
    )
  } else {
    # Check for DOCX format
    if (grepl("\\.qmd$", template_file)) {
      report_file <- gsub("\\.qmd$", ".docx", template_file)
    } else if (grepl("\\.typ$", template_file)) {
      report_file <- gsub("\\.typ$", ".docx", template_file)
    } else {
      report_file <- paste0(tools::file_path_sans_ext(template_file), ".docx")
    }
    
    if (file.exists(report_file)) {
      log_message(
        paste0("Report generated successfully: ", report_file),
        "REPORT"
      )
    } else {
      log_message("Report generation failed - no output file found", "ERROR")
      log_message(paste0("Looked for PDF/HTML/DOCX outputs from: ", template_file), "ERROR")
      stop("Report generation failed")
    }
  }
}

# Move report to output directory if specified
if (!is.null(config$report$output_dir) && 
    config$report$output_dir != "." && 
    config$report$output_dir != "") {
  
  # Create output directory if it doesn't exist
  if (!dir.exists(config$report$output_dir)) {
    dir.create(config$report$output_dir, recursive = TRUE, showWarnings = FALSE)
    log_message(paste0("Created output directory: ", config$report$output_dir), "REPORT")
  }
  
  # Move the report file
  dest_file <- file.path(config$report$output_dir, basename(report_file))
  if (file.copy(report_file, dest_file, overwrite = TRUE)) {
    log_message(paste0("Report moved to: ", dest_file), "REPORT")
    # Remove the original file from working directory
    file.remove(report_file)
    report_file <- dest_file
  } else {
    log_message("Failed to move report to output directory", "WARNING")
  }
}

log_message("Report generation completed successfully", "REPORT")
log_message(paste0("Final report location: ", report_file), "REPORT")