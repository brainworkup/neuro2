# Neuropsych Workflow Fixes

This document provides instructions for fixing the issues in the unified neuropsych workflow.

## Issues Identified

1. **"Embedded nul in string" error in Parquet file processing**:
   - The error occurs when trying to read binary Parquet files incorrectly
   - Fixed by improving error handling in the DuckDB data processor

2. **Missing domain files referenced in `_include_domains.qmd`**:
   - Files like `_02-01_iq.qmd` don't exist because domain generation failed
   - Fixed by adding a function to create placeholder domain files

3. **Missing `log_message` function in R6 update workflow**:
   - Function is defined in main runner but not in the R6 update script
   - Fixed by adding the `log_message` function to `neuro2_R6_update_workflow.R`

4. **Missing `IQReportGeneratorR6.R` file**:
   - This R6 class file is expected but doesn't exist
   - Fixed by creating this file with a complete implementation

## How to Apply the Fixes

Follow these steps to apply the fixes to your project:

1. **Fix the DuckDB data processor**:
   ```bash
   # Backup the original file
   cp R/duckdb_neuropsych_loader.R R/duckdb_neuropsych_loader.R.bak
   
   # Replace with the fixed version
   cp R/duckdb_neuropsych_loader_fixed.R R/duckdb_neuropsych_loader.R
   ```

2. **Fix the R6 update workflow**:
   ```bash
   # Backup the original file
   cp neuro2_R6_update_workflow.R neuro2_R6_update_workflow.R.bak
   
   # Replace with the fixed version
   cp neuro2_R6_update_workflow_fixed.R neuro2_R6_update_workflow.R
   ```

3. **Add the missing IQReportGeneratorR6.R file**:
   ```bash
   # The file has been created at R/IQReportGeneratorR6.R
   # No action needed if it's already in place
   ```

4. **Add the domain files checker**:
   ```bash
   # The file has been created at R/check_and_create_domain_files.R
   # No action needed if it's already in place
   ```

5. **Update the unified_workflow_runner.R file**:
   - Add the following line to the end of the `generate_domains` method in the `WorkflowRunner` class, right before the `return(TRUE)` statement:
   
   ```r
   # Source the check_and_create_domain_files.R file
   source("R/check_and_create_domain_files.R")
   
   # Call the function to check and create missing domain files
   check_and_create_domain_files(log_message)
   ```

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
2. Verify that all expected domain files are created (even if as placeholders)
3. Confirm that the workflow completes successfully

## Additional Recommendations

1. **Improve Error Handling**: Add more robust error handling throughout the workflow to gracefully handle failures.

2. **Data Validation**: Add validation steps for CSV files before processing to ensure they have the expected structure.

3. **Backup Strategy**: Implement a backup strategy for generated files to prevent data loss.

4. **Logging Improvements**: Enhance the logging system to provide more detailed information about each step.

5. **Configuration Validation**: Add validation for the configuration file to
   ensure all required parameters are present.
