# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Architecture

**neuro2** is a neuropsychological report generation system built on modern R patterns:

- **R6 Object-Oriented Classes**: Core functionality implemented using R6 for better performance and maintainability
- **DuckDB/Parquet Data Pipeline**: High-performance data processing (4-5x faster than CSV)
- **Quarto Report Generation**: Professional PDF reports using Quarto + Typst typography
- **Dynamic Domain Generation**: Report sections are generated based on available patient data

## Key R6 Classes (R/ directory)

- `NeuropsychReportSystemR6`: Main orchestrator for the entire report workflow
- `DomainProcessorR6`: Processes neuropsychological test data by cognitive domain
- `TableGT`: Creates publication-quality tables with gt package
- `DotplotR6`: Generates domain visualization plots
- `ReportTemplateR6`: Manages report templates and rendering
- `NeuropsychResultsR6`: Generates text summaries and interpretations

## Development Commands

### Setup Environment
```bash
# Install all dependencies
Rscript install_dependencies.R

# Setup development environment
Rscript setup_environment.R
```

### Data Processing
```bash
# Load and process data (CSV → Parquet conversion)
Rscript -e "load_data_duckdb(file_path = 'data-raw/csv', output_dir = 'data', output_format = 'all')"

# IMPORTANT: Add score ranges to processed data
Rscript -e "
data <- read.csv('data/neurocog.csv')
data <- gpluck_make_score_ranges(data, test_type = 'npsych_test')
write.csv(data, 'data/neurocog.csv', row.names = FALSE)
"

# Test domain workflow with parquet data
Rscript test_domain_workflow_parquet.R

# Run complete workflow test
./run_test_workflow.sh
```

### Report Generation
```bash
# Generate report using R6 workflow (recommended)
Rscript neuro2_r6_update_workflow.R

# Generate report using DuckDB workflow
Rscript neuro2_duckdb_workflow.R

# Render final report with Quarto
quarto render template.qmd --to typst-pdf
```

### Package Management
```bash
# Update package dependencies
Rscript maintain_deps.R

# Check package status
R -e "renv::status()"

# Snapshot current environment
R -e "renv::snapshot()"
```

## Data Structure

### Input Data (data-raw/csv/)
CSV files with required columns:
- `test`: Test abbreviation
- `test_name`: Full test name  
- `scale`: Subtest/scale name
- `raw_score`: Raw score
- `score`: Standard score
- `percentile`: Percentile rank
- `domain`: Cognitive domain

**Important**: The `range` column (e.g., "Average", "High Average") is automatically added by `gpluck_make_score_ranges()` based on percentiles:
- 98+: "Exceptionally High"
- 91-97: "Above Average"
- 75-90: "High Average"
- 25-74: "Average"
- 9-24: "Low Average"
- 2-8: "Below Average"
- <2: "Exceptionally Low"

### Processed Data (data/)
Files are converted to multiple formats:
- `*.csv`: Original format
- `*.parquet`: High-performance format (recommended)
- `*.feather`: Alternative binary format

### Domain Mappings
Defined in `data-raw/create_sysdata.R`:
- General Cognitive Ability → `iq` 
- Academic Skills → `academics`
- Verbal/Language → `verbal`
- Memory → `memory`
- Attention/Executive → `executive`

## Report Templates

### Main Template Structure
- `template.qmd`: Main report template
- `_quarto.yml`: Quarto configuration
- `_variables.yml`: Patient-specific variables

### Domain Templates (auto-generated)
- `_02-XX_domain.qmd`: Main domain section
- `_02-XX_domain_text.qmd`: Text summary section

Sequential numbering (XX) is assigned based on available domains.

## Performance Notes

### R6 vs Procedural Approach
- R6 classes provide 2-3x performance improvement
- 40-60% memory reduction through reference semantics
- Better code organization and maintainability

### DuckDB vs CSV
- Parquet files process 4-5x faster than CSV
- Use `load_data_duckdb()` for optimal performance
- SQL queries available via `query_neuropsych()`

## Common Workflows

### Basic Report Generation
```r
# 1. Process data
load_data_duckdb(file_path = "data-raw/csv", output_dir = "data")

# 2. Create report system
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = "Patient Name",
    domains = c("Memory", "Executive"),
    data_files = list(neurocog = "data/neurocog.parquet")
  )
)

# 3. Generate report
report_system$run_workflow()
```

### Individual Domain Processing
```r
processor <- DomainProcessorR6$new(
  domains = "Memory",
  pheno = "memory", 
  input_file = "data/neurocog.parquet"
)
processor$process()
```

## Troubleshooting

### Missing Dependencies
Run `source("install_dependencies.R")` to install all required packages.

### DuckDB Issues
Verify installation: `DBI::dbConnect(duckdb::duckdb())`

### Webshot2 Problems  
Reinstall: `webshot2::install_chromote()`

### Template Errors
Ensure all QMD template files exist and Quarto is properly installed.

## Testing

No formal test framework is configured. Testing is done through:
- `test_domain_workflow_parquet.R`: Tests domain processing pipeline
- `run_test_workflow.sh`: Full workflow integration test
- Manual verification of generated reports and outputs