# Load necessary libraries
library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(glue)
library(here)
library(qs)
library(tabulapdf)
library(bwu) # Assuming this package provides `calc_ci_95()` and `gpluck_make_columns()`

# Define the function to set test parameters
set_test_params <- function(test, test_name, pages, extract_columns, variables, score_type) {
  list(
    test = test,
    test_name = test_name,
    pages = pages,
    extract_columns = extract_columns,
    variables = variables,
    score_type = score_type
  )
}

# Define the function to extract data
extract_data <- function(file, pages, extract_columns) {
  extracted_areas <- tabulapdf::extract_areas(file = file, pages = pages, method = "decide", output = "matrix", copy = TRUE)
  lapply(extracted_areas, function(x) x[, extract_columns])
}

# Define the function to mutate and clean dataframe
clean_data <- function(df, params) {
  colnames(df) <- params$variables
  df[df == "-"] <- NA
  df <- df %>%
    mutate(across(c(raw_score, score, percentile), as.numeric)) %>%
    filter(!is.na(score) & !is.na(percentile))
  df
}

# Define the function to create confidence intervals
add_confidence_intervals <- function(df) {
  for (i in seq_len(nrow(df))) {
    ci_values <- bwu::calc_ci_95(ability_score = df$score[i], mean = 10, standard_deviation = 3, reliability = 0.90)
    df[i, c("true_score", "ci_lo", "ci_hi")] <- ci_values[c("true_score", "lower_ci_95", "upper_ci_95")]
    df$ci_95[i] <- paste0(ci_values["lower_ci_95"], " - ", ci_values["upper_ci_95"])
  }
  df <- df %>%
    select(-true_score, -ci_lo, -ci_hi) %>%
    relocate(ci_95, .after = score)
  df
}

# Define the function to merge with lookup table
merge_with_lookup <- function(df, lookup_table_path) {
  lookup_table <- readr::read_csv(lookup_table_path)
  df_merged <- df %>%
    mutate(test = params$test) %>%
    left_join(lookup_table, by = c("test" = "test", "scale" = "scale")) %>%
    relocate(all_of(c("test", "test_name")), .before = "scale")

  df_mutated <- bwu::gpluck_make_columns(df_merged, range = "", result = "", absort = NULL) %>%
    mutate(range = NULL) %>%
    bwu::gpluck_make_score_ranges(table = ., test_type = "npsych_test") %>%
    relocate(c(range), .after = percentile)

  df_mutated
}

# Define the function to generate result text
generate_result <- function(df) {
  # Ensure 'description' and 'range' columns exist and have no NA values
  df <- df %>%
    mutate(
      result = case_when(
        percentile == 1 ~ glue("{description} fell within the {range} and ranked at the {percentile}st percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"),
        percentile == 2 ~ glue("{description} fell within the {range} and ranked at the {percentile}nd percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"),
        percentile == 3 ~ glue("{description} fell within the {range} and ranked at the {percentile}rd percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"),
        !is.na(percentile) ~ glue("{description} fell within the {range} and ranked at the {percentile}th percentile, indicating performance as good as or better than {percentile}% of same-age peers from the general population.\n"),
        TRUE ~ NA_character_
      )
    ) %>%
    select(-description) %>%
    relocate(absort, .after = result)
}

# Define the function to write output
write_output <- function(df, test_name, g) {
  readr::write_excel_csv(df, here::here("data", "csv", paste0(test_name, ".csv")), col_names = TRUE)

  file_path <- here::here("data", paste0(g, ".csv"))
  append_header <- ifelse(!file.exists(file_path) || (length(readLines(file_path, n = 1)) == 0), TRUE, FALSE)

  readr::write_excel_csv(df, file_path, append = TRUE, col_names = append_header, quote = "all")
}

# Main processing routine

patient <- "Biggie" # Define patient name

# Example for WISC-V Subtests
wisc5_params <- set_test_params("wisc5", "WISC-V", c(7), c(2, 4, 5, 6), c("scale", "raw_score", "score", "percentile"), "scaled_score")

file <- file.path(file.choose())
qs::qsave(file, paste0(wisc5_params$test, "_path.rds"))
file <- qs::qread(paste0(wisc5_params$test, "_path.rds"))

extracted_data <- extract_data(file, wisc5_params$pages, wisc5_params$extract_columns)
df <- do.call(rbind, lapply(extracted_data, data.frame)) # Convert and combine extracted areas to data frame
df_clean <- clean_data(df, wisc5_params) # Clean data
df_with_ci <- add_confidence_intervals(df_clean) # Add confidence intervals

df_final <- merge_with_lookup(df_with_ci, "~/reports/neuropsych_lookup_table_combined.csv") # Merge with lookup table
df_result <- generate_result(df_final) # Generate descriptive results

write_output(df_result, wisc5_params$test, "g2") # Write outputs



# Verifying the lookup table structure
lookup_table <- readr::read_csv("~/reports/neuropsych_lookup_table_combined.csv")

# Make sure the lookup_table has the columns you expect for joining
glimpse(lookup_table) # Make sure columns like 'test', 'scale' exist.

# Define the function to merge with lookup table
merge_with_lookup <- function(df, lookup_table_path) {
  # Load the lookup table
  lookup_table <- readr::read_csv(lookup_table_path)

  # Merge with the lookup table
  df_merged <- df %>%
    mutate(test = params$test) %>%
    left_join(lookup_table, by = c("test" = "test", "scale" = "scale")) %>%
    relocate(all_of(c("test", "test_name")), .before = "scale")

  # Ensure the merge was successful and inspect the first few rows for debugging
  print(head(df_merged))

  df_mutated <- bwu::gpluck_make_columns(df_merged, range = "", result = "", absort = NULL) %>%
    mutate(range = NULL) %>% # Temporary placeholder to avoid missing error
    mutate(range = dplyr::case_when(
      percentile >= 98 ~ "Exceptionally High",
      percentile %in% 91:97 ~ "Very High",
      percentile %in% 75:90 ~ "High",
      percentile %in% 25:74 ~ "Average",
      percentile %in% 9:24 ~ "Low Average",
      percentile %in% 2:8 ~ "Very Low",
      percentile >= 1 ~ "Exceptionally Low",
      TRUE ~ NA_character_ # Default case catches any unexpected values
    )) %>%
    bwu::gpluck_make_score_ranges(table = ., test_type = "npsych_test") %>%
    relocate(c(range), .after = percentile)

  # Return the mutated result
  df_mutated
}

# Now attempt to run your function again to see if this resolves the issue
df_final <- merge_with_lookup(df_with_ci, "~/reports/neuropsych_lookup_table_combined.csv")

# Now apply function again to the dataframe
df_result <- generate_result(df_final)

# Printing the first few rows to verify
print(df_result)
