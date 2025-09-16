#!/usr/bin/env Rscript

#' Diagnostic script for Quarto rendering issues
#' Run this to identify why the report rendering is failing

cat("\n========================================\n")
cat("QUARTO RENDERING DIAGNOSTICS\n")
cat("========================================\n\n")

# Function to check file existence
check_file <- function(file, required = TRUE) {
  exists <- file.exists(file)
  status <- if (exists) "✅" else if (required) "❌" else "⚠️"
  cat(sprintf("%s %s: %s\n", status, basename(file), 
              if (exists) "Found" else "Missing"))
  return(exists)
}

# Function to run command and capture output
run_command <- function(cmd, args = character()) {
  result <- tryCatch({
    output <- system2(cmd, args, stdout = TRUE, stderr = TRUE)
    list(success = TRUE, output = output)
  }, error = function(e) {
    list(success = FALSE, error = e$message)
  }, warning = function(w) {
    list(success = FALSE, warning = w$message)
  })
  return(result)
}

# 1. Check Quarto installation
cat("1. CHECKING QUARTO INSTALLATION\n")
cat("--------------------------------\n")
quarto_check <- run_command("quarto", "--version")
if (quarto_check$success) {
  cat("✅ Quarto version:", quarto_check$output[1], "\n")
} else {
  cat("❌ Quarto not found or not in PATH\n")
  cat("   Install from: https://quarto.org/docs/get-started/\n")
}

# Check Quarto formats
format_check <- run_command("quarto", c("list", "formats"))
if (format_check$success) {
  cat("✅ Available formats detected\n")
} else {
  cat("⚠️  Could not list Quarto formats\n")
}

# 2. Check required files
cat("\n2. CHECKING REQUIRED FILES\n")
cat("--------------------------------\n")
required_files <- c(
  "template.qmd",
  "_quarto.yml",
  "config.yml",
  "_domains_to_include.qmd"
)

for (file in required_files) {
  check_file(file, required = TRUE)
}

# 3. Check included domain files
cat("\n3. CHECKING DOMAIN FILES\n")
cat("--------------------------------\n")
domain_files <- c(
  "_02-01_iq.qmd",
  "_02-02_academics.qmd",
  "_02-03_verbal.qmd",
  "_02-04_spatial.qmd",
  "_02-05_memory.qmd",
  "_02-06_executive.qmd",
  "_02-07_motor.qmd",
  "_02-10_emotion.qmd"
)

domain_count <- 0
for (file in domain_files) {
  if (check_file(file, required = FALSE)) {
    domain_count <- domain_count + 1
  }
}
cat(sprintf("\nFound %d/%d domain files\n", domain_count, length(domain_files)))

# 4. Check other included files from template
cat("\n4. CHECKING TEMPLATE INCLUDES\n")
cat("--------------------------------\n")
template_includes <- c(
  "_00-00_tests.qmd",
  "_01-00_nse.qmd",
  "_01-01_behav_obs.qmd",
  "_03-00_sirf.qmd",
  "_03-00_sirf_text.qmd",
  "_03-01_recs.qmd",
  "_03-02_signature.qmd",
  "_03-03_appendix.qmd"
)

for (file in template_includes) {
  check_file(file, required = FALSE)
}

# 5. Check pre-render scripts from _quarto.yml
cat("\n5. CHECKING PRE-RENDER SCRIPTS\n")
cat("--------------------------------\n")
prerender_scripts <- c(
  "generate_all_domain_assets.R",
  "generate_domain_files.R"
)

for (script in prerender_scripts) {
  check_file(script, required = FALSE)
}

# 6. Check R packages
cat("\n6. CHECKING R PACKAGES\n")
cat("--------------------------------\n")
required_packages <- c(
  "neuro2", "dplyr", "readr", "here", "yaml",
  "ggplot2", "gt", "gtExtras", "knitr", "quarto"
)

for (pkg in required_packages) {
  installed <- requireNamespace(pkg, quietly = TRUE)
  status <- if (installed) "✅" else "❌"
  cat(sprintf("%s %s\n", status, pkg))
}

# 7. Check directories
cat("\n7. CHECKING DIRECTORIES\n")
cat("--------------------------------\n")
dirs <- c("data", "figs", "output", "inst/resources")
for (dir in dirs) {
  exists <- dir.exists(dir)
  status <- if (exists) "✅" else "⚠️"
  cat(sprintf("%s %s/\n", status, dir))
}

# 8. Check custom Typst format
cat("\n8. CHECKING CUSTOM TYPST FORMAT\n")
cat("--------------------------------\n")
if (file.exists("_quarto.yml")) {
  quarto_config <- yaml::read_yaml("_quarto.yml")
  
  # Check if custom format is defined
  custom_formats <- names(quarto_config$format)
  cat("Custom formats defined:", paste(custom_formats, collapse = ", "), "\n")
  
  if ("neurotyp-pediatric-typst" %in% custom_formats) {
    cat("✅ neurotyp-pediatric-typst format is defined\n")
  } else {
    cat("❌ neurotyp-pediatric-typst format NOT found in _quarto.yml\n")
  }
} else {
  cat("❌ _quarto.yml not found\n")
}

# 9. Try a test render with verbose output
cat("\n9. TEST RENDER (VERBOSE)\n")
cat("--------------------------------\n")
cat("Attempting to render with --verbose flag...\n\n")

# First try with just typst format
test_result <- run_command("quarto", c("render", "template.qmd", 
                                       "--to", "typst",
                                       "--verbose"))

if (test_result$success) {
  cat("✅ Basic Typst render succeeded\n")
} else {
  cat("❌ Basic Typst render failed\n")
  cat("Error output:\n")
  cat(test_result$output, sep = "\n")
}

# 10. Check for data files
cat("\n10. CHECKING DATA FILES\n")
cat("--------------------------------\n")
data_files <- c(
  "data/neurocog.parquet",
  "data/neurocog.csv",
  "data/neurobehav.parquet",
  "data/neurobehav.csv"
)

data_found <- FALSE
for (file in data_files) {
  if (check_file(file, required = FALSE)) {
    data_found <- TRUE
  }
}

if (!data_found) {
  cat("\n⚠️  No data files found - workflow may need to process raw data first\n")
}

# Summary and recommendations
cat("\n========================================\n")
cat("DIAGNOSTIC SUMMARY\n")
cat("========================================\n\n")

issues <- character()

if (!quarto_check$success) {
  issues <- c(issues, "Quarto is not installed or not in PATH")
}

if (!all(sapply(required_files, file.exists))) {
  issues <- c(issues, "Some required files are missing")
}

if (domain_count == 0) {
  issues <- c(issues, "No domain QMD files found - run domain generation first")
}

if (!data_found) {
  issues <- c(issues, "No processed data files found")
}

if (!file.exists("_quarto.yml")) {
  issues <- c(issues, "_quarto.yml configuration is missing")
}

if (length(issues) > 0) {
  cat("ISSUES FOUND:\n")
  for (i in seq_along(issues)) {
    cat(sprintf("  %d. %s\n", i, issues[i]))
  }
  
  cat("\nRECOMMENDATIONS:\n")
  cat("1. Ensure all domain files are generated before rendering\n")
  cat("2. Check that data processing completed successfully\n")
  cat("3. Verify _quarto.yml has the correct format definitions\n")
  cat("4. Try rendering with basic typst format first:\n")
  cat("   quarto render template.qmd --to typst\n")
  cat("5. Check the workflow log for more details\n")
} else {
  cat("✅ No obvious issues found\n")
  cat("Try running: quarto render template.qmd --to typst --verbose\n")
  cat("to see detailed error messages\n")
}

cat("\n")
