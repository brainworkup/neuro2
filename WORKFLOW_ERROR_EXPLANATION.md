# Understanding and Fixing Your Neuropsych Workflow Error

## What Went Wrong? 🤔

The error message "could not find function 'run_neuropsych_workflow'" occurred because of a fundamental mismatch between what your code expected and what actually existed in your workflow file.

### The Root Cause

Your `joey_startup_clean.R` file was written with this assumption:

``` r
run_workflow <- function(patient = patient_name) {
  source("inst/scripts/00_complete_neuropsych_workflow.R")  # Load the file
  run_neuropsych_workflow(...)  # Then call this function
}
```

However, your `00_complete_neuropsych_workflow.R` file **never defines** a function called `run_neuropsych_workflow()`.
Instead, it's written as a **standalone script** that executes immediately when sourced.

### What Actually Happened

Here's the sequence of events:

1.  **You call** `run_workflow()`
2.  **R sources** `00_complete_neuropsych_workflow.R`
3.  **The workflow runs immediately** (all 5 steps execute)
4.  **Workflow completes successfully** (all those ✅ you saw)
5.  **Control returns** to your startup script
6.  **Your script tries to call** `run_neuropsych_workflow(...)`
7.  **R looks for the function** but can't find it
8.  **Error thrown**: "could not find function"

The confusing part is that the workflow actually worked perfectly!
All those success messages you saw were real.
The error only happened at the very end when your code tried to call a function that was never defined.

## The Two Solutions

### Solution 1: Wrap the Workflow in a Function (Recommended)

I've created a fixed version that wraps all the workflow logic inside a proper function definition.
This is the better approach because:

-   It gives you control over when the workflow runs
-   It allows you to pass parameters
-   It returns useful information (the path to the generated report)
-   It follows R best practices for reusable code

**To use this solution:**

1.  Replace your current workflow file:

    ``` bash
    cp /mnt/user-data/outputs/00_complete_neuropsych_workflow_FIXED.R \
       inst/scripts/00_complete_neuropsych_workflow.R
    ```

2.  Replace your startup file:

    ``` bash
    cp /mnt/user-data/outputs/joey_startup_clean_FIXED.R \
       joey_startup_clean.R
    ```

3.  Restart R and source the startup script:

    ``` r
    source("joey_startup_clean.R")
    run_workflow()
    ```

### Solution 2: Simplify the Startup Script

Alternatively, you could just change your startup script to not expect a function:

``` r
patient_name <- "Ethan"

run_workflow <- function(patient = patient_name) {
  # Just source the script - it will run automatically
  source("inst/scripts/00_complete_neuropsych_workflow.R")
  # Don't try to call a function that doesn't exist
}
```

But this is less flexible because you can't pass parameters to control the workflow behavior.

## Why This Matters for Development

This issue highlights an important concept in R development: the difference between **scripts** and **functions**.

### Scripts

-   Execute line-by-line when sourced
-   Can't easily accept parameters
-   Can't return values
-   Harder to test and reuse

### Functions

-   Only execute when called
-   Accept parameters for flexible behavior
-   Return values
-   Easy to test and reuse

Your original workflow was a script pretending to be a function.
The fixed version is a proper function that can be used like any other R function.

## Additional Benefits of the Fixed Version

The updated workflow function now supports:

1.  **Flexible patient names**: `run_neuropsych_workflow(patient = "John Doe")`

2.  **Skip steps**: `run_neuropsych_workflow(generate_qmd = FALSE)` - useful if you just want to regenerate assets

3.  **Force reprocessing**: `run_neuropsych_workflow(force_reprocess = TRUE)` - useful when you update raw data

4.  **Return values**: The function returns the path to the generated report, so you can do:

    ``` r
    report_path <- run_neuropsych_workflow(patient = "Ethan")
    # Open the report automatically
    system2("open", report_path)
    ```

## Testing the Fix

After applying the fix, test it with:

``` r
# Load the fixed workflow
source("inst/scripts/00_complete_neuropsych_workflow_FIXED.R")

# Test 1: Basic run
run_neuropsych_workflow(patient = "Test Patient")

# Test 2: Skip rendering (faster for testing)
run_neuropsych_workflow(
  patient = "Test",
  render_report = FALSE
)

# Test 3: Full control
report <- run_neuropsych_workflow(
  patient = "Ethan",
  generate_qmd = TRUE,
  render_report = TRUE,
  force_reprocess = FALSE
)

# The report path is returned
cat("Report saved to:", report, "\n")
```

## About That "run_workflow.R" Comment

You mentioned not recalling using "run_workflow.R" for a while.
This is likely a different file that may exist somewhere in your project structure.
To check for old files that might be causing confusion:

``` r
source("/mnt/user-data/outputs/diagnose_workflow_issue.R")
```

This diagnostic script will scan your project for any old workflow files that might be interfering.

## Prevention Going Forward

To avoid this type of issue in the future:

1.  **Always define functions explicitly** in files that will be sourced
2.  **Use consistent naming** - if a file is named `foo.R`, it should define a function called `foo()`
3.  **Test your functions** by sourcing the file in a clean R session and calling the function
4.  **Document your functions** with roxygen2 comments so you remember what they're supposed to do

## Summary

The error wasn't because your workflow was broken - it was working perfectly!
The error was simply because your code expected a function that was never defined.
The fix is to wrap your workflow logic in a proper function definition, which also makes your code more flexible and maintainable.

The fixed files are ready for you in `/mnt/user-data/outputs/`.
Copy them over and you should be good to go!