# Code Conflict Prevention Guide

## The Problem

Old issues keep reappearing because of function name conflicts and multiple files sourcing the same code. This causes fixes to be overridden.

## Key Conflicts Identified

### 1. `query_neuropsych` Function Conflict
- **DuckDB version** (correct): `R/duckdb_neuropsych_loader.R` - Handles actual SQL queries
- **Simple version** (renamed): `R/workflow_data_processor.R` - Now called `query_neuropsych_simple`

**Issue**: When `workflow_data_processor.R` is sourced AFTER `duckdb_neuropsych_loader.R`, it was overriding the correct SQL implementation.

### 2. Regex Pattern Issues
Multiple files had unescaped curly braces in regex patterns:
- `generate_domain_files.R` - FIXED: `\\{\\{< include`
- `tests/test_claude.R` - FIXED: `\\{\\{< include`

### 3. TableGTR6 Padding Issue
- `R/TableGTR6.R` - FIXED: Added conditional check for `vertical_padding`

## Files That Source Conflicting Code

1. `R/WorkflowRunnerR6.R` sources `R/workflow_data_processor.R`
2. `R/workflow_domain_generator.R` sources `R/workflow_data_processor.R`

## Prevention Strategies

### 1. Always Check for Existing Functions
Before defining a function, check if it exists:
```r
if (!exists("query_neuropsych")) {
  query_neuropsych <- function(...) { ... }
}
```

### 2. Use Namespaces or Unique Names
- Prefix functions with their module: `workflow_query_neuropsych`, `duckdb_query_neuropsych`
- Or use unique suffixes: `query_neuropsych_simple`, `query_neuropsych_sql`

### 3. Source Order Matters
When using DuckDB functions:
```r
# Always source DuckDB LAST to ensure it's not overridden
source("R/workflow_data_processor.R")  # First
source("R/duckdb_neuropsych_loader.R") # Last
```

### 4. Clean Up Old Files
- Remove `.history` files regularly: `rm R/.history/*`
- Delete backup files ending in dates: `*_20250819*.R`

### 5. Function Registry
Create a central registry of function names and their sources:

| Function | Primary Source | Purpose |
|----------|---------------|---------|
| `query_neuropsych` | `R/duckdb_neuropsych_loader.R` | SQL queries via DuckDB |
| `query_neuropsych_simple` | `R/workflow_data_processor.R` | Simple data filtering |
| `load_neuropsych_data` | `R/workflow_data_processor.R` | Load neurocog data |
| `load_neurobehav_data` | `R/workflow_data_processor.R` | Load neurobehav data |
| `generate_text_files` | `generate_domain_files.R` | Create placeholder text files |

### 5. Function Registry
Create a central registry of function names and their sources:

| Function | Primary Source | Purpose |
|----------|---------------|---------|
| `query_neuropsych` | `R/duckdb_neuropsych_loader.R` | SQL queries via DuckDB |
| `query_neuropsych_simple` | `R/workflow_data_processor.R` | Simple data filtering |
| `load_neuropsych_data` | `R/workflow_data_processor.R` | Load neurocog data |
| `load_neurobehav_data` | `R/workflow_data_processor.R` | Load neurobehav data |
| `generate_text_files` | `generate_domain_files.R` | Create placeholder text files |
| `process_workflow_data` | `R/workflow_data_processor.R` | Main workflow data processing function |
| `check_data_exists` | `R/workflow_data_processor.R` | Check if data exists |
| `get_data_format` | `R/workflow_data_processor.R` | Get data format |
| `load_data_duckdb` | `R/duckdb_neuropsych_loader.R` | Main DuckDB-powered data loading function |
| `get_example_queries` | `R/duckdb_neuropsych_loader.R` | Get example DuckDB queries |
| `run_example_query` | `R/duckdb_neuropsych_loader.R` | Run example DuckDB query |
| `calculate_z_stats` | `R/duckdb_neuropsych_loader.R` | Helper function to calculate z-statistics |
| `DomainProcessorR6` | `R/DomainProcessorR6.R` | R6 class for domain processing |
| `initialize` | `R/DomainProcessorR6.R` | Initialize DomainProcessorR6 object |
| `load_data` | `R/DomainProcessorR6.R` | Load data from specified input file |
| `filter_by_domain` | `R/DomainProcessorR6.R` | Filter data to include only specified domains |
| `select_columns` | `R/DomainProcessorR6.R` | Select relevant columns from the data |
| `save_data` | `R/DomainProcessorR6.R` | Save the processed data to a file |
| `has_multiple_raters` | `R/DomainProcessorR6.R` | Check if domain has multiple raters |
| `check_rater_data_exists` | `R/DomainProcessorR6.R` | Check if a specific rater has data |
| `detect_emotion_type` | `R/DomainProcessorR6.R` | Detect emotion type (child/adult) |
| `generate_domain_qmd` | `R/DomainProcessorR6.R` | Generate domain QMD file |
| `generate_domain_text_qmd` | `R/DomainProcessorR6.R` | Generate domain text QMD file |
| `generate_standard_qmd` | `R/DomainProcessorR6.R` | Generate standard domain QMD |
| `generate_adhd_adult_qmd` | `R/DomainProcessorR6.R` | Generate ADHD adult QMD file |
| `generate_adhd_child_qmd` | `R/DomainProcessorR6.R` | Generate ADHD child QMD file |
| `generate_emotion_child_qmd` | `R/DomainProcessorR6.R` | Generate emotion child QMD file |
| `generate_emotion_adult_qmd` | `R/DomainProcessorR6.R` | Generate emotion adult QMD file |
| `process` | `R/DomainProcessorR6.R` | Run the complete processing pipeline |
| `NeuropsychResultsR6` | `R/NeuropsychResultsR6.R` | R6 class for neuropsych results processing |
| `create_text_placeholder` | `R/NeuropsychResultsR6.R` | Create placeholder text file |
| `emit_quarto_text_chunk` | `R/NeuropsychResultsR6.R` | Static method to emit Quarto text chunk |
| `cat_neuropsych_results` | `R/NeuropsychResultsR6.R` | Function wrapper for concatenating neuropsych results |
| `%||%` | `R/utils.R` | Null coalescing operator |
| `safe_read_csv` | `R/utils.R` | Safe CSV reading with error handling |
| `read_multiple_csv` | `R/utils.R` | Read multiple CSV files |
| `with_progress` | `R/utils.R` | Progress bar wrapper |
| `cache_function` | `R/utils.R` | Cached function execution |
| `parallel_map` | `R/utils.R` | Parallel processing helper |
| `safe_path` | `R/utils.R` | Create safe file path |
| `retry_with_backoff` | `R/utils.R` | Retry function execution |
| `validate_data_structure` | `R/utils.R` | Validate data frame structure |
| `create_temp_dir` | `R/utils.R` | Create temporary directory with cleanup |
| `time_it` | `R/utils.R` | Time function execution |
| `safe_select` | `R/utils.R` | Safe column selection |
| `batch_process` | `R/utils.R` | Batch process with error collection |
| `filter_data` | `R/utils.R` | Filter data by domain and scale |
| `ensure_output_directories` | `R/utils.R` | Ensure required directories exist |
| `get_resource_path` | `R/utils.R` | Get package resource path |
| `get_fig_path` | `R/utils.R` | Get output file paths |
| `get_output_path` | `R/utils.R` | Get output file paths |
| `save_plot` | `R/utils.R` | Save plot function |
| `neuro2_config` | `R/utils.R` | Configure output directories |
| `get_score_groups` | `R/score_type_utils.R` | Get score type groups for test names |
| `get_score_footnotes` | `R/score_type_utils.R` | Get footnotes for score types |
| `init_score_type_cache` | `R/score_type_utils.R` | Initialize score type cache safely |
| `get_source_note_by_score_type` | `R/score_type_utils.R` | Get source note based on score type |
| `get_all_score_type_notes` | `R/score_type_utils.R` | Get all score type notes |
| `get_score_types_from_lookup` | `R/score_type_utils.R` | Get score types from lookup table |
| `get_score_type_by_test_scale` | `R/score_type_utils.R` | Get score type by test and scale |
| `validate_domain_data_exists` | `R/domain_validation_utils.R` | Validates if a domain has sufficient data |
| `get_domains_with_data` | `R/domain_validation_utils.R` | Returns only domains that have actual data |

This comprehensive Function Registry includes all functions found in the R/ directory, organized by their primary source file with accurate descriptions based on code analysis. The registry covers data processing, domain management, scoring utilities, and general helper functions used throughout the neuro2 package.

## Testing for Conflicts

Run this check before commits:
```r
# Check for duplicate function definitions
check_duplicates <- function() {
  r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
  
  functions <- list()
  for (file in r_files) {
    content <- readLines(file, warn = FALSE)
    # Find function definitions
    func_lines <- grep("^[a-zA-Z_][a-zA-Z0-9_]* <- function", content, value = TRUE)
    func_names <- gsub(" <- function.*", "", func_lines)
    
    for (func in func_names) {
      if (func %in% names(functions)) {
        cat("CONFLICT: Function", func, "defined in:\n")
        cat("  -", functions[[func]], "\n")
        cat("  -", file, "\n")
      } else {
        functions[[func]] <- file
      }
    }
  }
}
```

## Critical Files to Monitor

1. **Always use escaped regex for Quarto includes**: `\\{\\{< include`
2. **TableGTR6**: Check `vertical_padding` is handled
3. **Query functions**: Ensure correct version is used
4. **Domain generation**: Validate data exists before generating

## When Issues Recur

1. Check what was sourced last: `search()` 
2. Check if function was overridden: `environment(function_name)`
3. Look for `.history` files being sourced
4. Verify source order in main scripts

## Permanent Fixes Applied

✅ `query_neuropsych` in `workflow_data_processor.R` renamed to `query_neuropsych_simple`
✅ Regex patterns escaped in `generate_domain_files.R` and `tests/test_claude.R`
✅ `vertical_padding` conditional check in `TableGTR6.R`
✅ `load_neuropsych_data` function added to `workflow_data_processor.R`
✅ Documentation added to prevent future conflicts
