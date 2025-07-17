# neuro2: Neuropsychological Report Generation Package

A comprehensive R package for generating professional neuropsychological evaluation reports using Quarto and Typst. This package automates the process of converting raw neuropsychological test data into publication-ready clinical reports.

## Overview

The `neuro2` package provides an integrated workflow for:
- Importing and processing neuropsychological test data from CSV files
- Standardizing test scores across different assessment instruments
- Generating domain-specific analyses and interpretations
- Creating professional reports using customizable Quarto/Typst templates
- Producing publication-quality tables and visualizations

### Key Features

- **Automated Data Processing**: Imports CSV files from various neuropsychological tests and standardizes the data format
- **Domain-Based Analysis**: Organizes results by cognitive domains (e.g., IQ, Memory, Executive Function)
- **Clinical Interpretations**: Generates automated text summaries based on test performance
- **Professional Formatting**: Uses Typst for high-quality PDF output with customizable templates
- **R6 Object-Oriented Design**: Modular architecture for extensibility and maintainability

## Installation

### Prerequisites

1. **R** (version 4.1 or higher)
2. **Quarto** (version 1.4.0 or higher) - [Install Quarto](https://quarto.org/docs/get-started/)
3. **CMake** (version 3.10 or higher) - Required for some dependencies
4. **LaTeX** distribution (for PDF output) - TinyTeX recommended:
   ```r
   tinytex::install_tinytex()
   ```

### Install from GitHub

```r
# Install devtools if not already installed
install.packages("devtools")

# Install neuro2 package
devtools::install_github("brainworkup/neuro2")
```

### Install Required Dependencies

The package will automatically install most dependencies, but you can manually install them:

```r
# Core dependencies
install.packages(c(
  "tidyverse", "here", "glue", "yaml", "quarto",
  "gt", "gtExtras", "janitor", "R6", "readr", "readxl"
))

# Install NeurotypR if not available
if (!requireNamespace("NeurotypR", quietly = TRUE)) {
  devtools::install_github("brainworkup/NeurotypR")
}
```

## Quick Start

### Basic Usage

The simplest way to generate a report is using the efficient workflow:

```r
# Load the package
library(neuro2)

# Run the efficient workflow
source("efficient_workflow_v5.R")
```

This will:
1. Process data files from `data-raw/` directory
2. Update patient variables
3. Generate domain summaries
4. Render the final report

### Step-by-Step Workflow

For more control over the process:

```r
# Step 1: Import and process data
source("01_import_process_data.R")

# Step 2: Create domain-specific QMD files
source("02_create_domain_qmds.R")

# Step 3: Render domains and generate summaries
source("03_render_domains.R")

# Step 4: Update variables and render final report
source("04_updated_workflow_quarto.R")
```

## Directory Structure

```
neuro2/
├── data-raw/           # Input CSV files from neuropsych tests
├── data/               # Processed data files
├── R/                  # R6 classes and utility functions
├── inst/               # Package resources
│   ├── extdata/        # Data files and templates
│   └── rmarkdown/      # Report templates
├── _*.qmd             # Quarto template sections
├── template.qmd        # Main report template
├── _quarto.yml        # Quarto configuration
└── _variables.yml     # Patient variables configuration
```

## Data Requirements

### Input Data Format

Place CSV files in the `data-raw/` directory. Each CSV should contain:

- `test`: Test abbreviation (e.g., "WAIS-5")
- `test_name`: Full test name
- `scale`: Subtest or scale name
- `raw_score`: Raw score value
- `score`: Standard/scaled score
- `percentile`: Percentile rank
- `range`: Performance classification
- `domain`: Cognitive domain

### Example CSV Structure

```csv
test,test_name,scale,raw_score,score,percentile,range,domain
WAIS5,Wechsler Adult Intelligence Scale-5,Full Scale IQ,NA,95,37,Average,General Cognitive Ability
WAIS5,Wechsler Adult Intelligence Scale-5,Verbal Comprehension,NA,98,45,Average,Verbal/Language
```

## Configuration

### Patient Information

Edit `_variables.yml` to set patient demographics:

```yaml
patient: "John Doe"
first_name: "John"
last_name: "Doe"
age: 45
sex: "male"
dob: "1979-01-15"
education: 16
handedness: "right"
referral: "Dr. Smith"
```

### Report Format

Configure output format in `_quarto.yml`:

```yaml
format:
  neurotyp-adult-typst:
    papersize: "us-letter"
    fontsize: 11pt
    fig-format: svg
```

## Customization

### Adding New Tests

1. Create CSV file with test data in `data-raw/`
2. Ensure proper column naming convention
3. Run workflow to include in report

### Modifying Report Sections

Edit the corresponding QMD files:
- `_01-00_nse_adult.qmd` - Neurobehavioral status exam
- `_02-*_*_text.qmd` - Domain-specific interpretations
- `_03-01_recs.qmd` - Clinical recommendations

### Creating Custom Templates

1. Copy existing template structure
2. Modify Typst formatting in template files
3. Update `_quarto.yml` to use new template

## Workflow Examples

### Example 1: Standard Adult Assessment

```r
# Set patient information
update_patient_variables(
  patient = "Jane Smith",
  age = 35,
  sex = "female"
)

# Run complete workflow
source("efficient_workflow_v5.R")
```

### Example 2: Forensic Evaluation

```r
# Use forensic-specific workflow
source("06_run_complete_workflow.R")
```

### Example 3: Custom Domain Analysis

```r
# Load and process specific domains
neurocog <- read_csv("data/neurocog.csv")
memory_data <- neurocog %>% 
  filter(domain == "Memory")

# Generate custom analysis
source("R/DomainProcessorR6.R")
processor <- DomainProcessorR6$new(memory_data)
processor$generate_summary()
```

## Troubleshooting

### Common Issues

1. **Missing data files**
   - Ensure CSV files are in `data-raw/` directory
   - Check file naming conventions

2. **Quarto rendering errors**
   - Verify Quarto installation: `quarto check`
   - Check LaTeX installation for PDF output

3. **Package dependencies**
   - Run `devtools::install_deps()` to install missing packages
   - Update R to version 4.1 or higher if needed

4. **Template not found**
   - Ensure all `_*.qmd` files are in project root
   - Check `_include_domains.qmd` references

### Debug Mode

Enable verbose output for troubleshooting:

```r
# Set debug options
options(neuro2.debug = TRUE)
options(neuro2.verbose = TRUE)

# Run workflow with debugging
source("efficient_workflow_v5.R")
```

## Advanced Usage

### Using R6 Classes Directly

```r
# Create report system instance
library(neuro2)
report_system <- NeuropsychReportSystemR6$new()

# Process specific test
report_system$process_test_data("data-raw/wais5.csv")

# Generate domain report
iq_generator <- IQReportGeneratorR6$new()
iq_generator$generate_report(report_system$data)
```

### Batch Processing

```r
# Process multiple patients
patients <- list(
  list(name = "Patient1", age = 30, sex = "male"),
  list(name = "Patient2", age = 45, sex = "female")
)

for (patient in patients) {
  update_patient_variables(
    patient = patient$name,
    age = patient$age,
    sex = patient$sex
  )
  source("efficient_workflow_v5.R")
  
  # Move output to patient folder
  dir.create(patient$name)
  file.copy("template.pdf", 
            file.path(patient$name, "report.pdf"))
}
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/NewFeature`)
3. Commit changes (`git commit -m 'Add NewFeature'`)
4. Push to branch (`git push origin feature/NewFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this package in your work, please cite:

```
Trampush, J. (2024). neuro2: Neuropsychological Report Generation Package. 
R package version 0.2.2. https://github.com/yourusername/neuro2
```

## Contact

- **Author**: Joey Trampush
- **Email**: joey.trampush@brainworkup.org
- **Issues**: [GitHub Issues](https://github.com/yourusername/neuro2/issues)

## Acknowledgments

- Built on the Quarto publishing system
- Uses Typst for high-quality typesetting
- Incorporates gt for table generation
- Integrates with NeurotypR for specialized neuropsych functions
