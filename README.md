# NeurotypR: Neuropsychological Report Generation System

NeurotypR is an R package designed to streamline the creation of neuropsychological evaluation reports. It provides tools for data import, processing, visualization, and report generation using Quarto and Typst templates.

## Features

- Data import from multiple CSV files
- Statistical analysis and z-score calculations
- Automated table and plot generation
- Modular report generation with interchangeable templates
- Support for both HTML and Typst output formats

## Installation

```r
# Install from GitHub
devtools::install_github("neuro2/NeurotypR")
```

## Workflow Overview

1. **Data Import**: Load neuropsychological test data from CSV files
2. **Data Processing**: Filter, transform, and calculate statistics
3. **Visualization**: Generate standardized plots and tables
4. **Report Assembly**: Combine processed data with template sections
5. **Rendering**: Produce final reports in HTML or Typst formats

## Key Components

### 1. ReportGenerator Class

The core R6 class that orchestrates the entire workflow:

```r
gen <- ReportGenerator$new(
  params = list(patient = "John Doe", dob = "1980-01-01"),
  output_dir = "reports"
)
```

### 2. Data Processing

- `load_data()`: Import and combine CSV files
- `filter_data()`: Subset by domains or scales
- `calculate_stats()`: Compute z-scores and other statistics

### 3. Visualization

- `generate_tables()`: Create standardized tables (GT/Kable)
- `generate_plots()`: Generate dotplots and other visualizations

### 4. Report Generation

Two main approaches:

1. **Single Template Rendering**:
```r
gen$render(output_file = "report.html")
```

2. **Modular Section Assembly**:
```r
gen$render_sections(
  sections_dir = "sections",
  output_file = "modular_report.html"
)
```

## Template System

NeurotypR uses a flexible template system with interchangeable components:

### Template Types

1. **Adult Neuropsychological** (`_01-00_nse_adult.qmd`)
2. **Forensic** (`_01-00_nse_forensic.qmd`)
3. **Pediatric** (`_01-00_nse_pediatric.qmd`)

### Template Structure

```
inst/quarto/templates/
├── typst-report/          # Typst template
│   ├── template.qmd       # Master template
│   ├── _quarto.yml        # Quarto config
│   └── sections/          # Modular sections
└── html-report/           # HTML template
    └── template.qmd
```

### Using Templates

1. **Static Files**: Store in `inst/quarto/templates/[format]/`
2. **Dynamic Sections**: Generate QMD files based on test battery

## File Management

- **Static Files**: Store in `inst/extdata/` for package data
- **Dynamic Files**: Generated at runtime in the output directory

## Example Usage

```r
library(NeurotypR)

# Initialize with patient parameters
gen <- ReportGenerator$new(
  params = list(
    patient = "Jane Doe",
    dob = "1990-05-15",
    author = "Clinician Name"
  ),
  output_dir = "reports"
)

# Load and process data
gen$
  load_data()$
  filter_data(domains = c("Memory", "Attention"))$
  calculate_stats(group_vars = c("domain", "scale"))

# Generate outputs
gen$
  generate_tables()$
  generate_plots()$
  render(output_file = "jane_doe_report.html")
```

## Directory Structure

```
neuro2/
├── R/                  # R source code
│   ├── report_generator.R  # Main class
│   ├── data.R          # Data processing
│   ├── plots.R         # Visualization
│   └── tables.R        # Table generation
├── inst/
│   ├── examples/       # Usage examples
│   ├── extdata/        # Sample data
│   └── quarto/         # Report templates
├── man/                # Documentation
└── reports/            # Output directory
```

## Customization

To create a new template:

1. Copy an existing template directory
2. Modify the `template.qmd` and section files
3. Update the `_quarto.yml` configuration
4. Reference the new template path in your code

## Troubleshooting

- **Template Not Found**: Verify the path in `private$template_qmd`
- **Missing Sections**: Ensure all included QMD files exist
- **Parameter Errors**: Check that all required params are provided

## License

MIT License - See [LICENSE](LICENSE) for details.
