# File: run_analysis.R (Robust Version)
# Neuropsychological Assessment Analysis
# This version handles missing files gracefully

# Source workflow lock to prevent multiple executions
source("workflow_lock.R")

#' Safe file sourcing with error handling
#' @param file_path Path to R file to source
#' @param required Whether file is required (stops execution if missing)
safe_source <- function(file_path, required = TRUE) {
  if (file.exists(file_path)) {
    tryCatch(
      {
        source(file_path)
        message("✅ Loaded: ", file_path)
        return(TRUE)
      },
      error = function(e) {
        message("❌ Error loading ", file_path, ": ", e$message)
        if (required) {
          stop("Required file failed to load: ", file_path)
        }
        return(FALSE)
      }
    )
  } else {
    message("❌ File not found: ", file_path)
    if (required) {
      stop(
        "Required file missing: ",
        file_path,
        "\nPlease ensure all neuro2 files are in place."
      )
    }
    return(FALSE)
  }
}

#' Initialize the analysis environment
init_analysis <- function() {
  message("🧠 Initializing neuropsychological assessment analysis...")

  # Try to load required packages first
  required_packages <- c("yaml", "here", "dplyr", "readr")

  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      message("Installing required package: ", pkg)
      install.packages(pkg)
    }
    library(pkg, character.only = TRUE, quietly = TRUE)
  }

  # Check if we're in the right directory
  if (!file.exists("config.yml")) {
    stop(
      "config.yml not found. Please run this from your patient workspace directory."
    )
  }

  # Try to load neuro2 setup (with fallback)
  setup_loaded <- FALSE

  # Method 1: Try the dedicated setup file
  if (file.exists("R/setup_neuro2.R")) {
    setup_loaded <- safe_source("R/setup_neuro2.R", required = FALSE)
  }

  # Method 2: Try loading individual files if setup failed
  if (!setup_loaded) {
    message("📜 Loading individual R files...")

    essential_files <- c("R/data_validation.R", "R/DomainProcessorR6.R")

    for (file in essential_files) {
      safe_source(file, required = FALSE)
    }

    # Load any other R files we can find
    other_r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
    other_r_files <- setdiff(
      other_r_files,
      c(essential_files, "R/setup_neuro2.R")
    )

    for (file in other_r_files) {
      safe_source(file, required = FALSE)
    }
  }

  message("✅ Environment initialization complete")
  return(TRUE)
}

#' Main analysis function with comprehensive error handling
main_analysis <- function() {
  # Initialize environment
  init_analysis()

  # Load configuration
  if (!file.exists("config.yml")) {
    stop("Configuration file 'config.yml' not found")
  }

  config <- yaml::read_yaml("config.yml")
  patient_name <- config$patient$name %||% "Unknown Patient"

  message("🧠 Starting assessment analysis for ", patient_name)

  # Step 1: Validate data availability
  message("📊 Checking data availability...")

  data_dir <- config$data$input_dir %||% "data"

  if (!dir.exists(data_dir)) {
    stop(
      "Data directory not found: ",
      data_dir,
      "\nPlease create the directory and add your data files."
    )
  }

  # List available data files
  data_files <- list.files(data_dir, pattern = "\\.(csv|parquet|feather)$")

  if (length(data_files) == 0) {
    stop(
      "No data files found in ",
      data_dir,
      "\nPlease add your neurocog.csv and neurobehav.csv files."
    )
  }

  message("  📄 Found data files: ", paste(data_files, collapse = ", "))

  # Step 2: Load and validate data
  message("📋 Loading and validating data...")

  loaded_data <- NULL

  # Try the fancy validation function if it exists
  if (exists("validate_and_load_data")) {
    tryCatch(
      {
        loaded_data <- validate_and_load_data(
          data_dir = data_dir,
          config = config,
          verbose = TRUE
        )
        message("✅ Data loaded using validation function")
      },
      error = function(e) {
        message("⚠️  Validation function failed: ", e$message)
        message("   Falling back to simple data loading...")
        loaded_data <- NULL
      }
    )
  }

  # Fallback: Simple data loading
  if (is.null(loaded_data)) {
    loaded_data <- list()

    for (file in data_files) {
      file_path <- file.path(data_dir, file)
      file_name <- tools::file_path_sans_ext(file)

      tryCatch(
        {
          if (tools::file_ext(file) == "csv") {
            data <- readr::read_csv(file_path, show_col_types = FALSE)
            loaded_data[[file_name]] <- data
            message("  ✅ Loaded: ", file, " (", nrow(data), " rows)")
          }
        },
        error = function(e) {
          message("  ❌ Failed to load ", file, ": ", e$message)
        }
      )
    }

    if (length(loaded_data) == 0) {
      stop("No data files could be loaded. Please check your file formats.")
    }
  }

  # Step 3: Process domains (with fallback)
  message("🧠 Processing assessment domains...")

  results <- NULL

  # Try the sophisticated processing function if available
  if (exists("process_all_domains")) {
    tryCatch(
      {
        results <- process_all_domains(
          data_dir = data_dir,
          age_group = config$patient$age_group %||% "auto",
          verbose = TRUE
        )
        message("✅ Domains processed using advanced function")
      },
      error = function(e) {
        message("⚠️  Advanced processing failed: ", e$message)
        message("   Falling back to basic processing...")
        results <- NULL
      }
    )
  }

  # Fallback: Basic domain processing
  if (is.null(results)) {
    message("📊 Using basic domain processing...")

    results <- list()

    for (data_name in names(loaded_data)) {
      data <- loaded_data[[data_name]]

      if ("domain" %in% names(data)) {
        domains <- unique(data$domain[!is.na(data$domain)])

        for (domain in domains) {
          domain_data <- data[data$domain == domain & !is.na(data$domain), ]

          if (nrow(domain_data) > 0) {
            results[[paste0(domain, "_", data_name)]] <- domain_data
            message(
              "  📋 Processed: ",
              domain,
              " (",
              nrow(domain_data),
              " tests)"
            )
          }
        }
      }
    }
  }

  # Step 4: Generate outputs
  message("📄 Generating outputs...")

  output_dir <- config$data$output_dir %||% "output"
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Save processed data
  summary_file <- file.path(output_dir, "assessment_summary.csv")

  if (length(results) > 0) {
    # Create a summary of all results
    summary_data <- data.frame(
      domain = names(results),
      test_count = sapply(results, function(x) {
        if (is.data.frame(x)) nrow(x) else 0
      }),
      data_source = sapply(names(results), function(n) {
        parts <- strsplit(n, "_")[[1]]
        if (length(parts) > 1) parts[length(parts)] else "unknown"
      }),
      stringsAsFactors = FALSE
    )

    readr::write_csv(summary_data, summary_file)
    message("  📊 Saved summary: ", summary_file)
  }

  # Generate simple report
  report_content <- c(
    paste("# Assessment Report for", patient_name),
    paste("Generated on:", Sys.Date()),
    "",
    "## Data Summary",
    paste("- Data files processed:", length(loaded_data)),
    paste("- Domains identified:", length(results)),
    paste("- Output directory:", output_dir),
    "",
    "## Next Steps",
    "1. Review the generated summary file",
    "2. Check output directory for additional files",
    "3. Consider using advanced processing if available"
  )

  report_file <- file.path(output_dir, "assessment_report.md")

  # Check if report already exists
  if (file.exists(report_file)) {
    message("  📄 Report already exists, will be overwritten: ", report_file)
  }

  writeLines(report_content, report_file)
  message("  📄 Saved report: ", report_file)

  message("✅ Analysis complete!")
  message("📁 Check the output directory: ", output_dir)

  return(list(
    results = results,
    summary_file = summary_file,
    report_file = report_file,
    config = config
  ))
}

#' Safe execution wrapper
safe_main_analysis <- function() {
  tryCatch(
    {
      result <- main_analysis()
      message("🎉 Assessment analysis completed successfully!")
      return(result)
    },
    error = function(e) {
      message("❌ Analysis failed: ", e$message)
      message("")
      message("🔧 Troubleshooting checklist:")
      message(
        "  1. Are you in the correct directory? (should contain config.yml)"
      )
      message("  2. Do you have data files in the data/ directory?")
      message("  3. Are your CSV files properly formatted?")
      message("  4. Do you have all required R files in the R/ directory?")
      message("")
      message("💡 Try running these diagnostic commands:")
      message("  - list.files('data')")
      message("  - list.files('R')")
      message("  - yaml::read_yaml('config.yml')")

      return(NULL)
    }
  )
}

# Run analysis if script is executed directly
if (!interactive()) {
  result <- safe_main_analysis()

  if (is.null(result)) {
    quit(status = 1) # Exit with error code if failed
  }
}
