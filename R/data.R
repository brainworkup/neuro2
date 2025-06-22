#' CAARS-2 Self-Report Subtest Scores
#'
#' A sample data set extracted from a CAARS-2 PDF report (self-report version)
#' with the tabulapdf package. Each row is one subtest score.
#'
#' @format A data frame with \code{n} rows and the following columns:
#' \describe{
#'   \item{scale}{\code{character} Subtest name (e.g. \"Inattention\")}
#'   \item{raw_score}{\code{numeric} Raw score on the subtest}
#'   \item{t_score}{\code{numeric} T-score (mean = 50, SD = 10)}
#'   \item{percentile}{\code{numeric} Percentile rank}
#'   \item{date_administered}{\code{Date} Date of testing}
#' }
#' @source Clinical CAARS-2 report, extracted via tabulapdf
#' @examples
#' head(caars2_self)
"caars2_self"


#' CVLT-3 Brief Form Trial Data
#'
#' A sample dataset of trial-by-trial recall scores from a CVLT-3 Brief.
#'
#' @format A data frame with \code{n} rows:
#' \describe{
#'   \item{trial}{\code{integer} Trial number}
#'   \item{list_a}{\code{integer} Items recalled from List A}
#'   \item{list_b}{\code{integer} Items recalled from List B}
#'   \item{long_delay}{\code{integer} List A recall after delay}
#'   \item{percentile}{\code{numeric} Percentile rank}
#' }
#' @source Clinical CVLT-3 report, extracted via tabulapdf
#' @examples
#' summary(cvlt3_brief)
"cvlt3_brief"

# (and similarly for nabs, wais5_index, wais5_subtest, wiat4)
