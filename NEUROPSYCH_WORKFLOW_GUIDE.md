# Neuropsychological Report Generation Workflow Guide

## Overview
This guide provides a complete, concrete workflow for generating neuropsychological reports from raw CSV data to final PDF output.

## Quick Start (Recommended)

Run the complete workflow with a single command:
```bash
Rscript complete_neuropsych_workflow.R "Patient Name"
```

This handles all steps automatically with proper error handling and state management.

## Manual Step-by-Step Workflow

If you prefer to run each step manually:

### 1. Environment Setup
```r
# Load the package
devtools::load_all(".")

# Verify all template files are in place
Rscript check_all_templates.R
```

### 2. Data Processing
```bash
# Convert raw CSVs to structured parquet files
Rscript inst/scripts/data_processor_module.R
```
- **Input**: CSV files in `data-raw/csv/`
- **Output**: Parquet files in `data/`
  - `neurocog.parquet`
  - `neurobehav.parquet`
  - `validity.parquet`

### 3. Domain Generation
```bash
# Generate domain-specific QMD files (only for domains with data)
Rscript generate_domain_files.R
```
- **Output**: 
  - Domain files: `_02-01_iq.qmd`, `_02-02_academics.qmd`, etc.
  - Text placeholders: `_02-01_iq_text.qmd`, etc.

### 4. Asset Generation
```bash
# Generate all tables and figures
Rscript generate_all_domain_assets.R
```
- **Output**:
  - Table images: `table_*.png` or `table_*.pdf`
  - Figure files: `fig_*.svg`
  - SIRF figure: `fig_sirf_overall.svg`

### 5. Report Rendering
```bash
# Render the final PDF (choose format as needed)
quarto render template.qmd -t neurotyp-adult-typst      # Adult format
quarto render template.qmd -t neurotyp-pediatric-typst  # Pediatric format
quarto render template.qmd -t neurotyp-forensic-typst   # Forensic format
```
- **Output**: `output/template.pdf`

## Configuration

Edit `config.yml` to customize:
```yaml
data:
  input_dir: "data-raw/csv"    # Where raw CSVs are located
  output_dir: "data"           # Where processed files go
  format: "parquet"            # Output format (parquet/csv/feather)

report:
  template: "template.qmd"     # Main template file
  format: "neurotyp-adult-typst"  # Default report format
  output_dir: "output"         # Where PDFs are saved
```

## Troubleshooting

### Missing Data Files
If you see "No data files found":
1. Ensure CSVs exist in `data-raw/csv/`
2. Check file naming conventions
3. Re-run data processing step

### Domain Generation Issues
If no domains are generated:
1. Check that data processing completed successfully
2. Verify data contains valid domain information
3. Look for domain-specific data in parquet files

### Asset Generation Failures
If figures/tables fail to generate:
1. Ensure domain files were created first
2. Check for required R packages
3. Look for error messages in console output

### Rendering Errors
If Quarto rendering fails:
1. Ensure Quarto and Typst are installed
2. Check that all asset files exist
3. Clear `_freeze/` directory and retry
4. Verify template format matches config

## Best Practices

1. **Clean Rebuilds**: Delete `output/`, `_freeze/`, and generated `_02-*.qmd` files before full rebuild

2. **Incremental Updates**: After initial setup, you can re-run individual steps as needed

3. **Version Control**: Commit `config.yml` and template files, but not generated outputs

4. **Patient Privacy**: Never commit patient data or generated reports to version control

## Development vs Production Mode

### Development Mode
- Use `devtools::load_all(".")` to load package
- Run scripts individually for debugging
- Check intermediate outputs

### Production Mode
- Use `complete_neuropsych_workflow.R` for reliability
- Automated error handling and logging
- Consistent results

## Key Files Reference

| File | Purpose | When to Edit |
|------|---------|--------------|
| `config.yml` | Main configuration | Before each report |
| `template.qmd` | Report template | To change layout |
| `check_all_templates.R` | Template verification | Never (utility) |
| `generate_domain_files.R` | Domain QMD generation | Never (automated) |
| `generate_all_domain_assets.R` | Figure/table generation | Never (automated) |
| `data_processor_module.R` | CSV to parquet conversion | Never (automated) |
| `complete_neuropsych_workflow.R` | Full workflow runner | Never (orchestrator) |

## Summary

The workflow follows this sequence:
1. **Setup** → Verify environment and templates
2. **Process** → Convert CSV to structured data
3. **Generate** → Create domain files and assets
4. **Render** → Produce final PDF report

Use the unified `complete_neuropsych_workflow.R` script for the most reliable, hands-off experience.