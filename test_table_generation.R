# Test script to isolate table generation issue

# Load necessary packages
library(R6)
library(gt)
library(gtExtras)
library(dplyr)
library(tidyr)
library(here)
library(arrow)

# Source the R6 classes
source("R/DomainProcessorR6.R")
source("R/TableGT_ModifiedR6.R")

# Load data
iq <- arrow::read_parquet("data/neurocog.parquet")

# Filter data for IQ domain
domains <- c("General Cognitive Ability")
scales_iq <- c(
  "Full Scale IQ (FSIQ)",
  "Verbal Comprehension (VCI)",
  "Visual Spatial (VSI)",
  "Fluid Reasoning (FRI)",
  "Working Memory (WMI)",
  "Processing Speed (PSI)"
)
data_iq <- iq[iq$domain %in% domains & iq$scale %in% scales_iq, ]

# Table parameters
table_name <- "table_iq"
vertical_padding <- 0
multiline <- TRUE

# Create table using our modified TableGT_ModifiedR6 R6 class
table_gt <- TableGT_ModifiedR6$new(
  data = data_iq,
  pheno = "iq",
  table_name = table_name,
  vertical_padding = vertical_padding,
  source_note = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
  multiline = multiline
)

# Get the table object without automatic saving
tbl <- table_gt$build_table()

# Save the table using our save_table method
table_gt$save_table(tbl)

# Check if file exists
if (file.exists("table_iq.png")) {
  print("Successfully created table_iq.png")
} else {
  print("Failed to create table_iq.png")
}
