#!/usr/bin/env Rscript

# Check test_type distribution in the data

library(dplyr)
library(readr)

cat("Checking test_type distribution in raw CSV files...\n")
cat("==================================================\n\n")

# Read all CSV files
csv_files <- list.files("data-raw/csv", pattern = "\\.csv$", full.names = TRUE)
all_data <- list()

for (i in seq_along(csv_files)) {
  file <- csv_files[i]
  df <- read_csv(file, show_col_types = FALSE)
  df$source_file <- basename(file)
  all_data[[i]] <- df
  cat("Read", basename(file), "-", nrow(df), "rows\n")
}

# Combine all data
combined <- bind_rows(all_data)
cat("\nTotal combined rows:", nrow(combined), "\n\n")

# Check test_type column
if ("test_type" %in% names(combined)) {
  cat("test_type distribution:\n")
  test_type_counts <- combined %>% count(test_type, sort = TRUE)
  print(test_type_counts)

  cat("\ntest_type by source file:\n")
  file_test_types <- combined %>% count(source_file, test_type, sort = TRUE)
  print(file_test_types)
} else {
  cat("ERROR: No test_type column found!\n")
  cat("Available columns:", paste(names(combined), collapse = ", "), "\n")
}

# Check domain column
cat("\n\ndomain distribution:\n")
if ("domain" %in% names(combined)) {
  domain_counts <- combined %>%
    count(domain, sort = TRUE) %>%
    filter(!is.na(domain))
  print(domain_counts, n = 20)
} else {
  cat("No domain column found\n")
}

# Check what would go into each file based on test_type
cat("\n\nExpected file distribution:\n")
cat("- neurocog.csv: test_type = 'npsych_test'\n")
cat("- neurobehav.csv: test_type = 'rating_scale'\n")
cat(
  "- validity.csv: test_type IN ('performance_validity', 'symptom_validity')\n"
)

neurocog_count <- sum(combined$test_type == "npsych_test", na.rm = TRUE)
neurobehav_count <- sum(combined$test_type == "rating_scale", na.rm = TRUE)
validity_count <- sum(
  combined$test_type %in% c("performance_validity", "symptom_validity"),
  na.rm = TRUE
)

cat("\nExpected counts:\n")
cat("  neurocog:", neurocog_count, "rows\n")
cat("  neurobehav:", neurobehav_count, "rows\n")
cat("  validity:", validity_count, "rows\n")

# Save the combined data for inspection
write_csv(combined, "data/diagnostic_combined.csv")
cat("\nSaved combined data to data/diagnostic_combined.csv for inspection\n")
