Report Workflow: Run From Scratch

This guide shows how to take the raw CSVs in `data-raw/csv/`, build the processed datasets, generate domain content, and render the final report PDF.

Prerequisites
- R (>= 4.2 recommended)
- Quarto (>= 1.4) with Typst support
- Typst CLI (>= 0.10)
- R packages: scripts auto-install most dependencies; if needed, install: `install.packages(c('arrow','duckdb','R6','ggplot2','ggthemes','gt','gtExtras','yaml','here','quarto'))`

Configuration
- Edit `config.yml` to set:
  - `data.input_dir`: where your raw CSVs live (default `data-raw/csv`)
  - `data.output_dir`: where processed files are written (default `data`)
  - `report.template`: the top-level QMD (default `template.qmd`)
  - `report.format`: one of `neurotyp-adult-typst`, `neurotyp-pediatric-typst`, `neurotyp-forensic-typst`
  - `report.output_dir`: where the final PDF lands (default `output`)

Quick Start (recommended)
1) Process raw data into `data/` (Parquet/CSV/Feather)
   - `Rscript inst/scripts/data_processor_module.R`

2) Render the report (Typst/PDF)
   - `quarto render template.qmd -t neurotyp-adult-typst`
   - Output: `output/template.pdf`

From-Scratch, Fully Explicit
- Step 1: Process the raw CSVs
  - `Rscript inst/scripts/data_processor_module.R`
  - Reads from `config.yml:data.input_dir` and writes `neurocog`, `neurobehav`, `validity` to `config.yml:data.output_dir`.

- Step 2: Generate figures and tables used by domains
  - `Rscript generate_all_domain_assets.R`
  - Produces `table_*.png/pdf` and `fig_*.svg` in the project root.
  - Also ensures the overall SIRF figure `fig_sirf_overall.svg` exists.

- Step 3: Generate domain QMD sections (only for domains with data)
  - `Rscript generate_domain_files.R`
  - Creates `_02-*.qmd` domain files and placeholder `*_text.qmd` files when needed.

- Step 4: Render the report
  - Option A (CLI): `quarto render template.qmd -t neurotyp-adult-typst`
  - Option B (R): `R -q -e "quarto::quarto_render('template.qmd', output_format='neurotyp-adult-typst')"`
  - Output appears under `output/` (set by project `_quarto.yml`).

Notes
- Template: the top-level `template.qmd` includes domain sections dynamically via `_domains_to_include.qmd`, which is produced during rendering.
- Alternative scripts:
  - `inst/scripts/batch_domain_processor.R` provides programmatic domain generation (`process_all_domains()`).
  - `inst/scripts/template_integration.R` contains helpers to inject domain includes when using a marker-based template. The current `template.qmd` already uses dynamic includes, so you typically don’t need to run this.
- Formats: to render pediatric or forensic variants, use `-t neurotyp-pediatric-typst` or `-t neurotyp-forensic-typst` in the Quarto command.

Common Pitfalls
- Missing SIRF figure: The Typst template expects `fig_sirf_overall.svg`. The pre-render step now auto-generates it in Step 2. If you still see an error, run Step 2 again or clear `_freeze/` and re-render.
- Clean rebuild: If outputs look stale, delete `_freeze/` and `output/` and then re-run the steps.

