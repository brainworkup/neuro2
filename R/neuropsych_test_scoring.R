#' @title Rey Complex Figure, Copy Trial Score Lookup
#' @description Calculates a Rey Complex Figure, Copy trial score (T-score) from a raw score and age. The predicted score and standard deviation are also calculated.
#' @param age A numeric value of the age of the participant. Must be between 16 and 89 years old.
#' @param raw_score A numeric value of the raw score from the Rey Complex Figure, Copy trial.
#' @return Returns a numeric value of the T-score for the Rey Complex Figure, Copy trial.
#' @details This function takes the raw score and age of a participant and calculates the Rey Complex Figure, Copy trial T-score using the formula provided by \emph{Manly et al. (2000)}. It also returns the predicted score and standard deviation for the trial.
#' @references Manly, J.J., Schinka, J.A., & Guerrero, L. (2000). Normative Data on the Rey Complex Figure Test in Older Adults. Archives of Clinical Neuropsychology, 15(7), 613-621.
#' @rdname rocft_copy_t_score
#' @export
rocft_copy_t_score <- function(age, raw_score) {
  MIN_AGE <- 16
  MAX_AGE <- 89

  validate_inputs <- function(age, raw_score) {
    if (raw_score == "") {
      return("No raw score provided")
    }

    if (age == "") {
      return("No age provided")
    }

    if (!is.numeric(raw_score)) {
      return("Raw score must be numeric")
    }

    if (!is.numeric(age)) {
      return("Age must be numeric")
    }

    if (age < MIN_AGE) {
      return(paste0("Age must be ", MIN_AGE, " or older"))
    }

    if (age > MAX_AGE) {
      return(paste0("Age must be ", MAX_AGE, " or younger"))
    }
    return(NULL)
  }

  validation_message <- validate_inputs(age, raw_score)
  if (!is.null(validation_message)) {
    return(validation_message)
  }

  predicted_score <- 34.40434 + (0.0595862 * age) - (0.0013855 * (age * age))

  predicted_sd <- -0.333026 + (0.0625042 * age)

  z_score <- (raw_score - predicted_score) / predicted_sd
  t_score <- (z_score * 10) + 50

  t_score <- round(t_score, digits = 0)
  z_score <- round(z_score, digits = 2)

  predicted_score <- round(predicted_score, digits = 2)
  predicted_sd <- round(predicted_sd, digits = 2)

  return(paste0(
    "ROCFT Copy T-Score: ",
    t_score,
    ", z-Score = ",
    z_score,
    ", Predicted Score = ",
    predicted_score,
    ", Predicted SD = ",
    predicted_sd
  ))
}

#' @title Rey Complex Figure, Long-Term Delayed Recall Score Lookup
#' @description Calculates a Rey Complex Figure, Delayed Recall (30-min) trial score (T-score) from a raw score and age. The predicted score and standard deviation are also calculated.
#' @param age A numeric value of the age of the participant. Must be between 16 and 89 years old.
#' @param raw_score A numeric value of the raw score from the Rey Complex Figure, Copy trial.
#' @return Returns a numeric value of the T-score for the Rey Complex Figure, Copy trial.
#' @details This function takes the raw score and age of a participant and calculates the Rey Complex Figure, Copy trial T-score using the formula provided by \emph{Manly et al. (2000)}. It also returns the predicted score and standard deviation for the trial.
#' @references Manly, J.J., Schinka, J.A., & Guerrero, L. (2000). Normative Data on the Rey Complex Figure Test in Older Adults. Archives of Clinical Neuropsychology, 15(7), 613-621.
#' @rdname rocft_recall_t_score
#' @export
rocft_recall_t_score <- function(age, raw_score) {
  MIN_AGE <- 16
  MAX_AGE <- 89

  validate_inputs <- function(age, raw_score) {
    if (raw_score == "") {
      return("No raw score provided")
    }

    if (age == "") {
      return("No age provided")
    }

    if (!is.numeric(raw_score)) {
      return("Raw score must be numeric")
    }

    if (!is.numeric(age)) {
      return("Age must be numeric")
    }

    if (age < MIN_AGE) {
      return(paste0("Age must be ", MIN_AGE, " or older"))
    }

    if (age > MAX_AGE) {
      return(paste0("Age must be ", MAX_AGE, " or younger"))
    }

    return(NULL)
  }

  validation_message <- validate_inputs(age, raw_score)
  if (!is.null(validation_message)) {
    return(validation_message)
  }

  predicted_score <- 25.39903 + (0.0416485 * age) - (0.0022144 * (age * age))

  # SD same across groups
  predicted_sd <- 6.67

  z_score <- (raw_score - predicted_score) / predicted_sd
  t_score <- (z_score * 10) + 50

  t_score <- round(t_score, digits = 0)
  z_score <- round(z_score, digits = 2)

  predicted_score <- round(predicted_score, digits = 2)
  predicted_sd <- round(predicted_sd, digits = 2)

  return(paste0(
    "ROCFT Delayed Recall T-Score: ",
    t_score,
    ", z-Score = ",
    z_score,
    ", Predicted Score = ",
    predicted_score,
    ", Predicted SD = ",
    predicted_sd
  ))
}


#' @title Grooved Pegboard, Dominant Hand
#' @description Calculates a Rey Complex Figure, Copy trial score (T-score) from a raw score and age. The predicted score and standard deviation are also calculated.
#' @param age A numeric value of the age of the participant. Must be between 16 and 89 years old.
#' @param raw_score A numeric value of the raw score from the Rey Complex Figure, Copy trial.
#' @return Returns a numeric value of the T-score for the Rey Complex Figure, Copy trial.
#' @rdname pegboard_dominant_hand
#' @export
pegboard_dominant_hand <- function(age, raw_score) {
  MIN_AGE <- 20
  MAX_AGE <- 64

  validate_inputs <- function(age, raw_score) {
    if (raw_score == "") {
      return("No raw score provided")
    }

    if (age == "") {
      return("No age provided")
    }

    if (!is.numeric(raw_score)) {
      return("Raw score must be numeric")
    }

    if (!is.numeric(age)) {
      return("Age must be numeric")
    }

    if (age < MIN_AGE) {
      return(paste0("Age must be ", MIN_AGE, " or older"))
    }

    if (age > MAX_AGE) {
      return(paste0("Age must be ", MAX_AGE, " or younger"))
    }
    return(NULL)
  }

  validation_message <- validate_inputs(age, raw_score)
  if (!is.null(validation_message)) {
    return(validation_message)
  }

  predicted_score <- 48.18889 + 0.4337963 * age

  predicted_sd <- -5.442114 + (0.7862791 * age) - (0.0077628 * (age * age))

  # For GPT, a lower raw score is better, so we invert the z-score calculation.
  z_score <- (predicted_score - raw_score) / predicted_sd

  t_score <- (z_score * 10) + 50

  t_score <- round(t_score, digits = 0)
  z_score <- round(z_score, digits = 2)

  predicted_score <- round(predicted_score, digits = 2)
  predicted_sd <- round(predicted_sd, digits = 2)

  return(paste0(
    "GPT Dominant Hand: ",
    t_score,
    ", z-Score = ",
    z_score,
    ", Predicted Score = ",
    predicted_score,
    ", Predicted SD = ",
    predicted_sd
  ))
}

#' @title Grooved Pegboard, NonDominant Hand
#' @description Calculates a GPT dominant hand (T-score) from a raw score and age. The predicted score and standard deviation are also calculated.
#' @param age A numeric value of the age of the participant. Must be between 16 and 89 years old.
#' @param raw_score A numeric value of the raw score from the GPT nondom.
#' @return Returns a numeric value of the T-score for the GPT nondom hand trial.
#' @rdname pegboard_nondominant_hand
#' @export
pegboard_nondominant_hand <- function(age, raw_score) {
  MIN_AGE <- 20
  MAX_AGE <- 64

  validate_inputs <- function(age, raw_score) {
    if (raw_score == "") {
      return("No raw score provided")
    }

    if (age == "") {
      return("No age provided")
    }

    if (!is.numeric(raw_score)) {
      return("Raw score must be numeric")
    }

    if (!is.numeric(age)) {
      return("Age must be numeric")
    }

    if (age < MIN_AGE) {
      return(paste0("Age must be ", MIN_AGE, " or older"))
    }

    if (age > MAX_AGE) {
      return(paste0("Age must be ", MAX_AGE, " or younger"))
    }
    return(NULL)
  }

  validation_message <- validate_inputs(age, raw_score)
  if (!is.null(validation_message)) {
    return(validation_message)
  }

  predicted_score <- 53.27121 + 0.460912 * age

  predicted_sd <- -5.48594 + (0.8551187 * age) - (0.0085961 * (age * age))

  # For GPT, a lower raw score is better, so we invert the z-score calculation.
  z_score <- (predicted_score - raw_score) / predicted_sd

  t_score <- (z_score * 10) + 50

  t_score <- round(t_score, digits = 0)

  z_score <- round(z_score, digits = 2)

  predicted_score <- round(predicted_score, digits = 2)

  predicted_sd <- round(predicted_sd, digits = 2)

  return(paste0(
    "GPT NonDominant Hand: ",
    t_score,
    ", z-Score = ",
    z_score,
    ", Predicted Score = ",
    predicted_score,
    ", Predicted SD = ",
    predicted_sd
  ))
}

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
    ~AgeMin,
    ~AgeMax,
    ~PredictedScore,
    ~PredictedSD,
    16,
    19,
    23.97,
    7.63,
    20,
    24,
    24.05,
    7.63,
    25,
    29,
    24.46,
    7.78,
    30,
    34,
    25.23,
    8.05,
    35,
    39,
    25.34,
    8.48,
    40,
    44,
    27.81,
    9.04,
    45,
    49,
    29.62,
    9.75,
    50,
    54,
    31.78,
    10.59,
    55,
    59,
    34.30,
    11.58,
    60,
    64,
    37.16,
    12.71,
    65,
    69,
    40.38,
    13.98,
    70,
    74,
    43.94,
    15.40,
    75,
    79,
    47.85,
    16.95,
    80,
    84,
    52.11,
    18.65,
    85,
    89,
    56.73,
    20.49
  )

  #--- Child imputation equations and anchors ---#
  pred_score_eq <- function(a) {
    26.50094 - 0.2665049 * a + 0.0069935 * a^2
  }
  pred_sd_eq <- function(a) {
    8.760348 - 0.1138093 * a + 0.0028324 * a^2
  }
  anchors <- tibble::tribble(
    ~age,
    ~PredictedScore,
    ~PredictedSD,
    8,
    30.55,
    13.71,
    12,
    16.30,
    5.70
  )

  # Build age-by-age norms for 4–15, override at anchors
  ages_df <- tibble::tibble(age = 4:15) |>
    dplyr::mutate(
      # Create PS_eq and SD_eq columns with equation results
      PS_eq = pred_score_eq(.data$age),
      SD_eq = pred_sd_eq(.data$age)
    ) |>
    dplyr::left_join(anchors, by = "age") |>
    dplyr::mutate(
      # Use coalesce to fill in values from equations if not in anchors
      PredictedScore = dplyr::coalesce(.data$PredictedScore, .data$PS_eq),
      PredictedSD = dplyr::coalesce(.data$PredictedSD, .data$SD_eq)
    ) |>
    dplyr::select(age, PredictedScore, PredictedSD)

  # Aggregate into broader child age-ranges
  child_norms <- tibble::tribble(
    ~AgeMin,
    ~AgeMax,
    4,
    7,
    8,
    10,
    11,
    13,
    14,
    15
  ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      PredictedScore = mean(ages_df$PredictedScore[
        ages_df$age >= .data$AgeMin & ages_df$age <= .data$AgeMax
      ]),
      PredictedSD = mean(ages_df$PredictedSD[
        ages_df$age >= .data$AgeMin & ages_df$age <= .data$AgeMax
      ])
    ) |>
    dplyr::ungroup()

  # Combine child and adult norms
  norms <- dplyr::bind_rows(adult_norms, child_norms)

  # Find the appropriate normative row
  norm_row <- norms |> dplyr::filter(norms$AgeMin <= age, age <= norms$AgeMax)

  if (nrow(norm_row) != 1) {
    stop("Age must be between 4 and 89 (inclusive).")
  }

  m <- norm_row$PredictedScore
  sd <- norm_row$PredictedSD

  # Compute reversed z, t, and percentile
  z <- (m - raw_score) / sd
  t <- 50 + 10 * z
  pct <- stats::pnorm(z) * 100

  # Return a one-row tibble
  tibble::tibble(
    age = age,
    raw_score = raw_score,
    predicted_mean = m,
    predicted_sd = sd,
    z_score = z,
    t_score = t,
    percentile = pct
  )
}

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
    ~AgeMin,
    ~AgeMax,
    ~PredictedScore,
    ~PredictedSD,
    16,
    19,
    53.92,
    20.12,
    20,
    24,
    53.77,
    19.19,
    25,
    29,
    54.72,
    18.87,
    30,
    34,
    56.84,
    19.29,
    35,
    39,
    60.15,
    20.46,
    40,
    44,
    64.63,
    22.37,
    45,
    49,
    70.29,
    25.02,
    50,
    54,
    77.13,
    28.42,
    55,
    59,
    85.15,
    32.55,
    60,
    64,
    94.34,
    37.44,
    65,
    69,
    104.71,
    43.07,
    70,
    74,
    116.26,
    49.44,
    75,
    79,
    128.99,
    56.55,
    80,
    84,
    142.90,
    64.41,
    85,
    89,
    157.98,
    73.01
  )

  #--- Child imputation equations and anchors for TMT-B ---#
  pred_score_eq_B <- function(a) {
    64.07469 - 0.9881013 * a + 0.0235581 * a^2
  }
  pred_sd_eq_B <- function(a) {
    29.8444 - 0.8080508 * a + 0.0148732 * a^2
  }
  anchors_B <- tibble::tribble(
    ~age,
    ~PredictedScore,
    ~PredictedSD,
    8,
    71.85,
    34.60,
    12,
    35.70,
    12.50
  )

  # Build age-by-age norms for 4–15, override at anchors
  ages_df <- tibble::tibble(age = 4:15) |>
    dplyr::mutate(
      # Create PS_eq and SD_eq columns with equation results
      PS_eq = pred_score_eq(.data$age),
      SD_eq = pred_sd_eq(.data$age)
    ) |>
    dplyr::left_join(anchors, by = "age") |>
    dplyr::mutate(
      # Use coalesce to fill in values from equations if not in anchors
      PredictedScore = dplyr::coalesce(.data$PredictedScore, .data$PS_eq),
      PredictedSD = dplyr::coalesce(.data$PredictedSD, .data$SD_eq)
    ) |>
    dplyr::select(age, PredictedScore, PredictedSD)
  # Build age-by-age norms for 4–15, override at anchors
  ages_B_df <- tibble::tibble(age = 4:15) |>
    dplyr::mutate(
      # Create PS_eq and SD_eq columns with equation results
      PS_eq = pred_score_eq_B(.data$age),
      SD_eq = pred_sd_eq_B(.data$age)
    ) |>
    dplyr::left_join(anchors_B, by = "age") |>
    dplyr::mutate(
      # Use coalesce to fill in values from equations if not in anchors
      PredictedScore = dplyr::coalesce(.data$PredictedScore, .data$PS_eq),
      PredictedSD = dplyr::coalesce(.data$PredictedSD, .data$SD_eq)
    ) |>
    dplyr::select(age, PredictedScore, PredictedSD)

  # Aggregate into broader child age-ranges
  child_norms <- tibble::tribble(
    ~AgeMin,
    ~AgeMax,
    4,
    7,
    8,
    10,
    11,
    13,
    14,
    15
  ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      PredictedScore = mean(ages_df$PredictedScore[
        ages_df$age >= .data$AgeMin & ages_df$age <= .data$AgeMax
      ]),
      PredictedSD = mean(ages_df$PredictedSD[
        ages_df$age >= .data$AgeMin & ages_df$age <= .data$AgeMax
      ])
    ) |>
    dplyr::ungroup()
  # Aggregate into broader child age-ranges
  child_norms_B <- tibble::tribble(
    ~AgeMin,
    ~AgeMax,
    4,
    7,
    8,
    10,
    11,
    13,
    14,
    15
  ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      PredictedScore = mean(ages_B_df$PredictedScore[
        ages_B_df$age >= .data$AgeMin & ages_B_df$age <= .data$AgeMax
      ]),
      PredictedSD = mean(ages_B_df$PredictedSD[
        ages_B_df$age >= .data$AgeMin & ages_B_df$age <= .data$AgeMax
      ])
    ) |>
    dplyr::ungroup()

  # Combine child and adult norms
  norms <- dplyr::bind_rows(adult_norms, child_norms)

  # Find the appropriate normative row
  norm_row <- norms |> dplyr::filter(norms$AgeMin <= age, age <= norms$AgeMax)
  # Combine child and adult norms
  norms <- dplyr::bind_rows(adult_norms_B, child_norms_B)

  # Find the appropriate normative row
  norm_row <- norms |> dplyr::filter(norms$AgeMin <= age, age <= norms$AgeMax)

  if (nrow(norm_row) != 1) {
    stop("Age must be between 4 and 89 (inclusive).")
  }

  m <- norm_row$PredictedScore
  sd <- norm_row$PredictedSD

  # Compute reversed z, t, and percentile
  z <- (m - raw_score) / sd
  t <- 50 + 10 * z
  pct <- stats::pnorm(z) * 100

  # Return a one-row tibble
  tibble::tibble(
    age = age,
    raw_score = raw_score,
    predicted_mean = m,
    predicted_sd = sd,
    z_score = z,
    t_score = t,
    percentile = pct
  )
}
