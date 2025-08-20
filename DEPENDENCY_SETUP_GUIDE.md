# Dependency Setup Guide for neuro2 Package

## Issue: renv::snapshot() fails due to missing AsioHeaders

When running `renv::snapshot()`, you may encounter:
```
The following required packages are not installed:
- AsioHeaders  [required by websocket]
```

## Solution Steps

### 1. Install Dependencies in Order

Run the provided script:
```r
source("install_dependencies.R")
```

Or manually install in this order:

```r
# 1. System dependencies
install.packages("AsioHeaders")

# 2. websocket (depends on AsioHeaders)
install.packages("websocket")

# 3. chromote (for webshot2)
install.packages("chromote")

# 4. Main packages
install.packages(c("arrow", "webshot2"))
```

### 2. Update renv

After installing all dependencies:

```r
# Restore any missing packages
renv::restore()

# Update the lockfile
renv::snapshot(prompt = FALSE)
```

### 3. Alternative: Use renv to install

If the above doesn't work, try:

```r
# Install with renv
renv::install("AsioHeaders")
renv::install("websocket")
renv::install("chromote")
renv::install("arrow")
renv::install("webshot2")

# Then snapshot
renv::snapshot(prompt = FALSE)
```

## Troubleshooting

### If webshot2 fails to create images:

1. **Check Chrome installation:**
   ```r
   chromote::find_chrome()
   ```

2. **Install Chrome if needed:**
   - macOS: Download from https://www.google.com/chrome/
   - Or use Homebrew: `brew install --cask google-chrome`

3. **Test webshot2:**
   ```r
   library(webshot2)
   webshot("https://www.google.com", "test.png")
   ```

### If arrow installation fails on macOS:

```bash
# Install system dependencies
brew install apache-arrow
```

Then retry:
```r
install.packages("arrow")
```

## Verifying Installation

Run this test:
```r
# Check all packages
required_pkgs <- c("AsioHeaders", "websocket", "chromote", 
                   "arrow", "webshot2", "gt", "duckdb")

for (pkg in required_pkgs) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat("✓", pkg, "installed\n")
  } else {
    cat("✗", pkg, "missing\n")
  }
}
```

## Complete Package Installation

For a fresh install of all neuro2 dependencies:

```r
# Read DESCRIPTION file
desc <- read.dcf("DESCRIPTION")
imports <- strsplit(desc[, "Imports"], ",\\s*")[[1]]
imports <- trimws(imports)

# Install all imports
install.packages(imports)

# Update renv
renv::snapshot(prompt = FALSE)
```

## Next Steps

After successful installation:

1. Test the workflow:
   ```r
   source("test_domain_workflow_parquet.R")
   ```

2. Or run individual tests:
   ```r
   source("test_verbal_domain_fixed.R")
   ```

3. Process patient data:
   ```bash
   ./run_test_workflow.sh
