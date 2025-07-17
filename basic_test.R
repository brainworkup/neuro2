#!/usr/bin/env Rscript

# Basic test to verify the workflow can run
cat("🧪 Running basic tests for neuro2 package...\n")

# Test 1: Check if required packages are available
required_packages <- c("here", "dplyr", "readr", "yaml", "glue")
missing_packages <- c()

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    missing_packages <- c(missing_packages, pkg)
  }
}

if (length(missing_packages) > 0) {
  cat("❌ Missing required packages:", paste(missing_packages, collapse = ", "), "\n")
  quit(status = 1)
} else {
  cat("✅ All required packages are available\n")
}

# Test 2: Check if data files exist
data_files <- list.files("data-raw", pattern = "\\.csv$", full.names = TRUE)
if (length(data_files) == 0) {
  cat("❌ No CSV data files found in data-raw/\n")
  quit(status = 1)
} else {
  cat("✅ Found", length(data_files), "data files in data-raw/\n")
}

# Test 3: Check if main workflow file exists and can be parsed
if (file.exists("efficient_workflow_v5.R")) {
  tryCatch({
    parse("efficient_workflow_v5.R")
    cat("✅ Main workflow file syntax is valid\n")
  }, error = function(e) {
    cat("❌ Main workflow file has syntax errors:", e$message, "\n")
    quit(status = 1)
  })
} else {
  cat("❌ Main workflow file not found\n")
  quit(status = 1)
}

# Test 4: Check if Quarto is available
quarto_check <- system("quarto --version", intern = TRUE, ignore.stderr = TRUE)
if (length(quarto_check) > 0) {
  cat("✅ Quarto is available (version:", quarto_check, ")\n")
} else {
  cat("❌ Quarto is not available\n")
  quit(status = 1)
}

# Test 5: Check if template files exist
template_files <- c("template.qmd", "_quarto.yml", "_variables.yml")
missing_templates <- c()

for (file in template_files) {
  if (!file.exists(file)) {
    missing_templates <- c(missing_templates, file)
  }
}

if (length(missing_templates) > 0) {
  cat("⚠️ Missing template files:", paste(missing_templates, collapse = ", "), "\n")
} else {
  cat("✅ All template files are present\n")
}

cat("🎉 Basic tests completed successfully!\n")
cat("The neuro2 package appears to be properly set up.\n")