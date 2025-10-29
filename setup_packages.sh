#!/bin/bash
# setup_packages.sh - One-time package installation
Rscript -e "install.packages(c('yaml', 'dplyr', 'readr', 'arrow', 'here', 'rmarkdown', 'quarto'))"
Rscript -e "devtools::install_local('.', dependencies = TRUE, upgrade = 'always')"
Rscript -e "source('inst/scripts/01_check_all_templates.R')"
Rscript -e "source('inst/scripts/02_data_processor_module.R')"
Rscript -e "source('inst/scripts/03_generate_domain_files.R')"
Rscript -e "source('inst/scripts/04_generate_all_domain_assets.R')"
Rscript -e "source('inst/scripts/00_complete_neuropsych_workflow.R')"
