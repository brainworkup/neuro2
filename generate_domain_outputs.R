#!/usr/bin/env Rscript

# This script processes domain .qmd files and creates clean versions
# with only the output content (no R code blocks)

# Ensure warnings are not converted to errors
old_warn <- getOption("warn")
options(warn = 1)  # Print warnings as they occur but don't convert to errors

library(knitr)
library(here)

# Load internal data to get plot titles
sysdata_path <- here::here("R", "sysdata.rda")
if (file.exists(sysdata_path)) {
  load(sysdata_path)
}

# List of domain files to process
domain_files <- c(
  "_02-01_iq.qmd",
  "_02-02_academics.qmd",
  "_02-03_verbal.qmd",
  "_02-04_spatial.qmd",
  "_02-05_memory.qmd",
  "_02-06_executive.qmd",
  "_02-07_motor.qmd",
  "_02-08_social.qmd",
  "_02-09_adhd_adult.qmd",
  "_02-09_adhd_child.qmd",
  "_02-10_emotion_adult.qmd",
  "_02-10_emotion_child.qmd",
  "_02-11_adaptive.qmd",
  "_02-12_daily_living.qmd"
)

# Process each domain file that exists
for (file in domain_files) {
  if (file.exists(file)) {
    cat("Processing", file, "...\n")
    
    # Create output filename
    output_file <- gsub("\\.qmd$", "_output.qmd", file)
    
    # Read the original file
    lines <- readLines(file)
    
    # Extract domain name from filename for plot title lookup
    # Files are named like _02-01_iq.qmd, _02-10_emotion_child.qmd
    domain_name <- gsub("^_02-[0-9]+_", "", gsub("\\.qmd$", "", file))
    
    # Get the plot title for this domain if it exists
    plot_title_var <- paste0("plot_title_", domain_name)
    
    # Check if the variable exists in the loaded sysdata
    if (exists(plot_title_var)) {
      plot_title <- get(plot_title_var)
      cat("  Using plot title for", domain_name, "from sysdata.rda\n")
    } else {
      # Default fallback text
      plot_title <- paste0("Test results for the ", domain_name, " domain.")
      cat("  No plot title found for", domain_name, "- using default\n")
    }
    
    # Find R code chunks and preserve Typst blocks with their markers
    in_r_chunk <- FALSE
    in_typst_block <- FALSE
    output_lines <- character()
    
    i <- 1
    while (i <= length(lines)) {
      line <- lines[i]
      
      # Check for R chunk start
      if (grepl("^```\\{r", line)) {
        in_r_chunk <- TRUE
        # Skip R chunks entirely
      }
      # Check for R chunk end
      else if (in_r_chunk && line == "```") {
        in_r_chunk <- FALSE
      }
      # Check for Typst block start
      else if (!in_r_chunk && grepl("^```\\{=typst\\}", line)) {
        in_typst_block <- TRUE
        # IMPORTANT: Include the marker so Quarto knows this is Typst code
        output_lines <- c(output_lines, line)
      }
      # Check for Typst block end
      else if (in_typst_block && line == "```") {
        in_typst_block <- FALSE
        # IMPORTANT: Include the closing marker
        output_lines <- c(output_lines, line)
      }
      # Capture content that's not in R chunks
      else if (!in_r_chunk) {
        # Replace R variable references with actual values
        if (grepl("`\\{r\\} plot_title_", line)) {
          # Replace R variable reference with actual plot title text
          # The reference appears as [`{r} plot_title_domain`], we replace just the inner part
          line <- gsub("`\\{r\\} plot_title_[^`]+`", plot_title, line)
        }
        # Include all non-R-chunk content (both Typst and regular)
        output_lines <- c(output_lines, line)
      }
      
      i <- i + 1
    }
    
    # Write the cleaned output file
    writeLines(output_lines, output_file)
    cat("  Created:", output_file, "\n")
  }
}

cat("Domain output processing complete.\n")

# Restore original warning setting
options(warn = old_warn)