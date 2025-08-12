#!/usr/bin/env Rscript
# NOT GREAT SO FAR
# Script to generate proper domain files using DomainProcessorR6

# Load required libraries
library(here)
library(R6)

# Source R6 classes
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGT_ModifiedR6.R")
source("R/score_type_utils.R")

cat("Generating domain files using R6 classes...\n\n")

# Define domain configurations
domain_configs <- list(
  list(
    domain_name = "General Cognitive Ability",
    pheno = "iq",
    input_file = "data/neurocog.parquet"
  ),
  list(
    domain_name = "Academic Skills",
    pheno = "academics",
    input_file = "data/neurocog.parquet"
  ),
  list(
    domain_name = "Verbal/Language",
    pheno = "verbal",
    input_file = "data/neurocog.parquet"
  ),
  list(
    domain_name = "Visual Perception/Construction",
    pheno = "spatial",
    input_file = "data/neurocog.parquet"
  ),
  list(
    domain_name = "Memory",
    pheno = "memory",
    input_file = "data/neurocog.parquet"
  ),
  list(
    domain_name = "Attention/Executive",
    pheno = "executive",
    input_file = "data/neurocog.parquet"
  ),
  list(
    domain_name = "Motor",
    pheno = "motor",
    input_file = "data/neurocog.parquet"
  ),
  list(
    domain_name = "Social Cognition",
    pheno = "social",
    input_file = "data/neurocog.parquet"
  ),
  list(
    domain_name = "ADHD",
    pheno = "adhd",
    input_file = "data/neurobehav.parquet"
  ),
  list(
    domain_name = "Emotional/Behavioral/Personality",
    pheno = "emotion",
    input_file = "data/neurobehav.parquet"
  )
)

# Generate domain files
for (config in domain_configs) {
  cat(paste0(
    "Generating files for ",
    config$domain_name,
    " (",
    config$pheno,
    ")...\n"
  ))

  tryCatch(
    {
      # Create processor
      processor <- DomainProcessorR6$new(
        domains = config$domain_name,
        pheno = config$pheno,
        input_file = config$input_file
      )

      # Since we don't have data, we'll inject empty data
      processor$data <- data.frame(
        domain = character(0),
        test = character(0),
        scale = character(0),
        score = numeric(0),
        percentile = numeric(0),
        range = character(0),
        stringsAsFactors = FALSE
      )

      # Generate domain QMD file
      generated_file <- processor$generate_domain_qmd()
      cat(paste0("  ✓ Generated ", generated_file, "\n"))
    },
    error = function(e) {
      cat(paste0("  ✗ Error: ", e$message, "\n"))
    }
  )
}

# Generate special domain files for adult/child variants
cat("\nGenerating adult/child variant files...\n")

# ADHD adult
tryCatch(
  {
    processor <- DomainProcessorR6$new(
      domains = "ADHD",
      pheno = "adhd",
      input_file = "data/neurobehav.parquet"
    )
    processor$data <- data.frame(
      domain = character(0),
      test = character(0),
      scale = character(0),
      score = numeric(0),
      percentile = numeric(0),
      range = character(0),
      stringsAsFactors = FALSE
    )
    generated_file <- processor$generate_domain_qmd(
      output_file = "_02-09_adhd_adult.qmd"
    )
    cat("  ✓ Generated _02-09_adhd_adult.qmd\n")
  },
  error = function(e) {
    cat(paste0("  ✗ Error: ", e$message, "\n"))
  }
)

# ADHD child
tryCatch(
  {
    processor <- DomainProcessorR6$new(
      domains = "ADHD",
      pheno = "adhd",
      input_file = "data/neurobehav.parquet"
    )
    processor$data <- data.frame(
      domain = character(0),
      test = character(0),
      scale = character(0),
      score = numeric(0),
      percentile = numeric(0),
      range = character(0),
      stringsAsFactors = FALSE
    )
    generated_file <- processor$generate_domain_qmd(
      output_file = "_02-09_adhd_child.qmd",
      is_child = TRUE
    )
    cat("  ✓ Generated _02-09_adhd_child.qmd\n")
  },
  error = function(e) {
    cat(paste0("  ✗ Error: ", e$message, "\n"))
  }
)

# Emotion adult
tryCatch(
  {
    processor <- DomainProcessorR6$new(
      domains = "Emotional/Behavioral/Personality",
      pheno = "emotion",
      input_file = "data/neurobehav.parquet"
    )
    processor$data <- data.frame(
      domain = character(0),
      test = character(0),
      scale = character(0),
      score = numeric(0),
      percentile = numeric(0),
      range = character(0),
      stringsAsFactors = FALSE
    )
    processor$generate_emotion_adult_qmd(
      "Emotional/Behavioral/Personality",
      "_02-10_emotion_adult.qmd"
    )
    cat("  ✓ Generated _02-10_emotion_adult.qmd\n")
  },
  error = function(e) {
    cat(paste0("  ✗ Error: ", e$message, "\n"))
  }
)

# Emotion child
tryCatch(
  {
    processor <- DomainProcessorR6$new(
      domains = "Behavioral/Emotional/Social",
      pheno = "emotion",
      input_file = "data/neurobehav.parquet"
    )
    processor$data <- data.frame(
      domain = character(0),
      test = character(0),
      scale = character(0),
      score = numeric(0),
      percentile = numeric(0),
      range = character(0),
      stringsAsFactors = FALSE
    )
    processor$generate_emotion_child_qmd(
      "Behavioral/Emotional/Social",
      "_02-10_emotion_child.qmd"
    )
    cat("  ✓ Generated _02-10_emotion_child.qmd\n")
  },
  error = function(e) {
    cat(paste0("  ✗ Error: ", e$message, "\n"))
  }
)

# Adaptive and Daily Living
remaining_domains <- list(
  list(
    domain = "Adaptive Functioning",
    pheno = "adaptive",
    file = "_02-11_adaptive.qmd"
  ),
  list(
    domain = "Daily Living",
    pheno = "daily_living",
    file = "_02-12_daily_living.qmd"
  )
)

for (dom in remaining_domains) {
  tryCatch(
    {
      processor <- DomainProcessorR6$new(
        domains = dom$domain,
        pheno = dom$pheno,
        input_file = "data/neurobehav.parquet"
      )
      processor$data <- data.frame(
        domain = character(0),
        test = character(0),
        scale = character(0),
        score = numeric(0),
        percentile = numeric(0),
        range = character(0),
        stringsAsFactors = FALSE
      )
      processor$generate_domain_qmd(output_file = dom$file)
      cat(paste0("  ✓ Generated ", dom$file, "\n"))
    },
    error = function(e) {
      cat(paste0("  ✗ Error generating ", dom$file, ": ", e$message, "\n"))
    }
  )
}

cat("\nDomain file generation complete!\n")
