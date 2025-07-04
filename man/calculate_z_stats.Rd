% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tidy_data.R
\name{calculate_z_stats}
\alias{calculate_z_stats}
\title{Helper function to calculate z-score statistics by grouping variables}
\usage{
calculate_z_stats(data, group_vars)
}
\arguments{
\item{data}{A dataframe containing z-scores}

\item{group_vars}{Character vector of column names to group by}
}
\value{
Dataframe with added z-score statistics columns
}
\description{
Efficiently calculates mean and standard deviation of z-scores for specified grouping variables
}
\keyword{internal}
