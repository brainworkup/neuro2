# Neuropsychological Report Generation Workflow Guide (FIXED)

## Overview
This guide provides a complete, concrete workflow for generating neuropsychological reports from raw CSV data to final PDF output, with fixes for common issues.

## Quick Start (Recommended)

Run the complete workflow with a single command:
```bash
Rscript complete_neuropsych_workflow_fixed.R "Patient Name"
```

This handles all steps automatically with proper error handling, state management, and fixes for:
- Domain files generated based on actual data (not templates)
- Assets only generated for domains with data
- Figures saved in the correct `figs/` directory

## Manual Step-by-Step Workflow

If you prefer to run each step manually:

### 1. Environment Setup
```r
# Load the package
devtools::load_all(".")

# Copy config.yml from template
file.copy("inst/quarto/templates/typst-report/config.yml", "config.yml", overwrite = TRUE)

# Verify template files (NOT domain files)
Rscript check_all_templates_fixed.R
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

### 3. Domain Generation (Based on Available Data)
```bash
# Generate domain-specific QMD files ONLY for domains with data
Rscript generate_domain_files.R
```
- **Output**: 
  - Domain files: `_02-01_iq.qmd`, `_02-02_academics.qmd`, etc. (only if data exists)
  - Text placeholders: `_02-01_iq_text.qmd`, etc.
- **Note**: This script validates data before creating files

### 4. Asset Generation (Only for Domains with Data)
```bash
# Generate tables and figures ONLY for domains that have data
Rscript generate_all_domain_assets_fixed.R
```
- **Output** (in `figs/` directory):
  - Table images: `figs/table_*.png`
  - Figure files: `figs/fig_*.svg`
  - SIRF figure: `figs/fig_sirf_overall.svg`

### 5. Report Rendering
```bash
# Clear any cached render data first
rm -rf _freeze/

# Render the final PDF (choose format as needed)
quarto render template.qmd -t neurotyp-adult-typst      # Adult format
quarto render template.qmd -t neurotyp-pediatric-typst  # Pediatric format
quarto render template.qmd -t neurotyp-forensic-typst   # Forensic format
```
- **Output**: `output/template.pdf`

## Key Fixes Applied

### 1. Domain File Generation
- **Problem**: `check_all_templates.R` was creating generic domain files without checking data
- **Fix**: Use `generate_domain_files.R` which validates data exists before creating files

### 2. Asset Generation for Non-existent Domains
- **Problem**: Assets were generated for all domains, even without data (e.g., social cognition)
- **Fix**: `generate_all_domain_assets_fixed.R` only processes domains that have QMD files

### 3. Figure Location
- **Problem**: Figures were saved in root directory instead of `figs/`
- **Fix**: Enforced `figs/` directory for all figure outputs

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

### Missing Domain Files
If expected domains are missing:
1. Check that the domain has data in the parquet files
2. Verify the domain name matches in `domain_config`
3. Look for validation messages in the generate_domain_files.R output

### Figures in Wrong Location
If figures appear in root instead of `figs/`:
1. Ensure `figs/` directory exists before generation
2. Use the fixed asset generation script
3. Check environment variable `FIGURE_OUTPUT_DIR`

### Rendering Failures
If Quarto rendering fails:
1. Clear `_freeze/` directory: `rm -rf _freeze/`
2. Check that all required assets exist in `figs/`
3. Verify template.qmd includes the correct domain files
4. Check Quarto and Typst are properly installed

## Best Practices

1. **Clean Rebuilds**: 
   ```bash
   rm -rf output/ _freeze/ figs/ _02-*.qmd
   Rscript complete_neuropsych_workflow_fixed.R
   ```

2. **Data Validation**: Always check which domains have data:
   ```r
   library(arrow)
   neurocog <- read_parquet("data/neurocog.parquet")
   table(neurocog$domain)
   ```

3. **Incremental Updates**: After initial setup, you can re-run individual steps

4. **Version Control**: Commit only:
   - `config.yml`
   - Template files (`_00-*.qmd`, `_01-*.qmd`, `_03-*.qmd`)
   - NOT generated files (`_02-*.qmd`, figures, PDFs)

## Development vs Production Mode

### Development Mode
- Use individual scripts for debugging
- Check intermediate outputs
- Review validation messages

### Production Mode
- Use `complete_neuropsych_workflow_fixed.R`
- Automated error handling and logging
- Consistent, validated results

## Key Files Reference

| File | Purpose | When to Edit |
|------|---------|--------------|
| `config.yml` | Main configuration | Before each report |
| `template.qmd` | Report template | To change layout |
| `check_all_templates_fixed.R` | Template verification (not domains) | Never (utility) |
| `generate_domain_files.R` | Domain QMD generation with validation | Never (automated) |
| `generate_all_domain_assets_fixed.R` | Figure/table generation for valid domains | Never (automated) |
| `data_processor_module.R` | CSV to parquet conversion | Never (automated) |
| `complete_neuropsych_workflow_fixed.R` | Full workflow runner with fixes | Never (orchestrator) |

## Summary

The workflow follows this validated sequence:
1. **Setup** → Verify environment and non-domain templates
2. **Process** → Convert CSV to structured data
3. **Validate & Generate** → Create domain files only where data exists
4. **Asset Creation** → Generate figures/tables only for valid domains
5. **Render** → Produce final PDF report

Use the fixed `complete_neuropsych_workflow_fixed.R` script for the most reliable experience with proper data validation and file organization.