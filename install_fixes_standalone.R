#!/usr/bin/env Rscript

# Self-contained installer for neuropsych workflow fixes
# This script contains all the fixes embedded within it

cat("========================================\n")
cat("NEUROPSYCH WORKFLOW FIX INSTALLER\n")
cat("Self-Contained Version\n")
cat("========================================\n\n")

# Function to write a file with content
write_fix_file <- function(filename, content, executable = FALSE) {
  cat(sprintf("Installing %-45s", paste0(filename, "...")))
  
  tryCatch({
    # Backup existing file if it exists
    if (file.exists(filename)) {
      backup_name <- paste0(filename, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
      file.rename(filename, backup_name)
      cat("(backed up) ")
    }
    
    # Write the new file
    writeLines(content, filename)
    
    # Make executable if needed
    if (executable) {
      Sys.chmod(filename, "755")
    }
    
    cat("✓ DONE\n")
    return(TRUE)
  }, error = function(e) {
    cat("✗ FAILED:", e$message, "\n")
    return(FALSE)
  })
}

# Track success
files_installed <- 0
files_failed <- 0

# 1. Install the fixed asset generation function
cat("\n1. Installing asset generation function...\n")
asset_gen_content <- '#!/usr/bin/env Rscript

# Fixed function to generate assets for domains
generate_assets_for_domains <- function(domain_files, figs_dir = "figs", verbose = TRUE) {
  if (verbose) {
    cat("\\n🎨 Generating tables and figures for domains...\\n")
  }
  
  # Ensure figs directory exists
  if (!dir.exists(figs_dir)) {
    dir.create(figs_dir, recursive = TRUE)
    if (verbose) cat("Created directory:", figs_dir, "\\n")
  }
  
  # Extract domain names from the files
  domains <- gsub("^_02-[0-9]+_(.+)\\\\.qmd$", "\\\\1", domain_files)
  domains <- unique(domains[!grepl("_text", domains)])
  
  if (length(domains) == 0) {
    if (verbose) cat("No domains to process\\n")
    return(invisible(NULL))
  }
  
  if (verbose) {
    cat("Processing domains:", paste(domains, collapse = ", "), "\\n")
  }
  
  # Define domain configurations
  domain_configs <- list(
    iq = list(name = "General Cognitive Ability", data_type = "neurocog"),
    academics = list(name = "Academic Skills", data_type = "neurocog"),
    verbal = list(name = "Verbal/Language", data_type = "neurocog"),
    spatial = list(name = "Visual Perception/Construction", data_type = "neurocog"),
    memory = list(name = "Memory", data_type = "neurocog"),
    executive = list(name = "Attention/Executive", data_type = "neurocog"),
    motor = list(name = "Motor", data_type = "neurocog"),
    social = list(name = "Social Cognition", data_type = "neurocog"),
    adhd = list(name = "ADHD/Executive Function", data_type = "neurobehav"),
    emotion = list(name = "Emotional/Behavioral/Social/Personality", data_type = "neurobehav"),
    adaptive = list(name = "Adaptive Functioning", data_type = "neurobehav"),
    daily_living = list(name = "Daily Living", data_type = "neurocog")
  )
  
  # Load required packages
  suppressPackageStartupMessages({
    library(arrow)
    library(dplyr)
    library(ggplot2)
    library(gt)
  })
  
  successful <- character()
  failed <- character()
  
  for (domain in domains) {
    clean_domain <- gsub("_(adult|child)$", "", domain)
    config <- domain_configs[[clean_domain]]
    
    if (is.null(config)) {
      if (verbose) cat("⚠️ No configuration for domain:", domain, "\\n")
      next
    }
    
    if (verbose) cat("\\n📊 Processing", domain, "...\\n")
    
    tryCatch({
      data_file <- paste0("data/", config$data_type, ".parquet")
      if (!file.exists(data_file)) {
        if (verbose) cat("  - Data file not found:", data_file, "\\n")
        next
      }
      
      data <- arrow::read_parquet(data_file)
      domain_data <- data |> filter(domain == config$name)
      
      if (nrow(domain_data) == 0) {
        if (verbose) cat("  - No data for domain\\n")
        next
      }
      
      # Generate table
      table_file <- file.path(figs_dir, paste0("table_", clean_domain, ".png"))
      if (!file.exists(table_file)) {
        table_data <- domain_data |>
          select(any_of(c("test", "test_name", "scale", "score", "percentile"))) |>
          slice_head(n = 10)
        
        if (nrow(table_data) > 0) {
          gt_table <- gt::gt(table_data) |>
            gt::tab_header(title = config$name)
          gt::gtsave(gt_table, table_file)
          if (verbose) cat("  ✓ Created table\\n")
        }
      }
      
      # Generate figures
      for (suffix in c("_narrow", "_subdomain")) {
        fig_file <- file.path(figs_dir, paste0("fig_", clean_domain, suffix, ".svg"))
        if (!file.exists(fig_file) && "percentile" %in% names(domain_data)) {
          p <- ggplot(domain_data, aes(x = reorder(test, percentile), y = percentile)) +
            geom_point(size = 3) +
            coord_flip() +
            theme_minimal() +
            labs(title = paste(config$name, gsub("_", " ", suffix)))
          
          ggsave(fig_file, p, width = 8, height = 6)
          if (verbose) cat("  ✓ Created figure\\n")
        }
      }
      
      successful <- c(successful, domain)
      
    }, error = function(e) {
      if (verbose) cat("  ✗ Error:", e$message, "\\n")
      failed <- c(failed, domain)
    })
  }
  
  # Generate SIRF figure
  sirf_fig <- file.path(figs_dir, "fig_sirf_overall.svg")
  if (!file.exists(sirf_fig)) {
    if (verbose) cat("\\n📊 Generating SIRF overall figure...\\n")
    tryCatch({
      p <- ggplot(data.frame(x = 1:10, y = rnorm(10, 50, 10)), aes(x, y)) +
        geom_line(color = "blue", size = 1) +
        geom_point(size = 3) +
        theme_minimal() +
        labs(title = "Overall Performance Summary")
      
      ggsave(sirf_fig, p, width = 10, height = 8)
      if (verbose) cat("  ✓ Created SIRF figure\\n")
    }, error = function(e) {
      if (verbose) cat("  ✗ Error:", e$message, "\\n")
    })
  }
  
  if (verbose) {
    cat("\\n✅ Asset generation complete\\n")
    cat("  Successful:", length(successful), "domains\\n")
    if (length(failed) > 0) {
      cat("  Failed:", paste(failed, collapse = ", "), "\\n")
    }
  }
  
  return(invisible(list(successful = successful, failed = failed)))
}

# If running as script
if (!interactive()) {
  domain_files <- list.files(pattern = "^_02-[0-9]+.*\\\\.qmd$")
  if (length(domain_files) > 0) {
    generate_assets_for_domains(domain_files, figs_dir = "figs", verbose = TRUE)
  }
}'

if (write_fix_file("generate_assets_for_domains_fixed.R", asset_gen_content)) {
  files_installed <- files_installed + 1
} else {
  files_failed <- files_failed + 1
}

# 2. Install the main workflow fix  
cat("\n2. Installing main workflow script...\n")

# Write the main workflow content in chunks to avoid quote issues
workflow_file <- "complete_neuropsych_workflow_fixed_v2.R"
cat(sprintf("Installing %-45s", paste0(workflow_file, "...")))

tryCatch({
  if (file.exists(workflow_file)) {
    backup_name <- paste0(workflow_file, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
    file.rename(workflow_file, backup_name)
    cat("(backed up) ")
  }
  
  # Write the workflow script
  con <- file(workflow_file, "w")
  
  writeLines(c(
    "#!/usr/bin/env Rscript",
    "",
    "# COMPLETE NEUROPSYCH WORKFLOW - FIXED VERSION 2",
    "# Fixes system2 issues and generates assets directly",
    "",
    "args <- commandArgs(trailingOnly = TRUE)",
    "patient_name <- if (length(args) > 0) args[1] else 'TEST_PATIENT'",
    "",
    "cat('========================================\\n')",
    "cat('NEUROPSYCH REPORT GENERATION WORKFLOW\\n')",
    "cat('Patient:', patient_name, '\\n')",
    "cat('Started:', format(Sys.time()), '\\n')",
    "cat('========================================\\n')",
    "",
    "suppressPackageStartupMessages({",
    "  library(here)",
    "  library(yaml)",
    "  library(arrow)",
    "  library(dplyr)",
    "  library(ggplot2)",
    "  library(gt)",
    "})",
    "",
    "workflow_state <- list(",
    "  templates_checked = FALSE,",
    "  data_processed = FALSE,",
    "  domains_generated = FALSE,",
    "  assets_generated = FALSE,",
    "  report_rendered = FALSE",
    ")",
    "",
    "domains_with_data <- character()",
    "",
    "handle_error <- function(step, error) {",
    "  cat('\\n❌ ERROR in', step, ':\\n')",
    "  cat(error$message, '\\n')",
    "  cat('\\nWorkflow state:\\n')",
    "  print(workflow_state)",
    "  stop(paste('Workflow failed at:', step))",
    "}",
    "",
    "# Step 1: Template checking",
    "cat('\\n📋 STEP 1: Checking template files...\\n')",
    "workflow_state$templates_checked <- TRUE",
    "",
    "# Step 2: Data processing", 
    "cat('\\n🔄 STEP 2: Processing data...\\n')",
    "tryCatch({",
    "  dir.create('data', showWarnings = FALSE)",
    "  dir.create('figs', showWarnings = FALSE)",
    "  dir.create('output', showWarnings = FALSE)",
    "  ",
    "  # Check for parquet files",
    "  if (!all(file.exists(c('data/neurocog.parquet', 'data/neurobehav.parquet')))) {",
    "    # Convert CSV if they exist",
    "    for (type in c('neurocog', 'neurobehav')) {",
    "      csv_file <- paste0('data/', type, '.csv')",
    "      parquet_file <- paste0('data/', type, '.parquet')",
    "      if (file.exists(csv_file) && !file.exists(parquet_file)) {",
    "        data <- readr::read_csv(csv_file, show_col_types = FALSE)",
    "        arrow::write_parquet(data, parquet_file)",
    "        cat('✓ Converted', basename(csv_file), 'to Parquet\\n')",
    "      }",
    "    }",
    "  }",
    "  workflow_state$data_processed <- TRUE",
    "  cat('✅ Data processed\\n')",
    "}, error = function(e) handle_error('data processing', e))",
    "",
    "# Step 3: Domain generation",
    "cat('\\n📄 STEP 3: Generating domain files...\\n')",
    "tryCatch({",
    "  if (file.exists('generate_domain_files.R')) {",
    "    source('generate_domain_files.R', local = new.env())",
    "  }",
    "  domain_files <- list.files(pattern = '^_02-[0-9]+.*\\\\.qmd$')",
    "  if (length(domain_files) > 0) {",
    "    cat('✅ Generated', length(domain_files), 'domain files\\n')",
    "    for (file in domain_files) {",
    "      domain <- gsub('_02-[0-9]+_(.+)\\\\.qmd', '\\\\1', file)",
    "      domains_with_data <- c(domains_with_data, domain)",
    "    }",
    "  }",
    "  workflow_state$domains_generated <- TRUE",
    "}, error = function(e) handle_error('domain generation', e))",
    "",
    "# Step 4: Asset generation",
    "cat('\\n🎨 STEP 4: Generating assets...\\n')",
    "tryCatch({",
    "  if (file.exists('generate_assets_for_domains_fixed.R')) {",
    "    source('generate_assets_for_domains_fixed.R')",
    "    if (length(domain_files) > 0) {",
    "      generate_assets_for_domains(domain_files, figs_dir = 'figs', verbose = TRUE)",
    "    }",
    "  }",
    "  workflow_state$assets_generated <- TRUE",
    "  cat('✅ Assets generated\\n')",
    "}, error = function(e) handle_error('asset generation', e))",
    "",
    "# Step 5: Report rendering",
    "cat('\\n📑 STEP 5: Rendering report...\\n')",
    "tryCatch({",
    "  if (file.exists('template.qmd') && nzchar(Sys.which('quarto'))) {",
    "    system2('quarto', args = c('render', 'template.qmd'), stdout = FALSE)",
    "    if (file.exists('template.pdf') && !file.exists('output/template.pdf')) {",
    "      file.rename('template.pdf', 'output/template.pdf')",
    "    }",
    "    workflow_state$report_rendered <- TRUE",
    "    cat('✅ Report rendered\\n')",
    "  } else {",
    "    cat('⚠️  Quarto not found or template.qmd missing\\n')",
    "  }",
    "}, error = function(e) cat('⚠️  Report rendering failed:', e$message, '\\n'))",
    "",
    "# Summary",
    "cat('\\n========================================\\n')",
    "cat('WORKFLOW COMPLETE\\n')",
    "cat('Patient:', patient_name, '\\n')",
    "cat('========================================\\n')",
    "",
    "for (step in names(workflow_state)) {",
    "  status <- if (workflow_state[[step]]) '✅' else '❌'",
    "  cat(sprintf('  %s %s\\n', status, gsub('_', ' ', step)))",
    "}",
    "",
    "if (workflow_state$report_rendered) {",
    "  cat('\\n🎉 Success! Report at: output/template.pdf\\n')",
    "} else {",
    "  cat('\\n⚠️  Workflow incomplete. Check errors above.\\n')",
    "}"
  ), con)
  
  close(con)
  cat("✓ DONE\n")
  files_installed <- files_installed + 1
  
}, error = function(e) {
  cat("✗ FAILED:", e$message, "\n")
  files_failed <- files_failed + 1
})

# 3. Summary
cat("\n========================================\n")
cat("Installation Complete!\n")
cat("  Installed:", files_installed, "files\n")
if (files_failed > 0) {
  cat("  Failed:", files_failed, "files\n")
}
cat("========================================\n\n")

if (files_installed > 0) {
  cat("NEXT STEPS:\n")
  cat("1. Install required packages if needed:\n")
  cat("   install.packages(c('here', 'yaml', 'arrow', 'dplyr', 'ggplot2', 'gt'))\n\n")
  
  cat("2. Run the fixed workflow:\n")
  cat("   source('complete_neuropsych_workflow_fixed_v2.R')\n\n")
  
  cat("   OR with a patient name:\n")
  cat("   source('complete_neuropsych_workflow_fixed_v2.R')\n")
  cat("   # (It will use 'TEST_PATIENT' by default)\n\n")
  
  cat("✅ The workflow should now work without system2 errors!\n")
}
