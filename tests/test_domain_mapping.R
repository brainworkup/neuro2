#!/usr/bin/env Rscript

# Test script to verify domain to pheno mapping and file generation

# Function to print colored messages in the console
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

# Print header
print_colored("🧠 TESTING DOMAIN TO PHENO MAPPING", "blue")
print_colored("=================================", "blue")
print_colored("")

# Step 1: Run the workflow
print_colored("Step 1: Running the workflow...", "blue")
system("./run_workflow.R")

# Step 2: Check the generated files
print_colored("Step 2: Checking generated files...", "blue")

# Define the expected files
expected_files <- c(
  "iq.parquet",
  "academics.parquet",
  "verbal.parquet",
  "spatial.parquet",
  "memory.parquet",
  "executive.parquet",
  "motor.parquet",
  "adhd.parquet",
  "emotion.parquet"
)

# Check if each expected file exists
data_dir <- "data"
missing_files <- character()

for (file in expected_files) {
  file_path <- file.path(data_dir, file)
  if (file.exists(file_path)) {
    print_colored(paste0("✓ Found: ", file), "green")
  } else {
    print_colored(paste0("✗ Missing: ", file), "red")
    missing_files <- c(missing_files, file)
  }
}

# Check if any unexpected files exist
all_files <- list.files(data_dir, pattern = "\\.parquet$")
unexpected_files <- setdiff(
  all_files,
  c(
    expected_files,
    "neurocog.parquet",
    "neurobehav.parquet",
    "validity.parquet",
    "neuropsych.parquet"
  )
)

if (length(unexpected_files) > 0) {
  print_colored("Unexpected files found:", "yellow")
  for (file in unexpected_files) {
    print_colored(paste0("! Unexpected: ", file), "yellow")
  }
}

# Step 3: Verify that emotion.parquet contains the combined data
print_colored("Step 3: Verifying emotion.parquet content...", "blue")

# Load the emotion.parquet file
if ("emotion.parquet" %in% all_files) {
  tryCatch(
    {
      emotion_data <- arrow::read_parquet(file.path(
        data_dir,
        "emotion.parquet"
      ))

      # Check if it contains data from the expected domains
      emotion_domains <- c(
        "Substance Use",
        "Psychosocial Problems",
        "Psychiatric Disorders",
        "Personality Disorders",
        "Behavioral/Emotional/Social"
      )

      found_domains <- unique(emotion_data$domain)
      missing_domains <- setdiff(emotion_domains, found_domains)

      if (length(missing_domains) == 0) {
        print_colored(
          "✓ emotion.parquet contains data from all expected domains",
          "green"
        )
      } else {
        print_colored(
          "✗ emotion.parquet is missing data from some domains:",
          "red"
        )
        for (domain in missing_domains) {
          print_colored(paste0("  - ", domain), "red")
        }
      }
    },
    error = function(e) {
      print_colored(paste0("Error reading emotion.parquet: ", e$message), "red")
    }
  )
} else {
  print_colored(
    "Cannot verify emotion.parquet content because the file is missing",
    "red"
  )
}

# Summary
if (length(missing_files) == 0 && length(unexpected_files) == 0) {
  print_colored(
    "✅ All tests passed! The domain to pheno mapping is working correctly.",
    "green"
  )
} else {
  print_colored("❌ Some tests failed. Please check the issues above.", "red")
}
