library(dplyr)
library(tibble)

# 1) Adult TMT-A norms from Appendix 4M (Table A4m.1)
tmtA_adult <- tribble(
  ~AgeMin, ~AgeMax, ~PredictedScore, ~CI_lower, ~CI_upper, ~PredictedSD, ~SD_CI_lower, ~SD_CI_upper,
  16,      19,       23.97,          22.33,      25.62,      7.63,          6.59,         8.67,
  20,      24,       24.05,          23.07,      25.02,      7.63,          7.09,         8.18,
  25,      29,       24.46,          23.74,      25.18,      7.78,          7.15,         8.39,
  30,      34,       25.23,          24.24,      26.21,      8.05,          7.03,         9.07,
  35,      39,       25.34,          25.04,      27.65,      8.48,          7.10,         9.86,
  40,      44,       27.81,          26.28,      29.33,      9.04,          7.40,        10.68,
  45,      49,       29.62,          27.99,      31.24,      9.75,          7.95,        11.54,
  50,      54,       31.78,          30.17,      33.40,     10.59,          8.74,        12.44,
  55,      59,       34.30,          32.74,      35.86,     11.58,          9.76,        13.40,
  60,      64,       37.16,          35.59,      38.74,     12.71,         10.98,        14.45,
  65,      69,       40.38,          38.56,      42.19,     13.98,         12.34,        15.63,
  70,      74,       43.94,          41.57,      46.31,     15.40,         13.74,        17.05,
  75,      79,       47.85,          44.63,      51.07,     16.95,         15.08,        18.82,
  80,      84,       52.11,          47.78,      56.44,     18.65,         16.30,        20.99,
  85,      89,       56.73,          51.07,      62.38,     20.49,         17.43,        23.54
)

# 2) Imputation for child age‐ranges using the published quadratic equations
pred_score_eq <- function(age) {
  26.50094 - 0.2665049 * age + 0.0069935 * age^2
}
pred_sd_eq <- function(age) {
  8.760348 - 0.1138093 * age + 0.0028324 * age^2
}

# your “anchor” norms at age 8 & 12
anchors <- tribble(
  ~age, ~PredictedScore, ~PredictedSD,
  8,         30.55,        13.71,
  12,         16.30,         5.70
)

# compute eq‐based norms for ages 4–15, then override at 8 & 12
ages_df <- tibble(age = 4:15) %>%
  mutate(
    PS_eq = pred_score_eq(age),
    SD_eq = pred_sd_eq(age)
  ) %>%
  left_join(anchors, by = "age") %>%
  mutate(
    PredictedScore = coalesce(PredictedScore, PS_eq),
    PredictedSD    = coalesce(PredictedSD,    SD_eq)
  ) %>%
  select(age, PredictedScore, PredictedSD)

# define the child age‐ranges
child_ranges <- tribble(
  ~AgeRange, ~AgeMin, ~AgeMax,
  "4-7",       4,       7,
  "8-10",      8,      10,
  "11-13",    11,      13,
  "14-15",    14,      15
)

# average the predictions within each range
tmtA_child_imputed <- child_ranges %>%
  rowwise() %>%
  mutate(
    Ages = list(seq(AgeMin, AgeMax)),
    PredictedScore = mean(ages_df$PredictedScore[ages_df$age %in% Ages]),
    PredictedSD    = mean(ages_df$PredictedSD[ages_df$age %in% Ages])
  ) %>%
  select(AgeRange, PredictedScore, PredictedSD)

# view results
tmtA_adult
tmtA_child_imputed
