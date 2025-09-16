#!/usr/bin/env Rscript

#' Fix Custom Typst Format Configuration
#' This script ensures the custom neurotyp formats work properly

cat("\n========================================\n")
cat("FIXING CUSTOM TYPST FORMAT CONFIGURATION\n")
cat("========================================\n\n")

# Function to create format extension directory
setup_custom_format <- function(format_name) {
  # Create _extensions directory structure
  ext_dir <- file.path("_extensions", format_name)
  
  if (!dir.exists("_extensions")) {
    dir.create("_extensions", showWarnings = FALSE)
    cat("📁 Created _extensions directory\n")
  }
  
  if (!dir.exists(ext_dir)) {
    dir.create(ext_dir, recursive = TRUE, showWarnings = FALSE)
    cat("📁 Created format directory:", ext_dir, "\n")
  }
  
  # Create _extension.yml for the format
  extension_yml <- file.path(ext_dir, "_extension.yml")
  
  if (!file.exists(extension_yml)) {
    # Get base config from main _quarto.yml
    base_config <- list()
    if (file.exists("_quarto.yml")) {
      quarto_config <- yaml::read_yaml("_quarto.yml")
      if (!is.null(quarto_config$format[[format_name]])) {
        base_config <- quarto_config$format[[format_name]]
      }
    }
    
    # Create extension configuration
    ext_config <- list(
      title = format_name,
      author = "neuro2",
      version = "1.0.0",
      contributes = list(
        formats = list(
          typst = base_config
        )
      )
    )
    
    yaml::write_yaml(ext_config, extension_yml)
    cat("✅ Created extension config:", extension_yml, "\n")
  }
  
  return(ext_dir)
}

# Function to create simplified _quarto.yml
create_simplified_quarto_yml <- function() {
  cat("\n📝 Creating simplified _quarto.yml with working formats...\n")
  
  # Backup existing _quarto.yml
  if (file.exists("_quarto.yml")) {
    backup_file <- paste0("_quarto.yml.backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
    file.copy("_quarto.yml", backup_file)
    cat("📋 Backed up existing _quarto.yml to:", backup_file, "\n")
  }
  
  # Create simplified configuration
  config <- list(
    project = list(
      type = "default",
      title = "neuro2",
      `execute-dir` = "project"
    ),
    
    execute = list(
      warning = FALSE,
      echo = FALSE,
      eval = TRUE,
      message = FALSE,
      freeze = "auto",
      cache = TRUE,
      engine = "knitr"
    ),
    
    format = list(
      # Basic typst format that should always work
      typst = list(
        `keep-typ` = TRUE,
        `keep-md` = TRUE,
        papersize = "us-letter",
        fontsize = "11pt",
        `number-sections` = FALSE,
        `fig-width` = 6,
        `fig-height` = 4,
        `fig-format` = "svg"
      ),
      
      # HTML fallback
      html = list(
        theme = "cosmo",
        `toc` = TRUE,
        `toc-depth` = 2,
        `number-sections` = FALSE,
        `fig-width` = 6,
        `fig-height` = 4,
        `fig-format` = "svg"
      ),
      
      # PDF fallback (if LaTeX is installed)
      pdf = list(
        documentclass = "article",
        papersize = "letter",
        fontsize = "11pt",
        geometry = "margin=1in",
        `fig-width` = 6,
        `fig-height` = 4
      )
    )
  )
  
  # Add custom formats as simple extensions of typst
  custom_formats <- c(
    "neurotyp-adult-typst",
    "neurotyp-forensic-typst", 
    "neurotyp-pediatric-typst"
  )
  
  for (fmt in custom_formats) {
    config$format[[fmt]] <- config$format$typst
    config$format[[fmt]]$bodyfont <- "IBM Plex Serif"
    config$format[[fmt]]$sansfont <- "IBM Plex Sans"
  }
  
  # Write simplified config
  yaml::write_yaml(config, "_quarto.yml")
  cat("✅ Created simplified _quarto.yml\n")
}

# Function to test rendering
test_render <- function(format = "typst") {
  cat("\n🧪 Testing render with format:", format, "\n")
  
  # Create minimal test document if template.qmd doesn't exist
  if (!file.exists("template.qmd")) {
    test_qmd <- '---
title: "Test Document"
---

# Test Section

This is a test document.
'
    writeLines(test_qmd, "template_test.qmd")
    test_file <- "template_test.qmd"
  } else {
    test_file <- "template.qmd"
  }
  
  # Try to render
  result <- system2("quarto",
    args = c("render", test_file, "--to", format),
    stdout = TRUE, stderr = TRUE
  )
  
  success <- !is.null(attr(result, "status")) && attr(result, "status") == 0
  
  if (success || any(grepl("Output created", result))) {
    cat("✅ Render test passed for format:", format, "\n")
    return(TRUE)
  } else {
    cat("❌ Render test failed for format:", format, "\n")
    cat("Error output:\n")
    cat(tail(result, 10), sep = "\n")
    return(FALSE)
  }
}

# Main execution
main <- function() {
  # 1. Check current situation
  cat("1. CHECKING CURRENT CONFIGURATION\n")
  cat("--------------------------------\n")
  
  if (file.exists("_quarto.yml")) {
    config <- yaml::read_yaml("_quarto.yml")
    formats <- names(config$format)
    cat("Current formats:", paste(formats, collapse = ", "), "\n")
    
    # Check for problematic custom formats
    custom_formats <- grep("neurotyp", formats, value = TRUE)
    if (length(custom_formats) > 0) {
      cat("Custom neurotyp formats found:", paste(custom_formats, collapse = ", "), "\n")
    }
  } else {
    cat("❌ No _quarto.yml found\n")
    formats <- character()
  }
  
  # 2. Test current configuration
  cat("\n2. TESTING CURRENT CONFIGURATION\n")
  cat("--------------------------------\n")
  
  # Test basic typst first
  typst_works <- test_render("typst")
  
  # Test custom format if exists
  custom_works <- FALSE
  if ("neurotyp-pediatric-typst" %in% formats) {
    custom_works <- test_render("neurotyp-pediatric-typst")
  }
  
  # 3. Apply fixes if needed
  if (!typst_works || !custom_works) {
    cat("\n3. APPLYING FIXES\n")
    cat("--------------------------------\n")
    
    # Create simplified configuration
    create_simplified_quarto_yml()
    
    # Set up custom format extensions
    for (fmt in c("neurotyp-adult-typst", "neurotyp-forensic-typst", "neurotyp-pediatric-typst")) {
      setup_custom_format(fmt)
    }
    
    # Test again
    cat("\n4. TESTING FIXED CONFIGURATION\n")
    cat("--------------------------------\n")
    
    typst_works <- test_render("typst")
    
    if (typst_works) {
      cat("\n✅ Basic Typst rendering is now working!\n")
    }
    
    # Test custom format
    custom_works <- test_render("neurotyp-pediatric-typst")
    
    if (custom_works) {
      cat("\n✅ Custom format rendering is now working!\n")
    }
  } else {
    cat("\n✅ All formats are working correctly!\n")
  }
  
  # 5. Provide recommendations
  cat("\n========================================\n")
  cat("RECOMMENDATIONS\n")
  cat("========================================\n\n")
  
  if (typst_works) {
    cat("✅ You can now render with Typst format\n")
    cat("   Command: quarto render template.qmd --to typst\n\n")
  }
  
  if (custom_works) {
    cat("✅ You can use custom neurotyp formats\n")
    cat("   Command: quarto render template.qmd --to neurotyp-pediatric-typst\n\n")
  }
  
  if (!typst_works && !custom_works) {
    cat("⚠️  Typst rendering is still not working\n")
    cat("Possible issues:\n")
    cat("1. Typst may not be installed. Install from: https://github.com/typst/typst\n")
    cat("2. Missing fonts (IBM Plex). Install from: https://github.com/IBM/plex\n")
    cat("3. Try HTML format as fallback: quarto render template.qmd --to html\n")
  }
  
  cat("\nTo use the fixed workflow:\n")
  cat("  Rscript complete_neuropsych_workflow_fixed_v3.R 'PatientName'\n\n")
}

# Run main function
if (!interactive()) {
  main()
} else {
  cat("Run main() to fix the Typst format configuration\n")
}
