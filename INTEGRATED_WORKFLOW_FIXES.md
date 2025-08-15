# Neuropsych Workflow Fixes - Integrated Guide

This document provides a clear, integrated guide for fixing the issues in the unified neuropsych workflow.

## Issues Identified

1. **"Embedded nul in string" error in Parquet file processing**:
   - The error occurs when trying to read binary Parquet files incorrectly
   - This happens during the domain processing step when trying to read the Parquet files

2. **Missing `log_message` function in R6 update workflow**:
   - Function is defined in main runner but not in the R6 update script
   - This causes the error at the end of domain generation

## How to Fix the Issues

### 1. Fix the DuckDB data processor

The main issue is in the Parquet file processing in `R/duckdb_neuropsych_loader.R`. The fix involves using the Arrow package directly for Parquet operations and adding better error handling:

```r
# In the query_neuropsych function, modify the code that handles different file extensions:

# Find the section that handles file extensions (around line 310-340)
# and replace the Parquet handling with:

else if (ext == "parquet") {
  # For Parquet files, use arrow package instead of DuckDB's native reader
  tryCatch(
    {
      parquet_data <- arrow::read_parquet(f)
      duckdb::duckdb_register(con, table_name, parquet_data)
    },
    error = function(e) {
      warning("Failed to read parquet file ", basename(f), ": ", e$message)
      # Try to fall back to CSV if available
      csv_file <- file.path(dirname(dirname(f)), "csv", paste0(table_name, ".csv"))
      if (file.exists(csv_file)) {
        message("Falling back to CSV file: ", basename(csv_file))
        csv_data <- readr::read_csv(csv_file)
        duckdb::duckdb_register(con, table_name, csv_data)
      }
    }
  )
}
```

Also, in the `load_data_duckdb` function, modify the Parquet writing section:

```r
# Find the section that writes Parquet files (around line 205-230)
# and replace it with:

# Parquet
if (output_format %in% c("parquet", "all")) {
  message("[DuckDB] Writing Parquet files...")
  for (name in dataset_names) {
    path <- file.path(output_dir, paste0(name, ".parquet"))
    # Use arrow package directly instead of DuckDB for Parquet writing
    tryCatch(
      {
        arrow::write_parquet(result_list[[name]], path)
        message("[OK] Wrote: ", basename(path))
      },
      error = function(e) {
        warning(
          "Parquet write failed for ",
          basename(path),
          ": ",
          e$message
        )
        # Fall back to CSV if Parquet fails
        csv_path <- file.path(output_dir, paste0(name, ".csv"))
        readr::write_excel_csv(result_list[[name]], csv_path)
        message("[OK] Wrote (fallback to CSV): ", basename(csv_path))
      }
    )
  }
}
```

### 2. Fix the R6 update workflow

Add the `log_message` function to the beginning of `neuro2_R6_update_workflow.R`:

```r
# Add this after loading packages but before sourcing R6 classes (around line 10-15)

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message)
  cat(log_entry, "\n")

  # Optionally write to a log file
  log_file <- "workflow_r6_update.log"
  cat(paste0(log_entry, "\n"), file = log_file, append = TRUE)
}
```

## Understanding the Current Workflow

Your workflow already has a dynamic approach to domain processing:

1. The `unified_workflow_runner.R` script queries the data to find all unique domains:
   ```r
   domains_data <- query_neuropsych(
     "SELECT DISTINCT domain FROM neurocog WHERE domain IS NOT NULL",
     self$config$data$output_dir
   )
   ```

2. It then processes each domain dynamically:
   ```r
   for (i in 1:nrow(domains_data)) {
     domain <- domains_data$domain[i]
     # Create a domain processor for this domain
     domain_processor <- DomainProcessorR6Combo$new(
       domains = domain,
       pheno = tolower(gsub("[^a-zA-Z0-9]", "_", domain)),
       input_file = file.path(
         self$config$data$output_dir,
         "neurocog.parquet"
       ),
       output_dir = self$config$data$output_dir
     )
     # Process the domain
     domain_processor$process(
       generate_reports = TRUE,
       report_types = c("self"),
       generate_domain_files = TRUE
     )
   }
   ```

3. The `DomainProcessorR6Combo` class handles the generation of domain files based on the domain data.

This approach is already dynamic and doesn't rely on hardcoded domain lists or static helper files. The `_include_domains.qmd` file is no longer needed as the system dynamically discovers domains from the data.

## Step-by-Step Implementation

1. **Backup your files**:
   ```bash
   cp R/duckdb_neuropsych_loader.R R/duckdb_neuropsych_loader.R.bak
   cp neuro2_R6_update_workflow.R neuro2_R6_update_workflow.R.bak
   ```

2. **Edit the DuckDB data processor**:
   - Open `R/duckdb_neuropsych_loader.R`
   - Make the changes described above for Parquet file handling

3. **Edit the R6 update workflow**:
   - Open `neuro2_R6_update_workflow.R`
   - Add the `log_message` function as described above

4. **Run the workflow**:
   ```bash
   Rscript unified_workflow_runner.R config.yml
   ```

## Verification

To verify that the fixes worked:

1. Check that no "embedded nul in string" error occurs during domain processing
2. Verify that domain files are generated correctly
3. Confirm that the workflow completes successfully

## Additional Recommendations

1. **Improve Error Handling**: Add more robust error handling throughout the workflow to gracefully handle failures.

2. **Data Validation**: Add validation steps for CSV files before processing to ensure they have the expected structure.

3. **Backup Strategy**: Implement a backup strategy for generated files to prevent data loss.

4. **Logging Improvements**: Enhance the logging system to provide more detailed information about each step.

5. **Configuration Validation**: Add validation for the configuration file to ensure all required parameters are present.

## Relationship to Existing Documentation

The fixes in this document are compatible with the existing documentation:

1. **UNIFIED_WORKFLOW_README.md**: This document provides a comprehensive overview of the unified workflow system. The fixes in this document enhance the workflow without changing its architecture.

2. **README.Rmd**: This is the main package documentation that will be rendered to README.md. It provides a high-level overview of the package and its features.

The fixes in this document address specific technical issues in the workflow
without changing its overall architecture or design philosophy.
