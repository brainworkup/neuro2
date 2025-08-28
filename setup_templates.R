#!/usr/bin/env Rscript

# TEMPLATE SETUP SCRIPT
# This script ensures all required template files are properly copied
# before running the main workflow

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry)
}

# Function to print colored messages in the console
.print_colored <- function(message, color = "blue") {
  colors <- list(
    red = "\033[0;31m",
    green = "\033[0;32m",
    yellow = "\033[1;33m",
    blue = "\033[0;34m",
    reset = "\033[0m"
  )

  cat(paste0(colors[[color]], message, colors$reset, "\n"))
}

# Print header
.print_colored("🔧 TEMPLATE SETUP UTILITY", "blue")
.print_colored("==========================", "blue")
.print_colored("")

# Define essential template files
essential_files <- c("template.qmd", "_quarto.yml", "_variables.yml")

# Define possible template directories
template_dirs <- c(
  "inst/quarto/templates/typst-report",
  system.file("quarto/templates/typst-report", package = "neuro2"),
  "../inst/quarto/templates/typst-report",
  "../../inst/quarto/templates/typst-report"
)

# Find the first valid template directory
template_dir <- NULL
for (dir in template_dirs) {
  if (dir != "" && dir.exists(dir)) {
    template_dir <- dir
    .print_colored(paste0("Found template directory: ", template_dir), "green")
    break
  }
}

if (is.null(template_dir)) {
  .print_colored("Could not find template directory in any location", "red")
  quit(status = 1)
}

# List files in the template directory
.print_colored("Template directory contents:", "blue")
dir_contents <- list.files(template_dir)
for (file in dir_contents) {
  .print_colored(paste0("  - ", file), "blue")
}

# Copy essential files
missing_files <- character()
for (file in essential_files) {
  source_file <- file.path(template_dir, file)

  if (!file.exists(file)) {
    if (file.exists(source_file)) {
      .print_colored(
        paste0("Copying ", file, " from template directory..."),
        "yellow"
      )
      copy_result <- file.copy(source_file, file, overwrite = TRUE)

      if (copy_result) {
        .print_colored(paste0("✓ Successfully copied ", file), "green")
      } else {
        .print_colored(paste0("✗ Failed to copy ", file), "red")
        missing_files <- c(missing_files, file)
      }
    } else {
      .print_colored(paste0("✗ Source file not found: ", source_file), "red")
      missing_files <- c(missing_files, file)
    }
  } else {
    .print_colored(paste0("✓ File already exists: ", file), "green")
  }
}

# Final check
if (length(missing_files) > 0) {
  .print_colored("Some essential files are still missing:", "red")
  for (file in missing_files) {
    .print_colored(paste0("  - ", file), "red")
  }
  .print_colored(
    "Please create these files manually before running the workflow",
    "red"
  )
  quit(status = 1)
} else {
  .print_colored("✅ All essential template files are in place", "green")
  .print_colored("You can now run the main workflow", "green")
  quit(status = 0)
}
