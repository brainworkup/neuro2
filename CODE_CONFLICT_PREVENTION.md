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
