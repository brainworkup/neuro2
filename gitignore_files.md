<!-- Minimal .gitignore for the template repo Goal: ignore build artifacts and local clutter, but keep your source (.qmd, .typ, R scripts, etc.) tracked. This replaces the current highly-specific ignore list and avoids hiding important template files. -->

# OS/system
.DS_Store
Thumbs.db
Icon
Icon?

# Env and secrets
.env

# R / RStudio
.Rhistory
.RData
.Ruserdata
.Rproj.user/

# Editors
.vscode/
.history/

# Quarto build artifacts
.quarto/
*_cache/
**/*_cache/
*_files/
**/*_files/

# Logs and temp
*.log
*.tmp
*.bak
*_backup.*

# Generated outputs (keep source tracked)
output/
reports/
neuropsych_report*.pdf
*_main.pdf
table_*.pdf
table_*.png

# Large binary data that should not be tracked by default
*.parquet
*.feather

# Node/quarto dashboard vendor bundles (if any get generated)
neuropsych-dashboard_files/

<!-- Optional: aggressive ignore for patient repos If you want new patient repos to aggressively ignore datasets and most binary exports, drop this next to the template as a helper file. After creating each patient repo, rename it to .gitignore (or append its content to the repo’s .gitignore). Name the file ".gitignore-patient" -->

# Aggressive ignore for per-patient repositories to minimize PHI in Git
# Rename this to .gitignore in the patient repo if desired.

# OS/system
.DS_Store
Thumbs.db
Icon
Icon?

# Env and secrets
.env

# R / RStudio
.Rhistory
.RData
.Ruserdata
.Rproj.user/

# Editors
.vscode/
.history/

# Quarto build artifacts
.quarto/
*_cache/
**/*_cache/
*_files/
**/*_files/

# Logs and temp
*.log
*.tmp
*.bak

# Generated outputs
output/
reports/
*.html
*.pdf
*.docx
*.pptx

# Data files (assume PHI)
data/
data-raw/
*.csv
*.tsv
*.xlsx
*.xls
*.sav
*.rda
*.rds
*.feather
*.parquet
*.zip
*.gz
