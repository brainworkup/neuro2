#!/usr/bin/env Rscript

# Test the complete domain generation system with adult/child variants
# This demonstrates how the system handles up to 14 total domains

library(dplyr)

# Simulate the domain configuration from NeuropsychReportSystemR6
domain_config <- list(
  list(domain = "General Cognitive Ability", number = "01", pheno = "iq"),
  list(domain = "Academic Skills", number = "02", pheno = "academics"),
  list(domain = "Verbal/Language", number = "03", pheno = "verbal"),
  list(
    domain = "Visual Perception/Construction",
    number = "04",
    pheno = "spatial"
  ),
  list(domain = "Memory", number = "05", pheno = "memory"),
  list(domain = "Attention/Executive", number = "06", pheno = "executive"),
  list(domain = "Motor", number = "07", pheno = "motor"),
  list(domain = "Social Cognition", number = "08", pheno = "social"),
  # ADHD has adult/child variants
  list(
    domain = "ADHD",
    number = "09",
    pheno = "adhd",
    variants = c("adult", "child")
  ),
  # Emotion domains all map to same number with adult/child variants
  list(
    domain = c(
      "Emotional/Behavioral/Personality",
      "Behavioral/Emotional/Social",
      "Psychiatric Disorders",
      "Personality Disorders",
      "Substance Use",
      "Psychosocial Problems"
    ),
    number = "10",
    pheno = "emotion",
    variants = c("adult", "child")
  ),
  list(domain = "Adaptive Functioning", number = "11", pheno = "adaptive"),
  list(domain = "Daily Living", number = "12", pheno = "daily_living"),
  list(domain = "Symptom Validity", number = "13", pheno = "validity")
)

# Function to generate domain files based on patient type and available domains
generate_domain_files_demo <- function(
  patient_type = "adult",
  available_domains
) {
  cat("=== Generating domain files for", patient_type, "patient ===\n\n")

  generated_files <- character()

  for (config in domain_config) {
    # Get all domain names for this config
    domain_names <- if (is.character(config$domain)) {
      config$domain
    } else {
      unlist(config$domain)
    }

    # Check if any of these domains exist in the data
    matching_domains <- intersect(domain_names, available_domains)

    if (length(matching_domains) > 0) {
      # Determine variant to use
      variant_suffix <- ""
      if (!is.null(config$variants) && patient_type %in% config$variants) {
        variant_suffix <- paste0("_", patient_type)
      }

      # Generate file names
      pheno_name <- paste0(config$pheno, variant_suffix)
      domain_file <- paste0("_02-", config$number, "_", pheno_name, ".qmd")
      text_file <- paste0("_02-", config$number, "_", pheno_name, "_text.qmd")

      cat("Domain:", paste(matching_domains, collapse = ", "), "\n")
      cat("  Main file:", domain_file, "\n")
      cat("  Text file:", text_file, "\n\n")

      generated_files <- c(generated_files, domain_file)
    }
  }

  cat("Total files generated:", length(generated_files), "\n\n")
  return(generated_files)
}

# Example 1: Adult patient with comprehensive testing
cat("EXAMPLE 1: Adult patient with comprehensive neuropsych battery\n")
cat(strrep("=", 60), "\n\n")

adult_domains <- c(
  "General Cognitive Ability",
  "Academic Skills",
  "Verbal/Language",
  "Visual Perception/Construction",
  "Memory",
  "Attention/Executive",
  "Motor",
  "ADHD",
  "Psychiatric Disorders",
  "Personality Disorders",
  "Substance Use"
)

adult_files <- generate_domain_files_demo("adult", adult_domains)

# Example 2: Child patient
cat("\nEXAMPLE 2: Child patient with developmental assessment\n")
cat(strrep("=", 60), "\n\n")

child_domains <- c(
  "General Cognitive Ability",
  "Academic Skills",
  "Verbal/Language",
  "Visual Perception/Construction",
  "Memory",
  "Attention/Executive",
  "Motor",
  "Social Cognition",
  "ADHD",
  "Behavioral/Emotional/Social",
  "Adaptive Functioning"
)

child_files <- generate_domain_files_demo("child", child_domains)

# Show all possible domain files
cat("\nALL POSSIBLE DOMAIN FILES (14 total):\n")
cat(strrep("=", 60), "\n\n")

all_possible_files <- c(
  "_02-01_iq.qmd",
  "_02-02_academics.qmd",
  "_02-03_verbal.qmd",
  "_02-04_spatial.qmd",
  "_02-05_memory.qmd",
  "_02-06_executive.qmd",
  "_02-07_motor.qmd",
  "_02-08_social.qmd",
  "_02-09_adhd_adult.qmd", # Adult variant
  "_02-09_adhd_child.qmd", # Child variant
  "_02-10_emotion_adult.qmd", # Adult variant
  "_02-10_emotion_child.qmd", # Child variant
  "_02-11_adaptive.qmd",
  "_02-12_daily_living.qmd"
)

for (i in seq_along(all_possible_files)) {
  cat(sprintf("%2d. %s\n", i, all_possible_files[i]))
}

cat("\nNote: A single patient would have at most 10-12 domains\n")
cat("(either adult OR child variants, not both)\n")

# Show how template.qmd would include these files
cat("\n\nHOW TEMPLATE.QMD INCLUDES FILES:\n")
cat(strrep("=", 60), "\n\n")

cat("The template.qmd checks for existence of each possible file:\n\n")
cat("For adult patient, it would find and include:\n")
for (file in adult_files) {
  cat("  {{< include", file, ">}}\n")
}

cat("\nFor child patient, it would find and include:\n")
for (file in child_files) {
  cat("  {{< include", file, ">}}\n")
}
