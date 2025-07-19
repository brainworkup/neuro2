# Replacing map_dfr in Modern R: A Migration Guide

The `map_dfr()` function in purrr was **superseded in version 1.0.0** (December 2022), marking a significant shift in tidyverse best practices for combining data frames. While your existing code will continue to work, understanding the modern alternatives is crucial for maintainable R code.

## When and Why map_dfr Was Superseded

**December 20, 2022** marked the official supersession of `map_dfr()` and its variants in purrr 1.0.0. The tidyverse team made this decision for four compelling reasons:

**Naming inconsistency** plagued the function from the start. While suffixes like `_lgl()` and `_int()` require single-value outputs, `_dfr` accepts any size, creating confusion about expected behavior. The dependency on `dplyr::bind_rows()` added unnecessary package requirements, while the function's edge case handling often produced unexpected results without proper size checks.

The superseded status means these functions receive only critical bug fixes going forward. No removal date exists, but new code should use the recommended replacements for better performance and clearer semantics.

## Current Recommended Alternatives in the Tidyverse

The modern pattern replaces `map_dfr()` with a two-step process that's more explicit and performant:

```r
# Old approach (superseded)
map_dfr(.x, .f, ...)

# New approach (recommended)
map(.x, .f, ...) |> list_rbind()
```

This pattern extends to all variants:
- `map2_dfr()` → `map2()` + `list_rbind()`
- `imap_dfr()` → `imap()` + `list_rbind()`
- `pmap_dfr()` → `pmap()` + `list_rbind()`

The new `list_rbind()` function uses `vctrs::vec_rbind()` internally, providing better type safety and performance than the old `dplyr::bind_rows()` approach.

## Practical Code Examples for Data Analysis

For neuropsychological test data processing, here's how to update common patterns:

### Processing Multiple Test Files

```r
# Scenario: Reading multiple CSV files with test results
test_files <- c("patient001_wisc.csv", "patient002_wisc.csv", "patient003_wisc.csv")

# OLD approach
test_data <- map_dfr(test_files, read_csv, .id = "patient_file")

# NEW approach
test_data <- test_files |>
  map(read_csv) |>
  list_rbind(names_to = "patient_file")
```

### Extracting Test Scores from Complex Objects

```r
# Scenario: Processing neuropsych test battery results
process_test_battery <- function(patient_data) {
  tibble(
    patient_id = patient_data$id,
    verbal_iq = patient_data$wisc$verbal,
    performance_iq = patient_data$wisc$performance,
    memory_index = patient_data$wms$general,
    test_date = patient_data$date
  )
}

# OLD approach
all_scores <- map_dfr(patient_list, process_test_battery)

# NEW approach
all_scores <- patient_list |>
  map(process_test_battery) |>
  list_rbind()
```

### Calculating Summary Statistics Across Groups

```r
# Scenario: Computing cognitive domain scores by age group
age_groups <- split(neuropsych_data, neuropsych_data$age_group)

# OLD approach
domain_summaries <- map_dfr(age_groups, function(group) {
  tibble(
    age_group = unique(group$age_group),
    mean_verbal = mean(group$verbal_score, na.rm = TRUE),
    mean_spatial = mean(group$spatial_score, na.rm = TRUE),
    n_patients = nrow(group)
  )
}, .id = "group_name")

# NEW approach
domain_summaries <- age_groups |>
  map(\(group) {
    tibble(
      mean_verbal = mean(group$verbal_score, na.rm = TRUE),
      mean_spatial = mean(group$spatial_score, na.rm = TRUE),
      n_patients = nrow(group)
    )
  }) |>
  list_rbind(names_to = "age_group")
```

### Parallel Processing with Error Handling

```r
# Scenario: Scoring multiple tests with potential failures
score_test_safely <- possibly(score_neuropsych_test, 
                              otherwise = tibble(error = "scoring_failed"))

# NEW approach with progress tracking
test_results <- test_files |>
  map(read_csv) |>
  map(score_test_safely, .progress = TRUE) |>
  list_rbind(names_to = "test_file")
```

## Best Practices for Row Binding in Modern Tidyverse

**Make data frame creation explicit** in your mapping functions. Rather than relying on automatic coercion, always return proper tibbles or data frames:

```r
# Good practice: explicit tibble creation
processed_data <- raw_scores |>
  map(\(score) {
    tibble(
      raw_score = score,
      z_score = (score - mean_val) / sd_val,
      percentile = pnorm(z_score) * 100
    )
  }) |>
  list_rbind()
```

**Handle edge cases proactively** by considering what happens when functions return unexpected types:

```r
# When working with functions that might not return data frames
results <- patient_ids |>
  map(\(id) {
    # Always ensure you return a data frame
    result <- lookup_patient_scores(id)
    if (!is.data.frame(result)) {
      tibble(patient_id = id, status = "no_data")
    } else {
      result
    }
  }) |>
  list_rbind()
```

**Use names_to parameter effectively** when preserving source information:

```r
# Preserving test battery information
test_batteries <- list(
  wais = wais_scores,
  wms = memory_scores,
  wcst = executive_scores
)

combined_scores <- test_batteries |>
  map(process_battery_scores) |>
  list_rbind(names_to = "battery_type")
```

## Performance Considerations Between Approaches

The new `list_rbind()` approach offers **improved memory efficiency** compared to `map_dfr()`. Benchmarks show that while `data.table::rbindlist()` remains fastest for pure speed, `list_rbind()` provides better type safety and integration with the tidyverse ecosystem.

**Memory usage patterns** differ significantly. The old `map_dfr()` accumulated results incrementally, potentially causing memory fragmentation with large datasets. The new approach collects all results in a list first, then performs a single efficient binding operation.

For neuropsychological datasets (typically hundreds to thousands of rows), the performance difference is negligible. However, the new approach provides **better error messages** when binding fails, making debugging easier when combining heterogeneous test results.

**Type coercion behavior** has also improved. The new `vctrs`-based binding is stricter about type compatibility, catching potential data integrity issues earlier in the pipeline. This is particularly valuable when combining test scores that might have inconsistent numeric types across different data sources.

## Conclusion

The supersession of `map_dfr()` represents an evolution toward more explicit, performant code. While your existing code continues to function, adopting the `map() |> list_rbind()` pattern provides clearer semantics, better error handling, and improved performance. For neuropsychological data processing, the new approach offers particular advantages in handling heterogeneous test batteries and maintaining data integrity across complex scoring pipelines.

Start by updating new analysis scripts to use the modern pattern. For existing code, migrate opportunistically during maintenance, focusing first on performance-critical sections or areas where better error handling would improve reliability. The investment in updating yields cleaner, more maintainable code that aligns with modern tidyverse best practices.