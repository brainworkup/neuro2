#' Upload Files Helper for neuro2 Workflow
#'
#' This function provides a user-friendly interface for uploading files
#' to the neuro2 neuropsychological report generation system.
#'
#' @param method Character string specifying upload method. Options:
#'   - "csv": Upload CSV files directly
#'   - "pdf": Extract data from PDF reports  
#'   - "interactive": Interactive mode with prompts
#' @param file_path Character string or vector of file paths to upload.
#'   If NULL, will open file chooser dialog(s)
#' @param patient_name Character string with patient name
#' @param test_type Character string specifying test type for PDF extraction.
#'   Options include: "wisc5", "wais5", "wiat4", "caars2", "rbans", etc.
#' @param destination Character string specifying destination directory.
#'   Default: "data-raw/csv"
#' @param run_workflow Logical. If TRUE, automatically runs the main workflow
#'   after file upload. Default: FALSE
#'
#' @return Invisibly returns list with upload results and file paths
#'
#' @examples
#' \dontrun{
#' # Interactive mode - will prompt for everything
#' upload_files(method = "interactive")
#'
#' # Upload CSV files directly
#' upload_files(
#'   method = "csv",
#'   file_path = c("test1.csv", "test2.csv"),
#'   patient_name = "John Doe"
#' )
#'
#' # Extract from PDF and run workflow
#' upload_files(
#'   method = "pdf",
#'   test_type = "wisc5", 
#'   patient_name = "Jane Smith",
#'   run_workflow = TRUE
#' )
#' }
#'
#' @export
upload_files <- function(
  method = "interactive",
  file_path = NULL,
  patient_name = NULL,
  test_type = NULL,
  destination = "data-raw/csv",
  run_workflow = FALSE
) {
  
  # Input validation
  valid_methods <- c("csv", "pdf", "interactive")
  if (!method %in% valid_methods) {
    stop("Method must be one of: ", paste(valid_methods, collapse = ", "))
  }
  
  # Create destination directory if needed
  if (!dir.exists(destination)) {
    dir.create(destination, recursive = TRUE)
    message("✓ Created directory: ", destination)
  }
  
  # Initialize results
  results <- list(
    method = method,
    files_processed = character(0),
    patient_name = patient_name,
    success = FALSE,
    message = ""
  )
  
  # Interactive mode
  if (method == "interactive") {
    cat("\n🧠 neuro2 File Upload Assistant\n")
    cat("================================\n\n")
    
    # Get patient name if not provided
    if (is.null(patient_name)) {
      patient_name <- readline(prompt = "Enter patient name: ")
    }
    
    # Choose upload method
    cat("\nChoose upload method:\n")
    cat("1. CSV files (already processed data)\n")
    cat("2. PDF reports (will extract data)\n")
    choice <- readline(prompt = "Enter choice (1 or 2): ")
    
    if (choice == "1") {
      method <- "csv"
    } else if (choice == "2") {
      method <- "pdf"
    } else {
      stop("Invalid choice. Please run again and choose 1 or 2.")
    }
    
    results$patient_name <- patient_name
  }
  
  # CSV upload method
  if (method == "csv") {
    message("📁 CSV Upload Mode")
    
    if (is.null(file_path)) {
      message("Select CSV file(s) to upload...")
      file_path <- file.choose()
      
      # Allow multiple file selection in interactive mode
      if (method == "interactive") {
        more_files <- TRUE
        all_files <- file_path
        
        while (more_files) {
          answer <- readline(prompt = "Upload another CSV file? (y/n): ")
          if (tolower(answer) %in% c("y", "yes")) {
            additional_file <- file.choose()
            all_files <- c(all_files, additional_file)
          } else {
            more_files <- FALSE
          }
        }
        file_path <- all_files
      }
    }
    
    # Copy files to destination
    for (f in file_path) {
      if (file.exists(f)) {
        dest_file <- file.path(destination, basename(f))
        file.copy(f, dest_file, overwrite = TRUE)
        results$files_processed <- c(results$files_processed, dest_file)
        message("✓ Uploaded: ", basename(f))
      } else {
        warning("File not found: ", f)
      }
    }
    
    results$success <- length(results$files_processed) > 0
    results$message <- paste("Uploaded", length(results$files_processed), "CSV files")
  }
  
  # PDF extraction method
  if (method == "pdf") {
    message("📄 PDF Extraction Mode")
    
    # Available test types
    available_tests <- c(
      "wisc5", "wais5", "wiat4", "caars2", "rbans", "wrat5",
      "basc3", "conners4", "cefi", "dkefs", "cvlt3", "nab"
    )
    
    # Get test type if not provided
    if (is.null(test_type)) {
      cat("\nAvailable test types:\n")
      for (i in seq_along(available_tests)) {
        cat(sprintf("%d. %s\n", i, available_tests[i]))
      }
      
      choice <- as.integer(readline(prompt = "Enter test type number: "))
      if (choice >= 1 && choice <= length(available_tests)) {
        test_type <- available_tests[choice]
      } else {
        stop("Invalid test type choice")
      }
    }
    
    # Check if template exists
    template_file <- file.path(
      "inst/rmarkdown/templates/pluck_pdfs/skeleton",
      paste0("pluck_", test_type, ".Rmd")
    )
    
    if (!file.exists(template_file)) {
      stop("Template not found for test type: ", test_type, 
           "\nAvailable types: ", paste(available_tests, collapse = ", "))
    }
    
    # Create extraction parameters
    if (is.null(patient_name)) {
      patient_name <- readline(prompt = "Enter patient name: ")
    }
    
    # Get PDF file if not provided
    if (is.null(file_path)) {
      message("Select PDF file to extract data from...")
      file_path <- file.choose()
    }
    
    # Run extraction using the template
    tryCatch({
      # This would ideally call the extraction function directly
      # For now, provide instructions
      message("📄 To extract data from PDF:")
      message("1. Open template: ", template_file)
      message("2. Update patient name to: ", patient_name)
      message("3. Run/knit the template")
      message("4. Select PDF file: ", file_path)
      
      results$success <- TRUE
      results$message <- paste("PDF extraction template ready for:", test_type)
      
    }, error = function(e) {
      results$success <- FALSE
      results$message <- paste("PDF extraction failed:", e$message)
      warning("PDF extraction failed: ", e$message)
    })
  }
  
  # Run workflow if requested
  if (run_workflow && results$success) {
    message("\n🚀 Running neuro2 workflow...")
    
    tryCatch({
      # Check if workflow script exists
      workflow_script <- "unified_neuropsych_workflow.sh"
      if (file.exists(workflow_script)) {
        system(paste(workflow_script, shQuote(patient_name)))
        message("✅ Workflow completed!")
      } else {
        message("⚠️ Workflow script not found. Please run manually:")
        message("   ./unified_neuropsych_workflow.sh \"", patient_name, "\"")
      }
    }, error = function(e) {
      warning("Workflow execution failed: ", e$message)
    })
  }
  
  # Summary
  cat("\n📊 Upload Summary\n")
  cat("=================\n")
  cat("Method:", results$method, "\n")
  cat("Patient:", results$patient_name, "\n")
  cat("Files processed:", length(results$files_processed), "\n")
  cat("Status:", if(results$success) "✅ Success" else "❌ Failed", "\n")
  cat("Message:", results$message, "\n")
  
  if (results$success && !run_workflow) {
    cat("\n💡 Next Steps:\n")
    cat("Run the workflow with: ./unified_neuropsych_workflow.sh \"", 
        patient_name, "\"\n")
  }
  
  invisible(results)
}

#' Quick file upload with sensible defaults
#'
#' Simplified wrapper around upload_files() for common use cases
#'
#' @param patient_name Character string with patient name
#' @param ... Additional arguments passed to upload_files()
#'
#' @examples
#' \dontrun{
#' # Quick interactive upload
#' quick_upload("John Doe")
#' }
#'
#' @export
quick_upload <- function(patient_name, ...) {
  upload_files(
    method = "interactive",
    patient_name = patient_name,
    ...
  )
}

#' List available PDF extraction templates
#'
#' @return Character vector of available test types for PDF extraction
#' @export
list_pdf_templates <- function() {
  template_dir <- "inst/rmarkdown/templates/pluck_pdfs/skeleton"
  
  if (!dir.exists(template_dir)) {
    message("Template directory not found: ", template_dir)
    return(character(0))
  }
  
  templates <- list.files(template_dir, pattern = "^pluck_.*\\.Rmd$")
  test_types <- gsub("^pluck_(.*)\\.Rmd$", "\\1", templates)
  
  cat("📄 Available PDF extraction templates:\n")
  cat("=====================================\n")
  for (i in seq_along(test_types)) {
    cat(sprintf("%2d. %-15s (%s)\n", i, test_types[i], templates[i]))
  }
  
  invisible(test_types)
}

#' Check file upload requirements
#'
#' Validates the current setup for file uploads
#'
#' @return List with validation results
#' @export
check_upload_requirements <- function() {
  requirements <- list(
    directories = list(),
    files = list(),
    packages = list(),
    overall = TRUE
  )
  
  pkg_root <- dirname(system.file(package = "neuro2"))

  dir_exists <- function(path) {
    dir.exists(path) || dir.exists(file.path(pkg_root, path))
  }

  resolve_file_path <- function(path) {
    if (file.exists(path)) {
      return(normalizePath(path, winslash = "/", mustWork = TRUE))
    }
    pkg_path <- file.path(pkg_root, path)
    if (file.exists(pkg_path)) {
      return(normalizePath(pkg_path, winslash = "/", mustWork = TRUE))
    }
    NA_character_
  }
  
  # Check directories
  required_dirs <- c("data-raw/csv", "data", "inst/rmarkdown/templates/pluck_pdfs/skeleton")
  
  for (dir in required_dirs) {
    exists <- dir_exists(dir)
    requirements$directories[[dir]] <- exists
    if (!exists && dir != "inst/rmarkdown/templates/pluck_pdfs/skeleton") {
      requirements$overall <- FALSE
    }
  }
  
  # Check key files
  required_files <- list(
    workflow_shell = list(
      description = "Workflow shell script",
      candidates = c(
        "unified_neuropsych_workflow.sh",
        "run_neuropsych_workflow.sh",
        "run_workflow.sh"
      )
    ),
    workflow_runner = list(
      description = "Workflow runner script",
      candidates = c(
        "unified_workflow_runner.R",
        "main_workflow_runner.R",
        "complete_neuropsych_workflow_fixed.R",
        "complete_neuropsych_workflow.R",
        "inst/scripts/main_workflow_runner.R"
      )
    )
  )

  for (key in names(required_files)) {
    entry <- required_files[[key]]
    resolved <- lapply(entry$candidates, resolve_file_path)
    found_index <- which(!is.na(unlist(resolved)))[1]
    found <- !is.na(found_index)
    found_path <- if (found) resolved[[found_index]] else NA_character_

    requirements$files[[key]] <- list(
      description = entry$description,
      candidates = entry$candidates,
      found = found,
      path = found_path
    )

    if (!found) {
      requirements$overall <- FALSE
    }
  }
  
  # Check packages
  required_packages <- c("tabulapdf", "duckdb", "readr", "dplyr")
  
  for (pkg in required_packages) {
    available <- requireNamespace(pkg, quietly = TRUE)
    requirements$packages[[pkg]] <- available
    if (!available) {
      requirements$overall <- FALSE
    }
  }
  
  # Print results
  cat("🔍 Upload Requirements Check\n")
  cat("============================\n\n")
  
  cat("📁 Directories:\n")
  for (dir in names(requirements$directories)) {
    status <- if(requirements$directories[[dir]]) "✅" else "❌"
    cat("  ", status, dir, "\n")
  }
  
  cat("\n📄 Files:\n")
  for (file_info in requirements$files) {
    status <- if (file_info$found) "✅" else "❌"
    target <- if (file_info$found) {
      basename(file_info$path)
    } else {
      paste(file_info$candidates, collapse = " | ")
    }
    cat("  ", status, " ", file_info$description, ": ", target, "\n", sep = "")
  }
  
  cat("\n📦 Packages:\n")
  for (pkg in names(requirements$packages)) {
    status <- if(requirements$packages[[pkg]]) "✅" else "❌"
    cat("  ", status, pkg, "\n")
  }
  
  cat("\n🎯 Overall Status:", if(requirements$overall) "✅ Ready" else "❌ Setup needed", "\n")
  
  if (!requirements$overall) {
    cat("\n💡 Setup Commands:\n")
    
    # Missing directories
    missing_dirs <- names(requirements$directories)[!unlist(requirements$directories)]
    if (length(missing_dirs) > 0) {
      cat("# Create directories:\n")
      for (dir in missing_dirs) {
        cat("mkdir -p", dir, "\n")
      }
    }
    
    # Missing packages
    missing_pkgs <- names(requirements$packages)[!unlist(requirements$packages)]
    if (length(missing_pkgs) > 0) {
      cat("# Install packages:\n")
      cat("install.packages(c(", paste(sprintf('"%s"', missing_pkgs), collapse = ", "), "))\n")
    }
  }
  
  invisible(requirements)
}
