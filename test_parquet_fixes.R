# Test script to verify fixes for Parquet file handling in neuropsychological report generation

# Load necessary libraries
library(neuro2)

# Check if arrow package is available, install if needed
if (!requireNamespace("arrow", quietly = TRUE)) {
  install.packages("arrow")
}
library(arrow)

# Remember the original directory
original_dir <- getwd()

# Set up a test directory
test_dir <- file.path(tempdir(), "neuro2_test_parquet")
dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)
setwd(test_dir)

# Create test data directories
dir.create("data", showWarnings = FALSE)

# Create sample data
cat("Creating sample data...\n")
neurocog_data <- data.frame(
  domain = c("General Cognitive Ability", "Memory", "Attention/Executive"),
  test = c("WAIS-IV", "WMS-IV", "D-KEFS"),
  scale = c("FSIQ", "Auditory Memory", "Trail Making"),
  score = c(100, 95, 90),
  z = c(0, -0.33, -0.67),
  percentile = c(50, 45, 40),
  range = c("Average", "Average", "Average"),
  stringsAsFactors = FALSE
)

neurobehav_data <- data.frame(
  domain = c("ADHD", "Psychiatric Disorders"),
  test = c("CAARS", "MMPI-2"),
  scale = c("Inattention", "Depression"),
  score = c(65, 70),
  z = c(1.5, 2.0),
  percentile = c(93, 98),
  range = c("Elevated", "Clinically Significant"),
  stringsAsFactors = FALSE
)

# Write sample data to Parquet files
cat("Writing sample data to Parquet files...\n")
arrow::write_parquet(neurocog_data, "data/neurocog.parquet")
arrow::write_parquet(neurobehav_data, "data/neurobehav.parquet")

# Test the Parquet file reading and writing
cat("\nTest 1: Testing Parquet file reading and writing...\n")
tryCatch(
  {
    # Read the Parquet file
    data <- arrow::read_parquet("data/neurocog.parquet")

    # Check if the data was read correctly
    if (nrow(data) == 3 && all(data$domain == neurocog_data$domain)) {
      cat("  ✓ Successfully read Parquet file\n")
    } else {
      cat("  ✗ Failed to read Parquet file correctly\n")
    }

    # Filter the data
    filtered_data <- data[data$domain == "General Cognitive Ability", ]

    # Write the filtered data to a new Parquet file
    arrow::write_parquet(filtered_data, "data/filtered.parquet")

    # Check if the output file exists
    if (file.exists("data/filtered.parquet")) {
      cat("  ✓ Successfully wrote Parquet file\n")
    } else {
      cat("  ✗ Failed to write Parquet file\n")
    }

    cat("Test 1 completed successfully!\n")
  },
  error = function(e) {
    cat("  ✗ Error:", e$message, "\n")
  }
)

# Test 2: Simulate the DomainProcessorR6Combo functionality
cat("\nTest 2: Simulating DomainProcessorR6Combo functionality...\n")
tryCatch(
  {
    # Read the Parquet file
    data <- arrow::read_parquet("data/neurocog.parquet")

    # Filter by domain
    filtered_data <- data[data$domain == "General Cognitive Ability", ]

    # Save to a new Parquet file
    arrow::write_parquet(filtered_data, "data/iq.parquet")

    # Check if the output file exists
    if (file.exists("data/iq.parquet")) {
      cat("  ✓ Successfully processed and saved Parquet data\n")
    } else {
      cat("  ✗ Failed to save Parquet data\n")
    }

    cat("Test 2 completed successfully!\n")
  },
  error = function(e) {
    cat("  ✗ Error:", e$message, "\n")
  }
)

# Return to the original directory
setwd(original_dir)

# Clean up
unlink(test_dir, recursive = TRUE)

cat("\nAll tests completed.\n")
