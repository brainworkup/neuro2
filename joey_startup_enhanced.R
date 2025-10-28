#!/usr/bin/env Rscript

#' joey_startup_enhanced.R - Enhanced Workflow Startup Script
#'
#' This script provides a clear interface to the two-stage neuropsych workflow
#' with built-in edit protection and intelligent caching.

# ==============================================================================
# CONFIGURATION
# ==============================================================================

patient_name <- "Biggie"

# ==============================================================================
# LOAD WORKFLOW
# ==============================================================================

# Source the enhanced workflow
source("inst/scripts/00_complete_neuropsych_workflow.R")

# ==============================================================================
# USER-FRIENDLY WRAPPER FUNCTIONS
# ==============================================================================

#' Run complete workflow (recommended for first time)
#'
#' This function runs the FULL two-stage workflow:
#'
#' Stage 1 (First Render):
#' - Processes data and generates domain files
#' - Creates text files with formatted test data
#' - Triggers LLM to generate clinical summaries
#' - Renders first PDF (may have incomplete summaries)
#'
#' Stage 2 (Second Render):
#' - Uses cached data (fast)
#' - Integrates completed LLM-generated summaries
#' - Renders final publication-quality PDF
#'
#' @param patient Patient name (default: "Ethan")
#' @examples
#' run_workflow()                 # Use default patient
#' run_workflow("Patient Name")   # Different patient
run_workflow <- function(patient = patient_name) {
  cat("\n")
  cat(
    "╔════════════════════════════════════════════════════════════════════════════╗\n"
  )
  cat(
    "║              NEUROPSYCH WORKFLOW - TWO-STAGE RENDERING                     ║\n"
  )
  cat(
    "╚════════════════════════════════════════════════════════════════════════════╝\n"
  )
  cat("\n")
  cat("This workflow runs in TWO stages:\n")
  cat("\n")
  cat("📊 STAGE 1: Data Generation + LLM Processing\n")
  cat("   - Generate domain files and format test data\n")
  cat("   - Trigger LLM to create clinical summaries\n")
  cat("   - First PDF render (may be incomplete)\n")
  cat("   - Duration: ~5-10 minutes\n")
  cat("\n")
  cat("📄 STAGE 2: Final Integration\n")
  cat("   - Use cached data (no reprocessing)\n")
  cat("   - Integrate completed LLM summaries\n")
  cat("   - Final publication-quality PDF\n")
  cat("   - Duration: ~2-3 minutes\n")
  cat("\n")
  cat("🔒 EDIT PROTECTION: Enabled\n")
  cat("   Manually edited files will NOT be overwritten\n")
  cat("\n")
  cat("Starting workflow for patient:", patient, "\n")
  cat(
    "════════════════════════════════════════════════════════════════════════════\n"
  )
  cat("\n")

  # Run the enhanced workflow
  result <- run_neuropsych_workflow(
    patient = patient,
    generate_qmd = TRUE,
    render_report = TRUE,
    two_stage_render = TRUE,
    protect_edits = TRUE,
    verbose = TRUE
  )

  # Display results
  if (result$success) {
    cat("\n")
    cat(
      "╔════════════════════════════════════════════════════════════════════════════╗\n"
    )
    cat(
      "║                          ✓ WORKFLOW COMPLETE                               ║\n"
    )
    cat(
      "╚════════════════════════════════════════════════════════════════════════════╝\n"
    )
    cat("\n")
    cat("📁 Report saved to:", result$report_path, "\n")
    cat("⏱️  Total time:", round(result$duration, 2), "minutes\n")

    if (length(result$protected_files) > 0) {
      cat("\n🔒 Protected files (not regenerated):\n")
      cat(paste("   -", result$protected_files), sep = "\n")
    }

    cat("\n")
    cat("💡 Next Steps:\n")
    cat("   - Review the PDF report\n")
    cat("   - Edit narrative summaries if needed (*_text.qmd files)\n")
    cat("   - Edit interpretation (_03-00_sirf.qmd)\n")
    cat("   - Edit recommendations (_04-00_recs.qmd)\n")
    cat("   - Run quick_rerender() to update PDF with your edits\n")
    cat("\n")
  } else {
    cat("\n")
    cat(
      "╔════════════════════════════════════════════════════════════════════════════╗\n"
    )
    cat(
      "║                         ✗ WORKFLOW FAILED                                  ║\n"
    )
    cat(
      "╚════════════════════════════════════════════════════════════════════════════╝\n"
    )
    cat("\n")
    cat("Check error messages above for details.\n")
    cat("\n")
  }

  invisible(result)
}

#' Quick re-render (uses cached data, preserves your edits)
#'
#' Use this after making manual edits to narrative files.
#' Fast because it uses cached data and doesn't regenerate files.
#'
#' @param patient Patient name (default: "Ethan")
#' @examples
#' quick_rerender()
quick_rerender <- function(patient = patient_name) {
  cat("\n")
  cat(
    "╔════════════════════════════════════════════════════════════════════════════╗\n"
  )
  cat(
    "║                        QUICK RE-RENDER                                     ║\n"
  )
  cat(
    "╚════════════════════════════════════════════════════════════════════════════╝\n"
  )
  cat("\n")
  cat("Using cached data and preserving your manual edits...\n")
  cat("\n")

  result <- run_neuropsych_workflow(
    patient = patient,
    generate_qmd = FALSE, # Use cached data
    render_report = TRUE,
    two_stage_render = FALSE, # Single render
    protect_edits = TRUE,
    verbose = TRUE
  )

  if (result$success) {
    cat("\n✓ Re-render complete\n")
    cat("📁 Report:", result$report_path, "\n\n")
  }

  invisible(result)
}

#' Update data and regenerate (preserves manual edits)
#'
#' Use this when you've added new test scores but want to keep
#' your manually edited narratives.
#'
#' @param patient Patient name (default: "Ethan")
#' @examples
#' update_with_new_data()
update_with_new_data <- function(patient = patient_name) {
  cat("\n")
  cat(
    "╔════════════════════════════════════════════════════════════════════════════╗\n"
  )
  cat(
    "║                   UPDATE WITH NEW TEST DATA                                ║\n"
  )
  cat(
    "╚════════════════════════════════════════════════════════════════════════════╝\n"
  )
  cat("\n")
  cat("This will:\n")
  cat("  ✓ Reprocess data files\n")
  cat("  ✓ Update domain files\n")
  cat("  ✓ Preserve your manual edits to narratives\n")
  cat("  ✓ Generate new LLM summaries only where needed\n")
  cat("\n")

  result <- run_neuropsych_workflow(
    patient = patient,
    generate_qmd = TRUE,
    render_report = TRUE,
    force_reprocess = FALSE, # Respect edit protection
    force_llm = FALSE, # Only process new data
    two_stage_render = TRUE,
    protect_edits = TRUE,
    verbose = TRUE
  )

  if (result$success) {
    cat("\n✓ Update complete\n")
    cat("📁 Report:", result$report_path, "\n\n")
  }

  invisible(result)
}

#' Show which files are protected from regeneration
#'
#' @examples
#' show_protected_files()
show_protected_files <- function() {
  protected <- get_protected_files()

  cat("\n")
  cat(
    "╔════════════════════════════════════════════════════════════════════════════╗\n"
  )
  cat(
    "║                      PROTECTED FILES                                       ║\n"
  )
  cat(
    "╚════════════════════════════════════════════════════════════════════════════╝\n"
  )
  cat("\n")

  if (length(protected) == 0) {
    cat("No protected files found.\n")
    cat("(Files become protected after manual editing)\n")
  } else {
    cat("The following files have been manually edited and are\n")
    cat("protected from automatic regeneration:\n\n")

    for (f in protected) {
      mtime <- file.mtime(f)
      cat(sprintf("  🔒 %s\n      Last modified: %s\n\n", f, mtime))
    }

    cat("To regenerate these files, use: force_regenerate_all()\n")
    cat("⚠️  WARNING: This will overwrite your edits!\n")
  }

  cat("\n")

  invisible(protected)
}

#' Check Ollama status
#'
#' @examples
#' check_llm_status()
check_llm_status <- function() {
  cat("\n")
  cat("Checking Ollama LLM status...\n\n")

  status <- check_ollama_status()

  if (status) {
    cat("✓ Ollama is running\n")
    cat("✓ Required models are available\n\n")
    cat("Available models:\n")
    system("ollama list")
  } else {
    cat("✗ Ollama is not running or models not found\n\n")
    cat("To start Ollama:\n")
    cat("  bash setup_ollama.sh\n\n")
    cat("Or manually:\n")
    cat("  ollama run qwen3:8b-q4_K_M\n\n")
  }

  invisible(status)
}

# ==============================================================================
# STARTUP MESSAGE
# ==============================================================================

cat("\n")
cat(
  "════════════════════════════════════════════════════════════════════════════\n"
)
cat(
  "                    NEUROPSYCH WORKFLOW SYSTEM                              \n"
)
cat(
  "════════════════════════════════════════════════════════════════════════════\n"
)
cat("\n")
cat("📋 Patient:", patient_name, "\n")
cat("\n")
cat("🚀 QUICK START COMMANDS:\n")
cat("\n")
cat("   run_workflow()              - Complete two-stage workflow\n")
cat("                                 (Use this for first-time generation)\n")
cat("\n")
cat("   quick_rerender()            - Fast re-render with cached data\n")
cat("                                 (Use after editing narratives)\n")
cat("\n")
cat("   update_with_new_data()      - Reprocess data, keep edits\n")
cat("                                 (Use when adding new test scores)\n")
cat("\n")
cat("🔍 UTILITY COMMANDS:\n")
cat("\n")
cat("   show_protected_files()      - List manually edited files\n")
cat("   check_llm_status()          - Check if Ollama is running\n")
cat("   force_regenerate_all()      - ⚠️  Overwrite ALL files\n")
cat("\n")
cat("📚 ADVANCED OPTIONS:\n")
cat("\n")
cat("   run_workflow('Patient')     - Different patient name\n")
cat("   \n")
cat("   run_neuropsych_workflow(    - Full control\n")
cat("     patient = 'Name',\n")
cat("     generate_qmd = TRUE,\n")
cat("     render_report = TRUE,\n")
cat("     force_reprocess = FALSE,\n")
cat("     force_llm = FALSE,\n")
cat("     two_stage_render = TRUE,\n")
cat("     protect_edits = TRUE\n")
cat("   )\n")
cat("\n")
cat(
  "════════════════════════════════════════════════════════════════════════════\n"
)
cat("\n")
cat("💡 WORKFLOW REMINDER:\n")
cat("\n")
cat(
  "   The first time you run the workflow, it requires TWO rendering passes:\n"
)
cat("\n")
cat(
  "   Pass 1: Generate data → Trigger LLM → First PDF (incomplete summaries)\n"
)
cat("   Pass 2: Use cached data → Integrate LLM summaries → Final PDF\n")
cat("\n")
cat("   This is automatic when using run_workflow()\n")
cat("\n")
cat("🔒 EDIT PROTECTION:\n")
cat("\n")
cat("   After initial generation, manually edited files are protected.\n")
cat("   Your clinical expertise won't be overwritten on subsequent runs.\n")
cat("\n")
cat(
  "════════════════════════════════════════════════════════════════════════════\n"
)
cat("\n")
cat("Ready! Type run_workflow() to begin.\n")
cat("\n")
