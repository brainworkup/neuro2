# Test script to verify domain file generation names

# Source the required files
source("R/DomainProcessorR6.R")

# Function to test file name generation
test_file_generation <- function() {
  cat("Testing Domain File Generation Names\n")
  cat("=====================================\n\n")
  
  # Expected file names
  expected_files <- c(
    "_02-09_adhd_adult.qmd",
    "_02-09_adhd_adult_text_observer.qmd",
    "_02-09_adhd_adult_text_self.qmd",
    "_02-09_adhd_child.qmd",
    "_02-09_adhd_child_text_parent.qmd",
    "_02-09_adhd_child_text_self.qmd",
    "_02-09_adhd_child_text_teacher.qmd",
    "_02-10_emotion_adult.qmd",
    "_02-10_emotion_adult_text.qmd",
    "_02-10_emotion_child.qmd",
    "_02-10_emotion_child_text_parent.qmd",
    "_02-10_emotion_child_text_self.qmd",
    "_02-10_emotion_child_text_teacher.qmd"
  )
  
  cat("Expected files:\n")
  for (f in expected_files) {
    cat(" -", f, "\n")
  }
  cat("\n")
  
  # Test ADHD Adult
  cat("Testing ADHD Adult domain:\n")
  test_adhd_adult <- list(
    domains = c("Attention/Executive"),
    pheno = "adhd",
    is_child = FALSE,
    expected = c(
      "_02-09_adhd_adult.qmd",
      "_02-09_adhd_adult_text_self.qmd",
      "_02-09_adhd_adult_text_observer.qmd"
    )
  )
  
  # Test ADHD Child
  cat("Testing ADHD Child domain:\n")
  test_adhd_child <- list(
    domains = c("Attention/Executive"),
    pheno = "adhd",
    is_child = TRUE,
    expected = c(
      "_02-09_adhd_child.qmd",
      "_02-09_adhd_child_text_self.qmd",
      "_02-09_adhd_child_text_parent.qmd",
      "_02-09_adhd_child_text_teacher.qmd"
    )
  )
  
  # Test Emotion Adult
  cat("Testing Emotion Adult domain:\n")
  test_emotion_adult <- list(
    domains = c("Emotional/Behavioral/Personality"),
    pheno = "emotion",
    is_child = FALSE,
    expected = c(
      "_02-10_emotion_adult.qmd",
      "_02-10_emotion_adult_text.qmd"
    )
  )
  
  # Test Emotion Child
  cat("Testing Emotion Child domain:\n")
  test_emotion_child <- list(
    domains = c("Behavioral/Emotional/Social"),
    pheno = "emotion",
    is_child = TRUE,
    expected = c(
      "_02-10_emotion_child.qmd",
      "_02-10_emotion_child_text_self.qmd",
      "_02-10_emotion_child_text_parent.qmd",
      "_02-10_emotion_child_text_teacher.qmd"
    )
  )
  
  # Run tests
  tests <- list(
    adhd_adult = test_adhd_adult,
    adhd_child = test_adhd_child,
    emotion_adult = test_emotion_adult,
    emotion_child = test_emotion_child
  )
  
  for (test_name in names(tests)) {
    test <- tests[[test_name]]
    cat("\n", test_name, ":\n", sep = "")
    cat("  Expected files:\n")
    for (f in test$expected) {
      cat("    -", f, "\n")
    }
  }
  
  cat("\n=====================================\n")
  cat("File generation test complete!\n")
  cat("Review the expected file names above to ensure they match the specification.\n")
}

# Run the test
test_file_generation()