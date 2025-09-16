# Neuropsych Workflow Quarto Rendering Fix

## Problem Summary

Your workflow is failing at Step 5 (report rendering) when trying to use the custom Typst format `neurotyp-pediatric-typst`. The error occurs because:

1. **Custom Format Issue**: The custom Typst formats defined in `_quarto.yml` may not be properly configured or recognized by Quarto
2. **Missing Dependencies**: Required files referenced in `template.qmd` may not exist
3. **Pre-render Scripts**: The `_quarto.yml` references pre-render scripts that may be missing

## Root Causes

### 1. Custom Typst Format Configuration
- Your `_quarto.yml` defines custom formats like `neurotyp-pediatric-typst`
- These are extensions of the base Typst format but may not be properly registered with Quarto
- Quarto may not recognize these as valid format specifications

### 2. Missing Include Files
Your `template.qmd` includes many files that may not exist:
- `_00-00_tests.qmd`
- `_01-00_nse.qmd`
- `_01-01_behav_obs.qmd`
- Domain files (`_02-01_iq.qmd`, etc.)
- `_03-00_sirf.qmd` and related files

### 3. Pre-render Script Issues
The `_quarto.yml` specifies pre-render scripts:
- `generate_all_domain_assets.R`
- `generate_domain_files.R`

If these don't exist or fail, the render will fail.

## Solutions Provided

I've created three scripts to fix these issues:

### 1. `diagnose_quarto_issue.R`
**Purpose**: Comprehensive diagnostics to identify what's wrong
```r
Rscript diagnose_quarto_issue.R
```

This script checks:
- Quarto installation
- Required files existence
- R package availability
- Directory structure
- Custom format configuration
- Performs test renders

### 2. `complete_neuropsych_workflow_fixed_v3.R`
**Purpose**: Enhanced workflow with multiple fallback strategies
```r
Rscript complete_neuropsych_workflow_fixed_v3.R "Ethan"
```

Key improvements:
- Creates missing directories automatically
- Generates minimal template files if missing
- Tries multiple rendering strategies:
  1. Custom format (neurotyp-pediatric-typst)
  2. Basic Typst format
  3. HTML as fallback
- Better error handling and recovery
- Debug mode with `--debug` flag

### 3. `fix_typst_format.R`
**Purpose**: Fix the custom Typst format configuration
```r
Rscript fix_typst_format.R
```

This script:
- Creates simplified `_quarto.yml` with working formats
- Sets up proper format extensions
- Tests rendering with different formats
- Provides specific recommendations

## Quick Fix Steps

### Option 1: Use the Fixed Workflow (Recommended)
```bash
# Run the fixed workflow
Rscript complete_neuropsych_workflow_fixed_v3.R "Ethan"
```

### Option 2: Fix Format Configuration
```bash
# Fix the Typst format issues
Rscript fix_typst_format.R

# Then run your original workflow
Rscript complete_neuropsych_workflow.R "Ethan"
```

### Option 3: Manual Quick Fix
```bash
# Use basic Typst format instead of custom
quarto render template.qmd --to typst

# Or use HTML as fallback
quarto render template.qmd --to html
```

## Immediate Workaround

If you need to generate a report RIGHT NOW:

1. **Edit your workflow** to use basic typst format:
```r
# In complete_neuropsych_workflow.R, change line 143:
format <- "typst"  # Instead of neurotyp-pediatric-typst
```

2. **Or render manually** with basic format:
```bash
quarto render template.qmd --to typst
```

3. **Or use HTML** if Typst isn't working:
```bash
quarto render template.qmd --to html
```

## Long-term Fix

1. **Ensure Typst is installed**:
   - macOS: `brew install typst`
   - Or download from: https://github.com/typst/typst

2. **Install required fonts**:
   - IBM Plex fonts: https://github.com/IBM/plex
   - Or use system fonts by editing `_quarto.yml`

3. **Use the diagnostic script** to identify missing components:
```r
Rscript diagnose_quarto_issue.R
```

4. **Generate all required files** before rendering:
   - Ensure all domain QMD files are generated
   - Create placeholder files for missing includes
   - Verify data files exist

## Testing Your Fix

After applying fixes, test with:

```r
# Test basic Typst rendering
system2("quarto", c("render", "template.qmd", "--to", "typst"))

# Test custom format
system2("quarto", c("render", "template.qmd", "--to", "neurotyp-pediatric-typst"))

# If both fail, use HTML
system2("quarto", c("render", "template.qmd", "--to", "html"))
```

## Fish Shell Consideration

Since you're using Fish shell, if you have PATH issues:

```fish
# Add R to Fish path if needed
set -x PATH /usr/local/bin $PATH

# Or run scripts with full path
/usr/local/bin/Rscript complete_neuropsych_workflow_fixed_v3.R "Ethan"
```

## Contact for Help

If these fixes don't work:
1. Run the diagnostic script and share the output
2. Check `logs/workflow_*.log` for detailed error messages
3. Try the HTML format as a temporary workaround

The fixed workflow should handle most issues automatically and fall back to working formats when custom ones fail.
