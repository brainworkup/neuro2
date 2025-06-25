#!/usr/bin/env Rscript

# This script renders the main template.qmd file to generate the final report
# It's designed to be called from CMake but can also be run standalone

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Default values
template_file <- "template.qmd"
output_dir <- "output"
output_name <- "neuropsych_report.pdf"

# If arguments are provided, use them
if (length(args) >= 1) {
  template_file <- args[1]
}
if (length(args) >= 2) {
  output_dir <- args[2]
}
if (length(args) >= 3) {
  output_name <- args[3]
}

# Load required packages
library(quarto)

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Fully qualified output path
output_path <- file.path(output_dir, output_name)

cat("Rendering report template:", template_file, "\n")
cat("Output will be saved to:", output_path, "\n")

# Attempt to render the template
tryCatch(
  {
    # Create output directory if it doesn't exist
    output_dir_path <- dirname(output_path)
    if (!dir.exists(output_dir_path)) {
      dir.create(output_dir_path, recursive = TRUE)
    }

    # Stay in the original directory for rendering
    original_dir <- getwd()

    # Create an R script that monkey-patches xfun::attr before rendering
    patch_script <- tempfile(fileext = ".R")

    # Use relative path to template file (since we stay in original directory)
    template_rel_path <- template_file

    patch_content <- paste0(
      "options(warn=-1)\n",
      "# Set working directory to source directory\n",
      "setwd('",
      original_dir,
      "')\n",
      "# Monkeypatch xfun::attr to use xfun::attr2 instead\n",
      "if (requireNamespace('xfun', quietly = TRUE)) {\n",
      "  if (exists('attr', envir = asNamespace('xfun'))) {\n",
      "    message('Applying xfun::attr patch')\n",
      "    unlockBinding('attr', asNamespace('xfun'))\n",
      "    assign('attr', xfun::attr2, envir = asNamespace('xfun'))\n",
      "    lockBinding('attr', asNamespace('xfun'))\n",
      "  }\n",
      "}\n",
      "suppressWarnings(quarto::quarto_render('",
      template_rel_path,
      "'))\n",
      "# Move the generated file to the output directory\n",
      "generated_file <- gsub('\\\\.qmd$', '.pdf', '",
      template_rel_path,
      "')\n",
      "if (file.exists(generated_file)) {\n",
      "  file.rename(generated_file, '",
      output_path,
      "')\n",
      "  cat('File moved to:', '",
      output_path,
      "')\n",
      "}\n",
      "options(warn=0)\n"
    )

    writeLines(patch_content, patch_script)

    # Use a system command to execute the patch and render
    cmd <- paste0("Rscript '", patch_script, "'")
    cat("Running patched R script for rendering...\n")

    system_result <- system(cmd)

    # Clean up the temporary script
    if (file.exists(patch_script)) {
      file.remove(patch_script)
    }

    if (system_result == 0) {
      cat("Report successfully rendered to:", output_path, "\n")
    } else {
      stop("quarto render command failed with status: ", system_result)
    }
  },
  error = function(e) {
    cat("Error rendering report:", e$message, "\n")
    # Return non-zero exit code to signal error to CMake
    quit(status = 1)
  }
)

# Create a stamp file to indicate completion
stamp_file <- file.path(output_dir, "report_rendered.stamp")
file.create(stamp_file)
cat("Stamp file created:", stamp_file, "\n")
