# Neuro2 R Package: Comprehensive Codebase Analysis Report

## Executive Summary

The `neuro2` package is a sophisticated R package for generating professional neuropsychological evaluation reports. It employs modern R6 object-oriented design, high-performance data processing with DuckDB/Parquet, and beautiful typesetting with Quarto/Typst. The package version is 0.1.7 and requires R >= 4.5.

## Overall Package Architecture

### 1. **Architectural Design Pattern**

The package follows a **modular, object-oriented architecture** with clear separation of concerns:

```
┌─────────────────────────────────────┐
│   Unified Workflow Orchestration    │
│  (unified_workflow_runner.R)        │
└───────────────┬─────────────────────┘
                │
    ┌───────────┴───────────┐
    │                       │
    ▼                       ▼
┌─────────────┐      ┌──────────────┐
│ Data Layer  │      │ Domain Layer │
│  (DuckDB)   │      │    (R6)      │
└─────┬───────┘      └──────┬───────┘
      │                      │
      └──────────┬───────────┘
                 │
                 ▼
         ┌───────────────┐
         │ Presentation  │
         │ (Quarto/Typst)│
         └───────────────┘
```

### 2. **Core Components and Their Relationships**

#### **Orchestration Layer**
- [`NeuropsychReportSystemR6`](R/NeuropsychReportSystemR6.R:23-619): Main orchestrator class that coordinates the entire workflow
- [`unified_workflow_runner.R`](unified_workflow_runner.R): Entry point script that provides CLI interface and manages the complete pipeline

#### **Data Processing Layer**
- [`DuckDBProcessorR6`](R/DuckDBProcessorR6.R:30-519): Handles efficient data operations using DuckDB
- [`load_data_duckdb()`](R/duckdb_neuropsych_loader.R:15-277): Function for loading and processing neuropsychological data
- Supports CSV, Parquet, and Arrow/Feather formats for optimal performance

#### **Domain Processing Layer**
- [`DomainProcessorR6`](R/DomainProcessorR6.R:32-592): Processes data by cognitive domains (e.g., IQ, Memory, Executive)
- [`NeuropsychResultsR6`](R/NeuropsychResultsR6.R): Generates narrative text summaries from test results
- Dynamic domain detection and processing based on available data

#### **Visualization Layer**
- [`TableGT`](R/TableGT.R:36-189): Creates publication-quality tables using the gt package
- [`DotplotR6`](R/DotplotR6.R:36-234): Generates domain visualization plots
- [`DrilldownR6`](R/DrilldownR6.R): Creates interactive drill-down visualizations

#### **Report Generation Layer**
- Quarto templates in [`inst/quarto/templates/typst-report/`](inst/quarto/templates/typst-report/)
- Typst extensions for three report types:
  - [`neurotyp-adult`](inst/quarto/_extensions/brainworkup/neurotyp-adult/)
  - [`neurotyp-forensic`](inst/quarto/_extensions/brainworkup/neurotyp-forensic/)
  - [`neurotyp-pediatric`](inst/quarto/_extensions/brainworkup/neurotyp-pediatric/)

### 3. **Data Flow Architecture**

1. **Input**: Raw CSV files containing neuropsychological test data
   - Location: `data-raw/csv/`
   - Required columns: test, test_name, scale, raw_score, score, percentile, domain

2. **Processing Pipeline**:
   ```
   CSV → DuckDB → Domain Filtering → R6 Processing → Output Generation
   ```

3. **Output**:
   - Processed data files (CSV/Parquet/Arrow)
   - Domain-specific QMD files (_02-*.qmd)
   - Final PDF report via Quarto/Typst

### 4. **Key Design Decisions**

#### **Performance Optimization**
- DuckDB provides 4-5x faster data processing compared to traditional R methods
- Parquet format reduces file size by 50-80% while improving query speed by 10-15x
- Arrow integration enables efficient columnar data operations

#### **Modularity**
- R6 classes enable encapsulation and reusability
- Each domain can be processed independently
- Dynamic domain detection adapts to available data

#### **Extensibility**
- New domains can be added by updating [`data-raw/create_sysdata.R`](data-raw/create_sysdata.R)
- Custom report formats supported through Quarto extensions
- Pluggable visualization components

### 5. **Package Dependencies** (52 total)

#### Core Data Manipulation
- [`dplyr`](DESCRIPTION:17), [`tidyr`](DESCRIPTION:45), [`purrr`](DESCRIPTION:35), [`tibble`](DESCRIPTION:44), [`readr`](DESCRIPTION:38), [`readxl`](DESCRIPTION:39), [`janitor`](DESCRIPTION:30)

#### Database and Performance
- [`DBI`](DESCRIPTION:16), [`duckdb`](DESCRIPTION:18), [`arrow`](DESCRIPTION:14)

#### Visualization
- [`ggplot2`](DESCRIPTION:22), [`gt`](DESCRIPTION:26), [`gtExtras`](DESCRIPTION:27), [`highcharter`](DESCRIPTION:29)

#### Report Generation
- [`knitr`](DESCRIPTION:32), [`quarto`](DESCRIPTION:36) (>= 1.4.0)

#### Object-Oriented Foundation
- [`R6`](DESCRIPTION:37)

### 6. **Workflow Execution Steps**

1. **Environment Setup** ([`setup_environment()`](unified_workflow_runner.R:202-552))
2. **Data Processing** ([`process_data()`](unified_workflow_runner.R:555-593))
3. **Domain Generation** ([`generate_domains()`](unified_workflow_runner.R:596-1053))
4. **Report Generation** ([`generate_report()`](unified_workflow_runner.R:1056-1157))

### 7. **Configuration System**

YAML-based configuration ([`config.yml`](inst/quarto/templates/typst-report/config.yml)) controls:
- Patient information
- Data directories and formats
- Processing options
- Report specifications

### 8. **Domain Mapping**

The system maps neuropsychological domains to processing phenotypes:
- **Cognitive**: General Cognitive Ability → iq, Memory → memory
- **Behavioral**: ADHD, Emotional/Behavioral → adult/child variants
- **Adaptive**: Adaptive Functioning, Daily Living

### 9. **Package Strengths**

1. **Modern Architecture**: R6 OOP provides clean, maintainable code
2. **Performance**: DuckDB integration delivers enterprise-grade performance
3. **Flexibility**: Supports multiple data formats and report types
4. **Professional Output**: Typst produces publication-quality typography
5. **Comprehensive**: Handles complete workflow from raw data to final report

The neuro2 package represents a sophisticated, modern approach to neuropsychological report generation, balancing performance, flexibility, and usability while maintaining professional standards for clinical reporting.
