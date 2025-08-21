# Development setup script
# Clear workspace
rm(list = ls())

# Load development packages
library(devtools)
library(testthat)
library(usethis)

# Load your package
devtools::load_all()

# Set up test data if needed
# test_data <- readr::read_csv("tests/testdata/sample.csv")

message("Development environment ready!")
