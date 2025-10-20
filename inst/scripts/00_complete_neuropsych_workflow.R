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

#' Locate the Quarto template directory bundled with the project
find_template_directory <- function() {
  # Prefer installed package location if available
  candidates <- c(
    system.file(
      "quarto",
      "templates",
      "typst-report",
      package = "neuro2"
    ),
    here::here("inst", "quarto", "templates", "typst-report")
  )

  # Keep only paths that exist
  candidates <- unique(candidates[nzchar(candidates) & dir.exists(candidates)])

  if (length(candidates) == 0) {
    stop(
      "Unable to locate Quarto template directory under ",
      "inst/quarto/templates/typst-report"
    )
  }

  candidates[[1]]
}

#' Ensure required Quarto template files exist in the working directory
#'
#' Copies template.qmd and supporting files from inst/quarto/templates/typst-report
#' if they are missing locally. Returns the normalized path to template.qmd.
ensure_template_files <- function(force = FALSE) {
  template_dir <- find_template_directory()
  template_files <- c("template.qmd", "_quarto.yml", "_variables.yml", "config.yml")

  for (fname in template_files) {
    src <- file.path(template_dir, fname)
    if (!file.exists(src)) {
      stop("Required template asset not found: ", src)
    }

    dest <- here::here(fname)

    if (!file.exists(dest) || force) {
      if (!file.copy(src, dest, overwrite = TRUE)) {
        stop("Failed to copy template asset: ", fname)
      }
    }
  }

  # Copy supporting section files (without overwriting existing edits)
  supplementary <- list.files(
    template_dir,
    pattern = "^_.*\\.qmd$",
    full.names = TRUE
  )
  supplementary <- supplementary[
    basename(supplementary) != "_domains_to_include.qmd"
  ]

  for (src in supplementary) {
    dest <- here::here(basename(src))
    if (!file.exists(dest)) {
      file.copy(src, dest, overwrite = FALSE)
    }
  }

  # Ensure bundled Quarto extensions are available
  dest_extensions_dir <- here::here("_extensions")
  if (!dir.exists(dest_extensions_dir)) {
    extension_candidates <- c(
      file.path(dirname(dirname(template_dir)), "_extensions"),
      here::here("inst", "quarto", "_extensions")
    )
    extension_candidates <- unique(extension_candidates[dir.exists(extension_candidates)])

    if (length(extension_candidates) > 0) {
      src_extensions <- extension_candidates[[1]]
      file.copy(
        src_extensions,
        here::here(),
        overwrite = TRUE,
        recursive = TRUE
      )
    }
  }

  normalizePath(here::here("template.qmd"), winslash = "/", mustWork = TRUE)
}

#' Generate the manifest Quarto uses to include domain sections
generate_domains_include_manifest <- function(
  include_file = "_domains_to_include.qmd"
) {
  domain_keys <- names(domain_definitions())
  domains_with_data <- domain_keys[vapply(
    domain_keys,
    domain_has_data,
    FUN.VALUE = logical(1)
  )]

  include_files <- character()

  if (length(domains_with_data) > 0) {
    definitions <- domain_definitions()

    # Order by domain number to preserve report structure
    ordered_keys <- domains_with_data[order(vapply(
      domains_with_data,
      function(k) definitions[[k]]$number,
      FUN.VALUE = character(1)
    ))]

    include_files <- vapply(
      ordered_keys,
      function(k) {
        file <- domain_qmd_filename(
          definitions[[k]]$pheno,
          definitions[[k]]$number
        )
        if (file.exists(file)) {
          return(file)
        }
        ""
      },
      FUN.VALUE = character(1)
    )

    include_files <- include_files[nzchar(include_files)]
  }

  if (length(include_files) == 0) {
    writeLines(character(0), include_file)
    return(FALSE)
  }

  include_lines <- paste0("{{< include ", include_files, " >}}")
  spaced_lines <- as.vector(rbind(include_lines, ""))
  writeLines(spaced_lines, include_file)
  TRUE
}

# ------------------------------------------------------------------------------
# Domain metadata helpers
# ------------------------------------------------------------------------------

DOMAIN_DATA_CACHE <- new.env(parent = emptyenv())

domain_definitions <- function() {
  list(
    iq = list(
      name = "General Cognitive Ability",
      pheno = "iq",
      number = "01",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    academics = list(
      name = "Academic Skills",
      pheno = "academics",
      number = "02",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    verbal = list(
      name = "Verbal/Language",
      pheno = "verbal",
      number = "03",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    spatial = list(
      name = "Visual Perception/Construction",
      pheno = "spatial",
      number = "04",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    memory = list(
      name = "Memory",
      pheno = "memory",
      number = "05",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    executive = list(
      name = "Attention/Executive",
      pheno = "executive",
      number = "06",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    motor = list(
      name = "Motor",
      pheno = "motor",
      number = "07",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    social = list(
      name = "Social Cognition",
      pheno = "social",
      number = "08",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    adhd = list(
      name = "ADHD/Executive Function",
      pheno = "adhd",
      number = "09",
      input_file = file.path("data", "neurobehav.parquet"),
      data_source = "neurobehav"
    ),
    emotion = list(
      name = "Emotional/Behavioral/Social/Personality",
      pheno = "emotion",
      number = "10",
      input_file = file.path("data", "neurobehav.parquet"),
      data_source = "neurobehav"
    ),
    adaptive = list(
      name = "Adaptive Functioning",
      pheno = "adaptive",
      number = "11",
      input_file = file.path("data", "neurobehav.parquet"),
      data_source = "neurobehav"
    ),
    daily_living = list(
      name = "Daily Living",
      pheno = "daily_living",
      number = "12",
      input_file = file.path("data", "neurocog.parquet"),
      data_source = "neurocog"
    ),
    validity = list(
      name = "Validity",
      pheno = "validity",
      number = "13",
      input_file = file.path("data", "validity.parquet"),
      data_source = "validity"
    )
  )
}

domain_qmd_filename <- function(pheno, number) {
  ph <- tolower(pheno)
  if (ph == "emotion") {
    return(sprintf("_02-%s_emotion.qmd", number))
  }
  if (ph == "adhd") {
    return(sprintf("_02-%s_adhd.qmd", number))
  }
  sprintf("_02-%s_%s.qmd", number, ph)
}

domain_text_pattern <- function(pheno, number) {
  ph <- tolower(pheno)
  if (ph == "emotion") {
    return(sprintf("^_02-%s_emotion_text.*\\.qmd$", number))
  }
  if (ph == "adhd") {
    return(sprintf("^_02-%s_adhd_text.*\\.qmd$", number))
  }
  sprintf("^_02-%s_%s_text\\.qmd$", number, ph)
}

load_domain_dataset <- function(data_source) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    return(NULL)
  }

  if (!exists(data_source, envir = DOMAIN_DATA_CACHE, inherits = FALSE)) {
    data_file <- switch(
      data_source,
      neurocog = here::here("data", "neurocog.parquet"),
      neurobehav = here::here("data", "neurobehav.parquet"),
      validity = here::here("data", "validity.parquet"),
      NULL
    )

    dataset <- NULL
    if (!is.null(data_file) && file.exists(data_file)) {
      dataset <- tryCatch(
        {
          arrow::read_parquet(data_file)
        },
        error = function(e) {
          warning("Failed to load data for ", data_source, ": ", e$message)
          NULL
        }
      )
    }

    assign(data_source, dataset, envir = DOMAIN_DATA_CACHE)
  }

  get(data_source, envir = DOMAIN_DATA_CACHE, inherits = FALSE)
}

domain_has_data <- function(domain_key) {
  definitions <- domain_definitions()
  config <- definitions[[domain_key]]

  if (is.null(config)) {
    return(FALSE)
  }

  dataset <- load_domain_dataset(config$data_source)

  if (is.null(dataset)) {
    return(FALSE)
  }

  if (!"domain" %in% names(dataset)) {
    return(FALSE)
  }

  domain_rows <- dataset[dataset$domain == config$name, , drop = FALSE]

  if (nrow(domain_rows) == 0) {
    return(FALSE)
  }

  measure_cols <- intersect(
    c(
      "percentile",
      "score",
      "scaled_score",
      "standard_score",
      "t_score",
      "z_score",
      "ss",
      "composite_score"
    ),
    names(domain_rows)
  )

  if (length(measure_cols) == 0) {
    return(TRUE)
  }

  any(vapply(
    measure_cols,
    function(col) any(!is.na(domain_rows[[col]])),
    FUN.VALUE = logical(1)
  ))
}

# ==============================================================================
# DOMAIN GENERATION
# ==============================================================================

generate_all_domains <- function(
  patient = DEFAULT_CONFIG$patient,
  force_regenerate = FALSE,
  protect_edits = TRUE,
  verbose = TRUE
) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Domain generation requires the 'arrow' package.")
  }

  # Load class definitions into an isolated environment
  domain_env <- new.env(parent = baseenv())
  class_files <- c(
    "R/ScoreTypeCacheR6.R",
    "R/score_type_utils.R",
    "R/tidy_data.R",
    "R/NeuropsychResultsR6.R",
    "R/TableGTR6.R",
    "R/DotplotR6.R",
    "R/DomainProcessorR6.R"
  )

  resolve_source_path <- function(rel_path) {
    primary <- here::here(rel_path)
    if (file.exists(primary)) {
      return(primary)
    }

    fallback <- here::here("inst", "scripts", basename(rel_path))
    if (file.exists(fallback)) {
      return(fallback)
    }

    NULL
  }

  for (rel_path in class_files) {
    src_path <- resolve_source_path(rel_path)
    if (is.null(src_path)) {
      stop("Required class file not found: ", rel_path)
    }
    sys.source(src_path, envir = domain_env, chdir = TRUE)
  }

  domain_config <- domain_definitions()

  statuses <- list(
    generated = character(),
    cached = character(),
    protected = character(),
    skipped = character(),
    failed = list(),
    text_files = list()
  )

  if (isTRUE(verbose)) {
    message("Generating domain QMD and text files for patient: ", patient)
  }

  for (domain_key in names(domain_config)) {
    config <- domain_config[[domain_key]]
    domain_label <- paste0(config$number, " - ", config$name)
    input_path <- here::here(config$input_file)

    if (!file.exists(input_path)) {
      if (isTRUE(verbose)) {
        message(
          "  ⚠ Skipping ",
          domain_label,
          " (missing data: ",
          input_path,
          ")"
        )
      }
      statuses$skipped <- c(statuses$skipped, domain_key)
      next
    }

    if (!domain_has_data(domain_key)) {
      if (isTRUE(verbose)) {
        message("  ⚠ No data available, skipping ", domain_label)
      }
      statuses$skipped <- c(statuses$skipped, domain_key)
      next
    }

    qmd_file <- domain_qmd_filename(config$pheno, config$number)
    qmd_preexisting <- file.exists(qmd_file)
    text_pattern <- domain_text_pattern(config$pheno, config$number)
    existing_text_files <- list.files(
      pattern = text_pattern,
      full.names = FALSE
    )

    if (!force_regenerate && protect_edits && length(existing_text_files) > 0) {
      edited_flags <- vapply(
        existing_text_files,
        FUN = function(path) isTRUE(is_manually_edited(path)),
        FUN.VALUE = logical(1)
      )

      if (any(edited_flags)) {
        if (isTRUE(verbose)) {
          message("  ⛔ Protected edits detected, skipping ", domain_label)
        }
        statuses$protected <- c(statuses$protected, domain_key)
        next
      }
    }

    if (force_regenerate) {
      removable <- c(
        qmd_file,
        existing_text_files,
        paste0(existing_text_files, ".generated")
      )
      removable <- removable[file.exists(removable)]
      if (length(removable) > 0) {
        invisible(file.remove(removable))
      }
    }

    tryCatch(
      {
        processor <- domain_env$DomainProcessorR6$new(
          domains = config$name,
          pheno = config$pheno,
          input_file = input_path,
          output_dir = here::here("output"),
          number = config$number,
          output_base = here::here()
        )

        processor$process(generate_domain_files = FALSE)
        processor$generate_domain_qmd(output_file = qmd_file)
        text_files <- processor$generate_domain_text_qmd()
        text_files <- unique(c(text_files, existing_text_files))

        statuses$text_files[[domain_key]] <- unique(text_files)

        if (qmd_preexisting && !force_regenerate) {
          statuses$cached <- c(statuses$cached, domain_key)
          if (isTRUE(verbose)) {
            message("  • ", domain_label, " already up to date")
          }
        } else {
          statuses$generated <- c(statuses$generated, domain_key)
          if (isTRUE(verbose)) {
            message("  ✓ Generated ", domain_label)
          }
        }
      },
      error = function(e) {
        statuses$failed[[domain_key]] <<- e$message
        if (isTRUE(verbose)) {
          message("  ✗ Failed ", domain_label, ": ", e$message)
        }
      }
    )
  }

  if (isTRUE(verbose)) {
    message(
      "Domain generation complete (generated: ",
      length(statuses$generated),
      ", cached: ",
      length(statuses$cached),
      ", protected: ",
      length(statuses$protected),
      ", skipped: ",
      length(statuses$skipped),
      ", failed: ",
      length(statuses$failed),
      ")"
    )
  }

  invisible(statuses)
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

  template_qmd_path <- NULL
  if (render_report) {
    template_qmd_path <- ensure_template_files()
    generate_domains_include_manifest()
  }

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
        if (is.null(template_qmd_path) || !file.exists(template_qmd_path)) {
          missing_path <- if (is.null(template_qmd_path)) {
            "NULL"
          } else {
            template_qmd_path
          }
          stop("Main QMD template not found at: ", missing_path)
        }

        quarto::quarto_render(
          input = template_qmd_path,
          output_format = "typst"
        )

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

    # Around line 668 in inst/scripts/00_complete_neuropsych_workflow.R
    # Before the second render, add validation:

    tryCatch(
      {
        log_message("STAGE", "4B: SECOND RENDER")
        log_message(
          "INFO",
          "Rendering report (second pass with complete LLM summaries)..."
        )

        # Validate input file exists
        if (is.null(template_qmd_path) || !file.exists(template_qmd_path)) {
          missing_path <- if (is.null(template_qmd_path)) {
            "NULL"
          } else {
            template_qmd_path
          }
          stop("Main QMD file not found: ", missing_path)
        }

        quarto::quarto_render(
          input = template_qmd_path,
          output_format = "neurotyp-pediatric-typst",
          quiet = FALSE
        )

        log_message("SUCCESS", "Second render completed successfully")
      },
      error = function(e) {
        warning("Second render failed: ", e$message)
      }
    )

    # Second render integrates LLM summaries
    tryCatch(
      {
        quarto::quarto_render(
          input = template_qmd_path,
          output_format = "typst"
        )

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
        if (is.null(template_qmd_path) || !file.exists(template_qmd_path)) {
          missing_path <- if (is.null(template_qmd_path)) {
            "NULL"
          } else {
            template_qmd_path
          }
          stop("Main QMD template not found: ", missing_path)
        }

        quarto::quarto_render(
          input = template_qmd_path,
          output_format = "typst"
        )

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
