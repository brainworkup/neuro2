# Neuropsychological Report Generation - Unified Workflow

## Overview

This unified workflow system integrates the best features of multiple existing workflow scripts to provide a streamlined, efficient process for generating neuropsychological reports. It combines modern technologies like R6 classes and DuckDB with a clear, maintainable architecture.

## Key Features

- **Single Entry Point**: Choose between shell script or R script interfaces
- **Modern Technologies**: Leverages R6 classes and DuckDB for optimal performance
- **Flexible Configuration**: YAML-based configuration for easy customization
- **Backward Compatible**: Works with existing domain files and templates
- **Comprehensive Logging**: Detailed logging for troubleshooting
- **Interactive Mode**: Guided workflow with user prompts (shell script)
- **Programmatic Mode**: API-like interface for automation (R script)

## Quick Start

### Option 1: Shell Script (Interactive)

```bash
# Make the script executable
chmod +x unified_neuropsych_workflow.sh

# Run with patient name as argument
./unified_neuropsych_workflow.sh "John Doe"

# Or run interactively (will prompt for patient name)
./unified_neuropsych_workflow.sh
```

### Option 2: R Script (Programmatic)

```r
# Run with default configuration
Rscript unified_workflow_runner.R

# Run with custom configuration file
Rscript unified_workflow_runner.R custom_config.yml
```

## Workflow Steps

1. **Environment Setup**: Checks and installs required packages, verifies R6 class files, creates necessary directories
2. **Data Processing**: Converts CSV files to optimized formats (Parquet/Arrow), adds score ranges
3. **Domain Generation**: Creates domain-specific QMD files with visualizations and tables
4. **Report Generation**: Renders the final report using Quarto

## Configuration

The workflow uses a YAML configuration file (`config.yml`) with the following structure:

```yaml
patient:
  name: "Patient Name"
  age: 35
  doe: "2025-07-01"

data:
  input_dir: "data-raw/csv"
  output_dir: "data"
  format: "parquet"  # Options: csv, parquet, arrow, all

processing:
  use_duckdb: true
  parallel: true
  
report:
  template: "template.qmd"
  format: "typst-pdf"  # Options: typst-pdf, html
  output_dir: "output"
```

## Directory Structure

```
/
├── data-raw/
│   └── csv/          # Raw CSV files
├── data/             # Processed data files
├── output/           # Generated reports
├── R/                # R6 class files
├── _*.qmd            # Template files
├── config.yml        # Configuration file
├── unified_workflow_runner.R        # R entry point
└── unified_neuropsych_workflow.sh   # Shell entry point
```

## Integration with Existing Scripts

The unified workflow integrates with existing scripts in the following ways:

1. **setup_environment.R**: Called by the unified workflow to set up the environment
2. **neuropsych_workflow.sh**: Replaced by unified_neuropsych_workflow.sh
3. **new_patient_workflow.R**: Replaced by unified_workflow_runner.R
4. **neuro2_R6_update_workflow.R**: Used as a fallback for domain generation
5. **neuro2_duckdb_workflow.R**: Used as a fallback for data processing

## Detailed Component Documentation

### 1. Unified Workflow Runner (R)

The `unified_workflow_runner.R` script is the main controller for the workflow. It:

- Parses command-line arguments
- Loads and validates configuration
- Orchestrates the workflow steps
- Provides detailed logging
- Returns appropriate exit codes

### 2. Unified Neuropsych Workflow (Shell)

The `unified_neuropsych_workflow.sh` script provides an interactive interface to the workflow. It:

- Prompts for patient information
- Checks for required files and directories
- Guides the user through PDF extraction
- Calls the R workflow runner
- Provides colored output for better readability

### 3. Configuration System

The configuration system uses YAML for flexibility and readability. The configuration file is:

- Created automatically if it doesn't exist
- Updated with patient information from the shell script
- Validated by the R workflow runner
- Used to control all aspects of the workflow

### 4. Logging System

The logging system provides detailed information about the workflow execution:

- Logs are written to `workflow.log`
- Each log entry includes timestamp and type
- Log levels include INFO, WARNING, ERROR, and SETUP
- Console output is color-coded for better readability

## Troubleshooting

### Common Issues

1. **Missing R6 class files**
   - Error: "Some R6 class files are missing"
   - Solution: Ensure all required R6 class files are in the R/ directory

2. **No CSV files found**
   - Error: "No CSV files found in data-raw/csv"
   - Solution: Add CSV files to the data-raw/csv directory

3. **Quarto not found**
   - Error: "Quarto not found"
   - Solution: Install Quarto from https://quarto.org/docs/get-started/

4. **DuckDB errors**
   - Error: "No suitable data processor found"
   - Solution: Ensure R/duckdb_neuropsych_loader.R exists or set use_duckdb: false in config.yml

### Log File Analysis

The `workflow.log` file contains detailed information about the workflow execution. To analyze it:

```bash
# View the entire log
cat workflow.log

# View only errors
grep "\[ERROR\]" workflow.log

# View only warnings
grep "\[WARNING\]" workflow.log
```

## Advanced Usage

### Custom Modules

You can create custom modules to extend the workflow:

1. **data_processor_module.R**: Custom data processing logic
2. **domain_generator_module.R**: Custom domain generation logic
3. **report_generator_module.R**: Custom report generation logic

### Parallel Processing

Enable parallel processing in the configuration:

```yaml
processing:
  parallel: true
```

### Alternative Data Formats

The workflow supports multiple data formats:

```yaml
data:
  format: "all"  # Generates CSV, Parquet, and Arrow formats
```

## Performance Considerations

- **DuckDB**: 5-10x faster data queries compared to traditional R
- **Parquet**: 10-15x faster queries, 50-80% smaller files compared to CSV
- **R6 Classes**: More efficient memory usage with reference semantics
- **Parallel Processing**: Faster execution on multi-core systems

## Migration Guide

### From neuropsych_workflow.sh

1. Replace calls to `neuropsych_workflow.sh` with `unified_neuropsych_workflow.sh`
2. No other changes required - the unified workflow is backward compatible

### From new_patient_workflow.R

1. Replace calls to `new_patient_workflow.R` with `unified_workflow_runner.R`
2. Create a `config.yml` file with your configuration
3. No other changes required - the unified workflow is backward compatible

## Contributing

To contribute to the unified workflow:

1. Follow the architecture defined in `unified_workflow_architecture.md`
2. Add comprehensive logging to new components
3. Update the configuration schema if adding new options
4. Maintain backward compatibility with existing files
5. Add tests for new functionality

## License

This project is licensed under the same license as the original neuro2 package.
