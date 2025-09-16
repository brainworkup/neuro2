#!/usr/bin/env Rscript

#' Fix DomainProcessorR6 File Path Issues
#' 
#' This script patches the DomainProcessorR6 class to:
#' 1. Save figures and tables to the figs/ directory
#' 2. Reference them correctly in the generated QMD files

cat("\n========================================\n")
cat("FIXING DOMAINPROCESSOR FILE PATHS\n")
cat("========================================\n\n")

# Function to patch the DomainProcessorR6 file
patch_domain_processor <- function() {
  
  # Look for the DomainProcessorR6.R file
  possible_locations <- c(
    "R/DomainProcessorR6.R",
    # "inst/R/DomainProcessorR6.R",
    # "DomainProcessorR6.R",
    here::here("R", "DomainProcessorR6.R")
  )
  
  processor_file <- NULL
  for (loc in possible_locations) {
    if (file.exists(loc)) {
      processor_file <- loc
      break
    }
  }
  
  if (is.null(processor_file)) {
    cat("❌ Could not find DomainProcessorR6.R\n")
    cat("Please specify the location of the file.\n")
    return(FALSE)
  }
  
  cat("📄 Found DomainProcessorR6.R at:", processor_file, "\n")
  
  # Backup the original file
  backup_file <- paste0(processor_file, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy(processor_file, backup_file)
  cat("📋 Backed up to:", backup_file, "\n")
  
  # Read the file
  lines <- readLines(processor_file)
  
  # Counter for fixes applied
  fixes_applied <- 0
  
  # Fix 1: Update file paths in QMD generation
  # Look for lines that set file_qtbl and file_fig variables
  for (i in seq_along(lines)) {
    # Fix table file reference
    if (grepl('#let file_qtbl = "table_', lines[i], fixed = TRUE)) {
      old_line <- lines[i]
      # Add figs/ prefix if not already there
      if (!grepl('figs/', lines[i])) {
        lines[i] <- gsub(
          '#let file_qtbl = "table_',
          '#let file_qtbl = "figs/table_',
          lines[i],
          fixed = TRUE
        )
        cat("✅ Fixed table path in line", i, "\n")
        fixes_applied <- fixes_applied + 1
      }
    }
    
    # Fix figure file reference
    if (grepl('#let file_fig = "fig_', lines[i], fixed = TRUE)) {
      old_line <- lines[i]
      # Add figs/ prefix if not already there
      if (!grepl('figs/', lines[i])) {
        lines[i] <- gsub(
          '#let file_fig = "fig_',
          '#let file_fig = "figs/fig_',
          lines[i],
          fixed = TRUE
        )
        cat("✅ Fixed figure path in line", i, "\n")
        fixes_applied <- fixes_applied + 1
      }
    }
    
    # Fix concatenated paths in QMD generation
    if (grepl('"#let file_qtbl = \\"table_"', lines[i])) {
      if (!grepl('figs/', lines[i])) {
        lines[i] <- gsub(
          '"#let file_qtbl = \\"table_"',
          '"#let file_qtbl = \\"figs/table_"',
          lines[i],
          fixed = TRUE
        )
        cat("✅ Fixed concatenated table path in line", i, "\n")
        fixes_applied <- fixes_applied + 1
      }
    }
    
    if (grepl('"#let file_fig = \\"fig_"', lines[i])) {
      if (!grepl('figs/', lines[i])) {
        lines[i] <- gsub(
          '"#let file_fig = \\"fig_"',
          '"#let file_fig = \\"figs/fig_"',
          lines[i],
          fixed = TRUE
        )
        cat("✅ Fixed concatenated figure path in line", i, "\n")
        fixes_applied <- fixes_applied + 1
      }
    }
  }
  
  # Fix 2: Ensure save_table method saves to figs/
  for (i in seq_along(lines)) {
    # Look for gt::gtsave calls
    if (grepl("gt::gtsave", lines[i])) {
      # Check if it already has figs/ in the path
      if (!grepl("figs/", lines[i])) {
        # Check if it's using here::here
        if (grepl("here::here", lines[i])) {
          # Fix here::here paths
          lines[i] <- gsub(
            'here::here\\("',
            'here::here("figs", "',
            lines[i]
          )
          lines[i] <- gsub(
            "here::here\\('",
            "here::here('figs', '",
            lines[i]
          )
        } else {
          # Fix direct paths
          lines[i] <- gsub(
            'filename = "',
            'filename = "figs/',
            lines[i]
          )
          lines[i] <- gsub(
            "filename = '",
            "filename = 'figs/",
            lines[i]
          )
        }
        cat("✅ Fixed gtsave path in line", i, "\n")
        fixes_applied <- fixes_applied + 1
      }
    }
    
    # Look for ggplot2::ggsave calls
    if (grepl("ggplot2::ggsave", lines[i]) || grepl("ggsave\\(", lines[i])) {
      if (!grepl("figs/", lines[i])) {
        # Check if it's using here::here
        if (grepl("here::here", lines[i])) {
          lines[i] <- gsub(
            'here::here\\("',
            'here::here("figs", "',
            lines[i]
          )
          lines[i] <- gsub(
            "here::here\\('",
            "here::here('figs', '",
            lines[i]
          )
        } else {
          # Fix direct paths  
          lines[i] <- gsub(
            'filename = "',
            'filename = "figs/',
            lines[i]
          )
          lines[i] <- gsub(
            "filename = '",
            "filename = 'figs/",
            lines[i]
          )
        }
        cat("✅ Fixed ggsave path in line", i, "\n")
        fixes_applied <- fixes_applied + 1
      }
    }
  }
  
  # Write the fixed file
  if (fixes_applied > 0) {
    writeLines(lines, processor_file)
    cat("\n✅ Applied", fixes_applied, "fixes to", processor_file, "\n")
    return(TRUE)
  } else {
    cat("\n⚠️  No fixes needed - paths may already be correct\n")
    return(FALSE)
  }
}

# Function to create a patched generate method
create_patched_methods <- function() {
  cat("\n📝 Creating patched method overrides...\n")
  
  patch_code <- '
# Patched methods for DomainProcessorR6
# Source this AFTER loading the original class

# Store original methods if they exist
if (exists("DomainProcessorR6")) {
  .original_generate_standard_qmd <- DomainProcessorR6$public_methods$generate_standard_qmd
  .original_generate_emotion_qmd <- DomainProcessorR6$public_methods$generate_emotion_qmd
  
  # Override the generate_standard_qmd method
  DomainProcessorR6$set("public", "generate_standard_qmd", function(domain_name, output_file) {
    # Ensure figs directory exists
    if (!dir.exists("figs")) {
      dir.create("figs", showWarnings = FALSE)
    }
    
    # Call original method if it exists
    if (!is.null(.original_generate_standard_qmd)) {
      result <- .original_generate_standard_qmd(domain_name, output_file)
    }
    
    # Fix the generated file to have correct paths
    if (file.exists(output_file)) {
      content <- readLines(output_file)
      
      # Fix file paths in the generated QMD
      content <- gsub(
        \'#let file_qtbl = "table_\',
        \'#let file_qtbl = "figs/table_\',
        content,
        fixed = TRUE
      )
      content <- gsub(
        \'#let file_fig = "fig_\',
        \'#let file_fig = "figs/fig_\',
        content,
        fixed = TRUE
      )
      
      writeLines(content, output_file)
    }
    
    return(output_file)
  })
  
  message("✅ Patched DomainProcessorR6 methods")
}
'
  
  writeLines(patch_code, "patch_domain_processor_methods.R")
  cat("✅ Created patch_domain_processor_methods.R\n")
}

# Function to fix already generated QMD files
fix_existing_qmd_files <- function() {
  cat("\n🔧 Fixing existing QMD files...\n")
  
  # Find all domain QMD files
  qmd_files <- list.files(
    pattern = "^_02-.*\\.qmd$",
    full.names = FALSE
  )
  
  if (length(qmd_files) == 0) {
    cat("No domain QMD files found to fix.\n")
    return()
  }
  
  fixed_count <- 0
  
  for (qmd_file in qmd_files) {
    content <- readLines(qmd_file)
    original_content <- content
    
    # Fix file paths
    content <- gsub(
      '#let file_qtbl = "table_',
      '#let file_qtbl = "figs/table_',
      content,
      fixed = TRUE
    )
    content <- gsub(
      '#let file_fig = "fig_',
      '#let file_fig = "figs/fig_',
      content,
      fixed = TRUE
    )
    
    # Only count as fixed if content actually changed
    if (!identical(content, original_content)) {
      writeLines(content, qmd_file)
      cat("✅ Fixed", qmd_file, "\n")
      fixed_count <- fixed_count + 1
    }
  }
  
  if (fixed_count > 0) {
    cat("✅ Fixed", fixed_count, "QMD files\n")
  } else {
    cat("ℹ️  All QMD files already have correct paths\n")
  }
}

# Function to ensure figs directory exists and has correct structure
ensure_figs_directory <- function() {
  if (!dir.exists("figs")) {
    dir.create("figs", showWarnings = FALSE)
    cat("📁 Created figs/ directory\n")
  }
  
  # Check if any images are in the wrong location
  misplaced_images <- list.files(
    pattern = "^(table_|fig_).*\\.(png|pdf|svg)$",
    full.names = FALSE
  )
  
  if (length(misplaced_images) > 0) {
    cat("\n🚚 Moving misplaced images to figs/...\n")
    for (img in misplaced_images) {
      new_path <- file.path("figs", img)
      if (file.rename(img, new_path)) {
        cat("  ✅ Moved", img, "to figs/\n")
      }
    }
  }
}

# Main execution
main <- function() {
  cat("This fix will:\n")
  cat("1. Patch DomainProcessorR6.R to use figs/ directory\n")
  cat("2. Fix existing QMD files to reference figs/\n")
  cat("3. Move any misplaced images to figs/\n")
  cat("\nProceed? (y/n): ")
  
  if (interactive()) {
    response <- readline()
  } else {
    response <- "y"
  }
  
  if (tolower(response) != "y") {
    cat("Cancelled.\n")
    return()
  }
  
  # Step 1: Ensure figs directory exists
  ensure_figs_directory()
  
  # Step 2: Patch the DomainProcessorR6 file
  if (patch_domain_processor()) {
    cat("\n✅ Successfully patched DomainProcessorR6.R\n")
  }
  
  # Step 3: Create method override file
  create_patched_methods()
  
  # Step 4: Fix existing QMD files
  fix_existing_qmd_files()
  
  cat("\n========================================\n")
  cat("FIX COMPLETE\n")
  cat("========================================\n\n")
  
  cat("The file paths have been fixed!\n\n")
  
  cat("IMPORTANT: After this fix, you need to:\n")
  cat("1. Restart your R session to reload the patched class\n")
  cat("2. Re-run the workflow to regenerate files with correct paths\n")
  cat("3. Or just run: quarto render template.qmd --to typst\n\n")
  
  cat("If you still get errors, check that:\n")
  cat("• Files are actually being saved to figs/\n")
  cat("• The figs/ directory exists\n")
  cat("• Images referenced in QMD files exist in figs/\n")
}

# Run if not interactive
if (!interactive()) {
  main()
} else {
  cat("Run main() to apply the fix\n")
}
