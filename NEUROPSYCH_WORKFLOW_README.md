# Neuropsychological Report Generation Workflow

This README provides a step-by-step guide for generating neuropsychological reports using the neuro2 package, following your standard workflow from PDF extraction to final report generation.

## Prerequisites

1. **PDF Reports**: Individual neuropsychological test PDFs (WISC-V, WAIS-V, RBANS, etc.)
2. **R Environment**: R 4.0+ with required packages installed
3. **Quarto**: For final PDF rendering
4. **Java**: Required for PDF extraction (tabulapdf package)

## Workflow Overview

```
PDFs → CSV Files → Consolidated Data → Domain Processing → Report Generation
```

## Step-by-Step Instructions

### Step 1: Extract Data from PDF Reports

**Location**: `inst/rmarkdown/templates/pluck_pdfs/skeleton/`

**Process**: Use RMarkdown templates to extract tables and text from individual test PDFs.

#### Available Templates:
- `pluck_wisc5.Rmd` - WISC-V intelligence test
- `pluck_wais5.Rmd` - WAIS-V adult intelligence test  
- `pluck_rbans.Rmd` - RBANS memory assessment
- `pluck_wiat4.Rmd` - WIAT-4 achievement test
- `pluck_ktea3.Rmd` - KTEA-3 achievement test
- `pluck_caars2.Rmd` - CAARS-2 ADHD rating scale
- And many more...

#### Manual Process:
1. Open the appropriate `.Rmd` template for your test
2. Update the `params` section with patient name and test details
3. Run `file.choose()` to select the PDF file
4. Knit the RMarkdown document
5. CSV files will be generated in the working directory

#### Automated Process:
```bash
# Run the automated extraction script
./extract_all_pdfs.sh
```

**Output**: Individual CSV files for each test (e.g., `wisc5.csv`, `rbans.csv`)

### Step 2: Organize CSV Files

**Action**: Move all generated CSV files to `data-raw/csv/` directory

```bash
# Create directory if it doesn't exist
mkdir -p data-raw/csv

# Move CSV files
mv *.csv data-raw/csv/
```

**Flexibility**: The system automatically detects and processes any CSV files in this directory, so the number and type of files can vary per patient.

### Step 3: Generate Consolidated Datasets

**Function**: `load_data_duckdb()` from `R/duckdb_neuropsych_loader.R`

**Process**: Reads all CSV files and creates three summary datasets:

```r
# Run data processing
load_data_duckdb(
  file_path = "data-raw/csv",
  output_dir = "data", 
  output_format = "all"  # Creates CSV, Parquet, and Arrow formats
)
```

**Output Files**:
- `data/neurocog.csv` - Cognitive test results
- `data/neurobehav.csv` - Behavioral assessments  
- `data/validity.csv` - Validity measures

**Score Ranges**: Automatically adds performance ranges based on percentiles:
- 98+: "Exceptionally High"
- 91-97: "Above Average" 
- 75-90: "High Average"
- 25-74: "Average"
- 9-24: "Low Average"
- 2-8: "Below Average"
- <2: "Exceptionally Low"

### Step 4: Domain Processing with R6 Classes

**Script**: `neuro2_r6_update_workflow.R`

**Process**: Uses R6 classes to create domain-specific content:

#### A) Text Generation (`NeuropsychResultsR6`)
- Concatenates patient performance descriptions
- Creates narrative text for each domain
- Generates `_02-XX_domain_text.qmd` files

#### B) Table Generation (`TableGT`)
- Creates formatted tables using the `gt` package
- Handles statistical formatting and footnotes
- Exports publication-ready tables

#### C) Visualization (`DotplotR6`) 
- Generates domain-specific dot plots
- Creates overall cognitive profile visualizations
- Saves plots as SVG files for high-quality rendering

**Domain Files Created**:
- `_02-01_iq.qmd` - General Cognitive Ability
- `_02-02_academics.qmd` - Academic Skills
- `_02-03_verbal.qmd` - Verbal/Language
- `_02-04_memory.qmd` - Memory
- `_02-05_executive.qmd` - Attention/Executive
- And corresponding `*_text.qmd` files

### Step 5: Template Assembly

**File**: `template.qmd`

**Process**: 
- Dynamically includes generated domain files
- Incorporates NSE (Neurobehavioral Status Exam) content
- Assembles all components into cohesive report structure

**Automatic Integration**: Domain files are included based on available patient data.

### Step 6: Manual Summary Writing

**Your Task**: Add clinical summary and recommendations to designated sections in `template.qmd`

**Sections to Complete**:
- Clinical summary and interpretation
- Diagnostic impressions
- Recommendations for treatment/intervention
- Follow-up suggestions

### Step 7: Final Report Rendering

**Command**: 
```bash
quarto render template.qmd --to typst-pdf
```

**Output**: Professional PDF report with Typst typesetting

## Automation Scripts

### Complete Workflow Script
```bash
# Run the complete automated workflow
./neuropsych_workflow.sh [patient_name]
```

### Individual Steps
```bash
# Step 1-3: Data processing only
./process_patient_data.sh

# Step 4-5: Domain generation only  
Rscript neuro2_r6_update_workflow.R

# Step 7: Render final report
quarto render template.qmd --to typst-pdf
```

## Troubleshooting

### Java Issues (PDF Extraction)
- Ensure Java 11+ is installed
- Set `JAVA_HOME` environment variable
- Use `process_rbans_data()` function as alternative for RBANS

### Missing Dependencies
```bash
# Install R dependencies
Rscript install_dependencies.R

# Update package environment
R -e "renv::restore()"
```

### DuckDB Issues
```r
# Verify DuckDB installation
DBI::dbConnect(duckdb::duckdb())
```

### Quarto Rendering Issues
```bash
# Check Quarto installation
quarto check

# Try HTML format if PDF fails
quarto render template.qmd --to html
```

## File Structure

```
neuro2/
├── data-raw/csv/           # Raw CSV files from PDF extraction
├── data/                   # Processed datasets (neurocog, neurobehav, validity)
├── inst/rmarkdown/templates/pluck_pdfs/skeleton/  # PDF extraction templates
├── R/                      # R6 classes and functions
├── _02-XX_*.qmd           # Generated domain files
├── template.qmd           # Main report template
├── _variables.yml         # Patient information
└── neuropsych_workflow.sh # Automation script
```

## Performance Notes

- **R6 Classes**: 2-3x faster than procedural approach
- **DuckDB/Parquet**: 4-5x faster than CSV processing
- **Memory Efficiency**: 40-60% reduction through reference semantics

## Next Steps

After running the workflow:
1. Review generated domain files for accuracy
2. Check data quality in processed datasets
3. Add your clinical summary and recommendations
4. Render final report and review formatting
5. Customize styling or content as needed
