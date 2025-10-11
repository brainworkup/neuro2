#!/usr/bin/env Rscript

#' Complete Neuropsychological Report Workflow
#'
#' This script provides a unified entry point for the entire neuropsych report
#' generation process, from raw data to final PDF output.
#'
#' @param patient Patient name for the report
#' @param generate_qmd Whether to generate QMD domain files (default: TRUE)
#' @param render_report Whether to render the final PDF report (default: TRUE)
#' @param force_reprocess Whether to force data reprocessing even if files exist (default: FALSE)
#' @return Path to the generated report (if rendered)
#' @export
run_neuropsych_workflow <- function(
  patient = "Patient",
  generate_qmd = TRUE,
  render_report = TRUE,
  force_reprocess = FALSE
) {
  
  # Set up logging
  log_file <- paste0("workflow_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
  sink(log_file, split = TRUE)
  on.exit(sink(), add = TRUE)
  
  cat("========================================\n")
  cat("NEUROPSYCH REPORT GENERATION WORKFLOW\n")
  cat("Patient:", patient, "\n")
  cat("Started:", format(Sys.time()), "\n")
  cat("========================================\n\n")
  
  # Track workflow state
  workflow_state <- list(
    templates_checked = FALSE,
    data_processed = FALSE,
    domains_generated = FALSE,
    assets_generated = FALSE,
    llm_processed = FALSE,
    report_rendered = FALSE
  )
  
  report_output_file <- NULL
  
  # Error handler
  handle_error <- function(step, e) {
    cat("\n❌ ERROR in", step, ":\n")
    cat(conditionMessage(e), "\n")
    cat("\nWorkflow state:\n")
    print(workflow_state)
    cat("\nPlease fix the error and re-run the workflow.\n")
    stop(paste("Workflow failed at:", step), call. = FALSE)
  }
  
  # Step 1: Environment setup
  cat("\n📋 STEP 1: Checking environment and templates...\n")
  tryCatch({
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
  }, error = function(e) handle_error("template checking", e))
  
  # Step 2: Data processing
  cat("\n🔄 STEP 2: Processing raw data...\n")
  tryCatch({
    data_files <- c(
      "data/neurocog.parquet",
      "data/neurobehav.parquet",
      "data/validity.parquet"
    )
    
    if (all(file.exists(data_files)) && !force_reprocess) {
      cat("ℹ️  Data files already exist. Skipping processing.\n")
      cat("   Use force_reprocess=TRUE to reprocess.\n")
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
  }, error = function(e) handle_error("data processing", e))
  
  # Step 3: Domain file generation
  if (generate_qmd) {
    cat("\n📄 STEP 3: Generating domain files...\n")
    tryCatch({
      result <- system2(
        "Rscript",
        "inst/scripts/03_generate_domain_files.R",
        stdout = TRUE,
        stderr = TRUE
      )
      
      domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
      if (length(domain_files) == 0) {
        warning(
          "No domain files generated - check if data contains valid domains"
        )
      } else {
        cat("✅ Generated", length(domain_files), "domain files\n")
      }
      workflow_state$domains_generated <- TRUE
    }, error = function(e) handle_error("domain generation", e))
  } else {
    cat("\n⏭️  STEP 3: Skipping domain file generation (generate_qmd=FALSE)\n")
    workflow_state$domains_generated <- TRUE
  }
  
  # Step 4: Asset generation
  cat("\n🎨 STEP 4: Generating tables and figures...\n")
  tryCatch({
    result <- system2(
      "Rscript",
      "inst/scripts/04_generate_all_domain_assets.R",
      stdout = TRUE,
      stderr = TRUE
    )

    critical_assets <- c("figs/fig_sirf_overall.svg")
    if (!all(file.exists(critical_assets))) {
      warning("Some critical assets missing - report may have errors")
    }

    workflow_state$assets_generated <- TRUE
    cat("✅ Assets generated successfully\n")
  }, error = function(e) handle_error("asset generation", e))

  # Step 4.5: LLM processing (NSE, SIRF, Recommendations)
  cat("\n🤖 STEP 4.5: Processing LLM prompts (NSE, SIRF, Recommendations)...\n")
  tryCatch({
    # Run LLM processing for all domain prompts
    llm_result <- run_llm_for_all_domains(
      domain_keywords = c(
        "instnse",
        "instiq",
        "instacad",
        "instverb",
        "instvis",
        "instmem",
        "instexe",
        "instmot",
        "instsoc",
        "instadhd",
        "instadhd_p",
        "instadhd_t",
        "instadhd_o",
        "instemo",
        "instemo_p",
        "instemo_t",
        "instadapt",
        "instdl",
        "instsirf",
        "instrec"
      ),
      backend = "ollama",
      temperature = 0.2,
      base_dir = "."
    )

    workflow_state$llm_processed <- TRUE
    cat("✅ LLM processing completed successfully\n")
  }, error = function(e) handle_error("LLM processing", e))

  # Step 5: Report rendering
  if (render_report) {
    cat("\n📑 STEP 5: Rendering final report...\n")
    tryCatch({
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
      
      # Prepare domain text context
      prepare_domain_text_context()
      
      # Create output directory if needed
      if (!identical(output_dir, ".") && !dir.exists(output_dir)) {
        if (!dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)) {
          stop("Failed to create report output directory: ", output_dir)
        }
      }
      
      # Render with Quarto
      quarto_args <- c("render", template_file, "-t", format)
      if (!identical(output_dir, ".")) {
        quarto_args <- c(quarto_args, "--output-dir", output_dir)
      }
      
      result <- system2(
        "quarto",
        args = quarto_args,
        stdout = TRUE,
        stderr = TRUE
      )
      
      status <- attr(result, "status") %||% 0
      if (status != 0) {
        stop(paste0(
          "Quarto render failed with status ",
          status,
          ":\n",
          paste(result, collapse = "\n")
        ))
      }
      
      if (file.exists(output_file)) {
        cat("✅ Report rendered successfully:", output_file, "\n")
        workflow_state$report_rendered <- TRUE
        report_output_file <- output_file
      } else {
        stop("Report rendering failed - no output file created")
      }
    }, error = function(e) handle_error("report rendering", e))
  } else {
    cat("\n⏭️  STEP 5: Skipping report rendering (render_report=FALSE)\n")
  }
  
  # Summary
  cat("\n========================================\n")
  cat("WORKFLOW COMPLETE\n")
  cat("Patient:", patient, "\n")
  cat("Completed:", format(Sys.time()), "\n")
  
  cat("\nFinal workflow state:\n")
  for (step in names(workflow_state)) {
    status <- if (workflow_state[[step]]) "✅" else "❌"
    cat(sprintf("  %s %s\n", status, gsub("_", " ", step)))
  }
  
  if (workflow_state$report_rendered) {
    cat("\n🎉 Success! Your report is ready at:", report_output_file, "\n")
  } else if (!render_report) {
    cat("\n✅ Workflow complete. Report rendering was skipped.\n")
  } else {
    cat("\n⚠️  Workflow incomplete. Check the log for errors.\n")
  }
  
  cat("========================================\n")
  cat("\nWorkflow log saved to:", log_file, "\n")
  
  # Return the output file path invisibly
  invisible(report_output_file)
}

# Helper function for domain text context
prepare_domain_text_context <- function() {
  text_files <- list.files(
    pattern = "^_02-[0-9]+_.*_text(?:_[a-z]+)?\\.qmd$",
    full.names = FALSE
  )
  
  if (!length(text_files)) {
    return(invisible(NULL))
  }
  
  # Domain lookup configuration
  domain_lookup <- list(
    iq = list(
      domain = "General Cognitive Ability",
      input = "data/neurocog.parquet"
    ),
    academics = list(
      domain = "Academic Skills",
      input = "data/neurocog.parquet"
    ),
    verbal = list(
      domain = "Verbal/Language",
      input = "data/neurocog.parquet"
    ),
    spatial = list(
      domain = "Visual Perception/Construction",
      input = "data/neurocog.parquet"
    ),
    memory = list(
      domain = "Memory",
      input = "data/neurocog.parquet"
    ),
    executive = list(
      domain = "Attention/Executive",
      input = "data/neurocog.parquet"
    ),
    motor = list(
      domain = "Motor",
      input = "data/neurocog.parquet"
    ),
    social = list(
      domain = "Social Cognition",
      input = "data/neurocog.parquet"
    ),
    adhd = list(
      domain = "ADHD/Executive Function",
      input = "data/neurobehav.parquet"
    ),
    emotion = list(
      domain = "Emotional/Behavioral/Social/Personality",
      input = "data/neurobehav.parquet"
    ),
    adaptive = list(
      domain = "Adaptive Functioning",
      input = "data/neurobehav.parquet"
    ),
    daily_living = list(
      domain = "Daily Living",
      input = "data/neurocog.parquet"
    )
  )
  
  # Process each text file
  for (text_file in text_files) {
    matches <- regexec(
      "^_02-([0-9]+)_([a-z_]+)_text(?:_([a-z]+))?\\.qmd$",
      text_file
    )
    parts <- regmatches(text_file, matches)[[1]]
    
    if (length(parts) == 0) next
    
    pheno <- parts[3]
    rater <- if (length(parts) >= 4) parts[4] else ""
    cfg <- domain_lookup[[pheno]]
    
    if (is.null(cfg)) next
    
    processor <- DomainProcessorR6$new(
      domains = cfg$domain,
      pheno = pheno,
      input_file = cfg$input
    )
    
    proc_ok <- tryCatch({
      processor$load_data()
      processor$filter_by_domain()
      processor$select_columns()
      TRUE
    }, error = function(e) FALSE)
    
    if (!proc_ok) next
    
    data <- processor$data
    if (is.null(data) || !nrow(data)) next
    
    if (nzchar(rater) && "rater" %in% names(data)) {
      data <- data[
        tolower(trimws(data$rater)) == tolower(rater),
        ,
        drop = FALSE
      ]
    }
    
    if (is.null(data) || !nrow(data)) next
    
    try({
      results_processor <- NeuropsychResultsR6$new(
        data = data,
        file = text_file
      )
      results_processor$process(llm = TRUE)
    }, silent = TRUE)
  }
  
  invisible(NULL)
}

# If run as a script (not sourced), execute with command line args
if (!interactive() && !is.null(sys.calls())) {
  args <- commandArgs(trailingOnly = TRUE)
  patient_name <- if (length(args) > 0) args[1] else "Patient"
  
  run_neuropsych_workflow(
    patient = patient_name,
    generate_qmd = TRUE,
    render_report = TRUE
  )
}
