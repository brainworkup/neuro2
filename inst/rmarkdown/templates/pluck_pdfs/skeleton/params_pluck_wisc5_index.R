# Extract Areas - General

# Patient name ----------------------------------------------------------

patient <- "Biggie"

# WISC-V Parameters - Index Scores --------------------------------------
# do this second

test <- "wisc5_index"
test_name <- "WISC-V"
pages <- c(32, 35)
extract_columns <- c(1, 3, 4, 5, 6)
variables <- c("scale", "raw_score", "score", "percentile", "ci_95")
score_type <- "standard_score"

# File path -------------------------------------------------------------

file_path <- file.path(file.choose())
saveRDS(file_path, paste0(test, "_path.rds"))
file_path <- readRDS(paste0(test, "_path.rds"))

# Parameters -------------------------------------------------------------

params <- list(
  patient = patient,
  test = test,
  test_name = test_name,
  file = file_path,
  pages = pages,
  extract_columns = extract_columns,
  score_type = score_type,
  variables = variables
)

# Extract Areas function --------------------------------------------------

# Extracted areas
extracted_areas <- tabulapdf::extract_areas(
  file = file_path,
  pages = pages,
  method = "decide",
  output = "matrix",
  copy = TRUE
)

# Loop and Save ---------------------------------------------------------

# Save the entire list to an R data file
saveRDS(extracted_areas, file = paste0(test, "_extracted_areas.rds"))
# Load the list from the R data file (if necessary)
extracted_areas <- readRDS(paste0(test, "_extracted_areas.rds"))

# Check the extracted areas
str(extracted_areas)

# Loop over the list and write each matrix to a CSV file
for (i in seq_along(extracted_areas)) {
  write.csv(
    extracted_areas[[i]],
    file = paste0(test, "_", i, ".csv"),
    row.names = FALSE
  )
}

# To convert a single test using extracted areas into a single data frame
df1 <- as.data.frame(extracted_areas[[1]])
df2 <- as.data.frame(extracted_areas[[2]])

df <- as.data.frame(rbind(df1, df2))

# Remove asterick from the first column (wisc5 only)
df[, 2] <- gsub("\\*", "", df[, 2])

# # Remove parentheses (wisc5 subtests)
# df <- df |>
#   dplyr::mutate(V2 = stringr::str_remove_all(V2, "\\(|\\)"))

# For Wechsler Indexes
# Merge Columns 1-2 and add parentheses
library(tidyverse)
df <- df |>
  dplyr::mutate(col2_paren = paste0("(", df[[2]], ")")) |>
  tidyr::unite("scale", 1, col2_paren, sep = " ", remove = TRUE)

# FUNCTIONS ---------------------------------------

# Function to extract columns by position---------------------------

extract_columns <- params$extract_columns

# Function to extract columns by position
extract_columns_by_position <- function(df, positions) {
  df[, positions]
}

# To save the filtered data.frame separately
filtered_df <- extract_columns_by_position(df, extract_columns)

# To overwrite the original data.frame
df <- extract_columns_by_position(df, extract_columns)

# Rename the variables
colnames(df) <- params$variables

# Step 1: Replace "-" with NA in the entire dataframe
df[df == "-"] <- NA

# Step 2 (Optional): Convert 'raw score' 'score' and 'percentile' to numeric
df <- df |>
  dplyr::mutate(
    raw_score = as.numeric(raw_score),
    score = as.numeric(score),
    percentile = as.numeric(percentile)
  )

# Step 3: Remove rows where 'score' or 'percentile' are missing
df <- df |>
  dplyr::filter(!is.na(score) & !is.na(percentile)) |>
  dplyr::distinct()

# Lookup Table Match ------------------------------------------------------

# Merge the data with the lookup table
test <- "wisc5"

# Load the lookup table
lookup_table <- readr::read_csv("~/Dropbox/neuropsych_lookup_table.csv")

df_merged <- dplyr::mutate(df, test = test) |>
  dplyr::left_join(lookup_table, by = c("test" = "test", "scale" = "scale")) |>
  dplyr::relocate(all_of(c("test", "test_name")), .before = "scale")

# add missing columns
df_mutated <- NeurotypR::gpluck_make_columns(
  df_merged,
  range = "",
  result = "",
  absort = NULL
)

# Test score ranges -------------------------------------------------------

df_mutated <- df_mutated |>
  dplyr::mutate(range = NULL) |>
  NeurotypR::gpluck_make_score_ranges(
    table = df_mutated,
    test_type = "npsych_test"
  ) |>
  dplyr::relocate(c(range), .after = percentile)

# Glue results for each scale ---------------------------------------------

df <- df_mutated |>
  dplyr::mutate(
    result = ifelse(
      percentile == 1,
      glue::glue(
        "{description} fell within the {range} and ranked at the {percentile}st percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
      ),
      ifelse(
        percentile == 2,
        glue::glue(
          "{description} fell within the {range} and ranked at the {percentile}nd percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
        ),
        ifelse(
          percentile == 3,
          glue::glue(
            "{description} fell within the {range} and ranked at the {percentile}rd percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
          ),
          glue::glue(
            "{description} fell within the {range} and ranked at the {percentile}th percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"
          )
        )
      )
    )
  ) |>
  dplyr::select(-description) |>
  dplyr::relocate(absort, .after = result)

wisc5_index <- df

# Save csv ----------------------------------------------------------------

w1 <- wisc5_index
readr::write_excel_csv(w1, "data/wisc5_index.csv")

# Write out final csv --------------------------------------------------

w1 <- wisc5_index
w2 <- wisc5_subtest
w3 <- wisc5_process

wisc5 <- as.data.frame(rbind(w1, w2, w3))

test <- "wisc5"
readr::write_excel_csv(
  wisc5,
  here::here("data", "csv", paste0(test, ".csv")),
  col_names = TRUE
)

# Write to "g.csv" file --------------------------------------------------

has_headers <- function(file_path) {
  if (!file.exists(file_path)) {
    return(FALSE) # File doesn't exist, headers are needed
  }
  # Check if the file has at least one line (header)
  return(length(readLines(file_path, n = 1)) > 0)
}

csv_file <- wisc5
g <- "g"
file_path <- here::here("data", paste0(g, ".csv"))

readr::write_excel_csv(
  csv_file,
  file_path,
  append = TRUE,
  col_names = !has_headers(file_path),
  quote = "all"
)

# Print message indicating completion
cat(
  "Data for",
  test,
  "has been successfully processed and saved to",
  file_path,
  "\n"
)
