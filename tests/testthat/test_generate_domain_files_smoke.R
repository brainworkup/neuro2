test_that("generate_domain_files runs without error for basic domains", {
  rs <- NeuropsychReportSystemR6$new(
    config = list(
      domains = c("Verbal/Language", "ADHD"),
      data_files = list(
        neurocog = "data/neurocog.parquet",
        neurobehav = "data/neurobehav.parquet",
        neuropsych = "data/neuropsych.parquet",
        validity = "data/validity.parquet"
      ),
      template_file = "template.qmd",
      output_file = "neuropsych_report.pdf"
    )
  )

  # Should not error even if data files are missing; function warns and skips
  expect_error(rs$generate_domain_files(), NA)
})

