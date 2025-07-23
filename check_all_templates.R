#!/usr/bin/env Rscript

# COMPREHENSIVE TEMPLATE CHECKER
# This script checks for all required template files and creates them if missing

# Function to print colored messages
print_colored <- function(message, color = "blue") {
  colors <- list(
    red = "\033[0;31m",
    green = "\033[0;32m",
    yellow = "\033[1;33m",
    blue = "\033[0;34m",
    reset = "\033[0m"
  )

  cat(paste0(colors[[color]], message, colors$reset, "\n"))
}

print_colored("🔍 CHECKING ALL REQUIRED TEMPLATE FILES", "blue")
print_colored("=========================================", "blue")
print_colored("")

# Define the template directory
template_dir <- "inst/quarto/templates/typst-report"

# Check if the template directory exists
if (!dir.exists(template_dir)) {
  print_colored(paste("Template directory not found:", template_dir), "red")
  stop("Template directory not found")
}

# List all files in the template directory
template_files <- list.files(template_dir, full.names = TRUE)
print_colored(
  paste("Found", length(template_files), "files in template directory"),
  "blue"
)

# Define essential template files
essential_files <- c(
  "template.qmd",
  "_quarto.yml",
  "_variables.yml",
  "_00-00_tests.qmd",
  "_01-00_nse_adult.qmd",
  "_02-00_behav_obs.qmd",
  "_03-00_sirf.qmd",
  "_03-00_sirf_text.qmd",
  "_03-01_recs.qmd",
  "_03-02_signature.qmd",
  "_03-03_appendix.qmd",
  "config.yml"
)

# Check each essential file
missing_files <- character()
for (file in essential_files) {
  source_file <- file.path(template_dir, file)

  if (!file.exists(file)) {
    if (file.exists(source_file)) {
      print_colored(
        paste("Copying", file, "from template directory..."),
        "yellow"
      )
      file.copy(source_file, file)
      if (file.exists(file)) {
        print_colored(paste("✓ Successfully copied", file), "green")
      } else {
        print_colored(paste("✗ Failed to copy", file), "red")
        missing_files <- c(missing_files, file)
      }
    } else {
      print_colored(paste("✗ Source file not found:", source_file), "red")
      missing_files <- c(missing_files, file)
    }
  } else {
    print_colored(paste("✓ File already exists:", file), "green")
  }
}

# Create domain files if needed
domain_files <- c(
  "_02-01_iq.qmd",
  "_02-02_academics.qmd",
  "_02-03_verbal.qmd",
  "_02-04_spatial.qmd",
  "_02-05_memory.qmd",
  "_02-06_executive.qmd",
  "_02-07_motor.qmd",
  "_02-09_adhd_adult.qmd"
)

for (file in domain_files) {
  if (!file.exists(file)) {
    print_colored(paste("Creating domain file:", file), "yellow")

    # Create a simple domain template
    content <- paste0(
      "---\n",
      "title: \"",
      gsub("_02-[0-9]+_(.+)\\.qmd", "\\1", file),
      "\"\n",
      "---\n\n",
      "## ",
      gsub("_02-[0-9]+_(.+)\\.qmd", "\\1", file),
      " {#sec-",
      tolower(gsub("_02-[0-9]+_(.+)\\.qmd", "\\1", file)),
      "}\n\n",
      "### Summary\n\n",
      "No assessment data was available for this domain.\n\n"
    )

    # Write the file
    writeLines(content, file)

    if (file.exists(file)) {
      print_colored(paste("✓ Successfully created", file), "green")
    } else {
      print_colored(paste("✗ Failed to create", file), "red")
      missing_files <- c(missing_files, file)
    }
  } else {
    print_colored(paste("✓ Domain file already exists:", file), "green")
  }
}

# Final check
if (length(missing_files) > 0) {
  print_colored("Some essential files are still missing:", "red")
  for (file in missing_files) {
    print_colored(paste("  -", file), "red")
  }
  print_colored(
    "Please create these files manually before running the workflow",
    "red"
  )
  quit(status = 1)
} else {
  print_colored("✅ All essential template files are in place", "green")
  print_colored(
    "You can now run the workflow with: Rscript unified_workflow_runner.R config.yml",
    "green"
  )
  quit(status = 0)
}
