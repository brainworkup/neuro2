# R/rocft_child_norms.R
# Documentation + scoring helpers for ROCFT child norms

#' ROCFT Child Norms (Ages 6–15)
#'
#' Normative data for the Rey–Osterrieth Complex Figure Test (ROCFT) for children
#' aged 6 to 15. Includes means and standard deviations for both the Copy and
#' Delayed Recall trials. Ages 10 and 12 are imputed linearly from surrounding
#' ages. Ages 16–18 are intentionally excluded (use adult norms).
#'
#' @details
#' Imputation uses simple linear interpolation (`stats::approx`) between the nearest
#' available ages. Use this dataset to compute z/T/percentiles for raw Copy and
#' Delayed Recall scores in this age range.
#'
#' @format A data frame with 10 rows and 5 variables:
#' \describe{
#'   \item{age}{Age in years (integer).}
#'   \item{copy_m}{Mean raw score for the Copy trial.}
#'   \item{copy_sd}{Standard deviation for the Copy trial raw score.}
#'   \item{recall_m}{Mean raw score for the Delayed Recall trial.}
#'   \item{recall_sd}{Standard deviation for the Delayed Recall trial raw score.}
#' }
#' @usage # Data is embedded in rocft_child_score() function for compatibility
#' @source Derived from commonly cited neuropsychological sources; missing ages
#' 10 and 12 imputed for package use. Consult primary literature for specifics.
#' @keywords datasets
#' @docType data
#' @name rocft_child_norms
NULL

#' Score ROCFT Child Norms (Ages 6–15)
#'
#' Calculate normative scores (z, T, percentile) for the ROCFT based on child
#' norms for ages 6–15.
#'
#' @param trial Character string; one of \code{"copy"} or \code{"recall"}.
#' @param age Numeric; child's age in years (6–15). Non-integer ages are rounded.
#' @param raw_score Numeric; raw score for the specified trial.
#'
#' @return A tibble with columns:
#' \itemize{
#'   \item \code{age} (rounded)
#'   \item \code{raw_score}
#'   \item \code{mean}
#'   \item \code{sd}
#'   \item \code{z}
#'   \item \code{t} (T-score)
#'   \item \code{percentile}
#' }
#' Returns \code{NULL} if age is outside 6–15 or inputs are invalid.
#'
#' @examples
#' rocft_child_score(trial = "copy",   age = 7,  raw_score = 22)
#' rocft_child_score(trial = "recall", age = 13, raw_score = 20)
#'
#' @export
#' @importFrom dplyr filter
#' @importFrom tibble tibble
#' @importFrom stats pnorm
#' @importFrom utils data
rocft_child_score <- function(trial = c("copy", "recall"), age, raw_score) {
  trial <- match.arg(trial)
  if (is.na(age) || is.na(raw_score)) {
    return(NULL)
  }

  # Embed the data directly to avoid R CMD check data loading issues
  # This small dataset is appropriate to embed given the consistent loading problems
  rocft_child_norms <- data.frame(
    age = c(6, 7, 8, 9, 10, 11, 12, 13, 14, 15),
    copy_m = c(
      16.66,
      21.29,
      23.64,
      24.46,
      26.505,
      28.55,
      30.595,
      32.63,
      33.53,
      33.60
    ),
    copy_sd = c(7.97, 7.67, 8.00, 6.94, 6.295, 5.65, 4.995, 4.35, 3.18, 2.98),
    recall_m = c(
      10.53,
      13.57,
      16.34,
      18.71,
      20.18,
      21.65,
      23.12,
      24.59,
      26.24,
      26.00
    ),
    recall_sd = c(5.80, 6.28, 6.77, 6.61, 6.53, 6.45, 6.37, 6.29, 5.40, 6.35),
    stringsAsFactors = FALSE
  )

  age_r <- round(age)
  if (age_r < 6 || age_r > 15) {
    return(NULL)
  } # use adult path outside this range

  row <- dplyr::filter(rocft_child_norms, age == !!age_r)
  if (nrow(row) == 0) {
    return(NULL)
  }

  if (trial == "copy") {
    m <- row$copy_m
    sd <- row$copy_sd
  } else {
    m <- row$recall_m
    sd <- row$recall_sd
  }

  if (is.na(m) || is.na(sd) || sd <= 0) {
    return(NULL)
  }

  z <- (raw_score - m) / sd
  t <- 50 + 10 * z
  pct <- stats::pnorm(z) * 100

  tibble::tibble(
    age = age_r,
    raw_score = raw_score,
    mean = as.numeric(m),
    sd = as.numeric(sd),
    z = as.numeric(z),
    t = as.numeric(t),
    percentile = as.numeric(pct)
  )
}

#' ROCFT Copy (Child Norms) — Convenience Wrapper
#'
#' Convenience wrapper around \code{\link{rocft_child_score}} that returns a short
#' formatted summary string for the Copy trial.
#'
#' @param age Numeric; child's age in years (6–15). Non-integer ages are rounded.
#' @param raw_score Numeric; raw score for the Copy trial.
#'
#' @return A single formatted character string, or \code{NULL} if scoring
#' is not possible.
#'
#' @seealso \code{\link{rocft_child_score}}
#' @examples
#' rocft_copy_child(age = 8, raw_score = 24)
#'
#' @export
rocft_copy_child <- function(age, raw_score) {
  res <- rocft_child_score("copy", age, raw_score)
  if (is.null(res)) {
    return(NULL)
  }

  sprintf(
    "ROCFT Copy (Child Norms, age %d): Raw=%s; Mean=%.2f, SD=%.2f; z=%.2f, T=%.1f, Percentile=%.1f",
    res$age,
    res$raw_score,
    res$mean,
    res$sd,
    res$z,
    res$t,
    res$percentile
  )
}

#' ROCFT Delayed Recall (Child Norms) — Convenience Wrapper
#'
#' Convenience wrapper around \code{\link{rocft_child_score}} that returns a short
#' formatted summary string for the Delayed Recall trial.
#'
#' @param age Numeric; child's age in years (6–15). Non-integer ages are rounded.
#' @param raw_score Numeric; raw score for the Delayed Recall trial.
#'
#' @return A single formatted character string, or \code{NULL} if scoring
#' is not possible.
#'
#' @seealso \code{\link{rocft_child_score}}
#' @examples
#' rocft_recall_child(age = 11, raw_score = 21)
#' rocft_child_score("copy", 7, 22)
#' rocft_child_score("recall", 13, 20)
#' rocft_copy_child(8, 24)
#'
#' @export
rocft_recall_child <- function(age, raw_score) {
  res <- rocft_child_score("recall", age, raw_score)
  if (is.null(res)) {
    return(NULL)
  }

  sprintf(
    "ROCFT Delayed Recall (Child Norms, age %d): Raw=%s; Mean=%.2f, SD=%.2f; z=%.2f, T=%.1f, Percentile=%.1f",
    res$age,
    res$raw_score,
    res$mean,
    res$sd,
    res$z,
    res$t,
    res$percentile
  )
}
