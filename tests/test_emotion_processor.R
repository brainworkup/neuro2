# Test script for DomainProcessorR6Combo emotion domain processing
# Tests both child and adult emotion domains

library(here)
source(here("R/DomainProcessorR6Combo.R"))
source(here("R/NeuropsychResultsR6.R"))

# Create a test function to process and check results
test_emotion_processing <- function() {
  cat("=== Testing Emotion Domain Processing ===\n\n")

  # Test 1: Child Emotion Domain
  cat("Test 1: Child Emotion Domain (Behavioral/Emotional/Social)\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")

  # Create mock data for testing
  mock_data <- data.frame(
    test = c("BASC-3", "BASC-3", "CBCL", "TRF"),
    test_name = c("BASC-3 PRS", "BASC-3 PRS", "CBCL", "TRF"),
    scale = c(
      "Externalizing",
      "Internalizing",
      "Anxious/Depressed",
      "Attention Problems"
    ),
    raw_score = c(65, 70, 60, 55),
    score = c(65, 70, 60, 55),
    ci_95 = c("60-70", "65-75", "55-65", "50-60"),
    percentile = c(85, 90, 75, 70),
    range = c("At Risk", "Clinically Significant", "Normal", "Normal"),
    domain = rep("Behavioral/Emotional/Social", 4),
    subdomain = c("Behavioral", "Emotional", "Emotional", "Behavioral"),
    narrow = c("Aggression", "Depression", "Anxiety", "Attention"),
    pass = rep(NA, 4),
    verbal = rep(NA, 4),
    timed = rep(NA, 4),
    result = c("At Risk", "Clinically Significant", "Normal", "Normal"),
    z = c(1.04, 1.28, 0.67, 0.52)
  )

  processor_child <- DomainProcessorR6Combo$new(
    domains = c("Behavioral/Emotional/Social"),
    pheno = "emotion",
    input_file = NULL # We'll inject data directly
  )

  # Inject mock data
  processor_child$data <- mock_data

  # Check emotion type detection
  emotion_type_child <- processor_child$detect_emotion_type()
  cat("Detected emotion type:", emotion_type_child, "\n")

  # Check rater types
  rater_types_child <- processor_child$get_rater_types()
  cat("Rater types:", paste(rater_types_child, collapse = ", "), "\n")

  # Check which rater data exists
  cat("\nChecking rater data availability:\n")
  for (rater in rater_types_child) {
    exists <- processor_child$check_rater_data_exists(rater)
    cat(sprintf("  %s data exists: %s\n", rater, exists))
  }

  # Generate QMD content
  cat("\nGenerating child emotion QMD...\n")
  qmd_content_child <- processor_child$generate_domain_qmd()

  # Display first 50 lines of generated content
  cat("\nFirst 50 lines of generated child emotion QMD:\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")
  lines <- strsplit(qmd_content_child, "\n")[[1]]
  cat(paste(head(lines, 50), collapse = "\n"), "\n")

  # Save to file for inspection
  writeLines(qmd_content_child, here("test_output_emotion_child.qmd"))
  cat("\nFull child emotion QMD saved to: test_output_emotion_child.qmd\n")

  cat("\n", paste(rep("=", 50), collapse = ""), "\n\n")

  # Test 2: Adult Emotion Domain
  cat("Test 2: Adult Emotion Domain (Emotional/Behavioral/Personality)\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")

  # Create mock data for adult testing
  mock_data_adult <- data.frame(
    test = c("PAI", "PAI", "PAI", "PAI"),
    test_name = c("PAI", "PAI", "PAI", "PAI"),
    scale = c("ANX", "DEP", "MAN", "SCZ"),
    raw_score = c(65, 70, 60, 55),
    score = c(65, 70, 60, 55),
    ci_95 = c("60-70", "65-75", "55-65", "50-60"),
    percentile = c(85, 90, 75, 70),
    range = c("Elevated", "Clinically Significant", "Normal", "Normal"),
    domain = rep("Emotional/Behavioral/Personality", 4),
    subdomain = c("Anxiety", "Depression", "Mania", "Schizophrenia"),
    narrow = c("Anxiety", "Depression", "Mania", "Thought Disorder"),
    pass = rep(NA, 4),
    verbal = rep(NA, 4),
    timed = rep(NA, 4),
    result = c("Elevated", "Clinically Significant", "Normal", "Normal"),
    z = c(1.04, 1.28, 0.67, 0.52)
  )

  processor_adult <- DomainProcessorR6Combo$new(
    domains = c("Emotional/Behavioral/Personality"),
    pheno = "emotion",
    input_file = NULL # We'll inject data directly
  )

  # Inject mock data
  processor_adult$data <- mock_data_adult

  # Check emotion type detection
  emotion_type_adult <- processor_adult$detect_emotion_type()
  cat("Detected emotion type:", emotion_type_adult, "\n")

  # Check rater types
  rater_types_adult <- processor_adult$get_rater_types()
  cat("Rater types:", paste(rater_types_adult, collapse = ", "), "\n")
  cat("Note: Adult emotion should only have 'self' rater\n")

  # Check which rater data exists
  cat("\nChecking rater data availability:\n")
  for (rater in rater_types_adult) {
    exists <- processor_adult$check_rater_data_exists(rater)
    cat(sprintf("  %s data exists: %s\n", rater, exists))
  }

  # Generate QMD content
  cat("\nGenerating adult emotion QMD...\n")
  qmd_content_adult <- processor_adult$generate_domain_qmd()

  # Display first 50 lines of generated content
  cat("\nFirst 50 lines of generated adult emotion QMD:\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")
  lines <- strsplit(qmd_content_adult, "\n")[[1]]
  cat(paste(head(lines, 50), collapse = "\n"), "\n")

  # Save to file for inspection
  writeLines(qmd_content_adult, here("test_output_emotion_adult.qmd"))
  cat("\nFull adult emotion QMD saved to: test_output_emotion_adult.qmd\n")

  cat("\n", paste(rep("=", 50), collapse = ""), "\n\n")

  # Test 3: Check file naming
  cat("Test 3: File Naming Patterns\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")

  # Child emotion file names
  cat("Child emotion expected files:\n")
  cat("  CSV: emotion_child.csv\n")
  cat("  Scales: scales_emotion_child (from sysdata.rda)\n")
  cat("  Template section: _02-10_emotion_child_{rater}.qmd\n")

  # Adult emotion file names
  cat("\nAdult emotion expected files:\n")
  cat("  CSV: emotion_adult.csv\n")
  cat("  Scales: scales_emotion_adult (from sysdata.rda)\n")
  cat("  Template section: _02-10_emotion_adult_{rater}.qmd\n")

  cat("\n", paste(rep("=", 50), collapse = ""), "\n\n")

  # Test 4: ADHD Domain Raters
  cat("Test 4: ADHD Domain Raters\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")

  # Create a test ADHD processor
  processor_adhd <- DomainProcessorR6Combo$new(
    domains = c("Attention/Executive"),
    pheno = "adhd",
    input_file = NULL
  )

  # Check if ADHD has multiple raters
  has_multiple <- processor_adhd$has_multiple_raters()
  cat("ADHD has multiple raters:", has_multiple, "\n")

  # Check rater types
  rater_types_adhd <- processor_adhd$get_rater_types()
  cat("ADHD rater types:", paste(rater_types_adhd, collapse = ", "), "\n")
  cat("Note: Adult ADHD should have both 'self' and 'observer' raters\n")

  cat("\n", paste(rep("=", 50), collapse = ""), "\n\n")

  # Summary
  cat("Testing Summary:\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")
  cat("✓ Child emotion domain detection:", emotion_type_child == "child", "\n")
  cat(
    "✓ Child rater types correct:",
    identical(rater_types_child, c("self", "parent", "teacher")),
    "\n"
  )
  cat("✓ Adult emotion domain detection:", emotion_type_adult == "adult", "\n")
  cat(
    "✓ Adult emotion rater types correct (self only):",
    identical(rater_types_adult, c("self")),
    "\n"
  )
  cat("✓ ADHD has multiple raters:", has_multiple, "\n")
  cat(
    "✓ ADHD rater types correct (self & observer):",
    identical(rater_types_adhd, c("self", "observer")),
    "\n"
  )
  cat("\nBoth test output files have been generated for manual inspection.\n")
}

# Run the test
test_emotion_processing()

# Clean up test files (uncomment to remove after inspection)
# file.remove(here("test_output_emotion_child.qmd"))
# file.remove(here("test_output_emotion_adult.qmd"))
