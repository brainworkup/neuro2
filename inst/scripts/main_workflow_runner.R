#' Main Neuropsych Workflow Runner
#'
#' This script ensures the workflow runs ONCE and handles all domain processing
#' Place in: inst/scripts/main_workflow_runner.R

# Prevent multiple sourcing
if (exists(".WORKFLOW_RUNNING")) {
  message("Workflow is already running, skipping duplicate execution")
  return(invisible(NULL))
}
.WORKFLOW_RUNNING <- TRUE
on.exit(rm(.WORKFLOW_RUNNING, envir = .GlobalEnv))

#' Run the complete neuropsych workflow
#' @param patient Patient identifier
#' @param generate_qmd Whether to generate QMD files
#' @param render_report Whether to render the final report
run_neuropsych_workflow <- function(
  patient = "Biggie",
  generate_qmd = TRUE,
  render_report = FALSE
) {
  # Setup message
  message("\n==========================================")
  message("NEUROPSYCH WORKFLOW - SINGLE EXECUTION")
  message("Patient: ", patient)
  message("Time: ", Sys.time())
  message("==========================================\n")

  # Load required packages
  suppressPackageStartupMessages({
    library(here)
    library(dplyr)
    library(arrow)
    library(neuro2)
  })

  # Create a new environment for R6 classes to avoid namespace conflicts
  r6_env <- new.env()
  
  # Source R6 classes (check they exist first)
  r_files <- c(
    "DomainProcessorR6.R",
    "DomainProcessorFactoryR6.R",
    "NeuropsychResultsR6.R",
    "DotplotR6.R",
    "TableGTR6.R",
    "tidy_data.R"
  )

  # Get the package root directory
  pkg_root <- normalizePath(file.path(here::here(), "..", ".."))
  
  # Helper function to source files into a specific environment
  safe_source <- function(file_path, env) {
    if (file.exists(file_path)) {
      message("Loading: ", file_path)
      sys.source(file_path, envir = env, chdir = TRUE)
      return(TRUE)
    }
    return(FALSE)
  }
  
  # Try to source files from package R directory first, then inst/scripts
  for (file in r_files) {
    file_loaded <- FALSE
    
    # Try package R directory
    file_path <- file.path(pkg_root, "R", file)
    file_loaded <- safe_source(file_path, r6_env)
    
    # If not found, try inst/scripts
    if (!file_loaded) {
      file_path <- file.path(pkg_root, "inst", "scripts", file)
      file_loaded <- safe_source(file_path, r6_env)
    }
    
    if (!file_loaded) {
      stop(
        "Required file not found: ", file,
        "\nSearched in:\n- ", 
        file.path(pkg_root, "R", file),
        "\n- ",
        file.path(pkg_root, "inst", "scripts", file)
      )
    }
  }
  
  # Attach the environment with R6 classes
  attach(r6_env, name = "neuro2_r6_classes", warn.conflicts = FALSE)
  on.exit(detach("neuro2_r6_classes"), add = TRUE)

  # Create output directories
  ensure_output_directories()

  # Load data ONCE
  message("\n--- Loading Data ---")

  # Define data paths relative to package root
  data_paths <- list(
    neurocog = file.path(pkg_root, "data", "neurocog.parquet"),
    neurobehav = file.path(pkg_root, "data", "neurobehav.parquet")
  )

  # Check if data files exist
  for (data_name in names(data_paths)) {
    if (!file.exists(data_paths[[data_name]])) {
      stop(
        "Data file not found: ",
        data_paths[[data_name]],
        "\nPlease ensure the data files exist in the package's data/ directory."
      )
    }
  }

  # Load data
  neurocog_data <- load_data_safely(data_paths$neurocog)
  neurobehav_data <- load_data_safely(data_paths$neurobehav)

  if (is.null(neurocog_data) || is.null(neurobehav_data)) {
    stop(
      "Failed to load required data files. Check file formats and permissions."
    )
  }

  # Define domains to process with absolute paths
  domain_config <- list(
    iq = list(
      name = "General Cognitive Ability",
      pheno = "iq",
      input_file = file.path(pkg_root, "data", "neurocog.parquet"),
      number = "01"
    ),
    academics = list(
      name = "Academic Skills",
      pheno = "academics",
      input_file = file.path(pkg_root, "data", "neurocog.parquet"),
      number = "02"
    ),
    verbal = list(
      name = "Verbal/Language",
      pheno = "verbal",
      input_file = file.path(pkg_root, "data", "neurocog.parquet"),
      number = "03"
    ),
    spatial = list(
      name = "Visual Perception/Construction",
      pheno = "spatial",
      input_file = file.path(pkg_root, "data", "neurocog.parquet"),
      number = "04"
    ),
    memory = list(
      name = "Memory",
      pheno = "memory",
      input_file = file.path(pkg_root, "data", "neurocog.parquet"),
      number = "05"
    ),
    executive = list(
      name = "Attention/Executive",
      pheno = "executive",
      input_file = file.path(pkg_root, "data", "neurocog.parquet"),
      number = "06"
    ),
    motor = list(
      name = "Motor",
      pheno = "motor",
      input_file = file.path(pkg_root, "data", "neurocog.parquet"),
      number = "07"
    ),
    emotion = list(
      name = "Social Cognition",
      pheno = "social",
      input_file = file.path(pkg_root, "data", "neurobehav.parquet"),
      number = "08"
    ),
    emotion = list(
      name = "ADHD/Executive Functions",
      pheno = "adhd",
      input_file = file.path(pkg_root, "data", "neurobehav.parquet"),
      number = "09"
    ),
    emotion = list(
      name = "Emotional/Behavioral/Social/Personality",
      pheno = "emotion",
      input_file = file.path(pkg_root, "data", "neurobehav.parquet"),
      number = "10"
    ),
    emotion = list(
      name = "Adaptive Functioning",
      pheno = "adaptive",
      input_file = file.path(pkg_root, "data", "neurobehav.parquet"),
      number = "11"
    ),
    emotion = list(
      name = "Daily Living",
      pheno = "daily_living",
      input_file = file.path(pkg_root, "data", "neurobehav.parquet"),
      number = "12"
    ),
    validity = list(
      name = "Validity",
      pheno = "validity",
      input_file = file.path(pkg_root, "data", "neurocog.parquet"),
      number = "13"
    )
  )

  # Process each domain ONCE
  message("\n--- Processing Domains ---")
  successful_domains <- character()
  failed_domains <- character()

  for (domain_key in names(domain_config)) {
    config <- domain_config[[domain_key]]

    # Check if domain has data
    data_source <- if (grepl("neurocog", config$input_file)) {
      neurocog_data
    } else {
      neurobehav_data
    }

    validation <- validate_domain_data_exists(config$name, data_source)

    if (!validation$has_data) {
      message("  ✗ ", domain_key, ": ", validation$message)
      failed_domains <- c(failed_domains, domain_key)
      next
    }

    message("  ⟳ Processing ", domain_key, "...")

    tryCatch(
      {
        # Create processor in the correct environment
        processor <- with(r6_env, {
          DomainProcessorR6$new(
            domains = config$name,
            pheno = config$pheno,
            input_file = file.path(pkg_root, "data", basename(config$input_file)),
            output_dir = file.path(pkg_root, "output"),
            number = config$number
          )
        })

        # Process domain
        processor$process()

        # Generate QMD if requested
        if (generate_qmd) {
          qmd_file <- paste0("_02-", config$number, "_", config$pheno, ".qmd")
          processor$generate_domain_qmd(qmd_file)
        }

        successful_domains <- c(successful_domains, domain_key)
        message("  ✓ ", domain_key, " complete")
      },
      error = function(e) {
        message("  ✗ ", domain_key, " failed: ", e$message)
        failed_domains <- c(failed_domains, domain_key)
      }
    )
  }

  # Summary
  message("\n==========================================")
  message("WORKFLOW COMPLETE")
  message("Successful: ", length(successful_domains), " domains")
  if (length(failed_domains) > 0) {
    message("Failed: ", paste(failed_domains, collapse = ", "))
  }
  message("==========================================\n")

  # Optionally render report
  if (render_report && file.exists("template.qmd")) {
    message("\nRendering final report...")
    quarto::quarto_render(
      "template.qmd",
      execute_params = list(patient = patient),
      quiet = FALSE
    )
  }

  return(list(
    successful = successful_domains,
    failed = failed_domains,
    patient = patient
  ))
}

#' Safely load data with error handling
load_data_safely <- function(file_path) {
  if (!file.exists(file_path)) {
    warning("File not found: ", file_path)
    return(NULL)
  }

  tryCatch(
    {
      arrow::read_parquet(file_path)
    },
    error = function(e) {
      warning("Failed to load ", file_path, ": ", e$message)
      NULL
    }
  )
}

#' Ensure output directories exist
ensure_output_directories <- function() {
  dirs <- c("figs", "output", "tmp")
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      message("Created directory: ", dir)
    }
  }
}

#' Validate domain data exists
validate_domain_data_exists <- function(
  domain_name,
  data_source,
  min_rows = 1
) {
  validation <- list(
    has_data = FALSE,
    row_count = 0,
    domain_name = domain_name,
    message = ""
  )

  if (is.null(data_source) || nrow(data_source) == 0) {
    validation$message <- "Data source is empty"
    return(validation)
  }

  if (!"domain" %in% names(data_source)) {
    validation$message <- "Domain column not found"
    return(validation)
  }

  domain_data <- data_source |>
    dplyr::filter(domain == domain_name) |>
    dplyr::filter(!is.na(percentile) | !is.na(score))

  validation$row_count <- nrow(domain_data)
  validation$has_data <- validation$row_count >= min_rows

  if (validation$has_data) {
    validation$message <- paste("Found", validation$row_count, "rows")
  } else {
    validation$message <- paste(
      "Insufficient data -",
      validation$row_count,
      "rows"
    )
  }

  return(validation)
}
