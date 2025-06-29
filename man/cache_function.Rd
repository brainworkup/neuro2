% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{cache_function}
\alias{cache_function}
\title{Cached Function Execution}
\usage{
cache_function(fn, cache_dir = NULL)
}
\arguments{
\item{fn}{Function to cache}

\item{cache_dir}{Optional cache directory for persistent cache}
}
\value{
Memoised function
}
\description{
Caches function results using memoise for expensive operations.
Cache is session-specific by default.
}
