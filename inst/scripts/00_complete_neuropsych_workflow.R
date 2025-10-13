#' Enhanced Neuropsych Workflow Runner
#'
#' This script provides an improved workflow that explicitly handles:
#' 1. Two-stage rendering (data generation + LLM processing)
#' 2. Edit protection for manually modified files
#' 3. Intelligent caching and reprocessing
#' 4. Ollama model management
#'
#' @description
#' The workflow requires two rendering passes because:
#' - First pass: Generates data, caches it, triggers LLM processing
#' - Second pass: Integrates LLM summaries into final report
#'
#' After initial generation, manually edited files are protected from
#' regeneration unless explicitly forced.

# ==============================================================================
# CONFIGURATION
# ==============================================================================

#' Default configuration
DEFAULT_CONFIG <- list(
  patient = "Maya",
  data_dir = "data",
  output_dir = "output",
  verbose = TRUE,
  ollama_check = TRUE,
  edit_protection = TRUE
)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Check if Ollama models are running
#' @return Logical indicating if models are available
check_ollama_status <- function() {
  tryCatch(
    {
      # Try to connect to Ollama
      result <- system("ollama list", intern = TRUE, ignore.stderr = TRUE)

      # Check for required models
      has_models <- any(grepl("qwen3", result, ignore.case = TRUE))

      if (!has_models) {
        warning("Ollama models not found. Run: bash setup_ollama.sh")
        return(FALSE)
      }

      return(TRUE)
    },
    error = function(e) {
      warning("Ollama not running. Start with: bash setup_ollama.sh")
      return(FALSE)
    }
  )
}

#' Check if file has been manually edited
#' @param file_path Path to file
#' @param generation_marker_file Path to file containing generation timestamp
#' @return Logical indicating if file was manually edited
is_manually_edited <- function(file_path, generation_marker_file = NULL) {
  if (!file.exists(file_path)) {
    return(FALSE)
  }

  # Check for generation marker
  marker_file <- generation_marker_file %||% paste0(file_path, ".generated")

  if (!file.exists(marker_file)) {
    # No marker = assume manually created
    return(TRUE)
  }

  # Compare modification times
  file_mtime <- file.mtime(file_path)
  marker_mtime <- file.mtime(marker_file)

  # File modified after marker = manual edit
  return(file_mtime > marker_mtime)
}

#' Mark file as generated (for edit protection)
#' @param file_path Path to file
mark_as_generated <- function(file_path) {
  if (!file.exists(file_path)) {
    return(FALSE)
  }

  marker_file <- paste0(file_path, ".generated")

  # Write timestamp marker
  writeLines(
    c(paste("Generated:", Sys.time()), paste("File:", file_path)),
    marker_file
  )

  return(TRUE)
}

#' Get list of protected files (manually edited)
#' @param pattern File pattern to check
#' @return Character vector of protected files
get_protected_files <- function(pattern = ".*_text\\.qmd$") {
  files <- list.files(pattern = pattern)

  # Use vapply instead of sapply to ensure logical output
  protected <- vapply(
    files,
    function(f) {
      is_manually_edited(f)
    },
    FUN.VALUE = logical(1)
  )

  return(files[protected])
}

#' Display workflow status
#' @param stage Current workflow stage
#' @param message Status message
display_status <- function(stage, message) {
  cat("\n")
  cat(
    "================================================================================\n"
  )
  cat(paste0("STAGE: ", stage, "\n"))
  cat(
    "================================================================================\n"
  )
  cat(paste0(message, "\n"))
  cat(
    "================================================================================\n"
  )
  cat("\n")
}

# ==============================================================================
# ENHANCED WORKFLOW FUNCTION
# ==============================================================================

#' Run neuropsychological report workflow with two-stage rendering
#'
#' @param patient Patient name (default: "Ethan")
#' @param generate_qmd Generate domain QMD files (default: TRUE)
#' @param render_report Render final PDF report (default: TRUE)
#' @param force_reprocess Force regeneration of all files, ignoring edits (default: FALSE)
#' @param force_llm Force LLM to reprocess all summaries (default: FALSE)
#' @param two_stage_render Explicitly run two rendering passes (default: TRUE)
#' @param check_ollama Check if Ollama is running (default: TRUE)
#' @param protect_edits Protect manually edited files (default: TRUE)
#' @param verbose Print detailed status (default: TRUE)
#'
#' @return List with paths to generated files and workflow status
#'
#' @examples
#' \dontrun{
#' # Complete workflow with two-stage rendering
#' run_neuropsych_workflow()
#'
#' # Quick re-render (uses cached data, preserves edits)
#' run_neuropsych_workflow(
#'   generate_qmd = FALSE,
#'   two_stage_render = FALSE
#' )
#'
#' # Force complete regeneration (CAUTION: overwrites edits)
#' run_neuropsych_workflow(
#'   force_reprocess = TRUE,
#'   force_llm = TRUE
#' )
#' }
#'
#' @export
run_neuropsych_workflow <- function(
  patient = DEFAULT_CONFIG$patient,
  generate_qmd = TRUE,
  render_report = TRUE,
  force_reprocess = FALSE,
  force_llm = FALSE,
  two_stage_render = TRUE,
  check_ollama = TRUE,
  protect_edits = TRUE,
  verbose = TRUE
) {
  # Track workflow start time
  workflow_start <- Sys.time()

  # ===========================================================================
  # STAGE 0: PREPARATION
  # ===========================================================================

  if (verbose) {
    display_status(
      "0: PREPARATION",
      paste0(
        "Patient: ",
        patient,
        "\n",
        "Generate QMD: ",
        generate_qmd,
        "\n",
        "Render Report: ",
        render_report,
        "\n",
        "Two-Stage Render: ",
        two_stage_render,
        "\n",
        "Force Reprocess: ",
        force_reprocess,
        "\n",
        "Force LLM: ",
        force_llm,
        "\n",
        "Protect Edits: ",
        protect_edits
      )
    )
  }

  # Check Ollama status if requested
  if (check_ollama && (generate_qmd || force_llm)) {
    if (verbose) {
      cat("Checking Ollama status...\n")
    }

    if (!check_ollama_status()) {
      warning(
        "Ollama not available. LLM summaries will not be generated.\n",
        "To enable LLM processing, run: bash setup_ollama.sh"
      )

      # Ask user if they want to continue
      if (interactive()) {
        continue <- readline("Continue without LLM? (y/n): ")
        if (tolower(continue) != "y") {
          stop("Workflow cancelled by user")
        }
      }
    }
  }

  # Check for protected files
  if (protect_edits && !force_reprocess) {
    protected_files <- get_protected_files()

    if (length(protected_files) > 0 && verbose) {
      cat("\nProtected files (will not be regenerated):\n")
      cat(paste("  -", protected_files), sep = "\n")
      cat("\n")
    }
  }

  # ===========================================================================
  # STAGE 1: DATA PROCESSING
  # ===========================================================================

  if (generate_qmd) {
    if (verbose) {
      display_status(
        "1: DATA PROCESSING",
        "Loading and processing test data..."
      )
    }

    # Load data processing module
    tryCatch(
      {
        source(here::here("inst", "scripts", "02_data_processor_module.R"))

        if (verbose) cat("✓ Data processing complete\n")
      },
      error = function(e) {
        stop("Data processing failed: ", e$message)
      }
    )
  }

  # ===========================================================================
  # STAGE 2: DOMAIN FILE GENERATION
  # ===========================================================================

  if (generate_qmd) {
    if (verbose) {
      display_status(
        "2: DOMAIN FILE GENERATION",
        "Generating domain QMD files and text files..."
      )
    }

    # Load workflow runner
    tryCatch(
      {
        source(here::here(
          "inst",
          "scripts",
          "00_complete_neuropsych_workflow.R"
        ))

        # Generate domain files
        # This creates _02-XX_domain.qmd and _02-XX_domain_text.qmd files
        generate_all_domains(
          patient = patient,
          force_regenerate = force_reprocess,
          protect_edits = protect_edits
        )

        # Mark generated files
        if (protect_edits && !force_reprocess) {
          text_files <- list.files(pattern = ".*_text\\.qmd$")
          sapply(text_files, mark_as_generated)
        }

        if (verbose) cat("✓ Domain files generated\n")
      },
      error = function(e) {
        stop("Domain generation failed: ", e$message)
      }
    )
  }

  # ===========================================================================
  # STAGE 3: LLM PROCESSING (ASYNC)
  # ===========================================================================

  if (generate_qmd || force_llm) {
    if (verbose) {
      display_status(
        "3: LLM PROCESSING",
        "Triggering LLM to process domain text files...\n(This runs asynchronously in background)"
      )
    }

    # Trigger LLM processing
    # Note: This may complete after the first render finishes
    tryCatch(
      {
        # Call LLM processing function
        process_domains_with_llm(patient = patient, force_reprocess = force_llm)

        if (verbose) cat("✓ LLM processing initiated\n")
      },
      error = function(e) {
        warning("LLM processing failed: ", e$message)
      }
    )
  }

  # ===========================================================================
  # STAGE 4A: FIRST RENDER (Data + Partial Summaries)
  # ===========================================================================

  if (render_report && two_stage_render) {
    if (verbose) {
      display_status(
        "4A: FIRST RENDER",
        paste0(
          "Rendering report (first pass)...\n",
          "Note: LLM summaries may be incomplete on first render.\n",
          "A second render will integrate complete summaries."
        )
      )
    }

    # First render
    tryCatch(
      {
        quarto::quarto_render(input = "template.qmd", output_format = "typst")

        if (verbose) cat("✓ First render complete\n")
      },
      error = function(e) {
        warning("First render failed: ", e$message)
      }
    )

    # Brief pause to allow LLM to complete
    if (verbose) {
      cat("\nWaiting for LLM processing to complete...\n")
      cat("(Typically 30-60 seconds)\n")
    }
    Sys.sleep(30)
  }

  # ===========================================================================
  # STAGE 4B: SECOND RENDER (Complete Summaries)
  # ===========================================================================

  if (render_report && two_stage_render) {
    if (verbose) {
      display_status(
        "4B: SECOND RENDER",
        "Rendering report (second pass with complete LLM summaries)..."
      )
    }

    # Second render integrates LLM summaries
    tryCatch(
      {
        quarto::quarto_render(input = "template.qmd", output_format = "typst")

        if (verbose) cat("✓ Second render complete\n")
      },
      error = function(e) {
        stop("Second render failed: ", e$message)
      }
    )
  } else if (render_report && !two_stage_render) {
    # Single render (when using cached data)
    if (verbose) {
      display_status(
        "4: SINGLE RENDER",
        "Rendering report (using cached data and existing summaries)..."
      )
    }

    tryCatch(
      {
        quarto::quarto_render(input = "template.qmd", output_format = "typst")

        if (verbose) cat("✓ Render complete\n")
      },
      error = function(e) {
        stop("Render failed: ", e$message)
      }
    )
  }

  # ===========================================================================
  # STAGE 5: FINALIZATION
  # ===========================================================================

  if (verbose) {
    display_status("5: FINALIZATION", "Moving report to output directory...")
  }

  # Find and move report
  report_file <- paste0(patient, "_report.pdf")
  report_path <- NULL

  if (file.exists(report_file)) {
    output_dir <- DEFAULT_CONFIG$output_dir

    # Create output directory if needed
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }

    # Move report
    output_path <- file.path(output_dir, report_file)
    file.copy(report_file, output_path, overwrite = TRUE)
    file.remove(report_file)

    report_path <- output_path

    if (verbose) {
      cat("✓ Report saved to:", output_path, "\n")
    }
  }

  # ===========================================================================
  # COMPLETION
  # ===========================================================================

  workflow_end <- Sys.time()
  workflow_duration <- difftime(workflow_end, workflow_start, units = "mins")

  if (verbose) {
    cat("\n")
    cat(
      "================================================================================\n"
    )
    cat("WORKFLOW COMPLETE\n")
    cat(
      "================================================================================\n"
    )
    cat(paste0("Duration: ", round(workflow_duration, 2), " minutes\n"))
    if (!is.null(report_path)) {
      cat(paste0("Report: ", report_path, "\n"))
    }
    cat(
      "================================================================================\n"
    )
    cat("\n")
  }

  # Return workflow results
  invisible(list(
    patient = patient,
    report_path = report_path,
    duration = workflow_duration,
    protected_files = if (protect_edits) {
      get_protected_files()
    } else {
      character(0)
    },
    success = !is.null(report_path)
  ))
}

#' Quick workflow wrapper (convenience function)
#'
#' @param patient Patient name
#' @export
run_workflow <- function(patient = DEFAULT_CONFIG$patient) {
  run_neuropsych_workflow(
    patient = patient,
    generate_qmd = TRUE,
    render_report = TRUE,
    two_stage_render = TRUE,
    protect_edits = TRUE
  )
}

#' Quick re-render (uses cached data, preserves edits)
#'
#' @param patient Patient name
#' @export
quick_rerender <- function(patient = DEFAULT_CONFIG$patient) {
  run_neuropsych_workflow(
    patient = patient,
    generate_qmd = FALSE,
    render_report = TRUE,
    two_stage_render = FALSE,
    protect_edits = TRUE
  )
}

#' Force complete regeneration (CAUTION: overwrites manual edits)
#'
#' @param patient Patient name
#' @export
force_regenerate_all <- function(patient = DEFAULT_CONFIG$patient) {
  # Confirm with user
  if (interactive()) {
    cat("\n")
    cat("WARNING: This will overwrite all manually edited files!\n")
    cat("Protected files will be regenerated.\n\n")

    protected <- get_protected_files()
    if (length(protected) > 0) {
      cat("The following files will be overwritten:\n")
      cat(paste("  -", protected), sep = "\n")
      cat("\n")
    }

    confirm <- readline("Are you sure? Type 'YES' to continue: ")

    if (confirm != "YES") {
      cat("Regeneration cancelled.\n")
      return(invisible(NULL))
    }
  }

  # Remove generation markers
  markers <- list.files(pattern = "\\.generated$")
  if (length(markers) > 0) {
    file.remove(markers)
  }

  # Run with force flags
  run_neuropsych_workflow(
    patient = patient,
    force_reprocess = TRUE,
    force_llm = TRUE,
    two_stage_render = TRUE,
    protect_edits = FALSE # Disable protection
  )
}

# ==============================================================================
# PACKAGE STARTUP MESSAGE
# ==============================================================================

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "\n========================================\n",
    "neuro2 Workflow Loaded\n",
    "========================================\n",
    "Quick Commands:\n",
    "  run_workflow()           - Full workflow (two-stage)\n",
    "  quick_rerender()         - Fast re-render (cached data)\n",
    "  force_regenerate_all()   - Complete regeneration\n\n",
    "Manual edit protection: ENABLED\n",
    "Edited files will not be overwritten.\n",
    "========================================\n"
  )
}
