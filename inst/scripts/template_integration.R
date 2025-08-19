#!/usr/bin/env Rscript

#' Template Integration System
#'
#' This script integrates generated domain QMD files into the main template
#' and ensures the workflow runs correctly.

# Load required packages
suppressPackageStartupMessages({
  library(here)
})

#' Update main template with generated domain includes
update_template_with_domains <- function(
  template_file = "template.qmd",
  domain_marker = "<!-- DOMAIN_INCLUDES -->",
  verbose = TRUE
) {
  template_path <- here::here(template_file)

  if (!file.exists(template_path)) {
    stop("Template file not found: ", template_path)
  }

  # Read template content
  template_lines <- readLines(template_path)

  # Find domain files
  domain_files <- list.files(
    pattern = "^_02-[0-9]{2}_.*\\.qmd$",
    full.names = FALSE
  )

  if (length(domain_files) == 0) {
    if (verbose) {
      cat("⚠️  No domain files found to include\n")
    }
    return(FALSE)
  }

  # Sort domain files by number
  domain_files <- sort(domain_files)

  if (verbose) {
    cat("📄 Found domain files to include:\n")
    for (file in domain_files) {
      cat("  -", file, "\n")
    }
  }

  # Create include statements
  domain_includes <- paste0("{{< include ", domain_files, " >}}")

  # Find marker position
  marker_line <- which(grepl(domain_marker, template_lines, fixed = TRUE))

  if (length(marker_line) == 0) {
    if (verbose) {
      cat("⚠️  Domain marker not found in template\n")
      cat("   Add this line where you want domains included:\n")
      cat("   ", domain_marker, "\n")
    }
    return(FALSE)
  }

  # Replace marker with includes
  if (length(marker_line) > 1) {
    # Multiple markers - use the first one
    marker_line <- marker_line[1]
    if (verbose) {
      cat("⚠️  Multiple domain markers found, using first one\n")
    }
  }

  # Create new template content
  new_lines <- c(
    template_lines[1:(marker_line - 1)],
    domain_includes,
    template_lines[(marker_line + 1):length(template_lines)]
  )

  # Write updated template
  writeLines(new_lines, template_path)

  if (verbose) {
    cat("✅ Updated template with", length(domain_files), "domain includes\n")
  }

  return(TRUE)
}

#' Create a complete workflow template
create_workflow_template <- function(
  output_file = "neuropsych_report.qmd",
  verbose = TRUE
) {
  template_content <- c(
    "---",
    "title: \"NEUROCOGNITIVE EVALUATION\"",
    "author: \"Dr. Joey Trampush\"",
    "date: \"`r Sys.Date()`\"",
    "format:",
    "  typst:",
    "    toc: true",
    "    toc-depth: 2",
    "    margin:",
    "      x: 0.79in",
    "      y: 0.79in",
    "    mainfont: \"Minion Pro\"",
    "    sansfont: \"Myriad Pro\"",
    "    fontsize: 9pt",
    "    keep-typ: true",
    "execute:",
    "  echo: false",
    "  warning: false",
    "  message: false",
    "---",
    "",
    "```{r}",
    "#| label: setup",
    "#| include: false",
    "",
    "# Load required packages",
    "suppressPackageStartupMessages({",
    "  library(tidyverse)",
    "  library(gt)",
    "  library(gtExtras)",
    "  library(glue)",
    "  library(here)",
    "})",
    "",
    "# Set global options",
    "options(warn = -1)",
    "knitr::opts_chunk$set(",
    "  echo = FALSE,",
    "  warning = FALSE,",
    "  message = FALSE,",
    "  fig.align = 'center'",
    ")",
    "```",
    "",
    "# Background Information",
    "",
    "This comprehensive neuropsychological assessment was conducted to evaluate cognitive and behavioral functioning across multiple domains.",
    "",
    "# Test Results",
    "",
    "## Cognitive Domains",
    "",
    "<!-- DOMAIN_INCLUDES -->",
    "",
    "# Summary and Recommendations",
    "",
    "Based on the comprehensive assessment results, the following patterns emerged...",
    "",
    "## Clinical Impressions",
    "",
    "- Summary of key findings",
    "- Areas of strength and concern",
    "- Diagnostic considerations",
    "",
    "## Recommendations",
    "",
    "1. Educational accommodations",
    "2. Therapeutic interventions",
    "3. Follow-up assessments"
  )

  output_path <- here::here(output_file)
  writeLines(template_content, output_path)

  if (verbose) {
    cat("📝 Created workflow template:", output_path, "\n")
    cat("   This template includes the domain marker for automatic inclusion\n")
  }

  return(output_path)
}

#' Run complete workflow
run_complete_workflow <- function(verbose = TRUE) {
  if (verbose) {
    cat("🚀 Running complete neuropsychological report workflow\n")
    cat("=====================================================\n\n")
  }

  # Step 1: Process all domains
  if (verbose) {
    cat("Step 1: Processing domains...\n")
  }

  # Source and run the batch processor
  if (file.exists(here::here("R", "batch_domain_processor.R"))) {
    source(here::here("R", "batch_domain_processor.R"))
  } else {
    # Run the processing function directly
    if (exists("process_all_domains")) {
      process_all_domains(verbose = verbose)
    } else {
      if (verbose) {
        cat("⚠️  Batch processor not found, please run separately\n")
      }
    }
  }

  # Step 2: Check for template or create one
  template_file <- "template.qmd"
  # template_file <- "neuropsych_report.qmd"
  template_path <- here::here(template_file)

  if (!file.exists(template_path)) {
    if (verbose) {
      cat("\nStep 2: Creating workflow template...\n")
    }
    create_workflow_template(template_file, verbose = verbose)
  } else {
    if (verbose) {
      cat("\nStep 2: Using existing template:", template_file, "\n")
    }
  }

  # Step 3: Update template with domain includes
  if (verbose) {
    cat("\nStep 3: Updating template with domain includes...\n")
  }

  success <- update_template_with_domains(
    template_file = template_file,
    verbose = verbose
  )

  if (!success) {
    if (verbose) {
      cat("❌ Failed to update template\n")
    }
    return(FALSE)
  }

  # Step 4: Render the report
  if (verbose) {
    cat("\nStep 4: Rendering report...\n")
  }

  render_success <- tryCatch(
    {
      if (requireNamespace("quarto", quietly = TRUE)) {
        quarto::quarto_render(template_path)
        TRUE
      } else {
        # Try system quarto command
        result <- system2(
          "quarto",
          c("render", template_path),
          stdout = FALSE,
          stderr = FALSE
        )
        result == 0
      }
    },
    error = function(e) {
      if (verbose) {
        cat("❌ Render error:", e$message, "\n")
      }
      FALSE
    }
  )

  if (render_success) {
    if (verbose) {
      cat("✅ Report rendered successfully!\n")

      # Look for output files
      output_files <- c(
        gsub("\\.qmd$", ".pdf", template_path),
        gsub("\\.qmd$", ".typ", template_path),
        gsub("\\.qmd$", ".html", template_path),
        gsub("\\.qmd$", ".docx", template_path),
        gsub("\\.qmd$", ".md", template_path)
      )

      existing_outputs <- output_files[file.exists(output_files)]
      if (length(existing_outputs) > 0) {
        cat("\n📄 Output files:\n")
        for (file in existing_outputs) {
          cat("  -", file, "\n")
        }
      }
    }
  } else {
    if (verbose) {
      cat("❌ Render failed\n")
      cat("   Try running manually: quarto render", template_file, "\n")
    }
  }

  if (verbose) {
    cat("\n🎉 Workflow complete!\n")
  }

  return(render_success)
}

#' Quick setup function for first-time users
quick_setup <- function() {
  cat("🧠 Neuropsychological Report Quick Setup\n")
  cat("=======================================\n\n")

  # Check for required files/directories
  checks <- list(
    "data directory" = dir.exists(here::here("data")),
    "R directory" = dir.exists(here::here("R")),
    "figs directory" = dir.exists(here::here("figs")),
    "DomainProcessorR6.R" = file.exists(here::here("R", "DomainProcessorR6.R"))
  )

  cat("📋 Environment Check:\n")
  all_good <- TRUE
  for (name in names(checks)) {
    status <- if (checks[[name]]) "✅" else "❌"
    cat("  ", status, name, "\n")
    if (!checks[[name]]) all_good <- FALSE
  }

  if (!all_good) {
    cat("\n⚠️  Some required files/directories are missing\n")
    cat("   Please ensure your project structure is correct\n")
    return(FALSE)
  }

  # Create missing directories
  dirs_to_create <- c("figs", "output")
  for (dir in dirs_to_create) {
    dir_path <- here::here(dir)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      cat("📁 Created directory:", dir, "\n")
    }
  }

  cat("\n✅ Environment ready!\n")
  cat("\nNext steps:\n")
  cat("1. Run: source('R/batch_domain_processor.R'); main()\n")
  cat("2. Run: source('R/template_integration.R'); run_complete_workflow()\n")
  cat("3. Or run everything: quick_workflow()\n")

  return(TRUE)
}

#' One-command workflow
quick_workflow <- function() {
  if (quick_setup()) {
    run_complete_workflow()
  }
}

# Function to generate placeholder text files
generate_text_files <- function(generated_files, verbose = TRUE) {
  if (verbose) {
    cat("\nGenerating placeholder text files...\n")
  }

  text_files_created <- character(0)

  for (qmd_file in generated_files) {
    if (file.exists(qmd_file)) {
      # Read the QMD file to find text file references
      content <- readLines(qmd_file, warn = FALSE)

      # Look for {{< include patterns - more precise regex
      include_lines <- grep(
        '\\{\\{<\\s*include\\s+[^}]+_text\\.qmd',
        content,
        value = TRUE
      )

      for (include_line in include_lines) {
        # Extract the text filename more precisely
        # Look for pattern: {{< include filename_text.qmd >}}
        text_file_match <- regmatches(
          include_line,
          regexpr('_[0-9]+-[0-9]+_[^\\s>}]+_text\\.qmd', include_line)
        )

        if (length(text_file_match) > 0) {
          text_file <- text_file_match[1]

          if (!file.exists(text_file)) {
            # Extract domain name from the text filename itself
            # Pattern: _02-01_iq_text.qmd -> "iq"
            domain_match <- regmatches(
              text_file,
              regexpr('_[0-9]+-[0-9]+_([^_]+)_text', text_file)
            )

            if (length(domain_match) > 0) {
              # Extract just the domain part
              domain_name <- gsub(
                '.*_[0-9]+-[0-9]+_([^_]+)_text.*',
                '\\1',
                domain_match[1]
              )
              domain_name <- tools::toTitleCase(gsub("_", " ", domain_name))
            } else {
              # Fallback - use a generic name
              domain_name <- "Assessment"
            }

            # Create placeholder content
            placeholder_content <- paste0(
              "# ",
              domain_name,
              " Assessment\n\n",
              "The ",
              tolower(domain_name),
              " assessment results will be generated here.\n\n",
              "This section will include:\n\n",
              "- Overview of test results\n",
              "- Clinical interpretation\n",
              "- Relevant observations\n"
            )

            writeLines(placeholder_content, text_file)
            text_files_created <- c(text_files_created, text_file)

            if (verbose) cat("  ✓ Created placeholder:", text_file, "\n")
          }
        }
      }
    }
  }

  if (verbose) {
    cat("\n✓ Created", length(text_files_created), "placeholder text files\n")
  }

  return(text_files_created)
}

# Make functions available when sourced
if (!interactive()) {
  # If run as script, provide menu
  cat("🧠 Neuropsychological Report Workflow\n")
  cat("====================================\n\n")
  cat("Available commands:\n")
  cat("1. quick_setup() - Check environment and setup\n")
  cat("2. run_complete_workflow() - Run full workflow\n")
  cat("3. quick_workflow() - Do everything\n")
  cat("4. update_template_with_domains() - Just update template\n")
  cat("\nTo run: source this file and call the functions\n")
}
