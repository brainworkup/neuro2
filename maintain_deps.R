#!/usr/bin/env Rscript

# Maintain Dependencies Script for neuro2
# This script installs/updates the core R packages needed for the workflow

cat("📦 Maintaining R package dependencies...\n")

# Core packages needed for the neuro2 workflow
packages <- c(
  'here',
  'glue',
  'yaml',
  'R6',
  'readr',
  'janitor',
  'dplyr',
  'tidyr',
  'ggplot2',
  'stringr',
  'purrr',
  'webshot2',
  'tikzDevice'
)

# Install packages
for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("Installing", pkg, "...\n")
    install.packages(pkg, repos = 'https://cran.rstudio.com/', quiet = TRUE)
  } else {
    cat("✅", pkg, "already installed\n")
  }
}

cat("✅ All core dependencies are available\n")
