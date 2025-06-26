# Forensic Neuropsychological Report Generator

A comprehensive R-based workflow for generating professional forensic neuropsychological evaluation reports from raw test data.

## Overview

This system automates the creation of detailed neuropsychological reports by:
- Importing multiple CSV files containing test results
- Computing domain and subdomain scores
- Generating tables and visualizations
- Creating formatted text summaries
- Producing a professional PDF report

## Quick Start

```r
# Run the complete workflow
source("run_complete_workflow.R")
```

This will generate `forensic_report_biggie.pdf` with all analyses and visualizations.

## Project Structure

```
project/
├── data-raw/               # Raw CSV test files (input)
│   ├── wais5.csv
│   ├── nabs.csv
│   ├── caars2_self.csv
│   └── ... (other test CSVs)
├── data/                   # Processed data files (generated)
│   ├── neurocog.csv
│   └── neurobehav.csv
├── R6 Classes/             # Object-oriented components
│   ├── DomainProcessorR6.R
│   ├── DotplotR6.R
│   ├── TableGT.R
│   └── ... (other classes)
├── Workflow Scripts/       # Main processing scripts
│   ├── import_process_data.R      # Step 1
│   ├── create_domain_qmds.R       # Step 2
│   ├── render_domains.R           # Step 3
│   └── generate_final_report.R    # Step 4
├── Domain Files/           # Generated QMD files
│   ├── _02-01_iq.qmd
│   ├── _02-01_iq_text.qmd
│   └── ... (other domains)
└── Output/                 # Final products
    ├── forensic_report_biggie.pdf
    ├── forensic_report_biggie.html
    └── figures/
```

## Workflow Steps

### Step 1: Import and Process Data
- Reads all CSV files from `data-raw/`
- Standardizes column names
- Combines into `neurocog` and `neurobehav` datasets
- Computes z-scores and domain means

### Step 2: Create Domain Files
- Generates QMD templates for each cognitive domain
- Creates placeholder text files for results
- Sets up table and figure generation code

### Step 3: Render Domains
- Processes data for each domain
- Generates clinical summaries based on performance
- Creates tables and dotplot visualizations
- Writes interpretive text

### Step 4: Generate Final Report
- Combines all sections into master document
- Adds patient information and metadata
- Renders to PDF (and HTML) format
- Includes appendices and score conversion tables

## Key Features

### Cognitive Domains Assessed
1. **General Cognitive Ability** - Overall intellectual functioning
2. **Verbal/Language** - Language comprehension and expression
3. **Visual Perception/Construction** - Visuospatial abilities
4. **Memory** - Learning and recall
5. **Attention/Executive** - Focus and executive control
6. **Motor** - Fine motor speed and dexterity
7. **Daily Living** - Functional abilities

### Automated Interpretations
- Performance classifications (e.g., "Below Average", "Average") 
- Identification of strengths and weaknesses
- Functional impact statements
- Clinical recommendations

### Professional Formatting
- APA-style tables with proper footnotes
- Z-score visualizations with clinical cutoffs
- Comprehensive appendices
- Score conversion reference table

## Customization

### Patient Information
Edit `patient_info` in `generate_final_report.R`:
```r
patient_info <- list(
  name = "Patient Name",
  age = 50,
  sex = "Female",
  dob = "1974-01-01",
  doe = Sys.Date(),
  date_of_report = Sys.Date()
)
```

### Report Sections
Modify individual QMD files:
- `_01-00_nse.qmd` - Neurobehavioral status exam
- `_03-00_summary.qmd` - Summary/impressions
- `_03-01_recommendations.qmd` - Recommendations

### Domain Definitions
Edit `forensic_domains` in `create_domain_qmds.R` to change which scales belong to each domain.

## Requirements

### R Packages
- tidyverse (data manipulation)
- gt & gtExtras (tables)
- ggplot2 (visualizations)  
- quarto (document rendering)
- here (file paths)
- glue (string interpolation)
- janitor (data cleaning)

### External Software
- Quarto CLI (for rendering)
- LaTeX distribution (for PDF output)

### Data Format
CSV files must include:
- `test`: Test abbreviation
- `test_name`: Full test name
- `scale`: Subtest/scale name
- `raw_score`: Raw score value
- `score`: Standard/scaled score
- `percentile`: Percentile rank
- `range`: Performance classification
- `domain`: Cognitive domain

## Troubleshooting

See `troubleshooting_guide.md` for common issues and solutions.

### Quick Fixes
- Missing packages: Script auto-installs
- File not found: Check `data-raw/` directory
- PDF fails: Install tinytex or full LaTeX
- No data for domain: Check domain names in CSVs

## Example Usage

```r
# Full automated workflow
source("run_complete_workflow.R")

# Or run steps individually:
source("import_process_data.R")    # Import CSVs
source("create_domain_qmds.R")     # Create templates  
source("render_domains.R")         # Generate summaries
source("generate_final_report.R")  # Create final report
```

## Output

The workflow generates:
- **forensic_report_biggie.pdf** - Complete formatted report
- **forensic_report_biggie.html** - Web version
- **table_*.png** - Domain score tables
- **fig_*.svg** - Performance visualizations
- Individual domain analysis files

## License

This neuropsychological report generator is provided as-is for clinical and forensic use. Ensure compliance with relevant professional guidelines and regulations.

## Support

For issues or questions:
1. Check troubleshooting guide
2. Review error messages
3. Verify data format
4. Ensure all dependencies installed

---

*Generated with the Forensic Neuropsychological Report Generator v1.0*