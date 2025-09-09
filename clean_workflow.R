#!/usr/bin/env Rscript

#' CLEAN WORKFLOW - No Triple Execution, No Recursion, No Problems
#'
#' This is a complete, simple workflow that processes each domain ONCE

# Clear environment for clean start
rm(list = ls())

cat("\n================================================\n")
cat("CLEAN NEUROPSYCH WORKFLOW\n")
cat("Single execution guaranteed\n")
cat("================================================\n\n")

# Step 1: Load packages (ONCE)
cat("Step 1: Loading packages...\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(arrow)
  library(ggplot2)
  library(gt)
})
cat("  ✓ Packages loaded\n\n")

# Step 2: Source R6 classes (ONCE, with checks)
cat("Step 2: Loading R6 classes...\n")

load_r6_safely <- function(filename) {
  class_name <- gsub("\\.R$", "", filename)
  if (!exists(class_name)) {
    filepath <- here::here("R", filename)
    if (file.exists(filepath)) {
      source(filepath)
      cat("  ✓ Loaded", filename, "\n")
      return(TRUE)
    } else {
      cat("  ⚠️  Not found:", filename, "\n")
      return(FALSE)
    }
  } else {
    cat("  ⚠️  Already loaded:", class_name, "\n")
    return(TRUE)
  }
}

# Load each R6 class ONCE
r6_classes <- c(
  "DomainProcessorR6.R",
  "TableGTR6.R",
  "DotplotR6.R",
  "NeuropsychResultsR6.R"
)

for (r6_file in r6_classes) {
  load_r6_safely(r6_file)
}

# Step 3: Load data (ONCE)
cat("\nStep 3: Loading data...\n")

neurocog_data <- NULL
neurobehav_data <- NULL

if (file.exists("data/neurocog.parquet")) {
  neurocog_data <- arrow::read_parquet("data/neurocog.parquet")
  cat("  ✓ Loaded neurocog data:", nrow(neurocog_data), "rows\n")
}

if (file.exists("data/neurobehav.parquet")) {
  neurobehav_data <- arrow::read_parquet("data/neurobehav.parquet")
  cat("  ✓ Loaded neurobehav data:", nrow(neurobehav_data), "rows\n")
}

# Step 4: Define domains (ONCE)
cat("\nStep 4: Setting up domains...\n")

domains <- list(
  list(
    key = "iq",
    name = "General Cognitive Ability",
    data = "neurocog",
    num = "01"
  ),
  list(
    key = "academics",
    name = "Academic Skills",
    data = "neurocog",
    num = "02"
  ),
  list(key = "verbal", name = "Verbal/Language", data = "neurocog", num = "03"),
  list(
    key = "spatial",
    name = "Visual Perception/Construction",
    data = "neurocog",
    num = "04"
  ),
  list(key = "memory", name = "Memory", data = "neurocog", num = "05"),
  list(
    key = "executive",
    name = "Attention/Executive",
    data = "neurocog",
    num = "06"
  ),
  list(key = "motor", name = "Motor", data = "neurocog", num = "07"),
  list(
    key = "social",
    name = "Social Cognition",
    data = "neurocog",
    num = "08"
  ),
  list(key = "adhd", name = "ADHD", data = "neurobehav", num = "09"),
  list(
    key = "emotion",
    name = c("Behavioral/Emotional/Social", "Emotional/Behavioral/Personality"),
    data = "neurobehav",
    num = "10"
  )
)

cat("  ✓ Configured", length(domains), "domains\n")

# Step 5: Process domains (SINGLE LOOP, ONCE EACH)
cat("\nStep 5: Processing domains...\n")
cat("----------------------------------------\n")

# Track what we've done
processed <- character()
failed <- character()

for (i in seq_along(domains)) {
  d <- domains[[i]]

  # Progress indicator
  cat(sprintf("[%d/%d] %s: ", i, length(domains), d$key))

  # Skip if already processed (safety check)
  if (d$key %in% processed) {
    cat("SKIPPED (already done)\n")
    next
  }

  # Get the right data
  data_source <- if (d$data == "neurocog") neurocog_data else neurobehav_data

  if (is.null(data_source)) {
    cat("NO DATA SOURCE\n")
    failed <- c(failed, d$key)
    next
  }

  # Check if domain has data
  domain_data <- data_source %>%
    filter(domain == d$name) %>%
    filter(!is.na(percentile) | !is.na(score))

  if (nrow(domain_data) == 0) {
    cat("NO DATA (0 rows)\n")
    failed <- c(failed, d$key)
    next
  }

  # Process the domain (ONCE)
  tryCatch(
    {
      # Only process if DomainProcessorR6 exists
      if (exists("DomainProcessorR6")) {
        processor <- DomainProcessorR6$new(
          domains = d$name,
          pheno = d$key,
          input_file = paste0("data/", d$data, ".parquet")
        )

        # Set the number
        processor$number <- d$num

        # Process
        processor$process()

        # Generate QMD if it doesn't exist
        qmd_file <- paste0("_02-", d$num, "_", d$key, ".qmd")
        if (!file.exists(qmd_file)) {
          processor$generate_domain_qmd(qmd_file)
        }

        # Mark as done
        processed <- c(processed, d$key)
        cat("✓ PROCESSED\n")
      } else {
        cat("PROCESSOR NOT AVAILABLE\n")
        failed <- c(failed, d$key)
      }
    },
    error = function(e) {
      cat("ERROR:", e$message, "\n")
      failed <- c(failed, d$key)
    }
  )
}

# Step 6: Summary
cat("\n----------------------------------------\n")
cat("WORKFLOW COMPLETE\n")
cat("----------------------------------------\n")
cat("✓ Processed:", length(processed), "domains\n")
if (length(processed) > 0) {
  cat("  ", paste(processed, collapse = ", "), "\n")
}
if (length(failed) > 0) {
  cat("✗ Failed:", length(failed), "domains\n")
  cat("  ", paste(failed, collapse = ", "), "\n")
}

# Step 7: Create the main template.qmd if needed
if (!file.exists("template.qmd") && length(processed) > 0) {
  cat("\nCreating template.qmd...\n")

  template_content <- '---
title: "Neuropsychological Report"
format:
  typst:
    toc: true
execute:
  echo: false
  warning: false
  message: false
---

# Cognitive Domains

'

  # Add includes for processed domains
  for (p in processed) {
    d <- domains[[which(sapply(domains, function(x) x$key == p))]]
    qmd_file <- paste0("_02-", d$num, "_", d$key, ".qmd")
    if (file.exists(qmd_file)) {
      template_content <- paste0(
        template_content,
        "{{< include ",
        qmd_file,
        " >}}\n\n"
      )
    }
  }

  writeLines(template_content, "template.qmd")
  cat("  ✓ Created template.qmd\n")
}

cat("\n================================================\n")
cat("ALL DONE - Each domain processed exactly ONCE\n")
cat("================================================\n\n")

# Return summary for testing
invisible(list(processed = processed, failed = failed, total = length(domains)))
