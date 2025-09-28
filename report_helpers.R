# Report Generation Helpers

# Patient ID --------------------------------------------------------------

# Parameters
patient <- "Maya"
test <- "wisc5"
test_name <- "WISC-V"
file_path <- file.path(file.choose()) # Prompt user to select PDF file
saveRDS(file_path, paste0(test, "_path.rds"))
file_path <- readRDS(paste0(test, "_path.rds"))


# PDF data to extract -----------------------------------------------------

# Extract WISC-V index scores
index_data <- neuro2::extract_wisc5_data(
  patient = patient,
  test_type = "index",
  file_path = file_path,
  pages_index = c(28, 31)
)

# Extract subtest scores with custom page numbers
subtest_data <- neuro2::extract_wisc5_data(
  patient = patient,
  test_type = "subtest",
  file_path = file_path,
  pages_subtest = c(27)
)

# Extract process scores (will prompt for file selection)
process_data <- neuro2::extract_wisc5_data(
  patient = patient,
  test_type = "process",
  pages_process = c(38)
)
