# data-raw/rocft_child_norms.R
# Build & install ROCFT child norms as a compressed .rda in data/

# Suggested: run from project root with:
# source("data-raw/rocft_child_norms.R")

# No library() calls in package code paths; allowed in data-raw scripts:
suppressPackageStartupMessages({
  library(tibble)
})

# Base table with provided norms (some NAs to impute)
rocft_child_norms_raw <- tibble::tribble(
  ~age,
  ~copy_m,
  ~copy_sd,
  ~recall_m,
  ~recall_sd,
  6,
  16.66,
  7.97,
  10.53,
  5.80,
  7,
  21.29,
  7.67,
  13.57,
  6.28,
  8,
  23.64,
  8.00,
  16.34,
  6.77,
  9,
  24.46,
  6.94,
  18.71,
  6.61,
  10,
  NA,
  NA,
  NA,
  NA, # to impute
  11,
  28.55,
  5.65,
  21.65,
  6.45,
  12,
  NA,
  NA,
  NA,
  NA, # to impute
  13,
  32.63,
  4.35,
  24.59,
  6.29,
  14,
  33.53,
  3.18,
  26.24,
  5.40,
  15,
  33.60,
  2.98,
  26.00,
  6.35
)

# Simple linear imputation helper (local to data build)
impute_linear <- function(x, ages) {
  ok <- !is.na(x)
  if (sum(ok) < 2L) {
    return(x)
  } # not enough points to interpolate
  stats::approx(
    x = ages[ok],
    y = x[ok],
    xout = ages,
    method = "linear",
    rule = 2
  )$y
}

# Build final dataset with imputed ages 10 & 12
ages <- rocft_child_norms_raw$age
rocft_child_norms <- within(as.data.frame(rocft_child_norms_raw), {
  copy_m <- impute_linear(copy_m, ages)
  copy_sd <- impute_linear(copy_sd, ages)
  recall_m <- impute_linear(recall_m, ages)
  recall_sd <- impute_linear(recall_sd, ages)
})

# Store as .rda in data/
# usethis is convenient but optional; base save() works too.
if (!requireNamespace("usethis", quietly = TRUE)) {
  dir.create("data", showWarnings = FALSE)
  save(
    rocft_child_norms,
    file = file.path("data", "rocft_child_norms.rda"),
    compress = "bzip2"
  )
} else {
  usethis::use_data(rocft_child_norms, overwrite = TRUE, compress = "bzip2")
}

message("Wrote data/rocft_child_norms.rda")
