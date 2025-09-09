test_that("Domain mapping via factory and system works", {
  # Factory-level check
  factory <- DomainProcessorFactoryR6$new()
  cfg_verbal <- factory$get_processor_config("verbal")
  expect_type(cfg_verbal, "list")
  expect_equal(cfg_verbal$pheno, "verbal")
  expect_equal(cfg_verbal$data_source, "neurocog")

  # System-level mapping from human-readable name -> key
  rs <- NeuropsychReportSystemR6$new(
    config = list(
      domains = c("Verbal/Language"),
      data_files = list(
        neurocog = "data/neurocog.parquet",
        neurobehav = "data/neurobehav.parquet",
        neuropsych = "data/neuropsych.parquet",
        validity = "data/validity.parquet"
      )
    )
  )

  cfgs <- rs$create_processor_configs(c("Verbal/Language"))
  expect_true("Verbal/Language" %in% names(cfgs))
  expect_equal(cfgs[["Verbal/Language"]]$pheno, "verbal")
  expect_equal(cfgs[["Verbal/Language"]]$data_source, "neurocog")
})

test_that("Behavioral domain maps to neurobehav", {
  factory <- DomainProcessorFactoryR6$new()
  cfg_adhd <- factory$get_processor_config("adhd")
  expect_equal(cfg_adhd$data_source, "neurobehav")
})

