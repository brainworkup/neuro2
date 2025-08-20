
<!-- README.md is generated from README.Rmd. Please edit that file -->

# neuro2: Modern Neuropsychological Report Generation System

<!-- badges: start -->

<!-- [![R-CMD-check](https://github.com/brainworkup/neuro2/workflows/R-CMD-check/badge.svg)](https://github.com/brainworkup/neuro2/actions) -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

<!-- badges: end -->

## Overview

The `neuro2` package is a comprehensive R package for generating
professional neuropsychological evaluation reports using modern R6
object-oriented design, high-performance data processing with
DuckDB/Parquet, and beautiful typesetting with Quarto/Typst.

### 🎯 Key Features

- **🚀 High-Performance Data Pipeline**: Uses DuckDB and Parquet for
  4-5x faster data processing
- **🏗️ Modern R6 Architecture**: Object-oriented design for
  extensibility and maintainability
- **🧠 Dynamic Domain Generation**: Automatically generates report
  sections based on available patient data
- **📊 Beautiful Visualizations**: Creates publication-quality tables
  and plots with `gt` and custom R6 classes
- **📄 Professional Reports**: Generates PDF reports using Quarto and
  Typst for superior typography
- **🔧 Flexible Configuration**: Easily customizable for different
  assessment types and clinical settings

## Installation

### Prerequisites

1.  **R** (version 4.1 or higher)
2.  **Quarto** (version 1.4.0 or higher) - [Install
    Quarto](https://quarto.org/docs/get-started/)
3.  **CMake** (version 3.10 or higher) - Required for some dependencies
4.  **webshot2** - For converting tables to images

### Install from GitHub

``` r
# Install pak if not already installed
install.packages("pak")

# Install neuro2 package
pak::pak("brainworkup/neuro2")
```

### Install Core Dependencies

``` r
# Core dependencies
install.packages(c(
  "dplyr", "tidyr", "ggplot2", "stringr", "here", "glue", "yaml", "quarto", "gt", "gtExtras", "janitor", "R6", "readr", "readxl",
  "DBI", "duckdb", "arrow", "webshot2"
))
```

## 🏃 Quick Start

### Option 1: Unified Workflow Scripts (Recommended)

``` bash
# Interactive shell workflow (with guided prompts)
./unified_neuropsych_workflow.sh "Patient Name"

# Or programmatic R workflow
Rscript unified_workflow_runner.R config.yml
```

The unified workflow scripts provide a streamlined, efficient process
that combines the best features of all workflow components. See [Unified
Workflow README](UNIFIED_WORKFLOW_README.md) for detailed documentation.

### Option 2: Direct R6 Usage

``` r
# Load the package
library(neuro2)

# 1. Process raw data files (CSV → Parquet)
load_data_duckdb(
  file_path = "data-raw/csv",
  output_dir = "data",
  output_format = "all"  # Creates CSV, Parquet, and Feather formats
)

# 2. Generate a neuropsychological report
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = "Biggie Smalls",
    domains = c("General Cognitive Ability", "Memory", "Attention/Executive"),
    data_files = list(
      neurocog = "data/neurocog.parquet",
      neurobehav = "data/neurobehav.parquet"
    )
  )
)

# 3. Run the complete workflow
report_system$run_workflow()
```

## 📁 Project Structure

    neuro2/
    ├── data-raw/           # Input CSV files from neuropsych tests
    │   ├── csv/           # Raw test data files
    │   └── create_sysdata.R # Domain and scale definitions
    ├── data/              # Processed data (Parquet/Feather/CSV)
    ├── R/                 # R6 classes and functions
    │   ├── DomainProcessorR6.R      # Domain data processing
    │   ├── NeuropsychReportSystemR6.R # Report orchestration
    │   ├── TableGT.R                # Table generation
    │   ├── DotplotR6.R             # Visualization
    │   └── duckdb_neuropsych_loader.R # Data loading
    ├── inst/              # Package resources
    │   ├── extdata/       # Lookup tables and templates
    │   └── quarto/        # Report templates
    ├── _*.qmd            # Domain template sections
    ├── template.qmd      # Main report template
    ├── _quarto.yml      # Quarto configuration
    ├── unified_workflow_runner.R    # Main R workflow entry point
    ├── unified_neuropsych_workflow.sh # Interactive shell workflow
    ├── UNIFIED_WORKFLOW_README.md   # Unified workflow documentation
    └── _arxiv/           # Archived legacy scripts

## 🧪 Core R6 Classes

### NeuropsychReportSystemR6

Orchestrates the entire report generation workflow:

``` r
# Create report system with configuration
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = "Biggie",
    domains = c("Memory", "Verbal/Language", "Attention/Executive")
  )
)

# Generate domain files dynamically
report_system$generate_domain_files()
```

### DomainProcessorR6

Processes neuropsychological test data by cognitive domain:

``` r
# Process verbal domain data
processor <- DomainProcessorR6$new(
  domains = "Verbal/Language",
  pheno = "verbal",
  input_file = "data/neurocog.parquet"
)

processor$process()  # Runs complete pipeline
```

### TableGT

Creates publication-quality tables:

``` r
# Generate a formatted table
table <- TableGT$new(
  data = domain_data,
  pheno = "memory",
  table_name = "table_memory"
)

table$build_table()  # Creates PNG and PDF outputs
```

### DotplotR6

Creates domain visualization plots:

``` r
# Create domain visualization
plot <- DotplotR6$new(
  data = domain_data,
  pheno = "executive"
)

plot$build_plot()
```

## 📊 Data Processing Pipeline

### 1. Import Raw Data

Place CSV files in `data-raw/csv/` with required columns: - `test`: Test
abbreviation - `test_name`: Full test name - `scale`: Subtest/scale
name - `raw_score`: Raw score - `score`: Standard score - `percentile`:
Percentile rank - `domain`: Cognitive domain

### 2. Process with DuckDB

``` r
# High-performance data processing
load_data_duckdb(
  file_path = "data-raw/csv",
  output_dir = "data",
  use_duckdb = TRUE,
  output_format = "parquet"  # 4-5x faster than CSV
)
```

### 3. Query with SQL

``` r
# Use SQL for complex queries
query_neuropsych(
  "SELECT * FROM neurocog WHERE domain = 'Memory' AND percentile < 16",
  "data"
)
```

## 🎨 Customization

### Configure Patient Information

Edit `_variables.yml`:

``` yaml
patient: "Biggie Smalls"
age: 45
sex: "male"
education: 16
handedness: "right"
```

### Customize Domains

The system automatically detects available domains from your data.
Domain mappings are defined in `data-raw/create_sysdata.R`: - General
Cognitive Ability → `iq` - Academic Skills → `academics` -
Verbal/Language → `verbal` - Memory → `memory` - Attention/Executive →
`executive`

### Add Custom Tests

1.  Add test data to CSV in `data-raw/csv/`
2.  Ensure proper domain assignment
3.  Run the workflow - domains are generated dynamically

## 🔧 Advanced Usage

### Using Individual Components

``` r
# Load specific domain data
memory_data <- query_neuropsych(
  "SELECT * FROM neurocog WHERE domain = 'Memory'",
  "data"
)

# Create custom table
table_gt <- TableGT$new(
  data = memory_data,
  pheno = "memory",
  table_name = "custom_memory_table"
)

table_gt$build_table()
```

### Batch Processing

``` r
# Process multiple patients
patients <- list(
  list(name = "Patient1", age = 30),
  list(name = "Patient2", age = 45)
)

for (patient in patients) {
  report_system <- NeuropsychReportSystemR6$new(
    config = list(patient = patient$name, age = patient$age)
  )
  report_system$run_workflow()
}
```

## 🐛 Troubleshooting

### Common Issues

1.  **Missing dependencies**

    ``` r
    # Check and install dependencies
    source("install_dependencies.R")
    ```

2.  **DuckDB errors**

    ``` r
    # Verify DuckDB installation
    DBI::dbConnect(duckdb::duckdb())
    ```

3.  **Webshot2 issues**

    ``` r
    # Reinstall chromote
    webshot2::install_chromote()
    ```

4.  **Domain not found**

    - Check domain spelling in data matches `create_sysdata.R`
    - Verify data file contains the domain

## 📚 Documentation

- [Unified Workflow Guide](UNIFIED_WORKFLOW_README.md) - **Recommended
  workflow**
- [Unified Workflow Architecture](unified_workflow_architecture.md) -
  Technical design
- [Domain File Generation Workflow](DOMAIN_FILE_GENERATION_WORKFLOW.md)
- [DuckDB Integration Guide](DUCKDB_INTEGRATION_GUIDE.md)
- [R6 Implementation Guide](R6_IMPLEMENTATION_GUIDE.md)
- [Dependency Setup Guide](DEPENDENCY_SETUP_GUIDE.md)

## 🤝 Contributing

Contributions are welcome! Please: 1. Fork the repository 2. Create a
feature branch (`git checkout -b feature/NewFeature`) 3. Commit changes
(`git commit -m 'Add NewFeature'`) 4. Push to branch
(`git push origin feature/NewFeature`) 5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the
[LICENSE](LICENSE) file for details.

## 📖 Citation

If you use this package in your work, please cite:

    Trampush, J. (2024). neuro2: Modern Neuropsychological Report Generation System.
    R package version 0.1.8 https://github.com/brainworkup/neuro2

## 📧 Contact

- **Author**: Joey Trampush, PhD
- **Email**: <joey.trampush@brainworkup.org>
- **Issues**: [GitHub
  Issues](https://github.com/brainworkup/neuro2/issues)

## 🙏 Acknowledgments

- Built on the [Quarto](https://quarto.org) publishing system
- Uses [Typst](https://typst.app) for beautiful typesetting
- Powered by [DuckDB](https://duckdb.org) for fast data processing
- Tables created with [gt](https://gt.rstudio.com)
- R6 architecture inspired by modern OOP best practices
