#!/usr/bin/env Rscript

# Script to install all dependencies for the updated workflow

cat("Installing dependencies for neuro2 package...\n")
cat("============================================\n\n")

# Install missing system dependencies first
cat("1. Installing AsioHeaders (required by websocket)...\n")
if (!requireNamespace("AsioHeaders", quietly = TRUE)) {
  install.packages("AsioHeaders")
  cat("   ✓ AsioHeaders installed\n")
} else {
  cat("   ✓ AsioHeaders already installed\n")
}

# Install websocket (required by webshot2)
cat("\n2. Installing websocket...\n")
if (!requireNamespace("websocket", quietly = TRUE)) {
  install.packages("websocket")
  cat("   ✓ websocket installed\n")
} else {
  cat("   ✓ websocket already installed\n")
}

# Install arrow for parquet support
cat("\n3. Installing arrow for parquet support...\n")
if (!requireNamespace("arrow", quietly = TRUE)) {
  install.packages("arrow")
  cat("   ✓ arrow installed\n")
} else {
  cat("   ✓ arrow already installed\n")
}

# Install webshot2 for gt table image export
cat("\n4. Installing webshot2 for table image export...\n")
if (!requireNamespace("webshot2", quietly = TRUE)) {
  install.packages("webshot2")
  cat("   ✓ webshot2 installed\n")
} else {
  cat("   ✓ webshot2 already installed\n")
}

# Install chromote (webshot2 dependency)
cat("\n5. Installing chromote (webshot2 dependency)...\n")
if (!requireNamespace("chromote", quietly = TRUE)) {
  install.packages("chromote")
  cat("   ✓ chromote installed\n")
} else {
  cat("   ✓ chromote already installed\n")
}

# Check if all packages load correctly
cat("\n6. Verifying installations...\n")
packages_to_check <- c(
  "AsioHeaders",
  "websocket",
  "arrow",
  "webshot2",
  "chromote"
)
all_ok <- TRUE

for (pkg in packages_to_check) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat("   ✓", pkg, "loads correctly\n")
  } else {
    cat("   ✗", pkg, "failed to load\n")
    all_ok <- FALSE
  }
}

if (all_ok) {
  cat("\n✓ All dependencies installed successfully!\n")
  cat("\nYou can now run:\n")
  cat("  renv::snapshot(prompt = FALSE)\n")
  cat("\nOr test the workflow:\n")
  cat("  source('test_domain_workflow_parquet.R')\n")
} else {
  cat("\n✗ Some packages failed to install.\n")
  cat("Please check the error messages above.\n")
}

# Additional note about Chrome/Chromium
cat("\n============================================\n")
cat("Note: webshot2 requires Chrome or Chromium browser.\n")
cat("If you encounter issues with screenshots:\n")
cat("  - On macOS: Chrome should work automatically\n")
cat("  - You may need to install Chrome if not present\n")
cat("============================================\n")
