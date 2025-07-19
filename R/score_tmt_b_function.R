#' Compute TMT-B standardized scores (z, t, percentile)
#'
#' This function calculates standardized scores for the Trail Making Test B (TMT-B)
#' using normative data from adults (Appendix 4M, Mitrushina et al.) and imputed
#' child norms for ages 4–15. Because TMT-B is timed (higher raw = slower), scores
#' are reversed so that larger raw times yield more negative z-scores, lower t-scores,
#' and lower percentile ranks.
#'
#' @param age Numeric. Participant age in years (must be between 4 and 89).
#' @param raw_score Numeric. Raw completion time in seconds for TMT-B.
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
score_tmtB <- function(age, raw_score) {
  #--- Adult norms for TMT-B (Appendix 4M) ---#
  adult_norms_B <- tibble::tribble(
    ~AgeMin, ~AgeMax, ~PredictedScore, ~PredictedSD,
      16,      19,         53.92,       20.12,
      20,      24,         53.77,       19.19,
      25,      29,         54.72,       18.87,
      30,      34,         56.84,       19.29,
      35,      39,         60.15,       20.46,
      40,      44,         64.63,       22.37,
      45,      49,         70.29,       25.02,
      50,      54,         77.13,       28.42,
      55,      59,         85.15,       32.55,
      60,      64,         94.34,       37.44,
      65,      69,        104.71,       43.07,
      70,      74,        116.26,       49.44,
      75,      79,        128.99,       56.55,
      80,      84,        142.90,       64.41,
      85,      89,        157.98,       73.01
  )

  #--- Child imputation equations and anchors for TMT-B ---#
  pred_score_eq_B <- function(a) {
    64.07469 - 0.9881013 * a + 0.0235581 * a^2
  }
  pred_sd_eq_B <- function(a) {
    29.8444  - 0.8080508 * a + 0.0148732 * a^2
  }
  anchors_B <- tibble::tribble(
    ~age, ~PredictedScore, ~PredictedSD,
      8,    71.85,            34.60,
     12,    35.70,            12.50
  )

  # Build age-by-age norms for 4–15, override at anchors
  ages_B_df <- tibble::tibble(age = 4:15) |>
    dplyr::mutate(
      PS_eq = pred_score_eq_B(age),
      SD_eq = pred_sd_eq_B(age)
    ) |>
    dplyr::left_join(anchors_B, by = "age") |>
    dplyr::mutate(
      PredictedScore = dplyr::coalesce(PredictedScore, PS_eq),
      PredictedSD    = dplyr::coalesce(PredictedSD,    SD_eq)
    ) |>
    dplyr::select(age, PredictedScore, PredictedSD)

  # Aggregate into broader child age-ranges
  child_norms_B <- tibble::tribble(
    ~AgeMin, ~AgeMax,
       4,       7,
       8,      10,
      11,      13,
      14,      15
  ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      PredictedScore = mean(ages_B_df$PredictedScore[ages_B_df$age >= AgeMin & ages_B_df$age <= AgeMax]),
      PredictedSD    = mean(ages_B_df$PredictedSD   [ages_B_df$age >= AgeMin & ages_B_df$age <= AgeMax])
    ) |>
    dplyr::ungroup()

  # Combine child and adult norms
  norms <- dplyr::bind_rows(adult_norms_B, child_norms_B)

  # Find the appropriate normative row
  norm_row <- norms |>
    dplyr::filter(AgeMin <= age, age <= AgeMax)

  if (nrow(norm_row) != 1) {
    stop("Age must be between 4 and 89 (inclusive).")
  }

  m  <- norm_row$PredictedScore
  sd <- norm_row$PredictedSD

  # Compute reversed z, t, and percentile
  z   <- (m - raw_score) / sd
  t   <- 50 + 10 * z
  pct <- stats::pnorm(z) * 100

  # Return a one-row tibble
  tibble::tibble(
    age            = age,
    raw_score      = raw_score,
    predicted_mean = m,
    predicted_sd   = sd,
    z_score        = z,
    t_score        = t,
    percentile     = pct
  )
}
