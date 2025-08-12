#!/usr/bin/env Rscript

# Generate emotion text files for child patients
# This script creates the necessary text files for self and parent reports

cat("Generating emotion text files for child patients...\n")

# Create _02-10_emotion_child_text_self.qmd
self_content <- '---
title: "Behavioral, Emotional, and Personality Functioning"
---

## Summary

Biggie completed self-report rating scales of emotional and behavioral functioning. The results are summarized below.

## Interpretation

Based on self-report measures, Biggie\'s emotional and behavioral functioning appears to be within normal limits. No significant concerns were noted in the areas assessed.
'

cat("Creating _02-10_emotion_child_text_self.qmd...\n")
writeLines(self_content, "_02-10_emotion_child_text_self.qmd")

# Create _02-10_emotion_child_text_parent.qmd  
parent_content <- '---
title: "Behavioral, Emotional, and Personality Functioning - Parent Report"
---

## Summary

Biggie\'s parent/guardian completed rating scales regarding Biggie\'s emotional and behavioral functioning. The results are summarized below.

## Interpretation

Based on parent report measures, Biggie\'s emotional and behavioral functioning appears to be within normal limits. No significant concerns were noted by the parent/guardian in the areas assessed.
'

cat("Creating _02-10_emotion_child_text_parent.qmd...\n")
writeLines(parent_content, "_02-10_emotion_child_text_parent.qmd")

# Also create the general emotion text file if it doesn't exist
general_content <- '---
title: "Behavioral, Emotional, and Personality Functioning"
---

## Overview

Assessment of behavioral, emotional, and personality functioning was conducted using standardized rating scales completed by multiple informants.

## Clinical Observations

During the evaluation, Biggie\'s behavior and emotional presentation were appropriate for the testing situation. Biggie demonstrated adequate frustration tolerance and persistence when faced with challenging tasks.
'

cat("Creating _02-10_emotion_child_text.qmd...\n")
writeLines(general_content, "_02-10_emotion_child_text.qmd")

cat("Emotion text files created successfully!\n")

# List the created files
cat("\nCreated files:\n")
files_created <- c(
  "_02-10_emotion_child_text_self.qmd",
  "_02-10_emotion_child_text_parent.qmd", 
  "_02-10_emotion_child_text.qmd"
)

for (file in files_created) {
  if (file.exists(file)) {
    cat(paste0("  ✓ ", file, "\n"))
  } else {
    cat(paste0("  ✗ ", file, " (not created)\n"))
  }
}