#!/usr/bin/env Rscript

# Script to install all dependencies for neuro2 package
# This installs ALL packages listed in the DESCRIPTION file

cat("Installing all dependencies for neuro2 package...\n")
cat("==============================================\n\n")

# Complete list of dependencies from DESCRIPTION file
all_packages <- c(
  # Data manipulation and analysis
  "arrow",
  "DBI",
  "dplyr",
  "duckdb",
  "tibble",
  "tidyr",
  "tidyselect",
  "purrr",
  "readr",
  "readxl",
  "janitor",

  # Visualization and tables
  "ggplot2",
  "ggtext",
  "ggthemes",
  "gt",
  "gtExtras",
  "highcharter",
  "kableExtra",

  # Utilities
  "cli",
  "fs",
  "glue",
  "here",
  "progress",
  "yaml",

  # Development tools
  "knitr",
  "quarto",
  "R6",
  "rlang",
  "stringr",
  "usethis",
  "xfun",

  # Parallel processing
  "future",
  "future.apply",

  # Other specialized
  "memoise",
  "tabulapdf",
  "webshot2",

  # Core R packages (usually pre-installed)
  "stats",
  "tools",
  "utils"
)

# Additional dependencies not in main list but needed
additional_packages <- c(
  "AsioHeaders", # Required by websocket
  "websocket", # Required by webshot2
  "chromote" # Required by webshot2
)

all_packages <- c(all_packages, additional_packages)

# Function to install a package if not already installed
install_if_needed <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("Installing", pkg, "...\n")
    tryCatch(
      {
        install.packages(pkg)
        cat("   ✓", pkg, "installed\n")
        return(TRUE)
      },
      error = function(e) {
        cat("   ✗ Failed to install", pkg, ":", e$message, "\n")
        return(FALSE)
      }
    )
  } else {
    cat("   ✓", pkg, "already installed\n")
    return(TRUE)
  }
}

# Install packages in logical groups
cat("\n1. Installing core dependencies...\n")
core_packages <- c("rlang", "cli", "glue", "R6", "fs", "here")
sapply(core_packages, install_if_needed)

cat("\n2. Installing data manipulation packages...\n")
data_packages <- c(
  "dplyr",
  "tidyr",
  "tidyselect",
  "purrr",
  "tibble",
  "janitor",
  "readr",
  "readxl"
)
sapply(data_packages, install_if_needed)

cat("\n3. Installing database packages...\n")
db_packages <- c("DBI", "duckdb", "arrow")
sapply(db_packages, install_if_needed)

cat("\n4. Installing visualization packages...\n")
viz_packages <- c(
  "ggplot2",
  "ggtext",
  "ggthemes",
  "gt",
  "gtExtras",
  "highcharter",
  "kableExtra"
)
sapply(viz_packages, install_if_needed)

cat("\n5. Installing document generation packages...\n")
doc_packages <- c("knitr", "xfun", "yaml", "stringr")
sapply(doc_packages, install_if_needed)

cat("\n6. Installing webshot dependencies...\n")
webshot_deps <- c("AsioHeaders", "websocket", "chromote", "webshot2")
sapply(webshot_deps, install_if_needed)

cat("\n7. Installing remaining packages...\n")
remaining <- setdiff(
  all_packages,
  c(
    core_packages,
    data_packages,
    db_packages,
    viz_packages,
    doc_packages,
    webshot_deps
  )
)
# Remove base R packages that don't need installation
remaining <- setdiff(remaining, c("stats", "tools", "utils"))
sapply(remaining, install_if_needed)

# Verify all packages
cat("\n8. Verifying all installations...\n")
cat("==================================\n")
failed_packages <- character()

for (pkg in setdiff(all_packages, c("stats", "tools", "utils"))) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("   ✗", pkg, "- FAILED\n")
    failed_packages <- c(failed_packages, pkg)
  }
}

if (length(failed_packages) == 0) {
  cat("\n✓ All", length(all_packages), "dependencies installed successfully!\n")

  # Check for Quarto
  cat("\n9. Checking Quarto installation...\n")
  quarto_check <- system2("quarto", "--version", stdout = TRUE, stderr = TRUE)
  if (
    !is.null(attr(quarto_check, "status")) && attr(quarto_check, "status") != 0
  ) {
    cat(
      "   ⚠ Quarto CLI not found. Please install from: https://quarto.org/docs/get-started/\n"
    )
  } else {
    cat("   ✓ Quarto version:", quarto_check, "\n")
  }

  cat("\nNext steps:\n")
  cat("  1. Run: renv::snapshot(prompt = FALSE) to update renv.lock\n")
  cat("  2. Test the workflow: source('test_data_processing.R')\n")
  cat("  3. Generate a report: source('neuro2_r6_update_workflow.R')\n")
} else {
  cat("\n✗", length(failed_packages), "packages failed to install:\n")
  cat("  ", paste(failed_packages, collapse = ", "), "\n")
  cat("\nTry installing failed packages manually with:\n")
  cat(
    "  install.packages(c('",
    paste(failed_packages, collapse = "', '"),
    "'))\n"
  )
}

# Additional notes
cat("\n==============================================\n")
cat("Notes:\n")
cat("  • webshot2 requires Chrome or Chromium browser\n")
cat("  • tabulapdf requires Java for PDF table extraction\n")
cat("  • Some packages may require system libraries:\n")
cat("    - arrow: may need C++ compiler\n")
cat("    - duckdb: may need cmake\n")
cat("==============================================\n")

# Helper function to load all required packages for template
create_load_packages_function <- function() {
  cat("\n# Creating helper function for loading packages...\n")

  func_text <- '
#\' Load all required packages for neuropsych reports
#\'
#\' This function loads the minimal set of packages needed for
#\' report generation. Most data processing is handled by R6 classes.
#\'
#\' @param verbose Whether to print loading messages
#\' @return Invisible NULL
#\' @export
load_neuropsych_packages <- function(verbose = TRUE) {
  # Minimal packages needed for templates
  required_packages <- c(
    "knitr",     # For knitr options
    "here",      # For path management
    "readr",     # For reading CSV if needed
    "dplyr",     # For data manipulation
    "gt"         # For tables
  )
  
  # Load packages
  for (pkg in required_packages) {
    if (verbose) message("Loading ", pkg, "...")
    library(pkg, character.only = TRUE)
  }
  
  if (verbose) message("All packages loaded successfully!")
  invisible(NULL)
}
'

  # Write to R directory
  writeLines(func_text, "R/load_packages.R")
  cat("   ✓ Created R/load_packages.R\n")
}

# Create the helper function
create_load_packages_function()
