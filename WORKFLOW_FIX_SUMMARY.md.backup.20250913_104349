# Neuropsych Workflow Error Fix Summary

## The Problem

The workflow failed at Step 4 (asset generation) with the error:
```
❌ ERROR in asset generation :
error in running command
```

This error occurs when `system2()` cannot execute the external `Rscript` command.

## Root Causes

1. **Fish Shell PATH Issues**: Fish shell handles PATH differently than bash/zsh, which can cause `system2()` to fail to find executables.

2. **Script Name Mismatch**: The workflow was looking for `generate_all_domain_assets.R` but the actual file was named `generate_all_domain_assets_fixed.R`.

3. **system2() Limitations**: The `system2()` function in R can fail when:
   - The command isn't in PATH
   - Running from certain shells (like Fish)
   - Permission issues exist

## Solutions Provided

### 1. **Fixed Workflow Script** (`complete_neuropsych_workflow_fixed_v2.R`)
- Detects and handles Rscript PATH issues
- Sources scripts directly instead of using system2() when possible
- Includes inline asset generation function as fallback
- Better error handling and progress reporting

### 2. **Standalone Asset Generator** (`generate_assets_for_domains_fixed.R`)
- Self-contained function that doesn't rely on system2()
- Can be sourced directly into the workflow
- Generates tables and figures directly without external calls

### 3. **Shell Wrapper** (`run_neuropsych_workflow.sh`)
- Bash script that finds R installation regardless of shell
- Sets up proper PATH before running R
- Handles lock files to prevent concurrent runs
- Works with Fish, Zsh, and Bash shells

### 4. **Diagnostic Tool** (`diagnose_workflow_issues.R`)
- Tests system2() functionality
- Checks for Rscript in PATH
- Verifies required packages
- Tests different execution methods
- Provides specific fixes for identified issues

## How to Use the Fixes

### Option 1: Use the Fixed Workflow (Recommended)
```r
# Run from R console
source("complete_neuropsych_workflow_fixed_v2.R")
```

### Option 2: Use the Shell Wrapper
```bash
# Make executable
chmod +x run_neuropsych_workflow.sh

# Run with patient name
./run_neuropsych_workflow.sh "Ethan"
```

### Option 3: Run Diagnostics First
```r
# Identify issues
source("diagnose_workflow_issues.R")

# Then run the fixed workflow
source("complete_neuropsych_workflow_fixed_v2.R")
```

## Quick Fix for Fish Shell Users

Add R to your Fish PATH permanently:
```fish
# Add to ~/.config/fish/config.fish
set -x PATH /usr/local/bin $PATH
set -x PATH (R --slave -e 'cat(R.home("bin"))') $PATH
```

Then reload:
```fish
source ~/.config/fish/config.fish
```

## Testing the Fix

1. First, run the diagnostic:
   ```r
   source("diagnose_workflow_issues.R")
   ```

2. Address any issues shown (missing packages, etc.)

3. Run the fixed workflow:
   ```r
   source("complete_neuropsych_workflow_fixed_v2.R")
   ```

## Expected Output

When successful, you should see:
```
✅ Template files verified
✅ Data processed successfully
✅ Generated X domain files
✅ Assets generated successfully
✅ Report rendered successfully
🎉 Success! Your report is ready at: output/template.pdf
```

## Files Created

The workflow will create:
- `figs/` - Contains all tables and figures (PNG, SVG)
- `output/` - Contains the final PDF report
- `data/` - Contains processed Parquet files
- `_02-XX_*.qmd` - Domain-specific QMD files

## Troubleshooting

If issues persist:

1. **Check R installation**: 
   ```r
   R.home("bin")  # Should show path to R binaries
   ```

2. **Install missing packages**:
   ```r
   install.packages(c("here", "yaml", "arrow", "dplyr", "ggplot2", "gt"))
   ```

3. **Verify data files exist**:
   ```r
   list.files("data", pattern = "\\.(csv|parquet)$")
   ```

4. **Run asset generation directly**:
   ```r
   source("generate_assets_for_domains_fixed.R")
   domain_files <- list.files(pattern = "^_02-[0-9]+.*\\.qmd$")
   generate_assets_for_domains(domain_files)
   ```

## Contact for Support

If you continue to experience issues after trying these fixes, the problem may be:
- Missing R packages
- Corrupted data files
- Incorrect file permissions
- Incompatible R version (need R >= 4.0)

Check the diagnostic output for specific error messages and missing components.
