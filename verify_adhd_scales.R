# Verification script to show the correct ADHD scales being used

library(here)

# Load the internal data
load(here::here("R", "sysdata.rda"))

cat("=== Standardized ADHD Scales from sysdata.rda ===\n")
cat("Total number of scales:", length(scales_adhd_adult), "\n\n")

# Show all scales with numbering
for (i in seq_along(scales_adhd_adult)) {
  cat(sprintf("[%2d] %s\n", i, scales_adhd_adult[i]))
}

# Highlight key scale groups
cat("\n=== Key Scale Groups ===\n")
cat("BROWN EF/A scales: Activation, Focus, Effort, Emotion, Memory, Action\n")
cat("CAARS scales: Multiple ADHD indices and symptom scales\n")
cat("CEFI scales: Executive function assessment scales\n")
cat("DSM-5 scales: Diagnostic criteria-based scales\n")

# Show scales that appear multiple times (from different instruments)
cat("\n=== Scales appearing multiple times (different instruments) ===\n")
duplicated_scales <- scales_adhd_adult[duplicated(scales_adhd_adult)]
if (length(unique(duplicated_scales)) > 0) {
  for (scale in unique(duplicated_scales)) {
    positions <- which(scales_adhd_adult == scale)
    cat(sprintf("'%s' appears at positions: %s\n", 
                scale, paste(positions, collapse = ", ")))
  }
} else {
  cat("No duplicated scale names found.\n")
}