## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup--------------------------------------------------------------------
library(neuro2)

## ----eval=FALSE---------------------------------------------------------------
# check_dependencies()

## ----eval=FALSE---------------------------------------------------------------
# # Example data structure
# data_file <- system.file(
#   "extdata",
#   "neurocog.csv",
#   package = "neuro2"
# )

## ----eval=FALSE---------------------------------------------------------------
# processed_data <- process_domains(data_file)

## ----eval=FALSE---------------------------------------------------------------
# report_file <- generate_report(
#   data_file = data_file,
#   template_name = "template.qmd",
#   output_dir = "output",
#   output_format = "html"
# )

## ----eval=FALSE---------------------------------------------------------------
# data_files <- list.files("data", pattern = "*.csv", full.names = FALSE)
# reports <- lapply(data_files, generate_report)

## ----eval=FALSE---------------------------------------------------------------
# client_dir <- create_output_dir(
#   "reports",
#   subdirs = c("client_001", "client_002")
# )

