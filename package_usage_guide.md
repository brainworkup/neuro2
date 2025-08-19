# neuro2 R Package Installation & Usage

## Installation

### Option 1: Install from GitHub (Recommended)

```r
# Install devtools if you don't have it
if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools")
}

# Install neuro2 package
devtools::install_github("brainworkup/neuro2")
```

### Option 2: Install from Local Source

```r
# If you have the source code locally
devtools::install("path/to/neuro2")
```

## Quick Start

### 1. Create Patient Workspace

```r
library(neuro2)

# Create workspace for a new patient
workspace <- create_patient_workspace(
  patient_name = "Isabella",
  age = 12,
  assessment_date = "2024-01-15"
)

# This creates: Isabella_neuro/ directory with data/, figs/, output/, scripts/
```

### 2. Add Your Data

```r
# Copy your data files to the workspace
file.copy("path/to/your/neurocog.csv", "Isabella_neuro/data/")
file.copy("path/to/your/neurobehav.csv", "Isabella_neuro/data/")

# Or specify data files during workspace creation
workspace <- create_patient_workspace(
  patient_name = "Isabella",
  age = 12,
  data_files = list(
    neurocog = "path/to/your/cognitive_data.csv",
    neurobehav = "path/to/your/behavioral_data.csv"
  )
)
```

### 3. Process Assessment Data

```r
# Set working directory to patient workspace
setwd("Isabella_neuro")

# Process all available domains
results <- process_all_domains(
  data_dir = "data",
  age_group = "child",  # or "adult", "auto"
  verbose = TRUE
)

# Or process specific domains only
results <- process_all_domains(
  data_dir = "data",
  domains = c("iq", "memory", "executive", "adhd"),
  age_group = "child"
)
```

### 4. Generate Report

```r
# Generate complete assessment report
report_path <- generate_assessment_report(
  results = results,
  patient_info = list(
    name = "Isabella",
    age = 12,
    assessment_date = "2024-01-15"
  ),
  format = "typst"  # or "pdf", "html"
)

# Report saved to: output/assessment_report.pdf
```

## Advanced Usage

### Custom Configuration

```r
# Create workspace with custom config
custom_config <- list(
  processing = list(
    parallel = TRUE,
    verbose = FALSE
  ),
  output = list(
    format = "html",
    theme = "custom"
  )
)

workspace <- create_patient_workspace(
  "Isabella",
  age = 12,
  config = custom_config
)
```

### Domain-Specific Processing

```r
# Process single domain
processor <- create_domain_processor(
  domain_name = "Memory",
  data_file = "data/neurocog.csv",
  age_group = "child"
)

# Generate domain files
processor$process(generate_domain_files = TRUE)
```

### Multi-Rater Domains

```r
# Process multi-rater domains (ADHD, Emotion)
emotion_processors <- process_multi_rater_domain(
  domain_name = "Behavioral/Emotional/Social",
  data_file = "data/neurobehav.csv",
  age_group = "child"
)

# This creates separate processors for: self, parent, teacher
```

### Batch Processing

```r
# Process multiple patients
patients <- c("Isabella", "Marcus", "Sofia")

for (patient in patients) {
  workspace <- create_patient_workspace(patient, age = 12)
  # ... add data and process
}
```

## Data Format Requirements

Your CSV files should include these columns:

### Required Columns
- `test_name` - Name of test battery (e.g., "WISC-V", "BASC-3")
- `scale` - Subtest or scale name (e.g., "Block Design", "Hyperactivity")
- `score` - Numerical score (standard score, scaled score, T-score)
- `percentile` - Percentile rank (0-100)
- `domain` - Primary domain (e.g., "Memory", "ADHD")

### Optional Columns
- `range` - Descriptive classification (e.g., "Average", "Below Average")
- `ci_95` - 95% confidence interval
- `subdomain` - Secondary classification
- `raw_score` - Raw test score
- `rater` - Who provided ratings ("self", "parent", "teacher")

### Example Data

```csv
test_name,scale,score,percentile,range,domain,subdomain
WISC-V,Block Design,12,75,Above Average,Visual Perception/Construction,Spatial
WISC-V,Similarities,8,25,Below Average,Verbal/Language,Verbal Reasoning
BASC-3,Hyperactivity,65,92,Clinically Significant,ADHD,Hyperactivity/Impulsivity
```

## Package Configuration

Set global options for consistent behavior:

```r
# Set package options
options(
  neuro2.verbose = TRUE,        # Show detailed messages
  neuro2.parallel = FALSE,      # Use parallel processing
  neuro2.output_dir = "output"  # Default output directory
)
```

## Troubleshooting

### Common Issues

1. **Missing dependencies**:
   ```r
   # Install all suggested packages
   install.packages(c("gtExtras", "arrow", "quarto"))
   ```

2. **Data format errors**:
   ```r
   # Validate your data format
   validate_processor_inputs("Memory", "data/neurocog.csv", "child")
   ```

3. **Quarto rendering issues**:
   ```r
   # Install Quarto CLI: https://quarto.org/docs/get-started/
   # Or render manually: quarto render assessment_report.qmd
   ```

### Getting Help

```r
# Package help
?neuro2

# Function documentation
?create_patient_workspace
?process_all_domains

# View available domains
factory <- DomainProcessorFactoryR6$new()
factory$get_registry_info()
```

## Updating the Package

```r
# Update to latest version
devtools::install_github("brainworkup/neuro2", force = TRUE)

# Check for updates in existing workspaces
library(neuro2)
# Your workspace will automatically use the updated package functions
```

## Privacy & Security

- **Patient data stays in your local workspace** - never uploaded to GitHub
- **Each patient gets a separate workspace** - no data mixing
- **Workspaces include .gitignore** - prevents accidental data commits
- **Use private repositories** if you need version control for workspaces

## Integration with Existing Workflows

### RStudio Projects
```r
# Create RStudio project for patient
rstudioapi::initializeProject("Isabella_neuro")
```

### Version Control
```r
# Initialize git for workspace (optional)
setwd("Isabella_neuro")
system("git init")
system("git add .")
system("git commit -m 'Initial assessment setup'")
```

### Batch Analysis Scripts
```r
# Create analysis pipeline
create_batch_analysis_script <- function(patients) {
  for (patient in patients) {
    workspace <- create_patient_workspace(patient$name, patient$age)
    # ... processing logic
  }
}
```