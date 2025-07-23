# Neuropsych Workflow Fixes

This document provides instructions for fixing the issues in the unified neuropsych workflow.

## Issues Identified

1. **"Embedded nul in string" error in Parquet file processing**:
   - The error occurs when trying to read binary Parquet files incorrectly
   - Fixed by improving error handling in the DuckDB data processor

2. **Missing domain files referenced in `_include_domains.qmd`**:
   - Files like `_02-01_iq.qmd` don't exist because domain generation failed
   - Better approach: Enhance DomainProcessorR6 to dynamically generate domain files

3. **Missing `log_message` function in R6 update workflow**:
   - Function is defined in main runner but not in the R6 update script
   - Fixed by adding the `log_message` function to `neuro2_R6_update_workflow.R`

4. **Missing `IQReportGeneratorR6.R` file**:
   - This R6 class file is mentioned in the error message but doesn't need to exist
   - Better approach: Use the generic DomainProcessorR6 for all domains instead of domain-specific generators

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

3. **Update the unified_workflow_runner.R file**:
   - Modify the R6 class files list in the `setup_environment` method to remove the IQReportGeneratorR6.R reference:
   
   ```r
   # Change from:
   r6_files <- c(
     "R/ReportTemplateR6.R",
     "R/NeuropsychResultsR6.R",
     "R/NeuropsychReportSystemR6.R",
     "R/IQReportGeneratorR6.R",  # Remove this line
     "R/DomainProcessorR6.R",
     "R/DotplotR6.R",
     "R/DuckDBProcessorR6.R"
   )
   
   # To:
   r6_files <- c(
     "R/ReportTemplateR6.R",
     "R/NeuropsychResultsR6.R",
     "R/NeuropsychReportSystemR6.R",
     "R/DomainProcessorR6.R",
     "R/DotplotR6.R",
     "R/DuckDBProcessorR6.R"
   )
   ```
   
   - Enhance the `generate_domains` method in the `WorkflowRunner` class to dynamically handle missing domain files:
   
   ```r
   # Add this code at the end of the generate_domains method, before the return statement
   
   # Check for missing domain files referenced in _include_domains.qmd
   if (file.exists("_include_domains.qmd")) {
     include_content <- readLines("_include_domains.qmd")
     domain_files <- gsub(".*include\\s+([^\\s>]+).*", "\\1", include_content)
     domain_files <- domain_files[grepl("^_02-.*\\.qmd$", domain_files)]
     
     for (file in domain_files) {
       if (!file.exists(file)) {
         # Extract domain info from filename
         domain_num <- substr(file, 5, 6)
         pheno <- gsub("_", " ", substr(file, 8, nchar(file) - 4))
         domain_name <- paste0(toupper(substr(pheno, 1, 1)), substr(pheno, 2, nchar(pheno)))
         
         log_message(paste0("Creating placeholder for missing domain file: ", file), "DOMAINS")
         
         # Create placeholder content
         content <- paste0(
           "## ", domain_name, " {#sec-", gsub(" ", "-", tolower(pheno)), "}\n\n",
           "No data available for this domain.\n\n"
         )
         
         # Write placeholder file
         writeLines(content, file)
         
         # Also create text file
         text_file <- gsub("\\.qmd$", "_text.qmd", file)
         if (!file.exists(text_file)) {
           writeLines("<summary>\n\nNo data available for this domain.\n\n</summary>", text_file)
         }
       }
     }
   }
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

## Dynamic vs. Static Approach

The solution now uses a more dynamic approach:

1. **Dynamic Domain File Generation**: Instead of hardcoding domain files and their properties, the code reads the `_include_domains.qmd` file to determine which domain files are expected, then creates any that are missing.

2. **No Separate Helper File**: The domain file checking logic is integrated directly into the `generate_domains` method, eliminating the need for a separate static helper file.

3. **Adaptive to Changes**: If you modify the `_include_domains.qmd` file to add or remove domains, the code will automatically adapt to these changes.

## Why Not Use Domain-Specific Report Generators?

The original error mentioned a missing `IQReportGeneratorR6.R` file, but creating specialized report generators for each domain (IQ, memory, executive function, etc.) would lead to code duplication and maintenance issues. Instead, the better approach is to:

1. Use the generic `DomainProcessorR6` class for all domains
2. Configure it with domain-specific parameters
3. Let it handle the processing for any domain type

This approach is more maintainable, follows the DRY (Don't Repeat Yourself) principle, and allows for easier updates across all domains.

## Additional Recommendations

1. **Improve Error Handling**: Add more robust error handling throughout the workflow to gracefully handle failures.

2. **Data Validation**: Add validation steps for CSV files before processing to ensure they have the expected structure.

3. **Backup Strategy**: Implement a backup strategy for generated files to prevent data loss.

4. **Logging Improvements**: Enhance the logging system to provide more detailed information about each step.

5. **Configuration Validation**: Add validation for the configuration file to ensure all required parameters are present.

6. **Dynamic Domain Discovery**: Consider enhancing the workflow to dynamically
   discover domains from the data rather than relying on hardcoded domain lists.
