# File: create_root_wrappers.R
# Creates smart wrapper scripts in root that handle paths correctly

create_root_wrappers <- function() {
  
  # Define scripts to wrap
  scripts <- list(
    "setup_template_repo.R" = list(
      description = "Set up template repository structure",
      main_function = "setup_template_repo"
    ),
    "batch_domain_processor.R" = list(
      description = "Batch process all domains", 
      main_function = "process_all_domains"
    ),
    "template_integration.R" = list(
      description = "Integrate templates and run workflow",
      main_function = "run_complete_workflow"
    )
  )
  
  for (script_name in names(scripts)) {
    script_info <- scripts[[script_name]]
    
    # Create wrapper content
    wrapper_content <- sprintf('#!/usr/bin/env Rscript
# %s
# Wrapper for inst/scripts/%s

# Ensure we\'re in the right directory
if (!file.exists("inst/scripts/%s")) {
  stop("This script must be run from the root of the neuro2 repository")
}

# Source the actual script with proper working directory handling
original_wd <- getwd()
tryCatch({
  # Source the script from inst/scripts
  source(file.path("inst", "scripts", "%s"))
  
  # Call main function if it exists and script is run directly
  if (!interactive() && exists("%s")) {
    %s()
  }
}, finally = {
  # Restore working directory if it was changed
  setwd(original_wd)
})
', script_info$description, script_name, script_name, script_name, 
   script_info$main_function, script_info$main_function)
    
    # Write wrapper script
    wrapper_path <- file.path(tools::file_path_sans_ext(script_name))
    if (tools::file_ext(script_name) == "R") {
      wrapper_path <- paste0(wrapper_path, ".R")
    }
    
    writeLines(wrapper_content, wrapper_path)
    
    # Make executable on Unix systems
    if (.Platform$OS.type == "unix") {
      Sys.chmod(wrapper_path, mode = "0755")
    }
    
    message("✅ Created wrapper: ", wrapper_path)
  }
  
  # Create a master script loader
  master_loader <- '#!/usr/bin/env Rscript
# neuro2_scripts.R
# Master loader for all neuro2 functionality

#\' Load all neuro2 scripts and functions
#\' @param verbose Whether to show loading messages
load_neuro2_scripts <- function(verbose = TRUE) {
  
  if (verbose) message("🧠 Loading neuro2 scripts...")
  
  # Source all scripts from inst/scripts
  script_files <- list.files(
    file.path("inst", "scripts"), 
    pattern = "\\\\.R$", 
    full.names = TRUE
  )
  
  for (script in script_files) {
    if (verbose) message("  📜 Loading: ", basename(script))
    source(script)
  }
  
  if (verbose) message("✅ All scripts loaded!")
  
  invisible(TRUE)
}

# Auto-load when sourced
if (!interactive()) {
  load_neuro2_scripts()
}
'
  
  writeLines(master_loader, "neuro2_scripts.R")
  message("✅ Created master loader: neuro2_scripts.R")
  
  # Create usage guide
  usage_guide <- '# Script Usage Guide

## Option 1: Use wrapper scripts (recommended)
```bash
Rscript setup_template_repo.R
Rscript batch_domain_processor.R
```

## Option 2: Load all scripts at once
```r
source("neuro2_scripts.R")
# Now all functions are available
setup_template_repo()
process_all_domains()
```

## Option 3: Source specific scripts
```r
source("inst/scripts/setup_template_repo.R")
setup_template_repo()
```

## Option 4: Use from R console
```r
load_neuro2_scripts()
# All functions now available
```
'
  
  writeLines(usage_guide, "SCRIPT_USAGE.md")
  message("✅ Created usage guide: SCRIPT_USAGE.md")
  
  invisible(TRUE)
}

# Run if called directly
if (!interactive()) {
  create_root_wrappers()
}