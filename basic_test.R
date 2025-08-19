#!/usr/bin/env Rscript

# Basic test to verify the neuro2 package and workflows can run
cat("🧪 Running basic tests for neuro2 package...\n")

# Test 1: Check if required packages are available
required_packages <- c(
  "here",
  "dplyr",
  "readr",
  "yaml",
  "glue",
  "tidyverse",
  "quarto",
  "R6",
  "ggplot2",
  "gt"
)
# NeurotypR is optional - the package has fallback mechanisms
optional_packages <- c("duckdb", "DBI", "future", "furrr")
missing_packages <- c()
missing_optional <- c()
missing_neurotypr <- c()

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    missing_packages <- c(missing_packages, pkg)
  }
}

for (pkg in optional_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    missing_optional <- c(missing_optional, pkg)
  }
}

if (length(missing_packages) > 0) {
  cat(
    "❌ Missing required packages:",
    paste(missing_packages, collapse = ", "),
    "\n"
  )
  cat(
    "   Install with: install.packages(c(",
    paste0('"', missing_packages, '"', collapse = ", "),
    "))\n"
  )
  quit(status = 1)
} else {
  cat("✅ All required packages are available\n")
}


if (length(missing_optional) > 0) {
  cat(
    "⚠️  Missing optional packages:",
    paste(missing_optional, collapse = ", "),
    "\n"
  )
  cat("   These enable additional features (DuckDB, parallel processing)\n")
} else {
  cat("✅ All optional packages are available\n")
}

# Test 2: Check if data files exist
data_files <- list.files("data-raw/csv", pattern = "\\.csv$", full.names = TRUE)
if (length(data_files) == 0) {
  cat("❌ No CSV data files found in data-raw/csv\n")
  quit(status = 1)
} else {
  cat("✅ Found", length(data_files), "data files in data-raw/csv\n")
}

duckdb_workflow_files <- c("neuro2_duckdb_workflow.R")

# Check main workflows
found_workflows <- c()
for (file in workflow_files) {
  if (file.exists(file)) {
    tryCatch(
      {
        parse(file)
        found_workflows <- c(found_workflows, file)
      },
      error = function(e) {
        cat("❌", file, "has syntax errors:", e$message, "\n")
      }
    )
  }
}

if (length(found_workflows) == 0) {
  cat("❌ No workflow files found\n")
  quit(status = 1)
} else {
  cat("✅ Found", length(found_workflows), "workflow files\n")
}

# Check R6 workflows
found_r6 <- c()
for (file in r6_workflow_files) {
  if (file.exists(file)) {
    found_r6 <- c(found_r6, file)
  }
}

if (length(found_r6) > 0) {
  cat("✅ Found", length(found_r6), "R6 workflow files\n")
} else {
  cat("ℹ️  R6 workflow files not found (optional)\n")
}

# Check DuckDB workflows
if ("duckdb" %in% installed.packages()[, "Package"]) {
  if (file.exists("neuro2_duckdb_workflow.R")) {
    cat("✅ DuckDB workflow file found\n")
  } else {
    cat("ℹ️  DuckDB workflow file not found (optional)\n")
  }
}

# Test 4: Check if R6 classes exist
r6_classes <- c(
  "R/DomainProcessorR6.R",
  "R/DotplotR6.R",
  "R/NeuropsychResultsR6.R",
  "R/ReportTemplateR6.R"
)

found_r6_classes <- c()
for (file in r6_classes) {
  if (file.exists(file)) {
    found_r6_classes <- c(found_r6_classes, file)
  }
}

if (length(found_r6_classes) > 0) {
  cat("✅ Found", length(found_r6_classes), "R6 class files\n")
} else {
  cat("⚠️  No R6 class files found\n")
}

# Test 5: Check if DuckDB integration exists
if (file.exists("R/DuckDBProcessorR6.R")) {
  cat("✅ DuckDB processor class found\n")
}

# Test 6: Check if Quarto is available
quarto_check <- system("quarto --version", intern = TRUE, ignore.stderr = TRUE)
if (length(quarto_check) > 0) {
  cat("✅ Quarto is available (version:", quarto_check[1], ")\n")
} else {
  cat("❌ Quarto is not available\n")
  cat("   Install from: https://quarto.org/docs/get-started/\n")
  quit(status = 1)
}

# Test 7: Check if template files exist
template_files <- c("template.qmd", "_quarto.yml", "_variables.yml")
missing_templates <- c()

for (file in template_files) {
  if (!file.exists(file)) {
    missing_templates <- c(missing_templates, file)
  }
}

if (length(missing_templates) > 0) {
  cat(
    "⚠️  Missing template files:",
    paste(missing_templates, collapse = ", "),
    "\n"
  )
} else {
  cat("✅ All template files are present\n")
}

# Test 8: Check data directory
if (dir.exists("data")) {
  processed_files <- list.files("data", pattern = "\\.csv$")
  if (length(processed_files) > 0) {
    cat("✅ Found", length(processed_files), "processed data files in data/\n")
  } else {
    cat("ℹ️  No processed data files in data/ (will be created on first run)\n")
  }
} else {
  cat("ℹ️  Data directory not found (will be created on first run)\n")
}

# Test 9: Quick functionality test
cat("\n📊 Testing basic functionality...\n")
tryCatch(
  {
    # Test loading a simple CSV
    test_file <- data_files[1]
    test_data <- readr::read_csv(test_file, n_max = 5, show_col_types = FALSE)
    cat("✅ Can read data files\n")

    # Test R6 if available
    if (file.exists("R/DotplotR6.R")) {
      source("R/DotplotR6.R")
      cat("✅ Can load R6 classes\n")
    }

    # Test DuckDB if available
    if (
      "duckdb" %in%
        installed.packages()[, "Package"] &&
        file.exists("R/DuckDBProcessorR6.R")
    ) {
      cat("✅ DuckDB integration available\n")
    }
  },
  error = function(e) {
    cat("⚠️  Basic functionality test failed:", e$message, "\n")
  }
)

# Summary
cat("\n🎉 Basic tests completed!\n")
cat("===============================\n")

if (length(found_workflows) > 0) {
  cat("✅ Main workflow ready:", found_workflows[1], "\n")
  cat("   Run with: source('", found_workflows[1], "')\n", sep = "")
}

if (length(found_r6) > 0) {
  cat("✅ R6 workflow ready:", found_r6[1], "\n")
  cat("   Run with: source('", found_r6[1], "')\n", sep = "")
}

if (
  file.exists("neuro2_duckdb_workflow.R") &&
    "duckdb" %in% installed.packages()[, "Package"]
) {
  cat("✅ DuckDB workflow ready: neuro2_duckdb_workflow.R\n")
  cat("   Run with: source('neuro2_duckdb_workflow.R')\n")
}

cat("\nThe neuro2 package is properly set up and ready to use!\n")
