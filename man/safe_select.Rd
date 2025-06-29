% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{safe_select}
\alias{safe_select}
\title{Safe Column Selection}
\usage{
safe_select(df, cols, warn = TRUE)
}
\arguments{
\item{df}{Data frame}

\item{cols}{Column names to select}

\item{warn}{Whether to warn about missing columns}
}
\value{
Data frame with selected columns
}
\description{
Safely selects columns from a data frame, ignoring missing columns.
}
