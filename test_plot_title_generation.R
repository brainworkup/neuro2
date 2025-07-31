# Test script to verify plot title generation

library(here)

# Source the DomainProcessorR6 class
source(here::here("R/DomainProcessorR6.R"))

# Test for verbal domain
cat("=== Testing Plot Title Generation ===\n\n")

processor_verbal <- DomainProcessorR6$new(
  domains = "Verbal/Language",
  pheno = "verbal",
  input_file = "data/neurocog.parquet"
)

# Get the plot title
plot_title <- processor_verbal$get_default_plot_titles()
cat("Verbal domain plot title:\n")
cat(plot_title, "\n\n")

# Test for memory domain
processor_memory <- DomainProcessorR6$new(
  domains = "Memory",
  pheno = "memory",
  input_file = "data/neurocog.parquet"
)

plot_title_memory <- processor_memory$get_default_plot_titles()
cat("Memory domain plot title:\n")
cat(plot_title_memory, "\n\n")

# Test generation of a domain file to see if plot title is embedded correctly
cat("Generating test domain file for verbal...\n")
test_file <- "_test_verbal.qmd"
processor_verbal$generate_domain_qmd(output_file = test_file)

# Read the generated file and check if plot title is embedded
if (file.exists(test_file)) {
  content <- readLines(test_file)
  
  # Look for the plot title in the Typst section
  typst_start <- grep("```\\{=typst\\}", content)
  if (length(typst_start) > 0) {
    # Find where the plot title should be embedded
    caption_lines <- grep("caption: figure.caption", content)
    if (length(caption_lines) > 0) {
      # Check the lines around the caption
      for (i in caption_lines) {
        if (i > 0 && i <= length(content)) {
          cat("\nFound caption at line", i, ":\n")
          cat(content[max(1, i-2):min(length(content), i+2)], sep = "\n")
        }
      }
    }
  }
  
  # Clean up test file
  file.remove(test_file)
  if (file.exists("_test_verbal_text.qmd")) {
    file.remove("_test_verbal_text.qmd")
  }
}

cat("\n=== Test Complete ===\n")