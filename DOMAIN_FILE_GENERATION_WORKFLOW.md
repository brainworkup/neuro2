# Domain File Generation Workflow Documentation

## Overview

The neuro2 package uses a dynamic domain file generation system that creates personalized neuropsychological reports for each patient. This document explains how domain files (like `_02-03_verbal.qmd`) are generated dynamically based on patient-specific data.

## Key Components

### 1. NeuropsychReportSystemR6 Class
The main orchestrator that manages the entire report generation workflow.

```r
# Located in R/NeuropsychReportSystemR6.R
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = "Patient Name",
    domains = c("General Cognitive Ability", "Academics", "Verbal/Language", "Spatial", "Memory", ...),
    data_files = list(neurocog = "data/neurocog.parquet", ...)
  )
)
```

### 2. DomainProcessorR6 Class
Handles data processing for individual domains.

```r
# Located in R/DomainProcessorR6.R
processor <- DomainProcessorR6$new(
  domains = "Verbal/Language",
  pheno = "verbal",
  input_file = "data/neurocog.csv"
)
```

### 3. Domain File Generation Process

## Workflow Steps

### Step 1: Patient Data Loading
The system loads patient-specific data from CSV files:
- `neurocog.csv` - Cognitive test results
- `neurobehav.csv` - Behavioral assessments
- `neuropsych.csv` - Neuropsychological data
- `validity.csv` - Validity measures

### Step 2: Domain Detection
The system determines which domains to include based on available data:

```r
# In NeuropsychReportSystemR6::generate_domain_files()
# Domains are configured in the initialization
domains <- c(
  "IQ",
  "Academics", 
  "Verbal/Language",
  "Spatial",
  "Memory",
  "Executive",
  "Motor",
  "Social Cognition",
  "ADHD",
  "Emotional/Behavioral"
)
```

### Step 3: Sequential Domain File Generation
Domain files are generated with sequential numbering:

```r
# Domain numbering mapping
domain_numbers <- c(
  iq = "01",
  academics = "02",
  verbal = "03",
  spatial = "04",
  memory = "05",
  executive = "06",
  motor = "07",
  social = "08",
  adhd = "09",
  emotion = "10"
)
```

### Step 4: File Generation
For each domain, the system generates:
1. Main domain file: `_02-XX_domain.qmd`
2. Text content file: `_02-XX_domain_text.qmd`

```r
# Example: Verbal domain generates:
# _02-03_verbal.qmd (main file)
# _02-03_verbal_text.qmd (text summary)
```

## Dynamic Generation Process

### 1. Data Filtering
Each domain processor filters the patient data to include only relevant tests:

```r
processor$load_data()
processor$filter_by_domain()  # Filters to specific domain
processor$select_columns()    # Selects relevant columns
```

### 2. R6 Class Integration
The updated workflow uses R6 classes for:
- **TableGT**: Generates formatted tables with automatic footnotes
- **DotplotR6**: Creates domain performance visualizations
- **NeuropsychResultsR6**: Generates text summaries

### 3. Template Structure
Each domain file follows this structure:

```qmd
## Domain Name {#sec-domain}

{{< include _02-XX_domain_text.qmd >}}

```{r setup-domain}
# R6 processor initialization
```

```{r qtbl-domain}
# TableGT R6 class for table generation
table_gt <- TableGT$new(data = data_domain, ...)
table_gt$build_table()
```

```{r fig-domain}
# DotplotR6 class for visualization
dotplot <- DotplotR6$new(data = data_domain, ...)
dotplot$create_plot()
```
```

## Patient-Specific Customization

### 1. Domain Selection
Only domains with available data are included:
- If a patient has no motor tests, no motor domain file is generated
- Domain numbers remain sequential (no gaps)

### 2. Test Filtering
Different report types can be generated:
- Self-report measures
- Observer reports
- Performance-based tests

### 3. Adaptive Content
Text summaries adapt based on:
- Test results and percentiles
- Available data
- Clinical significance thresholds

## Usage Example

```r
# Generate report for a specific patient
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = "John Doe",
    domains = c("IQ", "Memory", "Executive")  # Only these domains
  )
)

# Run the workflow
report_system$run_workflow()

# This generates:
# _02-01_iq.qmd
# _02-02_memory.qmd  
# _02-03_executive.qmd
# (Note: sequential numbering regardless of domain type)
```

## File Regeneration

To regenerate domain files:

```r
# Method 1: Using NeuropsychReportSystemR6
report_system$generate_domain_files(domains = c("Verbal/Language"))

# Method 2: Using DomainProcessorR6 directly
processor <- DomainProcessorR6$new(
  domains = "Verbal/Language",
  pheno = "verbal",
  input_file = "data/neurocog.csv"
)
processor$generate_domain_qmd()
processor$generate_domain_text_qmd()
```

## Integration with DuckDB/Parquet

The workflow supports modern data formats:
- Load data from DuckDB databases
- Process parquet files with Arrow
- Use optimized R6 classes for performance

```r
# Example with DuckDB integration
processor <- DomainProcessorR6$new(
  domains = domains,
  pheno = pheno,
  input_file = NULL  # No file needed
)
processor$data <- duckdb_query_result  # Inject data from DuckDB
processor$filter_by_domain()
```

## Benefits of Dynamic Generation

1. **Personalization**: Each patient gets only relevant domains
2. **Consistency**: Standardized format across all reports
3. **Maintainability**: Changes to templates apply to all reports
4. **Scalability**: Easy to add new domains or modify existing ones
5. **Performance**: R6 classes and modern tools improve speed

## Troubleshooting

If domain files are missing:
1. Check that data files exist in the specified paths
2. Verify domain names match the data
3. Ensure R6 class files are sourced correctly
4. Check file permissions in the output directory

## Future Enhancements

- Automatic domain detection from available data
- Parallel processing for multiple domains
- Template versioning system
- Custom domain configurations per patient type
