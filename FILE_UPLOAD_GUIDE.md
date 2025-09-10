# File Upload Guide for neuro2

## Overview

The `neuro2` package supports multiple methods for inputting data files into the neuropsychological report generation system. This guide explains all available options for uploading and processing your test data.

## 📁 File Input Methods

### Method 1: Direct CSV Upload (Simplest)

If you already have CSV files with test data:

1. **Create the directory structure**:
   ```bash
   mkdir -p data-raw/csv
   ```

2. **Place your CSV files** in the `data-raw/csv/` directory
   - Files should contain neuropsychological test results
   - Supported formats: Any CSV with test scores, percentiles, etc.

3. **Run the workflow**:
   ```bash
   ./unified_neuropsych_workflow.sh "Patient Name"
   ```

### Method 2: PDF Extraction (Most Common)

If you have PDF reports from testing software:

1. **Choose the appropriate extraction template** based on your test:

   | Test Type | Template File | Description |
   |-----------|---------------|-------------|
   | WISC-V | `pluck_wisc5.Rmd` | Child intelligence test |
   | WAIS-5 | `pluck_wais5.Rmd` | Adult intelligence test |
   | WIAT-4 | `pluck_wiat4.Rmd` | Achievement test |
   | CAARS-2 | `pluck_caars2.Rmd` | ADHD rating scale |
   | RBANS | `pluck_rbans.Rmd` | Brief neurocognitive screen |
   | And many more... | See `inst/rmarkdown/templates/pluck_pdfs/skeleton/` |

2. **Open the template file** in RStudio or another R environment:
   ```r
   # Example: Open WISC-V template
   file.edit("inst/rmarkdown/templates/pluck_pdfs/skeleton/pluck_wisc5.Rmd")
   ```

3. **Update the patient name** in the YAML header:
   ```yaml
   params:
     patient: "Your Patient Name"
   ```

4. **Knit the document** - this will:
   - Prompt you to select your PDF file using `file.choose()`
   - Extract data from specified pages
   - Generate CSV files in `data-raw/csv/`

5. **Run the main workflow** to generate the report:
   ```bash
   ./unified_neuropsych_workflow.sh "Patient Name"
   ```

### Method 3: Programmatic Upload

For automated workflows or custom integrations:

```r
library(neuro2)

# Load data from a directory
load_data_duckdb(
  file_path = "path/to/your/csv/files",
  output_dir = "data",
  output_format = "all"  # Creates CSV, Parquet, and Arrow formats
)

# Run the complete workflow
config <- list(
  patient = list(name = "Patient Name", age = 35),
  data = list(input_dir = "data-raw/csv", output_dir = "data")
)

workflow <- WorkflowRunnerR6$new(config)
workflow$run()
```

## 📋 File Requirements

### CSV Files
- **Required columns**: Vary by test type, but typically include:
  - `test`, `test_name`, `scale`, `raw_score`, `score`, `percentile`
- **Format**: Standard CSV with headers
- **Encoding**: UTF-8 preferred

### PDF Files
- **Supported tests**: 50+ neuropsychological tests (see template list)
- **Pages**: Templates specify which pages to extract from
- **Quality**: Clear, text-based PDFs work best (not scanned images)

## 🛠️ Quick Setup Commands

### First-time setup:
```bash
# Create directories
mkdir -p data-raw/csv data output

# Make scripts executable
chmod +x unified_neuropsych_workflow.sh
chmod +x unified_workflow_runner.R

# Install R dependencies (if not already installed)
Rscript -e "install.packages(c('devtools', 'tabulapdf', 'duckdb', 'arrow'))"
```

### For each new patient:
```bash
# Method 1: Interactive workflow
./unified_neuropsych_workflow.sh "Patient Name"

# Method 2: Programmatic workflow  
Rscript unified_workflow_runner.R config.yml
```

## 🎯 Common Workflows

### Workflow A: Starting with PDF Reports
1. Run appropriate `pluck_*.Rmd` template to extract data from PDF
2. Verify CSV files were created in `data-raw/csv/`
3. Run `./unified_neuropsych_workflow.sh "Patient Name"`
4. Review generated report in `template.pdf`

### Workflow B: Starting with CSV Data
1. Place CSV files in `data-raw/csv/`
2. Run `./unified_neuropsych_workflow.sh "Patient Name"`
3. Review generated report in `template.pdf`

### Workflow C: Batch Processing
1. Organize multiple patients' CSV files in separate subdirectories
2. Use `unified_workflow_runner.R` with different config files
3. Automate with shell scripts for multiple patients

## 📊 Supported Test Types

The system supports extraction and processing for:

**Intelligence Tests:**
- WISC-V (Child), WAIS-5 (Adult), WPPSI-4 (Preschool)

**Achievement Tests:**
- WIAT-4, KTEA-3, WRAT-5

**Memory Tests:**
- WMS-IV, CVLT-3, RBANS

**Executive Function:**
- D-KEFS, CEFI, NAB

**ADHD/Behavior:**
- CAARS-2, Conners-4, BASC-3

**And many more** - see the complete list in `inst/rmarkdown/templates/pluck_pdfs/skeleton/`

## ❗ Troubleshooting

### "No CSV files found"
- **Problem**: `data-raw/csv/` directory is empty
- **Solution**: Add CSV files or run PDF extraction templates first

### "File upload failed" 
- **Problem**: `file.choose()` dialog was cancelled
- **Solution**: Re-run the template and select a valid PDF file

### "Extraction template not found"
- **Problem**: Test type not supported
- **Solution**: Use `pluck_general.Rmd` for custom extraction or modify existing template

### "Permission denied"
- **Problem**: Scripts are not executable
- **Solution**: Run `chmod +x *.sh *.R` to make scripts executable

## 💡 Pro Tips

1. **Batch Processing**: Place multiple test CSVs in `data-raw/csv/` for comprehensive reports
2. **Template Customization**: Copy and modify existing templates for new test types
3. **Data Validation**: Check the generated CSV files before running the main workflow
4. **Backup**: Keep original PDF files - you can re-extract if needed
5. **Performance**: Use Parquet format (`output_format = "parquet"`) for large datasets

## 🔗 Related Documentation

- [Unified Workflow README](UNIFIED_WORKFLOW_README.md) - Complete workflow documentation
- [README.md](README.md) - Package overview and installation
- Template files in `inst/rmarkdown/templates/pluck_pdfs/skeleton/` - Specific extraction examples

---

*For technical support or questions about file upload, please check the existing templates or create an issue in the GitHub repository.*