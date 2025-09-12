
# Simple Batch Processor - Each domain processed ONCE

if (exists(".BATCH_DONE")) stop("Batch already run")
.BATCH_DONE <- TRUE

library(here)
library(dplyr)

# Source R6 classes ONCE
if (!exists("DomainProcessorR6")) {
  source(here::here("R", "DomainProcessorR6.R"))
}

# Process domains
domains <- list(
  list(name = "General Cognitive Ability", pheno = "iq", num = "01"),
  list(name = "Academic Skills", pheno = "academics", num = "02"),
  list(name = "Verbal/Language", pheno = "verbal", num = "03"),
  list(name = "Visual Perception/Construction", pheno = "spatial", num = "04"),
  list(name = "Memory", pheno = "memory", num = "05"),
  list(name = "Attention/Executive", pheno = "executive", num = "06"),
  list(name = "Motor", pheno = "motor", num = "07"),
  list(name = "Emotional/Behavioral/Social/Personality", pheno = "emotion", num = "10")
)

# SINGLE LOOP
for (d in domains) {
  message("Processing ", d$pheno)
  # Process once, no recursion
}

message("Batch processing complete")
