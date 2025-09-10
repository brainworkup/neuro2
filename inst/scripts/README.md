# Scripts Overview

This folder contains modular scripts used by the neuro2 workflow. They are primarily invoked by higher‑level runners (e.g., `unified_workflow_runner.R`) but can be run directly if needed.

- `main_workflow_runner.R`
  - Single‑entry orchestrator that ensures the workflow runs once, loads data, processes domains, and optionally renders a report.
  - Usage: `Rscript inst/scripts/main_workflow_runner.R` (the function `run_neuropsych_workflow()` can be sourced and called programmatically).

- `batch_domain_processor.R`
  - Minimal example of iterating through standard domains one time each; useful for smoke testing domain processing logic.
  - Usage: `Rscript inst/scripts/batch_domain_processor.R`.

- `data_processor_module.R`
  - Handles high‑performance data processing via DuckDB based on `config.yml` (or a fallback config in the template dir).
  - Usage: `Rscript inst/scripts/data_processor_module.R`.

- `report_generator_module.R`
  - Renders the final report via Quarto using the configured template, with checks to ensure the template is available.
  - Usage: `Rscript inst/scripts/report_generator_module.R`.

- `template_integration.R`
  - Utilities for integrating template content into the workflow (helper module sourced by other scripts).

- `common_utils.R`
  - Shared helpers (package loading, logging, config loading, safe sourcing, data file discovery) used across the modules above.

- `build_docs.R`
  - Invoked by `make docs` to build the documentation site using the `altdoc` package (with a Quarto fallback).
  - Usage: `Rscript inst/scripts/build_docs.R` or simply `make docs`.

- `benchmarks.R`
  - Lightweight micro-benchmarks for hot paths (domain mapping, factory lookups). No extra packages required.
  - Usage: `Rscript inst/scripts/benchmarks.R` or `make bench`.

- `profile_report.R`
  - Profiles a typical orchestration run; uses `profvis` if available (saves HTML under `tmp/`), otherwise falls back to `Rprof` summary.
  - Usage: `Rscript inst/scripts/profile_report.R` or `make profile`.

Tips
- Prefer running top‑level workflows via `make` targets for reproducibility: `make deps`, `make test`, `make check`, `make docs`.
- For end‑to‑end runs with prompts, see `unified_neuropsych_workflow.sh` and `unified_workflow_runner.R` in the repo root.
