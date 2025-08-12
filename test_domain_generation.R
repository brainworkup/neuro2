# Test script for domain generation with scale standardization

library(here)

# Source all required R6 classes
source(here::here("R/DomainProcessorR6.R"))
source(here::here("R/NeuropsychResultsR6.R"))
source(here::here("R/DotplotR6.R"))
source(here::here("R/TableGTR6.R"))

# Test generating a complete domain file
cat("=== Testing Domain Generation ===\n")

# Test 1: Generate memory domain file
cat("\n--- Test 1: Memory Domain ---\n")
processor_memory <- DomainProcessorR6$new(
  domains = "Memory",
  pheno = "memory",
  input_file = "data/neurocog.parquet"
)

# Generate the domain QMD file
output_file <- processor_memory$generate_domain_qmd()
cat("Generated file:", output_file, "\n")

# Check if scales are loaded correctly
scales <- processor_memory$get_scales()
cat("Found", length(scales), "scales for memory domain\n")
if (length(scales) > 0) {
  cat("First 5 scales:", paste(head(scales, 5), collapse = ", "), "\n")
}

# Test 2: Generate emotion domain file (behavioral)
cat("\n--- Test 2: Emotion Domain (Adult) ---\n")
processor_emotion <- DomainProcessorR6$new(
  domains = c(
    "Emotional/Behavioral/Personality",
    "Psychiatric Symptoms",
    "Substance Use",
    "Personality Disorders",
    "Psychosocial Problems"
  ),
  pheno = "emotion_adult",
  input_file = "data/neurobehav.parquet"
)

output_file <- processor_emotion$generate_domain_qmd()
cat("Generated file:", output_file, "\n")

scales_emotion <- processor_emotion$get_scales()
cat("Found", length(scales_emotion), "scales for emotion_adult domain\n")

# Test 3: Check all domain scales exist
cat("\n--- Test 3: Checking All Domain Scales ---\n")
load(here::here("R/sysdata.rda"))

# List all scale datasets
scale_datasets <- ls(pattern = "^scales_")
cat("Available scale datasets:\n")
for (dataset in scale_datasets) {
  scale_count <- length(get(dataset))
  cat(sprintf("  %s: %d scales\n", dataset, scale_count))
}

# Test 4: Verify generate_domain_qmd creates complete files
cat("\n--- Test 4: Verify Complete File Generation ---\n")
test_file <- "_02-05_memory.qmd"
if (file.exists(test_file)) {
  content <- readLines(test_file)

  # Check for key sections
  has_setup <- any(grepl("label: setup-memory", content))
  has_text <- any(grepl("label: text-memory", content))
  has_table <- any(grepl("label: qtbl-memory", content))
  has_figure <- any(grepl("label: fig-memory", content))
  has_typst <- any(grepl("typst", content))

  cat("File completeness check:\n")
  cat("  Setup block:", ifelse(has_setup, "✓", "✗"), "\n")
  cat("  Text block:", ifelse(has_text, "✓", "✗"), "\n")
  cat("  Table block:", ifelse(has_table, "✓", "✗"), "\n")
  cat("  Figure block:", ifelse(has_figure, "✓", "✗"), "\n")
  cat("  Typst layout:", ifelse(has_typst, "✓", "✗"), "\n")

  # Check for scale loading
  has_scale_loading <- any(grepl("scales_memory", content))
  cat("  Dynamic scale loading:", ifelse(has_scale_loading, "✓", "✗"), "\n")
}

# Test 5: Test scale standardization in updated files
cat("\n--- Test 5: Test Scale Standardization ---\n")

# Check ADHD file
adhd_file <- "_02-09_adhd_adult.qmd"
if (file.exists(adhd_file)) {
  content <- readLines(adhd_file)
  has_scale_loading <- any(grepl("scales_adhd_adult", content))
  has_hardcoded <- any(grepl("CAARS ADHD Index", content)) # Look for old hardcoded scale

  cat("ADHD file check:\n")
  cat("  Uses scales_adhd_adult:", ifelse(has_scale_loading, "✓", "✗"), "\n")
  cat(
    "  Has hardcoded scales:",
    ifelse(has_hardcoded, "✗ (bad)", "✓ (good)"),
    "\n"
  )
}

# Check academics file
academics_file <- "_02-02_academics.qmd"
if (file.exists(academics_file)) {
  content <- readLines(academics_file)
  has_scale_loading <- any(grepl("scales_academics", content))
  has_r6_classes <- any(grepl("DomainProcessorR6", content))

  cat("\nAcademics file check:\n")
  cat("  Uses scales_academics:", ifelse(has_scale_loading, "✓", "✗"), "\n")
  cat("  Uses R6 classes:", ifelse(has_r6_classes, "✓", "✗"), "\n")
}

cat("\n=== Test Complete ===\n")
