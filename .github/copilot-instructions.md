# AI Agent Instructions for neuro2

This neuropsychological report generation system uses R6 OOP, DuckDB for data processing, and Quarto/Typst for report generation. The workflow processes CSV test data → Parquet → QMD sections → PDF reports.

## Architecture Overview

The system follows a modular R6 class hierarchy:
- **WorkflowRunnerR6** orchestrates the entire pipeline from `unified_workflow_runner.R`
- **DomainProcessorR6** handles domain-specific data processing and QMD generation
- **NeuropsychResultsR6** generates narrative text from test results
- **TableGTR6** creates publication-quality tables with dynamic footnotes
- **DotplotR6** generates domain visualization plots

Data flows: CSV → DuckDB/Parquet → Domain processors → QMD files → Quarto → PDF

## Critical Workflows

### Running the Complete Pipeline
```bash
./unified_neuropsych_workflow.sh "Patient Name"  # Interactive
Rscript unified_workflow_runner.R config.yml     # Programmatic
```

### Domain File Generation Pattern
1. **Text files** (`_02-XX_domain_text.qmd`) are created by `generate_domain_text_qmd()`
2. **QMD files** (`_02-XX_domain.qmd`) include text files and generate tables/plots
3. Multi-rater domains (emotion/ADHD) create separate files per rater (self/parent/teacher)

## Project-Specific Conventions

### Domain Naming & Numbers
Domains map to phenotypes with standardized numbers (see `get_domain_number()`):
- `01_iq`, `02_academics`, `03_verbal`, `04_spatial`, `05_memory`
- `06_executive`, `07_motor`, `08_social`, `09_adhd`, `10_emotion`

### Multi-Rater Handling
Emotion/ADHD domains detect child vs adult and generate rater-specific sections:
- Child emotion: self/parent/teacher → `_emotion_child_text_{rater}.qmd`
- Adult emotion: single file → `_emotion_adult_text.qmd`

### Score Type Management
Tables use dynamic footnotes based on test score types (t_score/scaled_score/standard_score).
The `score_type_utils.R` provides lookup functions for test-specific scoring.

### Data Format Preferences
- Input: CSV files in `data-raw/csv/`
- Processing: Parquet via DuckDB (4-5x faster)
- Output: Combined parquet files by domain

## Key Integration Points

### DuckDB Pipeline
```r
load_data_duckdb(file_path = "data-raw/csv", output_format = "all")
query_neuropsych("SELECT * FROM neurocog WHERE domain = ?", params)
```

### QMD Generation
The `generate_standard_qmd()` method creates complete Quarto documents with:
- R setup chunks sourcing all R6 classes
- Data filtering by domain/scale
- Table/plot generation
- Typst layout blocks

### Safe Sysdata Updates
Use `safe_use_data_internal()` from `safe_sysdata_update_fixed.R` to update internal data without overwriting existing objects.

## Common Pitfalls to Avoid

1. **Text file generation**: Always call `generate_domain_text_qmd()` before generating QMD files
2. **Rater detection**: Check `check_rater_data_exists()` before creating rater-specific files
3. **Domain headers**: Child emotion uses "Behavioral/Emotional/Social", adult uses "Emotional/Behavioral/Personality"
4. **File paths**: Input files may have "data/" prefix - handle both cases
5. **Scale loading**: Load from `R/sysdata.rda` with proper error handling

When modifying domain processors, ensure compatibility with both standard single-file domains and multi-rater domains. The system dynamically detects available domains from data.