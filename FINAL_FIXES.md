# Neuropsych Workflow Fixes - Final Version

This document provides instructions for fixing the issues in the unified neuropsych workflow.

## Issues Identified

1. **"Embedded nul in string" error in Parquet file processing**:
   - The error occurs when trying to read binary Parquet files incorrectly
   - Fixed by improving error handling in the DuckDB data processor

2. **Missing `log_message` function in R6 update workflow**:
   - Function is defined in main runner but not in the R6 update script
   - Fixed by adding the `log_message` function to `neuro2_R6_update_workflow.R`

## How to Apply the Fixes

Follow these steps to apply the fixes to your project:

### 1. Fix the DuckDB data processor

The main issue is in the Parquet file processing in `R/duckdb_neuropsych_loader.R`. The fix involves using the Arrow package directly for Parquet operations and adding better error handling:

```r
# In the query_neuropsych function, replace the existing code for handling Parquet files with:

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
# Replace the Parquet writing section with:

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
# Add this after loading packages but before sourcing R6 classes

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

## Dynamic Domain Processing

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
     domain_processor <- DomainProcessorR6$new(
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

3. The `DomainProcessorR6` class handles the generation of domain files based on the domain data.

This approach is already dynamic and doesn't rely on hardcoded domain lists or static helper files.

## Running the Fixed Workflow

After applying the fixes, run the workflow using:

```bash
Rscript unified_workflow_runner.R config.yml
```

Or use the shell script:

```bash
./unified_neuropsych_workflow.sh
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

5. **Configuration Validation**: Add validation for the configuration file to
   ensure all required parameters are present.
