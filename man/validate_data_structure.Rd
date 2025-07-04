% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{validate_data_structure}
\alias{validate_data_structure}
\title{Validate Data Frame Structure}
\usage{
validate_data_structure(df, required_cols, col_types = NULL)
}
\arguments{
\item{df}{Data frame to validate}

\item{required_cols}{Character vector of required column names}

\item{col_types}{Named list of column types (optional)}
}
\value{
TRUE if valid, otherwise stops with error
}
\description{
Validates that a data frame has required columns and types.
}
