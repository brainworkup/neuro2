# Package Management for neuro2

## Overview

This document describes the centralized package management system for the neuro2 neuropsychology report package.

## Package Dependencies

All package dependencies are defined in the `DESCRIPTION` file and installed via `install_dependencies.R`.

### Core Dependencies

The package requires the following main categories of dependencies:

1. **Data Manipulation**: `dplyr`, `tidyr`, `purrr`, `tibble`, `readr`, `readxl`, `janitor`
2. **Database**: `DBI`, `duckdb`, `arrow`
3. **Visualization**: `ggplot2`, `ggtext`, `ggthemes`, `gt`, `gtExtras`, `highcharter`, `kableExtra`
4. **Utilities**: `cli`, `fs`, `glue`, `here`, `progress`, `yaml`
5. **Development**: `knitr`, `quarto`, `R6`, `rlang`, `stringr`, `usethis`, `xfun`
6. **Parallel Processing**: `future`, `future.apply`
7. **Specialized**: `memoise`, `tabulapdf`, `webshot2`

## Installation

### Initial Setup

Run the installation script to install all dependencies:

```r
source('install_dependencies.R')
```

This script will:
- Install all packages listed in the DESCRIPTION file
- Install additional dependencies required by some packages (e.g., AsioHeaders, websocket, chromote)
- Verify successful installation
- Create the `load_neuropsych_packages()` helper function

### Manual Installation

If the script fails for specific packages, you can install them manually:

```r
# For a single package
install.packages("package_name")

# For multiple packages
install.packages(c("package1", "package2", "package3"))
```

## Loading Packages

### In Templates (template.qmd)

The template now uses a centralized package loading function:

```r
# Source package loading function
source("R/load_packages.R")

# Load all required packages
load_neuropsych_packages(verbose = FALSE)
```

This loads the minimal set of packages needed for report generation:
- `knitr` - For knitr options
- `here` - For path management  
- `readr` - For reading CSV if needed
- `dplyr` - For data manipulation
- `gt` - For tables

### In R Scripts

For R scripts that need additional packages, you can either:

1. Use the centralized function and load additional packages:
```r
source("R/load_packages.R")
load_neuropsych_packages()

# Load additional packages as needed
library(ggplot2)
library(arrow)
```

2. Load packages individually:
```r
library(dplyr)
library(duckdb)
library(arrow)
```

## Package Versioning

### Using renv

After installing packages, update the renv lockfile:

```r
renv::snapshot(prompt = FALSE)
```

To restore packages on a new system:

```r
renv::restore()
```

### Checking Package Versions

To see installed versions of all neuro2 dependencies:

```r
# Source the package list
source("install_dependencies.R")  # Creates all_packages variable

# Check versions
sapply(all_packages, function(pkg) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    packageVersion(pkg)
  } else {
    "Not installed"
  }
})
```

## System Requirements

Some packages have additional system requirements:

### webshot2
- Requires Chrome or Chromium browser
- On macOS: Chrome should work automatically
- Used for exporting gt tables as images

### arrow
- May require C++ compiler
- Used for parquet file support

### duckdb
- May require cmake
- Used for efficient data processing

### tabulapdf
- Requires Java
- Used for extracting tables from PDF files

### Quarto
- Required for report generation
- Install from: https://quarto.org/docs/get-started/

## Troubleshooting

### Common Issues

1. **Package installation fails**
   - Check internet connection
   - Try a different CRAN mirror: `options(repos = c(CRAN = "https://cloud.r-project.org"))`
   - Install system dependencies (see System Requirements)

2. **webshot2 issues**
   - Ensure Chrome is installed
   - Try: `webshot2::install_chromote()`

3. **arrow installation fails**
   - On macOS: Install Xcode Command Line Tools
   - Try: `install.packages("arrow", type = "source")`

4. **Quarto not found**
   - Install Quarto CLI separately from website
   - Ensure quarto is in system PATH

### Getting Help

If issues persist:
1. Check package documentation: `?package_name`
2. Review package GitHub issues
3. Post specific error messages with system info

## Best Practices

1. **Keep packages updated**
   ```r
   # Check for updates
   old.packages()
   
   # Update all packages
   update.packages(ask = FALSE)
   ```

2. **Use renv for reproducibility**
   - Always snapshot after installing new packages
   - Commit renv.lock to version control

3. **Minimize dependencies in templates**
   - Templates should only load essential packages
   - Domain processors handle their own specific needs

4. **Document package usage**
   - Note which packages are used in each script
   - Document any special configuration needed
