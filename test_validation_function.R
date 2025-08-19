# File: test_validation.R
# Test script to verify the validation function works

#' Test the validate_and_load_data function
#' @param data_dir Directory to test (default: "data")
test_validation_function <- function(data_dir = "data") {
  
  message("🧪 Testing validate_and_load_data function...")
  
  # Test 1: Check if function exists
  if (!exists("validate_and_load_data")) {
    message("❌ Function validate_and_load_data not found")
    message("   Run: source('R/data_validation.R')")
    return(FALSE)
  }
  
  message("✅ Function exists")
  
  # Test 2: Check if data directory exists
  if (!dir.exists(data_dir)) {
    message("❌ Data directory not found: ", data_dir)
    message("   Create directory and add your CSV files")
    return(FALSE)
  }
  
  message("✅ Data directory exists: ", data_dir)
  
  # Test 3: List available files
  files <- list.files(data_dir, pattern = "\\.(csv|parquet|feather)$")
  if (length(files) == 0) {
    message("❌ No data files found in ", data_dir)
    message("   Add your neurocog.csv and neurobehav.csv files")
    return(FALSE)
  }
  
  message("✅ Found files: ", paste(files, collapse = ", "))
  
  # Test 4: Try to load data
  tryCatch({
    data_files <- validate_and_load_data(data_dir = data_dir, verbose = TRUE)
    
    message("✅ Data loading successful!")
    message("   Loaded ", length(data_files), " data files")
    
    # Test 5: Check domains
    domains <- get_available_domains(data_files, verbose = TRUE)
    message("✅ Found ", length(domains), " unique domains")
    
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Data loading failed: ", e$message)
    return(FALSE)
  })
}

# Quick diagnostic function
diagnose_data_issues <- function(data_dir = "data") {
  
  message("🔍 Diagnosing data issues in: ", data_dir)
  
  if (!dir.exists(data_dir)) {
    message("❌ Directory missing: ", data_dir)
    return()
  }
  
  files <- list.files(data_dir, full.names = TRUE)
  
  for (file in files) {
    message("\n📄 Checking: ", basename(file))
    
    # Check file type
    ext <- tools::file_ext(file)
    if (!ext %in% c("csv", "parquet", "feather")) {
      message("  ⚠️  Unsupported format: ", ext)
      next
    }
    
    # Try to load
    tryCatch({
      if (ext == "csv") {
        data <- readr::read_csv(file, show_col_types = FALSE, n_max = 5)
      } else {
        message("  ℹ️  Skipping ", ext, " file (need arrow package)")
        next
      }
      
      message("  ✅ Loads successfully (", nrow(data), " rows)")
      message("  📋 Columns: ", paste(names(data), collapse = ", "))
      
      # Check for required columns
      required <- c("test_name", "scale", "score", "percentile", "domain")
      missing <- setdiff(required, names(data))
      
      if (length(missing) > 0) {
        message("  ❌ Missing columns: ", paste(missing, collapse = ", "))
      } else {
        message("  ✅ Has all required columns")
      }
      
      # Check domains
      if ("domain" %in% names(data)) {
        domains <- unique(data$domain[!is.na(data$domain)])
        if (length(domains) > 0) {
          message("  🧠 Domains: ", paste(head(domains, 3), collapse = ", "),
                  if (length(domains) > 3) "..." else "")
        }
      }
      
    }, error = function(e) {
      message("  ❌ Failed to load: ", e$message)
    })
  }
}

# Run tests if script is called directly
if (!interactive()) {
  # Source the validation functions first
  if (file.exists("R/data_validation.R")) {
    source("R/data_validation.R")
  }
  
  # Run tests
  cat("🧪 Running validation tests...\n\n")
  success <- test_validation_function()
  
  if (!success) {
    cat("\n🔧 Running diagnostics...\n")
    diagnose_data_issues()
  }
  
  cat("\n", if (success) "✅ All tests passed!" else "❌ Tests failed - see diagnostics above", "\n")
}