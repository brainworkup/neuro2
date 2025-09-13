#!/usr/bin/env Rscript

# Diagnostic script to identify system2 and PATH issues

cat("========================================\n")
cat("SYSTEM DIAGNOSTIC FOR NEUROPSYCH WORKFLOW\n")
cat("========================================\n\n")

# 1. Check R version and platform
cat("1. R ENVIRONMENT:\n")
cat("   R Version:", R.version.string, "\n")
cat("   Platform:", R.version$platform, "\n")
cat("   OS:", Sys.info()["sysname"], "\n")
cat("   Machine:", Sys.info()["machine"], "\n")
cat("   R Home:", R.home(), "\n")
cat("\n")

# 2. Check shell environment
cat("2. SHELL ENVIRONMENT:\n")
cat("   Current shell: ", Sys.getenv("SHELL"), "\n")
cat("   PATH: ", Sys.getenv("PATH"), "\n")
cat("\n")

# 3. Check for Rscript
cat("3. RSCRIPT LOCATION:\n")
rscript_which <- Sys.which("Rscript")
cat("   Sys.which('Rscript'):", rscript_which, "\n")

# Try to find Rscript in common locations
possible_locations <- c(
  "/usr/local/bin/Rscript",
  "/usr/bin/Rscript",
  "/opt/homebrew/bin/Rscript",
  file.path(R.home("bin"), "Rscript")
)

cat("   Checking common locations:\n")
for (loc in possible_locations) {
  if (file.exists(loc)) {
    cat("     ✓", loc, "EXISTS\n")
  } else {
    cat("     ✗", loc, "NOT FOUND\n")
  }
}
cat("\n")

# 4. Test system2 with simple command
cat("4. TESTING system2():\n")

# Test 1: Echo command
cat("   Test 1 - echo command: ")
tryCatch({
  result <- system2("echo", args = "hello", stdout = TRUE, stderr = TRUE)
  if (is.null(attr(result, "status")) || attr(result, "status") == 0) {
    cat("✓ SUCCESS (output:", result, ")\n")
  } else {
    cat("✗ FAILED (status:", attr(result, "status"), ")\n")
  }
}, error = function(e) {
  cat("✗ ERROR:", e$message, "\n")
})

# Test 2: Rscript with version
cat("   Test 2 - Rscript --version: ")
tryCatch({
  result <- system2("Rscript", args = "--version", stdout = TRUE, stderr = TRUE)
  if (!is.null(result) && length(result) > 0) {
    cat("✓ SUCCESS\n")
    cat("     Output:", result[1], "\n")
  } else {
    cat("✗ FAILED\n")
  }
}, error = function(e) {
  cat("✗ ERROR:", e$message, "\n")
})

# Test 3: Rscript with full path
cat("   Test 3 - Rscript with full path: ")
rscript_path <- if (nzchar(rscript_which)) {
  rscript_which
} else {
  file.path(R.home("bin"), "Rscript")
}

if (file.exists(rscript_path)) {
  tryCatch({
    result <- system2(rscript_path, args = "--version", stdout = TRUE, stderr = TRUE)
    if (!is.null(result) && length(result) > 0) {
      cat("✓ SUCCESS using", rscript_path, "\n")
    } else {
      cat("✗ FAILED with", rscript_path, "\n")
    }
  }, error = function(e) {
    cat("✗ ERROR:", e$message, "\n")
  })
} else {
  cat("✗ Rscript not found at", rscript_path, "\n")
}
cat("\n")

# 5. Check for required packages
cat("5. REQUIRED PACKAGES:\n")
required_packages <- c("here", "yaml", "arrow", "dplyr", "ggplot2", "gt", "readr")

for (pkg in required_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat("   ✓", pkg, "installed\n")
  } else {
    cat("   ✗", pkg, "NOT installed\n")
  }
}
cat("\n")

# 6. Check for workflow files
cat("6. WORKFLOW FILES:\n")
workflow_files <- c(
  "generate_domain_files.R",
  "complete_neuropsych_workflow_fixed.R",
  "generate_all_domain_assets_fixed.R",
  "inst/scripts/data_processor_module.R"
)

for (file in workflow_files) {
  if (file.exists(file)) {
    cat("   ✓", file, "EXISTS\n")
  } else {
    cat("   ✗", file, "NOT FOUND\n")
  }
}
cat("\n")

# 7. Check data directory
cat("7. DATA FILES:\n")
if (dir.exists("data")) {
  data_files <- list.files("data", pattern = "\\.(csv|parquet)$", full.names = TRUE)
  if (length(data_files) > 0) {
    for (file in data_files) {
      cat("   ✓", basename(file), "\n")
    }
  } else {
    cat("   ⚠️  No CSV or Parquet files in data/\n")
  }
} else {
  cat("   ✗ data/ directory not found\n")
}
cat("\n")

# 8. Test creating and running a temporary script
cat("8. TESTING SCRIPT EXECUTION:\n")
temp_script <- tempfile(fileext = ".R")
writeLines('cat("Hello from temp script\\n")', temp_script)

cat("   Creating temp script:", temp_script, "\n")

# Try different methods
cat("   Method 1 - system2 with 'Rscript': ")
tryCatch({
  result <- system2("Rscript", args = temp_script, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status")) && attr(result, "status") != 0) {
    cat("✗ FAILED (status:", attr(result, "status"), ")\n")
  } else {
    cat("✓ SUCCESS\n")
  }
}, error = function(e) {
  cat("✗ ERROR:", e$message, "\n")
})

cat("   Method 2 - system2 with full path: ")
tryCatch({
  result <- system2(rscript_path, args = temp_script, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status")) && attr(result, "status") != 0) {
    cat("✗ FAILED\n")
  } else {
    cat("✓ SUCCESS\n")
  }
}, error = function(e) {
  cat("✗ ERROR:", e$message, "\n")
})

cat("   Method 3 - source(): ")
tryCatch({
  source(temp_script, local = new.env())
  cat("✓ SUCCESS\n")
}, error = function(e) {
  cat("✗ ERROR:", e$message, "\n")
})

# Clean up
unlink(temp_script)
cat("\n")

# 9. Summary and recommendations
cat("========================================\n")
cat("SUMMARY AND RECOMMENDATIONS:\n")
cat("========================================\n")

# Check if Rscript is accessible
if (!nzchar(rscript_which)) {
  cat("\n⚠️  ISSUE: Rscript not found in PATH\n")
  cat("   SOLUTION: Add R bin directory to PATH or use full path to Rscript\n")
  cat("   R bin directory:", file.path(R.home("bin")), "\n")
  
  if (Sys.getenv("SHELL") == "/usr/local/bin/fish" || 
      Sys.getenv("SHELL") == "/opt/homebrew/bin/fish") {
    cat("\n   For Fish shell, add to ~/.config/fish/config.fish:\n")
    cat("   set -x PATH", file.path(R.home("bin")), "$PATH\n")
  }
}

# Check for missing packages
missing_pkgs <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  cat("\n⚠️  ISSUE: Missing required packages\n")
  cat("   SOLUTION: Install missing packages:\n")
  cat("   install.packages(c(")
  cat(paste0('"', missing_pkgs, '"'), sep = ", ")
  cat("))\n")
}

# Check for workflow files
if (!file.exists("generate_domain_files.R")) {
  cat("\n⚠️  ISSUE: generate_domain_files.R not found\n")
  cat("   SOLUTION: Ensure all workflow scripts are in the current directory\n")
}

cat("\n✅ Diagnostic complete. Address any issues above and re-run the workflow.\n")
