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

#' NABS Data
#'
#' A sample dataset of scores from the Neuropsychological Assessment Battery (NABS).
#'
#' @format A data frame with \code{n} rows and the following columns:
#' \describe{
#'   \item{test}{\code{character} Test name (e.g., "NABS")}
#'   \item{test_name}{\code{character} Specific name of the subtest}
#'   \item{scale}{\code{character} Scale name (subtest name)}
#'   \item{raw_score}{\code{numeric} Raw score on the subtest}
#'   \item{score}{\code{numeric} Standard score}
#'   \item{ci_95}{\code{character} 95\% confidence interval for the score}
#'   \item{percentile}{\code{numeric} Percentile rank}
#'   \item{range}{\code{character} Qualitative description of the score range}
#'   \item{domain}{\code{character} Broad domain of the subtest}
#'   \item{subdomain}{\code{character} Subdomain within the broad domain}
#'   \item{narrow}{\code{character} Narrow ability measured by the subtest}
#'   \item{pass}{\code{character} Processing attribute (e.g., "Sequential")}
#'   \item{verbal}{\code{character} Verbal/nonverbal classification}
#'   \item{timed}{\code{character} Timed/untimed classification}
#'   \item{test_type}{\code{character} Type of test}
#'   \item{score_type}{\code{character} Type of score reported}
#'   \item{result}{\code{character} Textual description of the result}
#'   \item{absort}{\code{character} Unique identifier for the row}
#' }
#' @source Clinical NABS report, extracted via tabulapdf
#' @examples
#' head(nabs)
"nabs"

#' WAIS-5
#'
#' A sample dataset of scores from the Wechsler Adult Intelligence Scale, Fifth Edition (WAIS-5).
#'
#' @format A data frame with \code{n} rows and the following columns:
#' \describe{
#'   \item{test}{\code{character} Test name (e.g., "WAIS-5")}
#'   \item{test_name}{\code{character} Specific name of the index}
#'   \item{scale}{\code{character} Index name}
#'   \item{raw_score}{\code{numeric} Raw score on the index}
#'   \item{score}{\code{numeric} Standard score}
#'   \item{ci_95}{\code{character} 95\% confidence interval for the score}
#'   \item{percentile}{\code{numeric} Percentile rank}
#'   \item{range}{\code{character} Qualitative description of the score range}
#'   \item{domain}{\code{character} Broad domain of the index}
#'   \item{subdomain}{\code{character} Subdomain within the broad domain}
#'   \item{narrow}{\code{character} Narrow ability measured by the index}
#'   \item{pass}{\code{character} Processing attribute (e.g., "Sequential")}
#'   \item{verbal}{\code{character} Verbal/nonverbal classification}
#'   \item{timed}{\code{character} Timed/untimed classification}
#'   \item{test_type}{\code{character} Type of test}
#'   \item{score_type}{\code{character} Type of score reported}
#'   \item{result}{\code{character} Textual description of the result}
#'   \item{absort}{\code{character} Unique identifier for the row}
#' }
#' @source Clinical WAIS-5 report, extracted via tabulapdf
#' @examples
#' head(wais5)
"wais5"


#' WIAT-4 Subtest Scores
#'
#' A sample dataset of subtest scores from the Wechsler Individual Achievement Test, Fourth Edition (WIAT-4).
#'
#' @format A data frame with \code{n} rows and the following columns:
#' \describe{
#'   \item{test}{\code{character} Test name (e.g., "WIAT-4")}
#'   \item{test_name}{\code{character} Specific name of the subtest}
#'   \item{scale}{\code{character} Subtest name}
#'   \item{raw_score}{\code{numeric} Raw score on the subtest}
#'   \item{score}{\code{numeric} Standard score}
#'   \item{ci_95}{\code{character} 95\% confidence interval for the score}
#'   \item{percentile}{\code{numeric} Percentile rank}
#'   \item{range}{\code{character} Qualitative description of the score range}
#'   \item{domain}{\code{character} Broad domain of the subtest}
#'   \item{subdomain}{\code{character} Subdomain within the broad domain}
#'   \item{narrow}{\code{character} Narrow ability measured by the subtest}
#'   \item{pass}{\code{character} Processing attribute (e.g., "Sequential")}
#'   \item{verbal}{\code{character} Verbal/nonverbal classification}
#'   \item{timed}{\code{character} Timed/untimed classification}
#'   \item{test_type}{\code{character} Type of test}
#'   \item{score_type}{\code{character} Type of score reported}
#'   \item{result}{\code{character} Textual description of the result}
#'   \item{absort}{\code{character} Unique identifier for the row}
#' }
#' @source Clinical WIAT-4 report, extracted via tabulapdf
#' @examples
#' head(wiat4)
"wiat4"
