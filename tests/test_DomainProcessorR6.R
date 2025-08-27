
# Test script for DomainProcessorR6 class

# Load testthat library
library(testthat)

# Load the R6 class definition
source("../R/DomainProcessorR6.R")

# Define test data path
test_data_path <- "test_data.csv"

# 1. Test Initialization
test_that("DomainProcessorR6 can be initialized", {
  processor <- DomainProcessorR6$new(
    domains = "attention",
    pheno = "attention",
    input_file = test_data_path,
    number = 1
  )
  expect_true(!is.null(processor))
  expect_equal(processor$domains, "attention")
  expect_equal(processor$pheno, "attention")
  expect_equal(processor$input_file, test_data_path)
  expect_equal(processor$number, "01")
})

# 2. Test Data Loading
test_that("Data can be loaded from CSV", {
  processor <- DomainProcessorR6$new(
    domains = "attention",
    pheno = "attention",
    input_file = test_data_path,
    number = 1
  )
  processor$load_data()
  expect_true(!is.null(processor$data))
  expect_equal(nrow(processor$data), 3)
  expect_equal(ncol(processor$data), 3)
})

# 3. Test Domain Filtering
test_that("Data can be filtered by domain", {
  processor <- DomainProcessorR6$new(
    domains = "attention",
    pheno = "attention",
    input_file = test_data_path,
    number = 1
  )
  processor$load_data()
  processor$filter_by_domain()
  expect_equal(nrow(processor$data), 2)
  expect_true(all(processor$data$domain == "attention"))
})

# 4. Test select_columns method
test_that("select_columns correctly selects and calculates z-score", {
  processor <- DomainProcessorR6$new(
    domains = "attention",
    pheno = "attention",
    input_file = test_data_path,
    number = 1
  )
  processor$load_data()
  processor$select_columns()
  
  # Check if z-score is calculated from percentile
  expect_true("z" %in% names(processor$data))
  expect_equal(processor$data$z[1], qnorm(0.50))
  expect_equal(processor$data$z[2], round(qnorm(0.75), 2))
  expect_equal(processor$data$z[3], round(qnorm(0.25), 2))
})

# 5. Test detect_emotion_type method
test_that("detect_emotion_type correctly identifies child vs adult", {
  # Test with child-specific domains
  processor_child <- DomainProcessorR6$new(
    domains = "Behavioral/Emotional/Social",
    pheno = "emotion",
    input_file = test_data_path
  )
  expect_equal(processor_child$detect_emotion_type(), "child")

  # Test with adult-specific domains
  processor_adult <- DomainProcessorR6$new(
    domains = "Emotional/Behavioral/Personality",
    pheno = "emotion",
    input_file = test_data_path
  )
  expect_equal(processor_adult$detect_emotion_type(), "adult")
})

# 6. Test file generation (simple case)
test_that("generate_domain_text_qmd creates placeholder files", {
  # Create a processor for a standard domain
  processor <- DomainProcessorR6$new(
    domains = "Memory",
    pheno = "memory",
    input_file = "non_existent_file.csv", # Data not needed for this test
    number = 5
  )
  
  # Define the expected output file
  output_file <- "_02-05_memory_text.qmd"
  
  # Clean up before test
  if (file.exists(output_file)) file.remove(output_file)
  
  # Generate the file
  generated_files <- processor$generate_domain_text_qmd()
  
  # Check if the file was created
  expect_true(file.exists(output_file))
  expect_equal(generated_files, output_file)
  
  # Check the content of the file
  content <- readLines(output_file)
  expect_equal(content, c("<summary>", "", "</summary>", ""))
  
  # Clean up after test
  if (file.exists(output_file)) file.remove(output_file)
})

# Clean up the dummy data file
file.remove(test_data_path)

