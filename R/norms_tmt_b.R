library(dplyr)
library(tibble)

# 1) Adult TMT-B norms from your screenshot
tmtB_adult <- tribble(
  ~AgeMin, ~AgeMax, ~PredictedScore, ~CI_lower, ~CI_upper, ~PredictedSD, ~SD_CI_lower, ~SD_CI_upper,
  16,      19,       53.92,          49.21,      58.63,      20.12,         14.76,        25.48,
  20,      24,       53.77,          50.54,      56.99,      19.19,         14.93,        23.45,
  25,      29,       54.72,          51.69,      57.74,      18.87,         15.09,        22.65,
  30,      34,       56.84,          52.89,      60.80,      19.29,         15.30,        23.29,
  35,      39,       60.15,          55.05,      65.25,      20.46,         15.88,        25.03,
  40,      44,       64.63,          58.50,      70.77,      22.37,         17.11,        27.62,
  45,      49,       70.29,          63.29,      77.30,      25.02,         19.10,        30.94,
  50,      54,       77.13,          69.40,      84.86,      28.42,         21.86,        34.97,
  55,      59,       85.15,          76.76,      93.54,      32.55,         25.37,        39.74,
  60,      64,       94.34,          85.24,     103.45,      37.44,         29.55,        45.33,
  65,      69,      104.71,          94.71,     114.72,      43.07,         34.33,        51.80,
  70,      74,      116.26,         105.03,     127.50,      49.44,         39.63,        59.24,
  75,      79,      128.99,         116.11,     141.88,      56.55,         45.38,        67.72,
  80,      84,      142.90,         127.86,     157.94,      64.41,         51.54,        77.28,
  85,      89,      157.98,         140.26,     175.71,      73.01,         58.07,        87.95
)

# 2) Quadratic equations for prediction
pred_score_eq_B <- function(age) {
  64.07469 - 0.9881013 * age + 0.0235581 * age^2
}
pred_sd_eq_B <- function(age) {
  29.8444  - 0.8080508 * age + 0.0148732 * age^2
}

# 3) Child “anchor” norms at age 8 & 12 for TMT-B
anchors_B <- tribble(
  ~age, ~PredictedScore, ~PredictedSD,
  8,    71.85,            34.60,
  12,    35.70,            12.50
)

# 4) Build age‐by‐age table 4–15, eq‐based then override with anchors
ages_B_df <- tibble(age = 4:15) %>%
  mutate(
    PS_eq = pred_score_eq_B(age),
    SD_eq = pred_sd_eq_B(age)
  ) %>%
  left_join(anchors_B, by = "age") %>%
  mutate(
    PredictedScore = coalesce(PredictedScore, PS_eq),
    PredictedSD    = coalesce(PredictedSD,    SD_eq)
  ) %>%
  select(age, PredictedScore, PredictedSD)

# 5) Define the child age‐ranges
child_ranges <- tribble(
  ~AgeRange, ~AgeMin, ~AgeMax,
  "4-7",       4,       7,
  "8-10",      8,      10,
  "11-13",    11,      13,
  "14-15",    14,      15
)

# 6) Average within each range
tmtB_child_imputed <- child_ranges %>%
  rowwise() %>%
  mutate(
    Ages = list(seq(AgeMin, AgeMax)),
    PredictedScore = mean(ages_B_df$PredictedScore[ages_B_df$age %in% Ages]),
    PredictedSD    = mean(ages_B_df$PredictedSD   [ages_B_df$age %in% Ages])
  ) %>%
  select(AgeRange, PredictedScore, PredictedSD)

# View results
tmtB_adult
tmtB_child_imputed
