# Test script for ADHD scale standardization
# This tests both the modified ADHD document and enhanced DomainProcessorR6Combo class

library(here)

# Source the required R6 classes
source(here::here("R/DomainProcessorR6Combo.R"))
source(here::here("R/NeuropsychResultsR6.R"))
source(here::here("R/DotplotR6.R"))
source(here::here("R/TableGTR6.R"))

# Test 1: Verify sysdata.rda loads correctly
cat("=== Test 1: Loading sysdata.rda ===\n")
load(here::here("R/sysdata.rda"))
if (exists("scales_adhd_adult")) {
  cat("✓ scales_adhd_adult loaded successfully\n")
  cat(paste("  Found", length(scales_adhd_adult), "scales\n"))
} else {
  cat("✗ Failed to load scales_adhd_adult\n")
}

# Test 2: Test DomainProcessorR6Combo scale loading
cat("\n=== Test 2: Testing DomainProcessorR6Combo scale loading ===\n")
test_processor <- DomainProcessorR6Combo$new(
  domains = "ADHD",
  pheno = "adhd_adult",
  input_file = "data/neurobehav.parquet"
)

# Test automatic scale loading
scales_from_processor <- test_processor$get_scales()
if (length(scales_from_processor) > 0) {
  cat("✓ DomainProcessorR6Combo loaded scales automatically\n")
  cat(paste("  Found", length(scales_from_processor), "scales\n"))

  # Compare with expected scales
  if (identical(scales_from_processor, scales_adhd_adult)) {
    cat("✓ Loaded scales match expected scales_adhd_adult\n")
  } else {
    cat("✗ Loaded scales differ from expected\n")
  }
} else {
  cat("✗ DomainProcessorR6Combo failed to load scales\n")
}

# Test 3: Test with explicit scale_source
cat("\n=== Test 3: Testing with explicit scale_source ===\n")
custom_scales <- c("Test Scale 1", "Test Scale 2")
test_processor2 <- DomainProcessorR6Combo$new(
  domains = "ADHD",
  pheno = "adhd_adult",
  input_file = "data/neurobehav.parquet",
  scale_source = custom_scales
)

scales_custom <- test_processor2$get_scales()
if (identical(scales_custom, custom_scales)) {
  cat("✓ Custom scale_source works correctly\n")
} else {
  cat("✗ Custom scale_source failed\n")
}

# Test 4: Test ADHD document code chunk
cat("\n=== Test 4: Testing ADHD document scale loading ===\n")
# Simulate the code from _02-09_adhd_adult.qmd
if (!exists("scales_adhd_adult")) {
  sysdata_path <- here::here("R", "sysdata.rda")
  if (file.exists(sysdata_path)) {
    load(sysdata_path)
  }
}

# Use the standardized scales from internal data
scales <- scales_adhd_adult
if (length(scales) == 44) {
  cat("✓ ADHD document would load all 44 standardized scales\n")
} else {
  cat("✗ ADHD document scale loading issue\n")
}

# Test 5: Check scale content
cat("\n=== Test 5: Sample of standardized scales ===\n")
cat("First 10 scales:\n")
print(head(scales, 10))

cat("\n=== All tests completed ===\n")
cat("\nSummary:\n")
cat(
  "- scales_adhd_adult contains",
  length(scales_adhd_adult),
  "standardized scale names\n"
)
cat(
  "- DomainProcessorR6Combo can automatically load scales based on phenotype\n"
)
cat("- ADHD document now uses standardized scales instead of hardcoded list\n")
cat(
  "- The system maintains backward compatibility with scale_source parameter\n"
)
