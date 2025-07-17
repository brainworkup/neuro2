# neuro2 Workflow Guide: Step-by-Step Instructions

This guide provides detailed instructions for using the neuro2 package to generate neuropsychological reports from start to finish.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Data Preparation](#data-preparation)
3. [Running the Workflow](#running-the-workflow)
4. [Customizing Reports](#customizing-reports)
5. [Understanding the Output](#understanding-the-output)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Workflows](#advanced-workflows)

------------------------------------------------------------------------

## Initial Setup {#initial-setup}

### Step 1: Environment Preparation

1. **Install R and RStudio**

   - Download R (version 4.1+) from [CRAN](https://cran.r-project.org/)
   - Install RStudio from [Posit](https://posit.co/products/open-source/rstudio/)
1. **Install Quarto**

   ```bash
   # macOS (using Homebrew)
   brew install quarto

   # Or download from https://quarto.org/docs/get-started/
   ```
1. **Install LaTeX (for PDF output)**

   ```r
   # In R console
   install.packages("tinytex")
   tinytex::install_tinytex()
   ```
1. **Clone or Download the neuro2 Repository**

   ```bash
   git clone https://github.com/brainworkup/neuro2.git
   cd neuro2
   ```
1. **Install Package Dependencies**

   ```r
   # Open R in the neuro2 directory
   install.packages("devtools")
   devtools::install_deps()
   ```

### Step 2: Verify Installation

Run this verification script:

```r
# Check R version
R.version.string

# Check Quarto
system("quarto --version")

# Check package loading
library(tidyverse)
library(here)
library(gt)
library(quarto)

# Check working directory
getwd()  # Should show your neuro2 directory
```

------------------------------------------------------------------------

## Data Preparation {#data-preparation}

### Step 1: Understanding Data Requirements

Your CSV files must contain these columns:

- `test`: Name of test 
- `test_name`: Full test name (e.g., "WAIS-5", "CVLT-3") 
- `scale`: Subtest/scale name 
- `raw_score`: Raw score (can be NA) 
- `score`: Standard/scaled score 
- `percentile`: Percentile rank 
- `range`: Classification (e.g., "Average", "Low Average") 
- `domain`: Cognitive domain

### Step 2: Organizing Test Data

1. **Create data directory structure**

   ```bash
   mkdir -p data-raw
   mkdir -p data
   ```
1. **Place CSV files in data-raw/**

   - Name files descriptively: `wais5.csv`, `cvlt3_brief.csv`, etc.
   - Each file represents one test or battery
1. **Example CSV format**

   ```csv
   test,test_name,scale,raw_score,score,percentile,range,domain
   WAIS5,Wechsler Adult Intelligence Scale-5,Full Scale IQ,NA,95,37,Average,General Cognitive Ability
   WAIS5,Wechsler Adult Intelligence Scale-5,Verbal Comprehension,NA,102,55,Average,Verbal/Language
   ```

### Step 3: Validate Your Data

```r
# Check your CSV files
csv_files <- list.files("data-raw", pattern = "*.csv", full.names = TRUE)
print(csv_files)

# Validate a sample file
sample_data <- read_csv(csv_files[1])
names(sample_data)  # Should show required columns
summary(sample_data)
```

------------------------------------------------------------------------

## Running the Workflow {#running-the-workflow}

### Option 1: Quick Start (Efficient Workflow)

The fastest way to generate a report:

```r
# 1. Set working directory
setwd("~/neuro2")

# 2. Run the efficient workflow
source("efficient_workflow_v5.R")
```

This automatically: 

- Processes all CSV files in `data-raw/` 
- Updates patient variables 
- Generates domain summaries 
- Creates the final report

### Option 2: Step-by-Step Workflow

For more control over each step:

#### Step 1: Import and Process Data

```r
# Load and process raw data files
source("01_import_process_data.R")

# This creates:
# - data/neurocog.csv (cognitive test data)
# - data/neurobehav.csv (behavioral test data)
# - data/validity.csv (validity measures)
```

#### Step 2: Update Patient Information

```r
# Edit patient demographics
# You can do this manually in _variables.yml or programmatically:

variables <- yaml::read_yaml("_variables.yml")
variables$patient <- "John Doe"
variables$first_name <- "John"
variables$last_name <- "Doe"
variables$age <- 45
variables$sex <- "male"
variables$education <- 16
variables$handedness <- "right"
yaml::write_yaml(variables, "_variables.yml")
```

#### Step 3: Create Domain Files

```r
# Generate domain-specific QMD files
source("02_create_domain_qmds.R")

# This creates files like:
# - _02-01_iq.qmd
# - _02-02_academics.qmd
# - _02-05_memory.qmd
```

#### Step 4: Generate Domain Summaries

```r
# Process data and create interpretations
source("03_render_domains.R")

# This:
# - Analyzes performance by domain
# - Generates clinical interpretations
# - Creates summary text files
```

#### Step 5: Render Final Report

```r
# Compile everything into final report
quarto::quarto_render("template.qmd")

# Output: template.pdf (and template.html)
```

### Option 3: Complete Forensic Workflow

For forensic evaluations with additional requirements:

```r
# Run the forensic-specific workflow
source("06_run_complete_workflow.R")

# This includes:
# - Forensic-specific formatting
# - Additional validity measures
# - Legal disclaimer sections
```

------------------------------------------------------------------------

## Customizing Reports {#customizing-reports}

### Modifying Patient Information

1. **Edit `_variables.yml`**

   ```yaml
   patient: "Jane Smith"
   first_name: "Jane"
   last_name: "Smith"
   age: 35
   sex: "female"
   dob: "1989-06-15"
   education: 18  # Years of education
   handedness: "left"
   referral: "Dr. Johnson"
   ```
1. **Add custom variables**

   ```yaml
   # Add any custom fields
   ethnicity: "Hispanic"
   primary_language: "Spanish"
   interpreter_used: false
   ```

### Customizing Report Sections

1. **Neurobehavioral Status Exam** (`_01-00_nse_adult.qmd`)

   - Edit clinical history
   - Modify mental status observations
   - Add relevant background information
1. **Domain Interpretations** (`_02-*_*_text.qmd` files)

   - Customize clinical interpretations
   - Add qualitative observations
   - Include test-specific notes
1. **Summary and Recommendations** (`_03-00_sirf.qmd`, `_03-01_recs.qmd`)

   - Tailor diagnostic impressions
   - Customize recommendations
   - Add referral suggestions

### Changing Report Format

Edit `_quarto.yml` to modify formatting:

```yaml
format:
  neurotyp-adult-typst:
    fontsize: 12pt  # Change font size
    papersize: "a4"  # Change paper size
    margin:
      top: 1in
      bottom: 1in
      left: 1.25in
      right: 1in
```

------------------------------------------------------------------------

## Understanding the Output {#understanding-the-output}

### Generated Files

After running the workflow, you'll find:

1. **Data Files** (`data/` directory)

   - `neurocog.csv`: Processed cognitive data
   - `neurobehav.csv`: Processed behavioral data
   - `validity.csv`: Validity indicators
1. **Domain Files** (root directory)

   - `_02-01_iq.qmd`: IQ analysis
   - `_02-01_iq_text.qmd`: IQ interpretation
   - Similar pairs for each domain
1. **Output Files**

   - `template.pdf`: Final report
   - `template.html`: Web version
   - `*.svg`: Generated figures

### Report Structure

The final report includes:

1. **Cover Page**

   - Patient demographics
   - Dates of evaluation
   - Report date
1. **Tests Administered**

   - Complete list of assessments
1. **Neurobehavioral Status Exam**

   - Reason for referral
   - Background information
   - Mental status
1. **Neurocognitive Findings**

   - Domain-by-domain analysis
   - Tables and figures
   - Clinical interpretations
1. **Summary/Impressions**

   - Overall findings
   - Diagnostic considerations
1. **Recommendations**

   - Clinical recommendations
   - Follow-up suggestions
1. **Appendix**

   - Score classification table
   - Technical notes

------------------------------------------------------------------------

## Troubleshooting {#troubleshooting}

### Common Issues and Solutions

#### 1. Data Import Errors

**Problem**: "File not found" errors

```r
Error in read_csv(file_path) : 'data-raw/wais5.csv' does not exist
```

**Solution**:

```r
# Check working directory
getwd()

# List files in data-raw
list.files("data-raw")

# Ensure correct path
file.exists("data-raw/wais5.csv")
```

#### 2. Missing Columns

**Problem**: "Unknown column" errors

```r
Error: Can't subset columns that don't exist
```

**Solution**:

```r
# Check column names in your CSV
data <- read_csv("data-raw/your_file.csv")
names(data)

# Ensure required columns exist
required_cols <- c("test", "scale", "score", "percentile", "domain")
missing_cols <- setdiff(required_cols, names(data))
print(missing_cols)
```

#### 3. Quarto Rendering Failures

**Problem**: Report won't render

```
Error: Failed to render template.qmd
```

**Solution**:

```r
# Check Quarto installation
system("quarto check")

# Try rendering with verbose output
quarto::quarto_render("template.qmd", quiet = FALSE)

# Check for missing QMD files
required_files <- c("_01-00_nse_adult.qmd", "_02-01_iq.qmd", "_03-00_sirf.qmd")
sapply(required_files, file.exists)
```

#### 4. LaTeX/PDF Issues

**Problem**: PDF generation fails

```
! LaTeX Error: File `typst.sty' not found
```

**Solution**:

```r
# Reinstall TinyTeX
tinytex::reinstall_tinytex()

# Or use HTML output instead
quarto::quarto_render("template.qmd", output_format = "html")
```

### Debug Mode

Enable detailed logging:

```r
# Set debug options
options(
  neuro2.debug = TRUE,
  neuro2.verbose = TRUE,
  warn = 2  # Turn warnings into errors
)

# Run with tracing
debug(source)
source("efficient_workflow_v5.R")
```

------------------------------------------------------------------------

## Advanced Workflows {#advanced-workflows}

### Batch Processing Multiple Patients

```r
# Process multiple patients
patients <- list(
  list(name = "Patient A", age = 30, sex = "male", folder = "patient_a"),
  list(name = "Patient B", age = 45, sex = "female", folder = "patient_b")
)

for (patient in patients) {
  # Create patient directory
  dir.create(patient$folder, showWarnings = FALSE)
  
  # Copy data files
  file.copy("data-raw", patient$folder, recursive = TRUE)
  
  # Change to patient directory
  setwd(patient$folder)
  
  # Update variables
  variables <- yaml::read_yaml("../_variables.yml")
  variables$patient <- patient$name
  variables$age <- patient$age
  variables$sex <- patient$sex
  yaml::write_yaml(variables, "_variables.yml")
  
  # Run workflow
  source("../efficient_workflow_v5.R")
  
  # Return to main directory
  setwd("..")
}
```

### Custom Domain Analysis

```r
# Load processed data
neurocog <- read_csv("data/neurocog.csv")

# Analyze specific domain
memory_data <- neurocog %>%
  filter(domain == "Memory") %>%
  group_by(scale) %>%
  summarise(
    mean_score = mean(score, na.rm = TRUE),
    mean_percentile = mean(percentile, na.rm = TRUE)
  )

# Create custom visualization
library(ggplot2)
ggplot(memory_data, aes(x = scale, y = mean_percentile)) +
  geom_col() +
  coord_flip() +
  theme_minimal() +
  labs(title = "Memory Performance Profile")
```

### Integrating with Electronic Health Records

```r
# Example: Export for EHR integration
library(jsonlite)

# Prepare summary data
summary_data <- list(
  patient_id = variables$patient,
  test_date = Sys.Date(),
  domains = neurocog %>%
    group_by(domain) %>%
    summarise(mean_percentile = mean(percentile, na.rm = TRUE)) %>%
    deframe()
)

# Export as JSON
write_json(summary_data, "patient_summary.json")
```

------------------------------------------------------------------------

## Best Practices

1. **Version Control**

   - Keep your data and reports in git
   - Tag versions for each patient report
   - Use `.gitignore` for sensitive data
1. **Data Security**

   - Never commit patient data to public repos
   - Use encrypted storage for PHI
   - Follow HIPAA guidelines
1. **Quality Control**

   - Review generated interpretations
   - Verify score conversions
   - Cross-check with manual calculations
1. **Documentation**

   - Document any custom modifications
   - Keep notes on unusual cases
   - Maintain change log for reports

------------------------------------------------------------------------

## Getting Help

- **Package Issues**: Check [GitHub Issues](https://github.com/yourusername/neuro2/issues)
- **Quarto Help**: Visit [Quarto Documentation](https://quarto.org/docs/guide/)
- **R Help**: Use `?function_name` or `help(package_name)`

For additional support, contact: joey.trampush\@brainworkup.org
