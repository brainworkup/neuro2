# Report Generation Helpers

# Patient ID --------------------------------------------------------------

# Parameters
patient <- "Biggie"
test <- "wisc5"
test_name <- "WISC-V"
file_path <- file.path(file.choose()) # Prompt user to select PDF file
saveRDS(file_path, paste0(test, "_path.rds"))
file_path <- readRDS(paste0(test, "_path.rds"))


# PDF data to extract -----------------------------------------------------

# Extract WISC-V index scores
pages <- c(28, 31)
index_data <- neuro2::extract_wisc5_data(
  patient = patient,
  test_type = "index",
  file_path = file_path,
  pages_index = pages
)

# Extract subtest scores with custom page numbers
pages <- c(27)
subtest_data <- neuro2::extract_wisc5_data(
  patient = patient,
  test_type = "subtest",
  file_path = file_path,
  pages_subtest = pages
)

# Extract process scores (will prompt for file selection)
pages <- c(34)
process_data <- neuro2::extract_wisc5_data(
  patient = patient,
  test_type = "process",
  file_path = file_path,
  pages_process = pages
)

wisc5 <- rbind(index_data, subtest_data, process_data) |> dplyr::arrange(absort)

readr::write_excel_csv(wisc5, here::here("data-raw", "csv", "wisc5.csv"))
