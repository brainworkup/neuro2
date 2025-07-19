#' Compute TMT-A standardized scores (z, t, percentile)
#'
#' This function calculates standardized scores for the Trail Making Test A (TMT-A)
#' using normative data from adults (Appendix 4M, Mitrushina et al.) and imputed
#' child norms for ages 4–15. Because TMT-A is timed (higher raw = slower), scores
#' are reversed so that larger raw times yield more negative z-scores, lower t-scores,
#' and lower percentile ranks.
#'
#' @param age Numeric. Participant age in years (must be between 4 and 89).
#' @param raw_score Numeric. Raw completion time in seconds for TMT-A.
#'
#' @return A tibble with the following columns:
#' * \code{age}: Input age.
#' * \code{raw_score}: Input raw completion time.
#' * \code{predicted_mean}: Normative mean completion time for that age.
#' * \code{predicted_sd}: Normative standard deviation for that age.
#' * \code{z_score}: Reversed z-score: (mean - raw) / sd.
#' * \code{t_score}: Reversed t-score: 50 + 10 * z-score.
#' * \code{percentile}: Percentile rank (pnorm(z) * 100).
#' @export
#'
score_tmtA <- function(age, raw_score) {
  #--- Adult norms (Appendix 4M) ---#
  adult_norms <- tibble::tribble(
    ~AgeMin, ~AgeMax, ~PredictedScore, ~PredictedSD,
      16,      19,         23.97,        7.63,
      20,      24,         24.05,        7.63,
      25,      29,         24.46,        7.78,
      30,      34,         25.23,        8.05,
      35,      39,         25.34,        8.48,
      40,      44,         27.81,        9.04,
      45,      49,         29.62,        9.75,
      50,      54,         31.78,       10.59,
      55,      59,         34.30,       11.58,
      60,      64,         37.16,       12.71,
      65,      69,         40.38,       13.98,
      70,      74,         43.94,       15.40,
      75,      79,         47.85,       16.95,
      80,      84,         52.11,       18.65,
      85,      89,         56.73,       20.49
  )

  #--- Child imputation equations and anchors ---#
  pred_score_eq <- function(a) {
    26.50094 - 0.2665049 * a + 0.0069935 * a^2
  }
  pred_sd_eq <- function(a) {
    8.760348 - 0.1138093 * a + 0.0028324 * a^2
  }
  anchors <- tibble::tribble(
    ~age, ~PredictedScore, ~PredictedSD,
      8,           30.55,         13.71,
     12,           16.30,          5.70
  )

  # Build age-by-age norms for 4–15, override at anchors
  ages_df <- tibble::tibble(age = 4:15) |>
    dplyr::mutate(
      PS_eq = pred_score_eq(age),
      SD_eq = pred_sd_eq(age)
    ) |>
    dplyr::left_join(anchors, by = "age") |>
    dplyr::mutate(
      PredictedScore = dplyr::coalesce(PredictedScore, PS_eq),
      PredictedSD    = dplyr::coalesce(PredictedSD,    SD_eq)
    ) |>
    dplyr::select(age, PredictedScore, PredictedSD)

  # Aggregate into broader child age-ranges
  child_norms <- tibble::tribble(
    ~AgeMin, ~AgeMax,
       4,       7,
       8,      10,
      11,      13,
      14,      15
  ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      PredictedScore = mean(ages_df$PredictedScore[ages_df$age >= AgeMin & ages_df$age <= AgeMax]),
      PredictedSD    = mean(ages_df$PredictedSD   [ages_df$age >= AgeMin & ages_df$age <= AgeMax])
    ) |>
    dplyr::ungroup()

  # Combine child and adult norms
  norms <- dplyr::bind_rows(
    adult_norms,
    child_norms
  )

  # Find the appropriate normative row
  norm_row <- norms |>
    dplyr::filter(AgeMin <= age, age <= AgeMax)

  if (nrow(norm_row) != 1) {
    stop("Age must be between 4 and 89 (inclusive).")
  }

  m  <- norm_row$PredictedScore
  sd <- norm_row$PredictedSD

  # Compute reversed z, t, and percentile
  z <- (m - raw_score) / sd
  t <- 50 + 10 * z
  pct <- stats::pnorm(z) * 100

  # Return a one-row tibble
  tibble::tibble(
    age             = age,
    raw_score       = raw_score,
    predicted_mean  = m,
    predicted_sd    = sd,
    z_score         = z,
    t_score         = t,
    percentile      = pct
  )
}
