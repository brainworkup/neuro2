# IMPLEMENTATION CHECKLIST FOR neuro2 FIXES
# =====================================================

# 1. CREATE NEW FILES
# -------------------
# Create: R/domain_validation_utils.R
# Content: The validate_domain_data_exists() and get_domains_with_data() functions

# Create: R/score_type_cache.R
# Content: The ScoreTypeCacheR6 class for caching score type mappings

# 2. UPDATE EXISTING FILES
# -------------------------

# A) Update domain_generator_module.R
# Replace main_processing() with main_processing_improved()
# Replace process_single_domain() with process_single_domain_validated()
# Add the validation logic at the beginning

# B) Update TableGTR6.R (or create TableGTR6_optimized.R)
# Replace the build_table() method with build_table_optimized()
# This eliminates the repetitive score type lookup

# C) Update DomainProcessorR6.R
# Add the enhanced text file generation methods
# Replace generate_domain_text_qmd() with generate_domain_text_qmd_fixed()
# Add check_rater_data_exists_fixed() method

# 3. INTEGRATION SCRIPT
# ----------------------
# Add this to the beginning of template.qmd preprocessing:

# Source the enhanced functions
source("R/domain_validation_utils.R")
source("R/score_type_cache.R")

# Initialize the score type cache once
.score_type_cache$build_mappings()

# Before domain generation, validate data
valid_domains_only <- get_domains_with_data(
  neurocog_data,
  neurobehav_data,
  domain_config
)

# After domain generation, ensure text files exist
domain_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$")
ensure_text_files_exist(domain_files)

# 4. PERFORMANCE IMPROVEMENTS
# ----------------------------
# BEFORE: Score type lookup runs ~10 times (once per domain)
# AFTER:  Score type lookup runs 1 time (cached and reused)

# BEFORE: Generates files for domains without data
# AFTER:  Only processes domains with actual data

# BEFORE: Missing text files cause render failures
# AFTER:  Missing text files are auto-generated as placeholders

# 5. TESTING THE FIXES
# ---------------------

# Test 1: Verify only domains with data are processed
test_domain_validation <- function() {
  # Should only show domains that actually have data
  source("R/domain_validation_utils.R")
  neurocog_data <- readr::read_csv("data/neurocog.csv")
  neurobehav_data <- readr::read_csv("data/neurobehav.csv")

  valid_domains <- get_domains_with_data(
    neurocog_data,
    neurobehav_data,
    domain_config
  )

  cat("Domains with data:\n")
  for (domain in names(valid_domains)) {
    validation <- valid_domains[[domain]]$validation
    cat(sprintf("  ✓ %s: %d rows\n", domain, validation$row_count))
  }
}

# Test 2: Verify score type cache works
test_score_cache <- function() {
  source("R/score_type_cache.R")
  cache <- ScoreTypeCacheR6$new()

  # This should run once and cache results
  system.time(cache$build_mappings())

  # These should be instant (using cache)
  test_names <- c("WISC-V", "RBANS", "WIAT-4")
  for (test in test_names) {
    groups <- cache$get_score_groups(test)
    cat(sprintf(
      "Score groups for %s: %s\n",
      test,
      paste(names(groups), collapse = ", ")
    ))
  }
}

# Test 3: Verify text files are created
test_text_files <- function() {
  # Run domain generation
  source("domain_generator_module.R")

  # Check for missing text files
  domain_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$")

  cat("Checking text file requirements:\n")
  for (file in domain_files) {
    if (file.exists(file)) {
      content <- readLines(file, warn = FALSE)
      includes <- content[grepl("{{< include.*_text.*\\.qmd >}}", content)]

      for (include_line in includes) {
        text_file <- gsub(".*include\\s+([^\\s}]+).*", "\\1", include_line)
        status <- if (file.exists(text_file)) "✓" else "✗"
        cat(sprintf("  %s %s -> %s\n", status, file, text_file))
      }
    }
  }
}

# 6. EXPECTED IMPROVEMENTS
# -------------------------
# ✓ No more "No data available for table generation" for domains with data
# ✓ No more files generated for domains without data
# ✓ ~90% reduction in score type lookup processing time
# ✓ No more missing text file errors during Quarto rendering
# ✓ Better error messages and logging
# ✓ More robust validation throughout the pipeline

print("Implementation checklist ready. Run the test functions to verify fixes.")
