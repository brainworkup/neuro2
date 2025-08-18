
# rocft_child_norms.R
# Adds child norms for ROCFT Copy & Delayed Recall, ages 6–15.
# Missing values at ages 10 and 12 are linearly imputed.
# Ages 16–18 intentionally left without child norms (use adult norms).

suppressPackageStartupMessages({
  library(dplyr)
})

# Build base table with provided norms (some NAs to impute)
.rocft_child_raw <- tibble::tribble(
  ~age, ~copy_m, ~copy_sd, ~recall_m, ~recall_sd,
    6,   16.66,    7.97,     10.53,      5.80,
    7,   21.29,    7.67,     13.57,      6.28,
    8,   23.64,    8.00,     16.34,      6.77,
    9,   24.46,    6.94,     18.71,      6.61,
   10,      NA,      NA,         NA,        NA,  # to impute
   11,   28.55,    5.65,     21.65,      6.45,
   12,      NA,      NA,         NA,        NA,  # to impute
   13,   32.63,    4.35,     24.59,      6.29,
   14,   33.53,    3.18,     26.24,      5.40,
   15,   33.60,    2.98,     26.00,      6.35
)

# Simple linear imputation helper
.impute_linear <- function(x, ages) {
  ok <- !is.na(x)
  if (sum(ok) < 2L) return(x)  # not enough points to interpolate
  approx(x = ages[ok], y = x[ok], xout = ages, method = "linear", rule = 2)$y
}

# Construct final child norms table with imputed 10 & 12
rocft_child_norms <- (function() {
  df <- .rocft_child_raw
  ages <- df$age
  df$copy_m   <- .impute_linear(df$copy_m,   ages)
  df$copy_sd  <- .impute_linear(df$copy_sd,  ages)
  df$recall_m <- .impute_linear(df$recall_m, ages)
  df$recall_sd<- .impute_linear(df$recall_sd,ages)
  df
})()

#' Score ROCFT child norms (ages 6–15)
#' @param trial One of "copy" or "recall"
#' @param age Numeric age in years
#' @param raw_score Numeric raw score
#' @return A tibble with age, raw_score, mean, sd, z, T, percentile
rocft_child_score <- function(trial = c("copy", "recall"), age, raw_score) {
  trial <- match.arg(trial)
  if (is.na(age) || is.na(raw_score)) return(NULL)
  if (age < 6 || age > 15) return(NULL)  # no child norms beyond this; use adult path
  row <- dplyr::filter(rocft_child_norms, age == !!round(age))
  if (nrow(row) == 0) return(NULL)

  if (trial == "copy") {
    m  <- row$copy_m
    sd <- row$copy_sd
  } else {
    m  <- row$recall_m
    sd <- row$recall_sd
  }

  if (is.na(m) || is.na(sd) || sd <= 0) return(NULL)

  z  <- (raw_score - m) / sd
  t  <- 50 + 10 * z
  pct<- pnorm(z) * 100

  tibble::tibble(
    age = round(age), raw_score = raw_score,
    mean = m, sd = sd,
    z = z, t = t, percentile = pct
  )
}

# Convenience wrappers that produce a short HTML summary for Quarto/Shiny
rocft_copy_child <- function(age, raw_score) {
  res <- rocft_child_score("copy", age, raw_score)
  if (is.null(res)) return(NULL)
  sprintf(
    "ROCFT Copy (Child Norms, age %d): Raw=%s; Mean=%.2f, SD=%.2f; z=%.2f, T=%.1f, Percentile=%.1f",
    res$age, res$raw_score, res$mean, res$sd, res$z, res$t, res$percentile
  )
}

rocft_recall_child <- function(age, raw_score) {
  res <- rocft_child_score("recall", age, raw_score)
  if (is.null(res)) return(NULL)
  sprintf(
    "ROCFT Delayed Recall (Child Norms, age %d): Raw=%s; Mean=%.2f, SD=%.2f; z=%.2f, T=%.1f, Percentile=%.1f",
    res$age, res$raw_score, res$mean, res$sd, res$z, res$t, res$percentile
  )
}
