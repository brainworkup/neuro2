<!-- Copilot / AI agent instructions for the neuro2 repository -->
# copilot-instructions.md

Purpose
-------
Short, actionable guidance for an AI contributor to get productive in this repository: architecture, conventions, core workflows, and concrete commands to build, test, and iterate.

Big picture
-----------
- This repository is an R package / reporting system (top-level `R/` with `neuro2-package.R`) that generates Quarto reports under the project root. The codebase centers on R6 classes that orchestrate data loading, processing, and report generation (see `R/Neuro2MainR6.R`, `R/NeuropsychReportSystemR6.R`, `R/ReportTemplateR6.R`).
- Data ingestion often uses DuckDB via `R/duckdb_neuropsych_loader.R` and `R/DuckDBProcessorR6.R`.
- Reporting is implemented as Quarto documents (many `*.qmd` files at repo root) and helper scripts in `inst/scripts/`.

Key files & directories (quick tour)
----------------------------------
- `R/` — main package and implementation. Look for R6 classes named `*R6.R` (e.g. `DomainProcessorR6.R`, `Neuro2MainR6.R`). These are central when modifying behavior.
- `inst/scripts/` — runnable scripts and workflow entrypoints (e.g. `main_workflow_runner.R`, `report_generator_module.R`). Good starting points for end-to-end flows.
- Root `*.qmd` and `_quarto.yml` — Quarto report templates and configuration. Changes here affect rendered reports.
- `DESCRIPTION`, `NAMESPACE`, `tests/` (if present) — standard R package files. Use devtools for iteration.

Developer workflows (concrete commands)
-------------------------------------
- Load package into an interactive R session (fast edit-then-test loop):
```fish
Rscript -e "devtools::load_all('.')"
```
- Generate documentation (roxygen -> man pages):
```fish
Rscript -e "devtools::document()"
```
- Run package checks (CRAN-like):
```fish
Rscript -e "devtools::check()"
```
- Run unit tests:
```fish
Rscript -e "devtools::test()"
```
- Render Quarto site / reports locally (from repo root):
```fish
quarto render
```

Project-specific conventions & patterns
-------------------------------------
- R6-first architecture: many components are R6 classes. Prefer reading the `initialize`, `process`, `run`, and `render` methods when tracing behavior.
- Naming: filenames often reflect class names (e.g. `ReportTemplateR6.R` contains `ReportTemplateR6`). Use that mapping to jump to implementations.
- Data flow: ingestion -> domain processing -> scoring -> report generation. Look at `DomainProcessorFactoryR6.R` and `NeuropsychResultsR6.R` to follow transformations.
- Side effects: report generation writes files (PDF/HTML) to disk; functions often accept configuration via YAML/`_variables.yml` and `quarto` parameters.

Integration points & external deps
---------------------------------
- DuckDB (via `duckdb` R package) for fast local queries (`duckdb_neuropsych_loader.R`).
- Quarto for rendering reports; ensure `quarto` CLI is installed for `quarto render`.
- devtools/testthat for package workflows.

Examples / patterns to copy
--------------------------
- To add a new report step, follow the pattern in `R/ReportUtilitiesR6.R` and add a Quarto `_qmd` file. Use `ReportTemplateR6` to standardize front-matter.
- To add a new data loader, mirror `duckdb_neuropsych_loader.R` and register it with `DomainProcessorFactoryR6.R`.

What AI agents should do first
-----------------------------
1. Open `R/Neuro2MainR6.R` and `inst/scripts/main_workflow_runner.R` to understand end-to-end execution.
2. Run `Rscript -e "devtools::load_all('.')"` and `Rscript -e "devtools::test()"` to see failing tests or runtime errors before edits.
3. When changing public behavior, update or add unit tests under the package testing framework.

Quick troubleshooting tips
------------------------
- If Quarto rendering fails, run `quarto check` and ensure the `quarto` CLI version matches project expectations.
- If a class is not found, search `R/` for `R6Class` declarations — many classes are declared with `R6::R6Class()`.

Files to reference while coding
------------------------------
- `R/Neuro2MainR6.R` — main orchestrator
- `R/NeuropsychReportSystemR6.R` — report system behavior
- `inst/scripts/main_workflow_runner.R` — runnable entrypoint for batch runs
- `_quarto.yml` and `_variables.yml` — report config

If you want changes to this doc
-----------------------------
Add specific instructions or command variants you've used locally (OS, R version, quarto CLI) and any extra entrypoints not listed above. Ask for clarification on any ambiguous workflows and I will iterate.

---
Requirements coverage: added repository-specific architecture, workflows, patterns, and concrete commands for build/test/render.
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
