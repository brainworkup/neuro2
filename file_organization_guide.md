# File Organization for neuro2 Package

## Package Structure (Version Controlled)

```
neuro2/
├── inst/
│   ├── resources/           # Static package assets
│   │   ├── logo.png        # Your logo
│   │   ├── signature.png   # Your signature  
│   │   ├── templates/      # Report templates
│   │   └── css/            # Styling files
│   ├── scripts/            # Workflow scripts
│   │   ├── batch_domain_processor.R
│   │   ├── template_integration.R
│   │   └── main_workflow_runner.R
│   └── extdata/            # Example data files (if any)
│       └── sample_data.csv
├── R/                      # Package R code
├── man/                    # Documentation
└── tests/                  # Unit tests
```

## User Workspace (Generated During Use)

```
user_project/
├── data/                   # User's input data
│   ├── neurocog.csv
│   └── neurobehav.csv
├── figs/                   # Generated plots & tables
│   ├── _fig_iq.png
│   ├── _fig_memory.png
│   ├── _qtbl_academics.png
│   └── _qtbl_executive.pdf
├── output/                 # Final reports & processed data
│   ├── neuropsych_report.pdf
│   ├── neurocog.parquet
│   └── domain_summaries.csv
├── tmp/                    # Temporary files (optional)
│   └── cache/
└── _02-01_iq.qmd          # Generated domain files
```

## Implementation in Your Code

### 1. Directory Creation Function
```r
#' Ensure required directories exist
ensure_output_directories <- function(base_dir = ".") {
  dirs <- c("figs", "output", "tmp")
  
  for (dir in dirs) {
    dir_path <- file.path(base_dir, dir)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      message("Created directory: ", dir_path)
    }
  }
  
  invisible(dirs)
}
```

### 2. File Path Functions
```r
#' Get package resource path
get_resource_path <- function(filename) {
  system.file("resources", filename, package = "neuro2")
}

#' Get output file paths  
get_fig_path <- function(filename, base_dir = ".") {
  file.path(base_dir, "figs", filename)
}

get_output_path <- function(filename, base_dir = ".") {
  file.path(base_dir, "output", filename)
}

#' Example usage in your processor
save_plot <- function(plot, filename, base_dir = ".") {
  ensure_output_directories(base_dir)
  
  # Save PNG for web/reports
  png_path <- get_fig_path(paste0(filename, ".png"), base_dir)
  ggplot2::ggsave(png_path, plot, width = 8, height = 6, dpi = 300)
  
  # Save PDF for print quality
  pdf_path <- get_fig_path(paste0(filename, ".pdf"), base_dir)  
  ggplot2::ggsave(pdf_path, plot, width = 8, height = 6)
  
  return(list(png = png_path, pdf = pdf_path))
}
```

### 3. Configuration Options
```r
#' Allow users to configure output directories
neuro2_config <- function(
  figs_dir = "figs",
  output_dir = "output", 
  tmp_dir = "tmp",
  base_dir = "."
) {
  config <- list(
    dirs = list(
      base = base_dir,
      figs = file.path(base_dir, figs_dir),
      output = file.path(base_dir, output_dir),
      tmp = file.path(base_dir, tmp_dir)
    )
  )
  
  # Store in options for package functions to use
  options(neuro2.config = config)
  
  # Create directories
  lapply(config$dirs[-1], function(d) {
    if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  })
  
  invisible(config)
}
```

## Benefits of This Approach

1. **CRAN Compliance**: Generated files don't clutter the package
2. **User Control**: Users can specify where outputs go
3. **Clean Separation**: Package resources vs. user outputs are distinct
4. **Reproducible**: Clear structure for sharing projects
5. **Flexible**: Works with different workflow tools (Quarto, knitr, etc.)

## Usage Examples

```r
# Set up user workspace
library(neuro2)
neuro2_config(base_dir = "my_assessment")

# Access package resources
logo_path <- get_resource_path("logo.png")

# Generate outputs (go to user directories)
processor <- DomainProcessorR6$new(...)
processor$generate_report()  # Saves to figs/ and output/
```

## .gitignore Recommendations

For user projects:
```gitignore
# Generated outputs (user decides what to commit)
figs/*.png
figs/*.pdf
output/*.pdf
tmp/

# But keep structure
!figs/.gitkeep
!output/.gitkeep
```

For the package itself:
```gitignore
# Don't include user-generated content in package
figs/
output/  
tmp/
```
