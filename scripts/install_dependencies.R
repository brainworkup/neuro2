#!/usr/bin/env Rscript

# This script installs and sets up dependencies required for the report generation

message("Installing and setting up required dependencies...")

# List of required packages
required_packages <- c(
  "webshot2", # Required for saving gt tables as images
  "htmlwidgets", # Required for widget output
  "gt", # For table generation
  "svglite" # For SVG graphics
)

# Install missing packages
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing package: ", pkg)
    install.packages(pkg, quiet = TRUE, force = TRUE)
  } else {
    message("Package already installed: ", pkg)
  }
}

# Setup webshot2
if (!requireNamespace("webshot2", quietly = TRUE)) {
  install.packages("webshot2")
}

# Try to install PhantomJS using different methods
tryCatch(
  {
    # Try to use webshot
    if (requireNamespace("webshot", quietly = TRUE)) {
      message("Installing PhantomJS using webshot package")
      webshot::install_phantomjs(force = TRUE)
    } else {
      # If webshot is not available, try to use webshot2 methods
      message("webshot package not found, using alternative method")
      if (requireNamespace("webshot2", quietly = TRUE)) {
        # Call the specific function that webshot2 uses to set up PhantomJS
        message("Setting up PhantomJS for webshot2")
        # Use system to install Chrome or other browsers that webshot2 can use
        system(
          "which chromium-browser || which chromium || which google-chrome || echo 'No compatible browser found'"
        )
      }
    }
  },
  error = function(e) {
    message("Warning: Error installing PhantomJS: ", e$message)
    message("You may need to install PhantomJS manually.")
  }
)

# Make sure index_scores.xlsx is available in execute directory
# This is needed because some QMD files look for it in data/ and others in execute/
data_xlsx <- file.path("data", "index_scores.xlsx")
execute_xlsx <- file.path("index_scores.xlsx")

# Check if the file exists in data directory
if (file.exists(data_xlsx)) {
  message("Found index_scores.xlsx in data directory")

  # Copy to execute directory (root)
  file.copy(data_xlsx, execute_xlsx, overwrite = TRUE)
  message("Copied index_scores.xlsx to execute directory")
} else {
  message("Warning: index_scores.xlsx not found in data directory")
}

message("Dependencies setup completed")
