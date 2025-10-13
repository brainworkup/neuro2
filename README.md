
<!-- README.md is generated from README.Rmd. Please edit that file -->

# `neuro2`: Modern Neuropsychological Report Generation System

<!-- badges: start -->

<!-- [![R-CMD-check](https://github.com/brainworkup/neuro2/workflows/R-CMD-check/badge.svg)](https://github.com/brainworkup/neuro2/actions) -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

<!-- badges: end -->

# `neuro2`: Modern Neuropsychological Report Generation System

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

## Overview

The `neuro2` package is a comprehensive R package for generating
professional neuropsychological evaluation reports using modern R6
object-oriented design, high-performance data processing with
DuckDB/Parquet, AI-powered narrative generation with Ollama, and
beautiful typesetting with Quarto/Typst.

### 🎯 Key Features

- **🚀 High-Performance Data Pipeline**: Uses DuckDB and Parquet for
  4-5x faster data processing
- **🏗️ Modern R6 Architecture**: Object-oriented design for
  extensibility and maintainability  
- **🤖 AI-Powered Narrative Generation**: Uses local Ollama LLMs to
  generate clinical summaries
- **🧠 Dynamic Domain Generation**: Automatically generates report
  sections based on available patient data
- **📊 Beautiful Visualizations**: Creates publication-quality tables
  and plots with `gt` and custom R6 classes
- **📄 Professional Reports**: Generates PDF reports using Quarto and
  Typst for superior typography
- **🔧 Flexible Configuration**: Easily customizable for different
  assessment types and clinical settings
- **✍️ Edit Protection**: Preserves manual edits across re-renders

## Quick Start: First Time Setup

### Prerequisites

1.  **R** (version 4.5 or higher)
2.  **Quarto** (version 1.4.0 or higher) - [Install
    Quarto](https://quarto.org/docs/get-started/)
3.  **Ollama** - [Install Ollama](https://ollama.com/download)
4.  **CMake** (version 3.10 or higher) - Required for some dependencies

### One-Time Installation

``` bash
# 1. Install the neuro2 package
Rscript -e "pak::pak('brainworkup/neuro2')"

# 2. Install required packages
bash setup_packages.sh

# 3. Start Ollama models (run in background)
bash setup_ollama.sh
```

## Running the Workflow

### The Complete Process (Two-Stage Workflow)

The workflow requires **TWO rendering passes** due to LLM processing:

#### Stage 1: Generate and Process Data

``` r
source("joey_startup_clean.R")

# First run - generates domain files and processes with LLM
run_workflow()  # Uses patient name "Ethan" by default
```

**What happens in Stage 1:** 1. ✅ Loads and processes raw CSV data →
Parquet 2. ✅ Generates domain QMD files (`_02-XX_domain.qmd`) 3. ✅
Creates domain text files with formatted data (`_02-XX_domain_text.qmd`)
4. ✅ **LLM processes data** to generate clinical summaries 5. ⚠️ First
PDF render (summaries may be incomplete)

#### Stage 2: Final Render with Complete Summaries

``` r
# Second run - integrates LLM summaries and renders final report
run_workflow()
```

**What happens in Stage 2:** 1. ✅ Uses cached data (no reprocessing) 2.
✅ Integrates completed LLM-generated summaries 3. ✅ Generates final
publication-quality PDF 4. ✅ **Protects any manual edits** you’ve made

### Important: Manual Edit Protection

After the first full workflow completion, if you manually edit any
files: - `_02-XX_domain_text.qmd` files (narrative summaries) -
`_03-00_sirf.qmd` (interpretation)  
- `_04-00_recs.qmd` (recommendations)

**These files will NOT be overwritten** on subsequent renders. The
workflow detects manual edits via timestamps and preserves your clinical
expertise.

### Advanced Usage

``` r
# Run with different patient
run_workflow("Patient Name")

# Control what gets processed
run_neuropsych_workflow(
  patient = "Ethan",
  generate_qmd = TRUE,       # Generate domain files
  render_report = TRUE,      # Render PDF
  force_reprocess = FALSE,   # Respect manual edits (default)
  force_llm = FALSE          # Skip LLM if summaries exist
)

# Skip LLM processing (use existing summaries)
run_neuropsych_workflow(
  patient = "Ethan", 
  force_llm = FALSE
)

# Force regeneration of everything (CAUTION: overwrites manual edits)
run_neuropsych_workflow(
  patient = "Ethan",
  force_reprocess = TRUE,
  force_llm = TRUE
)
```

## Workflow Architecture

### Data Flow

    Raw CSVs → Parquet → Domain Processors → Text Files (cached)
                                                  ↓
                                          LLM Processing (ollama)
                                                  ↓
                                        Clinical Summaries
                                                  ↓
                                QMD Files → Quarto → PDF Report

### File Structure Generated

    project/
    ├── data/
    │   ├── neurocog.parquet        # Processed cognitive data
    │   ├── neurobehav.parquet      # Processed behavioral data
    │   └── validity.parquet        # Validity indicators
    ├── _02-01_iq.qmd              # Domain QMD (has R chunks)
    ├── _02-01_iq_text.qmd         # LLM-generated summary ⚠️ Protected
    ├── _02-02_academics.qmd
    ├── _02-02_academics_text.qmd  # ⚠️ Protected
    ├── _03-00_sirf.qmd            # Interpretation ⚠️ Protected  
    ├── _04-00_recs.qmd            # Recommendations ⚠️ Protected
    ├── figs/                       # Generated tables and plots
    └── output/
        └── Ethan_report.pdf       # Final report

## Why Two Renders?

The two-stage process is necessary because:

1.  **First Render**:
    - Executes R chunks that format test data
    - Caches formatted data in `*_text.qmd` files
    - Triggers LLM to read cached data and generate summaries
    - LLM output may not complete before Quarto finishes rendering
2.  **Second Render**:
    - Uses cached R chunk outputs (fast)
    - Now includes completed LLM-generated summaries
    - Produces final publication-quality document

## Edit Protection System

The workflow uses **timestamp-based edit detection**:

``` r
# File is protected from regeneration if:
# 1. It exists AND
# 2. Has been modified after initial generation

# Check if file was manually edited
is_manually_edited <- function(file_path) {
  if (!file.exists(file_path)) return(FALSE)
  
  # Compare modification time to generation marker
  modification_time <- file.mtime(file_path)
  generation_time <- get_generation_timestamp(file_path)
  
  return(modification_time > generation_time)
}
```

### Override Edit Protection (when needed)

``` r
# Force regeneration of specific domain
processor <- DomainProcessorR6$new(
  domains = "Memory",
  pheno = "memory",
  force_regenerate = TRUE  # Ignores edit protection
)
processor$process()

# Or via workflow
run_neuropsych_workflow(
  force_reprocess = TRUE,  # Regenerates ALL files
  force_llm = TRUE         # Forces LLM to reprocess
)
```

## Helper Scripts Integration

### setup_ollama.sh

**Purpose**: Starts Ollama models in background  
**When to run**: Once per session, before first workflow run
**Integration**: Can be called automatically by workflow if models
aren’t running

``` bash
#!/bin/bash
# Starts LLM models for narrative generation
ollama run qwen3:8b-q4_K_M &           # Fast, general use
ollama run qwen3:30b-a3b-instruct-2507-q4_K_M &  # High quality
ollama run qwen3:14b-q4_K_M            # Balanced
```

### setup_packages.sh

**Purpose**: One-time package installation  
**When to run**: After initial package install or updates
**Integration**: Should be run manually, not part of workflow

``` bash
#!/bin/bash
# Install core dependencies
Rscript -e "install.packages(c('yaml', 'dplyr', 'readr', 'arrow', 'here'))"
Rscript -e "devtools::install_local('.', dependencies=TRUE)"
```

**Recommendation**: Keep these as standalone scripts. They serve
different purposes: - `setup_ollama.sh` - Session-level (could
auto-check in workflow) - `setup_packages.sh` - Installation-level
(manual only)

## Typical Workflow Session

``` r
# === Session Start ===

# 1. Start Ollama models (terminal 1)
$ bash setup_ollama.sh

# 2. Start R session (terminal 2)
$ R

# 3. Load workflow
source("joey_startup_clean.R")

# 4. First full run (with LLM processing)
run_workflow()  # Takes 5-10 minutes

# 5. Second run (fast, complete summaries)
run_workflow()  # Takes 2-3 minutes

# 6. Review output
$ open output/Ethan_report.pdf

# === Make Manual Edits ===

# 7. Edit narrative summaries (protected from overwrite)
# Edit _02-01_iq_text.qmd
# Edit _03-00_sirf.qmd  
# Edit _04-00_recs.qmd

# 8. Re-render (preserves edits)
run_workflow()  # Fast - uses cached data and preserved edits

# === Update Patient Data ===

# 9. Add new test scores to CSV files
# 10. Force reprocess (WARNING: overwrites unprotected edits)
run_neuropsych_workflow(
  force_reprocess = TRUE,
  force_llm = TRUE
)

# 11. Run twice again for complete integration
run_workflow()  # First pass
run_workflow()  # Final pass
```

## 📁 Project Structure

    neuro2/
    ├── data-raw/
    │   └── csv/                  # Raw test data (your input)
    ├── data/                     # Processed data (auto-generated)
    ├── R/                        # R6 classes (core system)
    │   ├── DomainProcessorR6.R
    │   ├── NeuropsychReportSystemR6.R
    │   ├── neuro2_llm.R         # LLM interface
    │   └── ...
    ├── inst/
    │   ├── scripts/
    │   │   └── 00_complete_neuropsych_workflow.R
    │   └── quarto/
    │       └── templates/
    ├── joey_startup_clean.R      # Quick start wrapper
    ├── setup_ollama.sh           # Start LLM models
    ├── setup_packages.sh         # Install dependencies
    ├── _*.qmd                    # Domain templates (auto-generated)
    └── template.qmd              # Main report template

## 🐛 Troubleshooting

### “No LLM summaries generated”

``` bash
# Check Ollama is running
$ ollama list
# Should show qwen3 models

# Restart Ollama
$ bash setup_ollama.sh
```

### “Manual edits were overwritten”

``` r
# Check file protection status
file.mtime("_02-01_iq_text.qmd")

# To prevent overwriting, ensure you're NOT using:
run_neuropsych_workflow(force_reprocess = TRUE)  # Danger!
```

### “Second render didn’t include summaries”

``` r
# Verify LLM completed processing
list.files(pattern = "*_text.qmd")

# Check for LLM output markers
readLines("_02-01_iq_text.qmd") |> tail(10)

# If needed, force LLM reprocessing
run_neuropsych_workflow(force_llm = TRUE)
```

### “Workflow seems slow”

``` r
# Check what's being reprocessed
run_neuropsych_workflow(
  force_reprocess = FALSE,  # Use cached data
  force_llm = FALSE         # Use existing summaries
)

# Only render changes
quarto::quarto_render("template.qmd")
```

## 🎨 Customization

### Configure Patient Information

Edit `_variables.yml`:

``` yaml
patient: "Patient Name"
age: 25
sex: "male"  
education: 16
handedness: "right"
```

### Customize LLM Models

Edit `R/neuro2_llm.R`:

``` r
# Change model
model <- "qwen3:30b-a3b-instruct-2507-q4_K_M"  # High quality
# model <- "qwen3:8b-q4_K_M"  # Faster

# Adjust temperature (0-1, higher = more creative)
temperature <- 0.3  # Conservative for clinical text
```

### Add Custom Domains

1.  Add test data to `data-raw/csv/`
2.  Ensure proper domain assignment
3.  Run workflow - domains auto-detect

## 📚 Additional Documentation

- [Domain Generation Fixes](DOMAIN_GENERATION_FIXES.md)
- [Workflow Architecture](unified_workflow_architecture.md)
- [Score Types Reference](docs/NEUROPSYCH_SCORE_TYPES.md)

## 🤝 Contributing

Contributions welcome! Please: 1. Fork the repository 2. Create a
feature branch 3. Test with real patient data 4. Submit a pull request

## 📧 Contact

- **Author**: Joey Trampush, PhD
- **Email**: <joey.trampush@brainworkup.org>
- **Issues**: [GitHub
  Issues](https://github.com/brainworkup/neuro2/issues)

## 🙏 Acknowledgments

- Built on [Quarto](https://quarto.org) and [Typst](https://typst.app)
- Powered by [DuckDB](https://duckdb.org) and
  [Ollama](https://ollama.com)
- Tables with [gt](https://gt.rstudio.com)
- R6 architecture and modern OOP best practices

<!-- ## Overview
&#10;The `neuro2` package is a comprehensive R package for generating professional neuropsychological evaluation reports using modern R6 object-oriented design, high-performance data processing with DuckDB/Parquet, and beautiful typesetting with Quarto/Typst.
&#10;- [Claude explanation](https://claude.ai/share/8fc99931-39b7-4de0-ba80-0c94573ae913)
&#10;### 🎯 Key Features
&#10;-   **🚀 High-Performance Data Pipeline**: Uses DuckDB and Parquet for 4-5x faster data processing
-   **🏗️ Modern R6 Architecture**: Object-oriented design for extensibility and maintainability
-   **🧠 Dynamic Domain Generation**: Automatically generates report sections based on available patient data
-   **📊 Beautiful Visualizations**: Creates publication-quality tables and plots with `gt` and custom R6 classes
-   **📄 Professional Reports**: Generates PDF reports using Quarto and Typst for superior typography
-   **🔧 Flexible Configuration**: Easily customizable for different assessment types and clinical settings
&#10;## Installation
&#10;### Prerequisites
&#10;1.  **R** (version 4.5 or higher)
2.  **Quarto** (version 1.4.0 or higher) - [Install Quarto](https://quarto.org/docs/get-started/)
3.  **CMake** (version 3.10 or higher) - Required for some dependencies
4.  **webshot2** - For converting tables to images
&#10;### Install from GitHub
&#10;``` r
# Install pak if not already installed
install.packages("pak")
&#10;# Install neuro2 package
pak::pak("brainworkup/neuro2")
```
&#10;### Install Core Dependencies
&#10;``` r
# Core dependencies
install.packages(c(
  "dplyr", "tidyr", "ggplot2", "stringr", "here", "glue", "yaml", "quarto", "gt", "gtExtras", "janitor", "R6", "readr", "readxl",
  "DBI", "duckdb", "arrow", "webshot2"
))
```
&#10;## 🏃 Quick Start
&#10;### Option 1: Unified Workflow Scripts (Recommended)
&#10;``` bash
# Interactive shell workflow (with guided prompts)
./unified_neuropsych_workflow.sh "Patient Name"
&#10;# Or programmatic R workflow
Rscript unified_workflow_runner.R config.yml
```
&#10;The unified workflow scripts provide a streamlined, efficient process that combines the best features of all workflow components.
See [Unified Workflow README](UNIFIED_WORKFLOW_README.md) for detailed documentation.
&#10;### Option 2: Direct R6 Usage
&#10;``` r
# Load the package
library(neuro2)
&#10;# 1. Process raw data files (CSV → Parquet)
load_data_duckdb(
  file_path = "data-raw/csv",
  output_dir = "data",
  output_format = "all"  # Creates CSV, Parquet, and Feather formats
)
&#10;# 2. Generate a neuropsychological report
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = "Biggie Smalls",
    domains = c("General Cognitive Ability", "Memory", "Attention/Executive"),
    data_files = list(
      neurocog = "data/neurocog.parquet",
      neurobehav = "data/neurobehav.parquet"
    )
  )
)
&#10;# 3. Run the complete workflow
report_system$run_workflow()
```
&#10;## 📁 Project Structure
&#10;```         
neuro2/
├── data-raw/           # Input CSV files from neuropsych tests
│   ├── csv/           # Raw test data files
│   └── create_sysdata.R # Domain and scale definitions
├── data/              # Processed data (Parquet/Feather/CSV)
├── R/                 # R6 classes and functions
│   ├── DomainProcessorR6.R      # Domain data processing
│   ├── NeuropsychReportSystemR6.R # Report orchestration
│   ├── TableGTR6.R                # Table generation
│   ├── DotplotR6.R             # Visualization
│   └── duckdb_neuropsych_loader.R # Data loading
├── inst/              # Package resources
│   ├── extdata/       # Lookup tables and templates
│   └── quarto/        # Report templates
├── _*.qmd            # Domain template sections
├── template.qmd      # Main report template
├── _quarto.yml      # Quarto configuration
├── unified_workflow_runner.R    # Main R workflow entry point
├── unified_neuropsych_workflow.sh # Interactive shell workflow
├── UNIFIED_WORKFLOW_README.md   # Unified workflow documentation
└── _arxiv/           # Archived legacy scripts
```
&#10;## 🧪 Core R6 Classes
&#10;### NeuropsychReportSystemR6
&#10;Orchestrates the entire report generation workflow:
&#10;``` r
# Create report system with configuration
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = "Biggie",
    domains = c("Memory", "Verbal/Language", "Attention/Executive")
  )
)
&#10;# Generate domain files dynamically
report_system$generate_domain_files()
```
&#10;### DomainProcessorR6
&#10;Processes neuropsychological test data by cognitive domain:
&#10;``` r
# Process verbal domain data
processor <- DomainProcessorR6$new(
  domains = "Verbal/Language",
  pheno = "verbal",
  input_file = "data/neurocog.parquet"
)
&#10;processor$process()  # Runs complete pipeline
```
&#10;### TableGTR6
&#10;Creates publication-quality tables:
&#10;``` r
# Generate a formatted table
table <- TableGTR6$new(
  data = domain_data,
  pheno = "memory",
  table_name = "table_memory"
)
&#10;table$build_table()  # Creates PNG and PDF outputs
```
&#10;### DotplotR6
&#10;Creates domain visualization plots:
&#10;``` r
# Create domain visualization
plot <- DotplotR6$new(
  data = domain_data,
  pheno = "executive"
)
&#10;plot$build_plot()
```
&#10;## 📊 Data Processing Pipeline
&#10;### 1. Import Raw Data
&#10;Place CSV files in `data-raw/csv/` with required columns:
&#10;-   `test`: Test abbreviation
-   `test_name`: Full test name
-   `scale`: Subtest/scale name
-   `raw_score`: Raw score
-   `score`: Standardized score (z, t, scaled, standard)
-   `percentile`: Percentile rank
-   `domain`: Cognitive and/or behavioral domain
&#10;### 2. Process with DuckDB
&#10;``` r
# High-performance data processing
load_data_duckdb(
  file_path = "data-raw/csv",
  output_dir = "data",
  use_duckdb = TRUE,
  output_format = "parquet"  # 4-5x faster than CSV
)
```
&#10;### 3. Query with SQL
&#10;``` r
# Use SQL for complex queries
query_neuropsych(
  "SELECT * FROM neurocog WHERE domain = 'Memory' AND percentile < 16",
  "data"
)
```
&#10;## 🎨 Customization
&#10;### Configure Patient Information
&#10;Edit `_variables.yml`:
&#10;``` yaml
patient: "Biggie"
age: 25
sex: "male"
education: 16
handedness: "right"
```
&#10;### Customize Domains
&#10;The system automatically detects available domains from your data.
Domain mappings are defined in `data-raw/create_sysdata.R`.
For example:
&#10;-   General Cognitive Ability → `iq`
-   Academic Skills → `academics`
-   Verbal/Language → `verbal`
-   Memory → `memory`
-   Attention/Executive → `executive`
&#10;### Add Custom Tests
&#10;1.  Add test data to CSV in `data-raw/csv/`
2.  Ensure proper domain assignment
3.  Run the workflow - domains are generated dynamically
&#10;## 🔧 Advanced Usage
&#10;### Using Individual Components
&#10;``` r
# Load specific domain data
memory_data <- query_neuropsych(
  "SELECT * FROM neurocog WHERE domain = 'Memory'",
  "data"
)
&#10;# Create custom table
table_gt <- TableGTR6$new(
  data = memory_data,
  pheno = "memory",
  table_name = "custom_memory_table"
)
&#10;table_gt$build_table()
```
&#10;### Batch Processing
&#10;``` r
# Process multiple patients
patients <- list(
  list(name = "Patient1", age = 30),
  list(name = "Patient2", age = 45)
)
&#10;for (patient in patients) {
  report_system <- NeuropsychReportSystemR6$new(
    config = list(patient = patient$name, age = patient$age)
  )
  report_system$run_workflow()
}
```
&#10;## 🐛 Troubleshooting
&#10;### Common Issues
&#10;1.  **Missing dependencies**
&#10;    ``` r
    # Check and install dependencies
    source("install_dependencies.R")
    ```
&#10;2.  **DuckDB errors**
&#10;    ``` r
    # Verify DuckDB installation
    DBI::dbConnect(duckdb::duckdb())
    ```
&#10;3.  **Webshot2 issues**
&#10;    ``` r
    # Reinstall chromote
    webshot2::install_chromote()
    ```
&#10;4.  **Domain not found**
&#10;    -   Check domain spelling in data matches `create_sysdata.R`
    -   Verify data file contains the domain
&#10;## 📚 Documentation
&#10;-   [Unified Workflow Guide](UNIFIED_WORKFLOW_README.md) — recommended workflow
-   [Unified Workflow Architecture](unified_workflow_architecture.md)
-   [Workflow Guide](WORKFLOW.md) and [Workflow Run Notes](WORKFLOW_RUN.md)
-   [Domain Generation Fixes](DOMAIN_GENERATION_FIXES.md)
-   [Integrated Workflow Fixes](INTEGRATED_WORKFLOW_FIXES.md)
-   [Neuropsych Score Types](docs/NEUROPSYCH_SCORE_TYPES.md)
&#10;## 🤝 Contributing
&#10;Contributions are welcome!
Please: 1.
Fork the repository 2.
Create a feature branch (`git checkout -b feature/NewFeature`) 3.
Commit changes (`git commit -m 'Add NewFeature'`) 4.
Push to branch (`git push origin feature/NewFeature`) 5.
Open a Pull Request
&#10;## 📝 License
&#10;This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
&#10;## 📖 Citation
&#10;If you use this package in your work, please cite:
&#10;```         
Trampush, J. (2024). neuro2: Modern Neuropsychological Report Generation System.
R package version 0.1.8 https://github.com/brainworkup/neuro2
```
&#10;## 📧 Contact
&#10;-   **Author**: Joey Trampush, PhD
-   **Email**: [joey.trampush\@brainworkup.org](mailto:joey.trampush@brainworkup.org){.email}
-   **Issues**: [GitHub Issues](https://github.com/brainworkup/neuro2/issues)
&#10;## 🙏 Acknowledgments
&#10;-   Built on the [Quarto](https://quarto.org) publishing system
-   Uses [Typst](https://typst.app) for beautiful typesetting
-   Powered by [DuckDB](https://duckdb.org) for fast data processing
-   Tables created with [gt](https://gt.rstudio.com)
-   R6 architecture inspired by modern OOP best practices -->
