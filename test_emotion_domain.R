# Test script for emotion domain with multiple raters
library(here)

# Source the updated R6 class
source("R/DomainProcessorR6.R")

# Create processor for emotion domain
processor <- DomainProcessorR6$new(
  domains = c("Personality Disorders"),
  pheno = "emotion",
  input_file = "data/neurobehav.parquet"
)

# Check if it has multiple raters
cat("Has multiple raters:", processor$has_multiple_raters(), "\n")
cat("Rater types:", paste(processor$get_rater_types(), collapse = ", "), "\n")

# Generate the emotion child QMD file
output_file <- processor$generate_domain_qmd(
  domain_name = "Behavioral/Emotional/Social",
  output_file = NULL,
  is_child = TRUE
)

cat("Generated file:", output_file, "\n")

# Check if the file was created
if (file.exists(output_file)) {
  cat("File successfully created!\n")
  
  # Display first 50 lines to verify structure
  content <- readLines(output_file, n = 50)
  cat("\nFirst 50 lines of generated file:\n")
  cat(paste(content, collapse = "\n"))
} else {
  cat("Error: File was not created\n")
}