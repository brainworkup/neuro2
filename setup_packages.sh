#!/bin/bash
# setup_packages.sh - One-time package installation
Rscript -e "install.packages(c('yaml', 'dplyr', 'readr', 'arrow', 'here', 'rmarkdown', 'quarto'))"
Rscript -e "devtools::install_local('.', dependencies=TRUE, upgrade='always')"
Rscript check_all_templates.R
Rscript -e "source('inst/scripts/03_data_processor_module.R')"
Rscript generate_domain_files.R
