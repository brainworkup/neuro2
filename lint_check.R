#!/usr/bin/env Rscript

# R Syntax Linting Script
files_to_check <- c('neuroefficient_workflow_v5.R', '01_import_process_data.R')

for (file in files_to_check) {
  if (file.exists(file)) {
    tryCatch(
      {
        parse(file)
        cat('✅', file, 'syntax OK\n')
      },
      error = function(e) {
        cat('❌', file, 'syntax error:', e$message, '\n')
        quit(status = 1)
      }
    )
  } else {
    cat('⚠️', file, 'not found\n')
  }
}

cat('✅ All R files passed syntax check\n')
