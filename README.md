# neuro2: Neuropsychological Report Generation Workflow

This repository contains a test workflow for generating neuropsychological reports using R and Quarto. The workflow demonstrates how to process neuropsychological test data, generate domain-specific files, and compile a complete report using a forensic template.

## Overview

The neuro2 package provides a comprehensive framework for processing neuropsychological assessment data and generating professional reports. It uses R6 classes to implement an object-oriented approach to data processing and report generation.

### Patient Information for Test Workflow

The test workflow uses the following patient information:
- **Name**: Biggie
- **Age**: 44
- **Sex**: Male
- **Template**: Forensic

## Directory Structure

- `data-raw/`: Contains raw CSV files from neuropsychological assessments
- `data/`: Processed data files and domain-specific output
- `output/`: Generated reports
- `R/`: R6 classes that implement the report generation system
- `inst/extdata/_extensions/`: Quarto templates for different report types

## Workflow Steps

The workflow consists of the following steps:

1. **Data Import and Processing**
   - Import individual CSV files from `data-raw/`
   - Process and standardize the data
   - Generate `neurocog.csv` and `neurobehav.csv` datasets

2. **Domain File Generation**
   - Create domain-specific QMD files (e.g., `_02-01_iq.qmd`, `_02-05_memory.qmd`)
   - Generate text summaries for each domain
   - Create tables and figures for visualization

3. **Report Rendering**
   - Compile all domain files into a complete report
   - Render the report using Quarto
   - Generate the final PDF

## R6 Classes in neuro2

The workflow uses several R6 classes defined in the package:

- `ReportTemplateR6`: Manages the Quarto template system for neuropsychological reports
- `NeuropsychResultsR6`: Processes and formats results text
- `DomainProcessorR6`: Processes domain-specific data
- `IQReportGeneratorR6`: Specialized processor for IQ data
- `NeuropsychReportSystemR6`: Orchestrates the entire report generation system

## Usage

To run the test workflow:

1. First run the setup script to ensure all dependencies are installed:
   ```R
   source("setup_environment.R")
   ```

2. Check that the R6 classes are properly loaded:
   ```R
   source("check_package.R")
   ```

3. Run the workflow script:
   ```R
   source("run_test_workflow.R")
   ```

4. Check the `output/` directory for the generated report (`Biggie_Neuropsych_Report.pdf`).

## Creating a New Patient Report

To create a report for a new patient:

1. Create a new directory for the patient
2. Copy the template files and scripts from this repository
3. Modify the patient information in `test_workflow.R`
4. Place the patient's CSV files in the `data-raw/` directory
5. Edit the text files (e.g., `_02-01_iq_text.qmd`) to customize the clinical interpretation
6. Run the workflow

## Requirements

- R 4.0.0 or higher
- Quarto 1.0.0 or higher
- Required R packages: R6, dplyr, readr, purrr, stringr, tidyr, here, quarto

## Future Development

This package is designed to be used as a GitHub template, allowing you to quickly create a new repository for each patient with the necessary structure and files. Future enhancements will include:

- Additional templates for different report types
- More domain processors for specialized assessments
- Enhanced visualization options
- Integration with electronic health record systems
