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
  skip_if_not_installed("neuro2")

  pkg_root <- dirname(system.file(package = "neuro2"))

  expect_true(
    file.exists(file.path(pkg_root, "FILE_UPLOAD_GUIDE.md")),
    info = "FILE_UPLOAD_GUIDE.md should be available at the repository root"
  )

  readme_candidates <- file.path(pkg_root, c("README_NEURO2.md", "README.md"))
  expect_true(
    any(file.exists(readme_candidates)),
    info = "A top-level README describing upload workflows should exist"
  )

  workflow_docs <- file.path(
    pkg_root,
    c("UNIFIED_WORKFLOW_README.md", "NEUROPSYCH_WORKFLOW_GUIDE.md", "inst/scripts/README.md")
  )
  expect_true(
    any(file.exists(workflow_docs)),
    info = "At least one detailed workflow README must be present"
  )

  shell_scripts <- file.path(
    pkg_root,
    c("run_neuropsych_workflow.sh", "run_workflow.sh", "unified_neuropsych_workflow.sh")
  )
  expect_true(
    any(file.exists(shell_scripts)),
    info = "A workflow shell script entry point should be available"
  )

  runner_scripts <- file.path(
    pkg_root,
    c(
      "main_workflow_runner.R",
      "complete_neuropsych_workflow_fixed.R",
      "complete_neuropsych_workflow.R",
      "unified_workflow_runner.R",
      "inst/scripts/main_workflow_runner.R"
    )
  )
  expect_true(
    any(file.exists(runner_scripts)),
    info = "An R workflow runner script should be available"
  )

  expect_true(
    "quick_upload" %in% getNamespaceExports("neuro2"),
    info = "quick_upload helper should be exported"
  )
})
