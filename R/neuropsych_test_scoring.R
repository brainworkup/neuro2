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

  predicted_score <-
    34.40434 + (0.0595862 * age) - (0.0013855 * (age * age))

  predicted_sd <-
    -0.333026 + (0.0625042 * age)

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

  predicted_score <-
    25.39903 + (0.0416485 * age) - (0.0022144 * (age * age))

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

  predicted_score <-
    48.18889 + 0.4337963 * age

  predicted_sd <-
    -5.442114 + (0.7862791 * age) - (0.0077628 * (age * age))

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

  predicted_score <-
    53.27121 + 0.460912 * age

  predicted_sd <-
    -5.48594 + (0.8551187 * age) - (0.0085961 * (age * age))

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
