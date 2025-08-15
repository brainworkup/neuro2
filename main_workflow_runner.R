#!/usr/bin/env Rscript

#' Main Workflow Runner - Updated for new file locations
#'
#' Simple script to run the complete neuropsychological report workflow
#' Usage: Rscript main_workflow_runner.R
#'    or: source("main_workflow_runner.R"); main()

# Load required packages
suppressPackageStartupMessages({
  library(here)
})

#' Check if required files exist and report status
check_required_files <- function() {
  cat("🔍 Checking required files...\n")

  required_files <- list(
    "DomainProcessorR6" = c(
      "R/DomainProcessorR6.R",
      "R/DomainProcessorFactoryR6.R"
    ),
    "Batch Processor" = c(
      "inst/scripts/batch_domain_processor.R",
      "scripts/batch_domain_processor.R"
    ),
    "Template Workflow" = c(
      "inst/scripts/template_integration.R",
      "scripts/template_integration.R"
    )
  )

  found_files <- list()
  missing_components <- character()

  for (component in names(required_files)) {
    possible_paths <- required_files[[component]]
    found <- FALSE

    for (path in possible_paths) {
      full_path <- here::here(path)
      if (file.exists(full_path)) {
        found_files[[component]] <- path
        cat("   ✅", component, ":", path, "\n")
        found <- TRUE
        break
      }
    }

    if (!found) {
      missing_components <- c(missing_components, component)
      cat("   ❌", component, "- NOT FOUND in any of these locations:\n")
      for (path in possible_paths) {
        cat("      -", path, "\n")
      }
    }
  }

  if (length(missing_components) > 0) {
    cat(
      "\n❌ Missing required components:",
      paste(missing_components, collapse = ", "),
      "\n"
    )
    return(list(success = FALSE, files = found_files))
  }

  cat("\n✅ All required files found!\n")
  return(list(success = TRUE, files = found_files))
}

#' Source required scripts with error handling
source_scripts <- function(file_paths) {
  cat("\n📁 Loading required scripts...\n")

  success_count <- 0
  total_count <- length(file_paths)

  for (component in names(file_paths)) {
    script_path <- file_paths[[component]]
    full_path <- here::here(script_path)

    cat("   Loading", component, "...")

    tryCatch(
      {
        source(full_path)
        cat(" ✅\n")
        success_count <- success_count + 1
      },
      error = function(e) {
        cat(" ❌\n")
        cat("      Error:", e$message, "\n")
      }
    )
  }

  cat(
    "\n📊 Successfully loaded",
    success_count,
    "out of",
    total_count,
    "scripts\n"
  )
  return(success_count == total_count)
}

#' Main function to run the complete workflow
main <- function() {
  cat("🧠 Neuropsychological Report Generator\n")
  cat("=====================================\n\n")

  # Check for required files
  file_check <- check_required_files()

  if (!file_check$success) {
    cat("\n⚠️  Cannot proceed without required files.\n")
    cat("💡 Please ensure all necessary scripts are in place.\n")
    return(FALSE)
  }

  # Source the required scripts
  source_success <- source_scripts(file_check$files)

  if (!source_success) {
    cat("\n⚠️  Some scripts failed to load. Proceeding with caution...\n")
  }

  cat("\n🚀 Starting complete workflow...\n")
  cat("==============================\n")

  # Try to run the complete workflow
  success <- tryCatch(
    {
      # Check if the function exists
      if (exists("run_complete_workflow")) {
        run_complete_workflow(verbose = TRUE)
      } else {
        cat("❌ run_complete_workflow function not found.\n")
        cat("💡 Trying alternative workflow functions...\n")

        # Try alternative functions
        if (exists("quick_workflow")) {
          quick_workflow()
        } else if (exists("process_all_domains")) {
          process_all_domains(verbose = TRUE)
          TRUE
        } else {
          cat("❌ No workflow functions found.\n")
          FALSE
        }
      }
    },
    error = function(e) {
      cat("❌ Error running workflow:", e$message, "\n")
      FALSE
    }
  )

  # Report results
  if (success) {
    cat("\n🎉 SUCCESS! Your neuropsychological report workflow completed.\n")
    cat("📄 Check for output files in your project directory.\n")

    # Look for generated files
    check_generated_files()
  } else {
    cat("\n⚠️  Workflow completed with issues.\n")
    cat("📋 Check the output above for details.\n")
    cat("💡 Try running individual components manually.\n")
  }

  return(success)
}

#' Check for generated files
check_generated_files <- function() {
  cat("\n📁 Checking for generated files...\n")

  # Look for domain QMD files
  domain_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$")
  if (length(domain_files) > 0) {
    cat("   📄 Domain files generated:\n")
    for (file in domain_files) {
      cat("      -", file, "\n")
    }
  }

  # Look for report files
  report_files <- list.files(".", pattern = "neuropsych.*\\.(pdf|html|docx)$")
  if (length(report_files) > 0) {
    cat("   📊 Report files generated:\n")
    for (file in report_files) {
      cat("      -", file, "\n")
    }
  }

  # Look for figures
  fig_dir <- here::here("figs")
  if (dir.exists(fig_dir)) {
    fig_files <- list.files(fig_dir, pattern = "\\.(png|pdf|svg)$")
    if (length(fig_files) > 0) {
      cat("   🎨 Figure files generated (", length(fig_files), " total)\n")
    }
  }
}

#' Quick test function
test_setup <- function() {
  cat("🧪 Testing setup...\n")

  file_check <- check_required_files()

  if (!file_check$success) {
    return(FALSE)
  }

  # Try to source and test template workflow
  template_component <- file_check$files[["Template Workflow"]]
  if (!is.null(template_component)) {
    template_script <- here::here(template_component)
    source(template_script)

    if (exists("quick_setup")) {
      quick_setup()
    } else {
      cat("⚠️  quick_setup function not found in template script\n")
    }
  }

  return(TRUE)
}

#' Test with a single domain
test_single <- function(domain = "Memory") {
  cat("🧪 Testing single domain:", domain, "\n")

  # Check for domain processor
  file_check <- check_required_files()
  if (!file_check$success) {
    return(FALSE)
  }

  # Source domain processor
  domain_component <- file_check$files[["DomainProcessorR6"]]
  if (!is.null(domain_component)) {
    source(here::here(domain_component))
  } else {
    cat("❌ Could not find domain processor\n")
    return(FALSE)
  }

  # Check for data file
  data_files <- c(
    "data/neurocog.parquet",
    "data/neurocog.feather",
    "data/neurocog.csv"
  )

  data_file <- NULL
  for (file in data_files) {
    if (file.exists(here::here(file))) {
      data_file <- file
      break
    }
  }

  if (is.null(data_file)) {
    cat("❌ No data file found. Looking for:\n")
    for (file in data_files) {
      cat("   -", file, "\n")
    }
    return(FALSE)
  }

  cat("📊 Using data file:", data_file, "\n")

  # Test domain processing
  tryCatch(
    {
      if (exists("DomainProcessorR6")) {
        processor <- DomainProcessorR6$new(
          domains = domain,
          pheno = tolower(domain),
          input_file = data_file
        )

        result <- processor$generate_domain_qmd()
        cat("✅ Test complete! Generated:", result, "\n")
        return(result)
      } else if (exists("DomainProcessorR6")) {
        processor <- DomainProcessorR6$new(
          domains = domain,
          pheno = tolower(domain),
          input_file = data_file
        )

        result <- processor$generate_domain_qmd()
        cat("✅ Test complete! Generated:", result, "\n")
        return(result)
      } else {
        cat("❌ No domain processor class found\n")
        return(FALSE)
      }
    },
    error = function(e) {
      cat("❌ Error testing domain:", e$message, "\n")
      return(FALSE)
    }
  )
}

#' Show usage information
show_usage <- function() {
  cat("🧠 Neuropsychological Report Generator\n")
  cat("=====================================\n\n")
  cat("Usage:\n")
  cat("  main()                    - Run complete workflow\n")
  cat("  test_setup()             - Test environment setup\n")
  cat("  test_single('Memory')    - Test single domain\n")
  cat("  check_required_files()   - Check if all files are present\n")
  cat("  show_usage()             - Show this help\n\n")
  cat("Command line usage:\n")
  cat("  Rscript main_workflow_runner.R           # Run main workflow\n")
  cat("  Rscript main_workflow_runner.R test      # Test setup\n")
  cat("  Rscript main_workflow_runner.R single    # Test single domain\n")
  cat("  Rscript main_workflow_runner.R check     # Check files only\n")
}

# If run as script, execute appropriate function
if (!interactive()) {
  # Check command line arguments
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) > 0) {
    if (args[1] == "test") {
      test_setup()
    } else if (args[1] == "single") {
      domain <- if (length(args) > 1) args[2] else "Memory"
      test_single(domain)
    } else if (args[1] == "check") {
      check_required_files()
    } else if (args[1] == "help" || args[1] == "--help" || args[1] == "-h") {
      show_usage()
    } else {
      cat("❌ Unknown argument:", args[1], "\n\n")
      show_usage()
    }
  } else {
    # Run main workflow
    main()
  }
} else {
  # When sourced interactively
  cat("🧠 Main Workflow Runner loaded!\n")
  show_usage()
}
