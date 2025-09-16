# THE REAL ISSUE: File Path Problem in DomainProcessorR6

## The Actual Problem You Identified

You're absolutely right! The core issue is **NOT** the custom Typst format. It's that the DomainProcessorR6 class generates QMD files with incorrect file paths.

### What's Happening:

1. **QMD files are generated with:**
```typst
#let file_qtbl = "table_iq.png"
#let file_fig = "fig_iq_subdomain.svg"
```

2. **But files are actually saved in:**
```
figs/table_iq.png
figs/fig_iq_subdomain.svg
```

3. **Typst fails with:**
```
error: file not found (searched at /Users/joey/neuro2/table_iq.png)
```

## The Root Cause

The DomainProcessorR6 class has methods that:
- Save images to `figs/` directory ✅ (correct)
- But generate QMD files referencing images WITHOUT the `figs/` prefix ❌ (wrong)

## The Solution

I've created **FIX_NOW.R** which:

1. **Fixes all existing QMD files** - adds `figs/` to all image references
2. **Moves misplaced images** - ensures all images are in `figs/`
3. **Verifies the fix** - checks that all referenced images exist

## How to Fix It RIGHT NOW

```r
# Just run this one command:
source("/mnt/user-data/outputs/FIX_NOW.R")
```

This will:
- ✅ Fix all QMD file paths
- ✅ Move images to correct location
- ✅ Verify everything is in place
- ✅ Optionally try rendering immediately

## What Gets Fixed

### Before (WRONG):
```typst
#let file_qtbl = "table_iq.png"
#domain(title: [IQ Scores], file_qtbl, file_fig)
```

### After (CORRECT):
```typst
#let file_qtbl = "figs/table_iq.png"  
#domain(title: [IQ Scores], file_qtbl, file_fig)
```

## For Permanent Fix

To fix the DomainProcessorR6 class permanently:

```r
# This will patch the source R file:
source("/mnt/user-data/outputs/fix_domain_processor_paths.R")
```

This modifies the actual DomainProcessorR6.R file so future generations have correct paths.

## Why This Keeps Happening

The DomainProcessorR6 class has hardcoded string concatenation like:
```r
'"#let file_qtbl = \\"table_"', tolower(self$pheno), '".png\\"\\n"'
```

When it should be:
```r
'"#let file_qtbl = \\"figs/table_"', tolower(self$pheno), '".png\\"\\n"'
```

## Files I Created for You

1. **FIX_NOW.R** - One-command fix for immediate relief
2. **quick_fix_paths.R** - Targeted fix for the path issue
3. **fix_domain_processor_paths.R** - Patches the source R6 class
4. **verify_images.R** - Checks all images are in place

## Bottom Line

You were 100% correct - the issue is the DomainProcessorR6 class not using the `figs/` prefix in generated QMD files. The fix is simple: add `figs/` to all image paths in the QMD files.

Run `source("/mnt/user-data/outputs/FIX_NOW.R")` and your workflow should work!
