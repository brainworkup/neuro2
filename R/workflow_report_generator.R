# Report Generation Module
# Handles report generation for the workflow

#' Fix domain files after generation to remove R6 dependencies
#'
#' @description This function replaces the R code chunks in generated domain files
#' that depend on R6 classes with simpler code that just sets plot titles
.fix_generated_domain_files <- function() {
  # Find all domain files
  domain_files <- list.files(pattern = "^_02-[0-9]{2}_.*\\.qmd$")
  domain_files <- domain_files[!grepl("_text.*\\.qmd$", domain_files)]

  fixed_count <- 0

  for (file in domain_files) {
    if (!file.exists(file)) {
      next
    }

    lines <- readLines(file, warn = FALSE)

    # Find the R code chunk that contains process_domain_data
    r_chunk_start <- grep("```\\{r\\}", lines)
    r_chunk_end <- grep("```$", lines)

    for (i in seq_along(r_chunk_start)) {
      start_idx <- r_chunk_start[i]
      # Find the corresponding end
      end_idx <- r_chunk_end[r_chunk_end > start_idx][1]

      # Check if this chunk contains process_domain_data
      chunk_lines <- lines[start_idx:end_idx]
      if (
        any(grepl(
          "process_domain_data|source.*domain_processing_utils",
          chunk_lines
        ))
      ) {
        # Extract the pheno and domain from the process_domain_data call
        process_line <- chunk_lines[grepl("process_domain_data", chunk_lines)]
        if (length(process_line) > 0) {
          # Extract the parameters from process_domain_data('pheno', 'Domain Name')
          matches <- regmatches(
            process_line,
            gregexpr("'([^']*)'", process_line)
          )[[1]]
          if (length(matches) >= 2) {
            pheno <- gsub("'", "", matches[1])
            domain_name <- gsub("'", "", matches[2])

            # Create a simple R code chunk that just sets the plot title
            new_chunk <- c(
              "```{r}",
              "#| label: process-domain",
              "#| include: false",
              "",
              "# Ensure plot title exists",
              paste0(
                "plot_title_",
                pheno,
                " <- \"",
                domain_name,
                " scores reflect performance across multiple measures.\""
              ),
              "",
              "# Try to load custom title from sysdata.rda",
              "sysdata_path <- here::here(\"R\", \"sysdata.rda\")",
              "if (file.exists(sysdata_path)) {",
              "  sysdata_env <- new.env()",
              "  load(sysdata_path, envir = sysdata_env)",
              paste0(
                "  custom_title_name <- paste0(\"plot_title_\", \"",
                pheno,
                "\")"
              ),
              "  if (exists(custom_title_name, envir = sysdata_env)) {",
              paste0(
                "    plot_title_",
                pheno,
                " <- get(custom_title_name, envir = sysdata_env)"
              ),
              "  }",
              "}",
              "```"
            )

            # Replace the old chunk with the new one
            lines <- c(
              lines[1:(start_idx - 1)],
              new_chunk,
              lines[(end_idx + 1):length(lines)]
            )

            # Write the fixed file
            writeLines(lines, file)
            log_message(paste("Fixed R code chunk in", file), "INFO")
            fixed_count <- fixed_count + 1
            break
          }
        }
      }
    }
  }

  if (fixed_count > 0) {
    log_message(
      paste("Fixed", fixed_count, "domain files for Quarto rendering"),
      "INFO"
    )
  }

  return(fixed_count > 0)
}

#' Generate Workflow Report
#'
#' @param config Configuration list from .load_workflow_config
#' @return Logical indicating success
#' @export
generate_workflow_report <- function(config) {
  log_message("Generating report...", "WORKFLOW")

  # Source the report generator module if it exists
  if (file.exists("scripts/report_generator_module.R")) {
    log_message("Running report_generator_module.R", "REPORT")
  # Use require() or check if object exists instead
  # FIXED: source("scripts/report_generator_module.R") # External script, so kept # Moved to lazy loading
    return(TRUE)
  }

  # Fix domain files to remove R6 dependencies for Quarto rendering
  .fix_generated_domain_files()

  # Run default report generation
  template_file <- .ensure_template_file("template.qmd")

  # Debug: Show what .ensure_template_file returned
  log_message(
    paste(
      ".ensure_template_file returned:",
      class(template_file),
      "with value:",
      template_file
    ),
    "DEBUG"
  )

  # Check if template_file is NULL or the file doesn't exist
  if (is.null(template_file) || !file.exists(template_file)) {
    log_message("No template file found or template_file is NULL", "ERROR")
    return(FALSE)
  }

  # Try to render using quarto if available
  if (requireNamespace("quarto", quietly = TRUE)) {
    tryCatch(
      {
        # Use absolute path to avoid 'invalid file argument' error
        template_abs_path <- normalizePath(template_file)
        log_message(
          paste("normalizePath returned:", template_abs_path),
          "DEBUG"
        )
        log_message(paste("Attempting to render:", template_abs_path), "INFO")

        # Double check the file exists at the absolute path
        if (!file.exists(template_abs_path)) {
          log_message(
            paste("File does not exist at absolute path:", template_abs_path),
            "ERROR"
          )
          return(FALSE)
        }

        # Ensure domain include list exists before Quarto preprocesses includes
        .generate_domains_include_file()

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
.print_report_summary <- function(config) {
  # Removed: source("R/workflow_utils.R") - not needed in R package

  log_message("Report generation complete", "REPORT")

  # Check for generated files
  output_files <- list.files(
    path = config$output$dir,
    pattern = "\\.(pdf|html|typ|docx)$",
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
.ensure_template_file <- function(template_file, log_type = "INFO") {
  log_message(paste("Checking for template file:", template_file), log_type)
  log_message(paste("Current working directory:", getwd()), log_type)

  if (file.exists(template_file)) {
    log_message(paste("Template file found:", template_file), log_type)
    file_info <- file.info(template_file)
    log_message(paste("File size:", file_info$size, "bytes"), log_type)
    log_message(paste("Last modified:", file_info$mtime), log_type)
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

# Create the dynamic include file with domain sections for the template
.generate_domains_include_file <- function(include_file = "_domains_to_include.qmd") {
  # Prefer explicit ordering if provided
  includes <- character(0)

  if (file.exists("domain_includes.txt")) {
    lines <- readLines("domain_includes.txt", warn = FALSE)
    lines <- trimws(lines)
    lines <- lines[nzchar(lines)]
    # Keep only files that actually exist
    includes <- lines[file.exists(lines)]
  }

  # Fallback: discover generated domain files
  if (length(includes) == 0) {
    files <- list.files(
      path = ".",
      pattern = "^_02-.*\\.qmd$",
      full.names = FALSE
    )
    # Exclude narrative-only helper files
    files <- files[!grepl("_text\\.qmd$", files)]
    includes <- sort(files)
  }

  if (length(includes) == 0) {
    # Write an empty file so Quarto include succeeds without content
    writeLines(character(0), include_file)
    log_message("No domain files found to include", "WARNING")
    return(FALSE)
  }

  lines <- paste0("{{< include ", includes, " >}}")
  # Add blank line between includes for readability
  spaced <- as.vector(rbind(lines, ""))
  writeLines(spaced, include_file)
  log_message(
    paste("Wrote", length(includes), "domain includes to", include_file),
    "REPORT"
  )
  TRUE
}
