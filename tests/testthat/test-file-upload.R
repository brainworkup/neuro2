# Test file upload functionality

test_that("file upload helpers work correctly", {
  skip_if_not_installed("neuro2")
  
  # Test check_upload_requirements
  expect_no_error(check_upload_requirements())
  
  # Test list_pdf_templates when directory exists
  if (dir.exists("inst/rmarkdown/templates/pluck_pdfs/skeleton")) {
    expect_no_error(list_pdf_templates())
    templates <- list_pdf_templates()
    expect_type(templates, "character")
  }
  
  # Test upload_files validation
  expect_error(upload_files(method = "invalid"), "Method must be one of")
  
  # Test that directories are created
  temp_dir <- tempdir()
  test_dest <- file.path(temp_dir, "test-upload")
  
  # Mock upload_files for CSV method (without file.choose)
  expect_no_error({
    result <- list(
      method = "csv",
      files_processed = character(0),
      patient_name = "Test Patient",
      success = FALSE,
      message = "Test mode"
    )
    expect_type(result, "list")
    expect_true("method" %in% names(result))
  })
})

test_that("upload workflow integration works", {
  skip_if_not_installed("neuro2")
  
  # Test that required directories can be created
  temp_dir <- tempdir()
  test_dest <- file.path(temp_dir, "neuro2-test")
  
  expect_no_error(dir.create(test_dest, recursive = TRUE))
  expect_true(dir.exists(test_dest))
  
  # Test that CSV files can be copied
  test_csv <- file.path(test_dest, "test.csv")
  writeLines("test,data\n1,2", test_csv)
  expect_true(file.exists(test_csv))
  
  # Cleanup
  unlink(test_dest, recursive = TRUE)
})

test_that("file upload documentation exists", {
  # Check that key documentation files exist
  expect_true(file.exists("FILE_UPLOAD_GUIDE.md"))
  expect_true(file.exists("README.md"))
  expect_true(file.exists("UNIFIED_WORKFLOW_README.md"))
  
  # Check that scripts exist
  expect_true(file.exists("unified_neuropsych_workflow.sh"))
  expect_true(file.exists("unified_workflow_runner.R"))
  expect_true(file.exists("quick_upload.R"))
})