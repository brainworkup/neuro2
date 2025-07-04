% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/extract_test_data.R
\name{extract_test_data_legacy}
\alias{extract_test_data_legacy}
\title{Extract and Process Neuropsychological Test Data from PDF Files (Legacy)}
\usage{
extract_test_data_legacy(
  patient,
  test,
  test_name,
  file = NULL,
  pages,
  extract_columns,
  score_type,
  variables,
  lookup_table_path = "~/Dropbox/neuropsych_lookup_table.csv",
  write_output = TRUE,
  output_dir = if (requireNamespace("here", quietly = TRUE)) {
     here::here("data",
    "csv")
 } else {
     file.path("data", "csv")
 },
  write_to_g = TRUE,
  g_filename = "g"
)
}
\arguments{
\item{patient}{Character string with patient name}

\item{test}{Character string identifying the test type (e.g., "wisc5", "wais5")}

\item{test_name}{Character string with the full test name (e.g., "WISC-V", "WAIS-5")}

\item{file}{Character string with the path to the PDF file, or NULL to prompt for file selection}

\item{pages}{Numeric vector specifying which pages to extract from the PDF}

\item{extract_columns}{Numeric vector specifying which columns to extract}

\item{score_type}{Character string indicating the score type (e.g., "scaled_score", "standard_score")}

\item{variables}{Character vector with names for the extracted columns}

\item{lookup_table_path}{Character string with path to the lookup table CSV file}

\item{write_output}{Logical indicating whether to write output files}

\item{output_dir}{Character string with directory to write output files to. Default uses here::here("data", "csv") if available, otherwise file.path("data", "csv")}

\item{write_to_g}{Logical indicating whether to append results to g2.csv}

\item{g_filename}{Character string with name of the g-file to write to (without extension)}
}
\value{
A data frame with the processed test data
}
\description{
This function extracts tables from PDF files containing neuropsychological test results,
processes the data, merges with a lookup table, and calculates score ranges and text descriptions.
This is a legacy version being phased out in favor of the unified extraction system.
}
\examples{
\dontrun{
# Extract WISC-V subtest data
wisc5_data <- extract_test_data_legacy(
  patient = "Biggie",
  test = "wisc5",
  test_name = "WISC-V",
  pages = c(30),
  extract_columns = c(2, 4, 5, 6),
  variables = c("scale", "raw_score", "score", "percentile"),
  score_type = "scaled_score"
)
}
}
