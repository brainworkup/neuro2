# Forensic Neuropsychological Report Generation - Troubleshooting Guide

## Pre-flight Checklist

### ✅ Required Files
Ensure all CSV files are in the `data-raw/` directory:
- [ ] caars2_observer.csv
- [ ] caars2_self.csv  
- [ ] cefi_observer.csv
- [ ] cefi_self.csv
- [ ] cvlt3_brief.csv
- [ ] dkefs.csv
- [ ] examiner.csv
- [ ] nabs.csv
- [ ] pai_clinical.csv
- [ ] pai_inatt.csv
- [ ] pai_validity.csv
- [ ] rocft.csv
- [ ] topf.csv
- [ ] wais5.csv
- [ ] wiat4.csv

### ✅ Required R Packages
The workflow will auto-install missing packages, but you can pre-install:
```r
install.packages(c("tidyverse", "here", "gt", "gtExtras", 
                   "glue", "janitor", "quarto", "rmarkdown"))
```

### ✅ Required R6 Classes
Ensure these files are in your working directory:
- [ ] DomainProcessorR6.R
- [ ] DotplotR6.R
- [ ] TableGT.R
- [ ] (Other R6 class files as needed)

## Common Issues and Solutions

### 1. **CSV Files Not Found**
**Error:** `File not found: data-raw/[filename].csv`

**Solution:**
- Create the `data-raw` directory: `dir.create("data-raw")`
- Ensure all CSV files are placed in this directory
- Check file names match exactly (case-sensitive)

### 2. **Missing Columns in Data**
**Error:** `object 'column_name' not found`

**Solution:**
- Check that your CSV files have the required columns:
  - test, test_name, scale, raw_score, score
  - ci_95, percentile, range, domain, subdomain, narrow
  - For behavioral data: test_type should indicate "behavioral"

### 3. **Quarto Rendering Fails**
**Error:** `Error in quarto_render: quarto not found`

**Solution:**
- Install Quarto from: https://quarto.org/docs/get-started/
- Or use RStudio (which includes Quarto)
- As fallback, the script will try rmarkdown

### 4. **GT Table Errors**
**Error:** `could not find function "gt"`

**Solution:**
```r
install.packages("gt")
install.packages("gtExtras") 
library(gt)
library(gtExtras)
```

### 5. **No Domain Data**
**Warning:** `No data available for this domain`

**Solution:**
- Check that the `domain` column in your CSV files contains:
  - "General Cognitive Ability"
  - "Verbal/Language"
  - "Visual Perception/Construction"
  - "Memory"
  - "Attention/Executive"
  - "Motor"
  - "Daily Living"

### 6. **PDF Generation Fails**
**Error:** `LaTeX Error` or `PDF conversion failed`

**Solution:**
- Install tinytex: `tinytex::install_tinytex()`
- Or install full LaTeX distribution
- Check for special characters in data that might break LaTeX

## Manual Workflow Steps

If the automated workflow fails, run each step manually:

```r
# Step 1: Import Data
source("import_process_data.R")

# Step 2: Create Domain Files
source("create_domain_qmds.R")

# Step 3: Generate Summaries
source("render_domains.R")

# Step 4: Create Final Report
source("generate_final_report.R")
```

## Customization Options

### Change Patient Information
Edit in `generate_final_report.R`:
```r
patient_info <- list(
  name = "Your Patient Name",
  age = 35,
  sex = "Female",
  dob = "1989-01-01",
  doe = "2024-01-15",
  date_of_report = Sys.Date()
)
```

### Modify Domain Scales
Edit in `create_domain_qmds.R`:
```r
forensic_domains <- list(
  iq = list(
    name = "General Cognitive Ability",
    scales = c("Your", "Scale", "Names", "Here")
  )
)
```

### Change Report Template
- Edit `forensic_report_biggie.qmd` for layout changes
- Modify individual `_##-##_*.qmd` files for section changes

## Quick Diagnostic Commands

```r
# Check if data loaded correctly
dim(neurocog)
dim(neurobehav)

# Check available domains
unique(neurocog$domain)

# Check for missing values
sum(is.na(neurocog$percentile))

# List all generated files
list.files(pattern = "\\.qmd$")
list.files(pattern = "\\.(png|svg|pdf)$")
```

## Contact for Support

If you encounter issues not covered here:
1. Check that all R6 class files are sourced
2. Ensure working directory is set correctly: `getwd()`
3. Check R and package versions: `sessionInfo()`
4. Review error messages carefully - they often indicate the specific issue

## Final Notes

- The workflow is designed to be modular - you can re-run individual steps
- Generated files are overwritten on each run - backup if needed
- The HTML output can be useful for debugging before PDF generation
- Domain summaries can be manually edited in the `*_text.qmd` files