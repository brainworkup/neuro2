#!/usr/bin/env Rscript

#' QUICK FIX: Domain File Path Issue
#' 
#' This directly fixes the issue where QMD files reference
#' "table_iq.png" instead of "figs/table_iq.png"

cat("\n========================================\n")
cat("QUICK FIX: DOMAIN FILE PATHS\n")
cat("========================================\n\n")

# Function to fix a single QMD file
fix_qmd_file <- function(file_path) {
  if (!file.exists(file_path)) {
    return(FALSE)
  }
  
  content <- readLines(file_path)
  original_content <- content
  fixed <- FALSE
  
  for (i in seq_along(content)) {
    line <- content[i]
    
    # Fix Typst variable declarations
    if (grepl('#let file_qtbl = "', line, fixed = TRUE)) {
      if (!grepl('figs/', line)) {
        content[i] <- gsub(
          '#let file_qtbl = "',
          '#let file_qtbl = "figs/',
          line,
          fixed = TRUE
        )
        fixed <- TRUE
      }
    }
    
    if (grepl('#let file_fig = "', line, fixed = TRUE)) {
      if (!grepl('figs/', line)) {
        content[i] <- gsub(
          '#let file_fig = "',
          '#let file_fig = "figs/',
          line,
          fixed = TRUE
        )
        fixed <- TRUE
      }
    }
    
    # Fix inline file references
    if (grepl('file_qtbl: "', line, fixed = TRUE)) {
      if (!grepl('figs/', line)) {
        content[i] <- gsub(
          'file_qtbl: "',
          'file_qtbl: "figs/',
          line,
          fixed = TRUE
        )
        fixed <- TRUE
      }
    }
    
    if (grepl('file_fig: "', line, fixed = TRUE)) {
      if (!grepl('figs/', line)) {
        content[i] <- gsub(
          'file_fig: "',
          'file_fig: "figs/',
          line,
          fixed = TRUE
        )
        fixed <- TRUE
      }
    }
    
    # Fix hardcoded image paths in R chunks
    if (grepl('gtsave.*"table_', line) || grepl("gtsave.*'table_", line)) {
      if (!grepl('figs', line)) {
        # Add figs to the path
        content[i] <- gsub('"table_', '"figs/table_', line)
        content[i] <- gsub("'table_", "'figs/table_", content[i])
        fixed <- TRUE
      }
    }
    
    if (grepl('ggsave.*"fig_', line) || grepl("ggsave.*'fig_", line)) {
      if (!grepl('figs', line)) {
        content[i] <- gsub('"fig_', '"figs/fig_', line)
        content[i] <- gsub("'fig_", "'figs/fig_", content[i])
        fixed <- TRUE
      }
    }
  }
  
  if (fixed) {
    writeLines(content, file_path)
    return(TRUE)
  }
  
  return(FALSE)
}

# Main fix function
apply_quick_fix <- function() {
  
  # 1. Ensure figs directory exists
  if (!dir.exists("figs")) {
    dir.create("figs", recursive = TRUE)
    cat("✅ Created figs/ directory\n")
  }
  
  # 2. Fix all domain QMD files
  cat("\n🔧 Fixing domain QMD files...\n")
  domain_files <- list.files(pattern = "^_02-.*\\.qmd$", full.names = FALSE)
  
  fixed_count <- 0
  for (file in domain_files) {
    if (fix_qmd_file(file)) {
      cat("  ✅ Fixed:", file, "\n")
      fixed_count <- fixed_count + 1
    }
  }
  
  if (fixed_count > 0) {
    cat("✅ Fixed", fixed_count, "domain files\n")
  } else if (length(domain_files) > 0) {
    cat("ℹ️  Domain files already have correct paths\n")
  } else {
    cat("⚠️  No domain files found\n")
  }
  
  # 3. Fix template.qmd if it has hardcoded paths
  if (file.exists("template.qmd")) {
    if (fix_qmd_file("template.qmd")) {
      cat("✅ Fixed template.qmd\n")
    }
  }
  
  # 4. Move any misplaced images to figs/
  cat("\n🚚 Checking for misplaced images...\n")
  image_patterns <- c("table_.*\\.png", "table_.*\\.pdf", 
                     "fig_.*\\.svg", "fig_.*\\.png", "fig_.*\\.pdf")
  
  moved_count <- 0
  for (pattern in image_patterns) {
    images <- list.files(pattern = paste0("^", pattern, "$"))
    for (img in images) {
      if (!grepl("^figs/", img)) {
        new_path <- file.path("figs", img)
        if (file.rename(img, new_path)) {
          cat("  ✅ Moved", img, "to figs/\n")
          moved_count <- moved_count + 1
        }
      }
    }
  }
  
  if (moved_count > 0) {
    cat("✅ Moved", moved_count, "images to figs/\n")
  } else {
    cat("ℹ️  No misplaced images found\n")
  }
  
  # 5. Create a wrapper to ensure correct generation going forward
  cat("\n📝 Creating generation wrapper...\n")
  
  wrapper_code <- '
# Wrapper to ensure domain files are generated with correct paths
# Source this before running the workflow

# Store original working directory
.original_wd <- getwd()

# Wrapper function for domain generation
generate_domain_with_correct_paths <- function(...) {
  # Ensure figs directory exists
  if (!dir.exists("figs")) {
    dir.create("figs", recursive = TRUE)
  }
  
  # Call the original generation function
  if (exists("generate_domain_files")) {
    result <- generate_domain_files(...)
  } else if (exists("generate_all_domain_assets")) {
    result <- generate_all_domain_assets(...)
  }
  
  # Fix any generated QMD files
  domain_files <- list.files(pattern = "^_02-.*\\\\.qmd$")
  for (file in domain_files) {
    content <- readLines(file)
    
    # Fix file paths
    content <- gsub(\'#let file_qtbl = "table_\', \'#let file_qtbl = "figs/table_\', content, fixed = TRUE)
    content <- gsub(\'#let file_fig = "fig_\', \'#let file_fig = "figs/fig_\', content, fixed = TRUE)
    
    writeLines(content, file)
  }
  
  return(result)
}

# Override the TableGTR6 save method if it exists
if (exists("TableGTR6") && R6::is.R6(TableGTR6)) {
  .original_save <- TableGTR6$public_methods$save_table
  
  TableGTR6$set("public", "save_table", function(table, dir = NULL) {
    # Ensure we save to figs/
    if (is.null(dir)) {
      dir <- "figs"
    } else if (!grepl("figs", dir)) {
      dir <- file.path("figs", dir)
    }
    
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
    }
    
    # Call original method with corrected directory
    if (!is.null(.original_save)) {
      .original_save(table, dir)
    }
  })
}

message("✅ Path correction wrapper loaded")
'
  
  writeLines(wrapper_code, "ensure_correct_paths.R")
  cat("✅ Created ensure_correct_paths.R\n")
  
  cat("\n========================================\n")
  cat("QUICK FIX COMPLETE!\n") 
  cat("========================================\n\n")
  
  cat("✅ File paths have been fixed!\n\n")
  
  cat("Now you can:\n")
  cat("1. Run the workflow again:\n")
  cat("   Rscript complete_neuropsych_workflow.R 'Ethan'\n\n")
  
  cat("2. Or just render directly:\n")
  cat("   quarto render template.qmd --to typst\n\n")
  
  cat("For future runs, source the wrapper first:\n")
  cat("   source('ensure_correct_paths.R')\n")
  cat("   # Then run your workflow\n")
}

# Check if we should also fix DomainProcessorR6.R directly
fix_source_file <- function() {
  cat("\n🔍 Looking for DomainProcessorR6.R to fix at source...\n")
  
  search_paths <- c(
    "R/DomainProcessorR6.R",
    here::here("R", "DomainProcessorR6.R"),
    "inst/R/DomainProcessorR6.R",
    "../R/DomainProcessorR6.R"
  )
  
  for (path in search_paths) {
    if (file.exists(path)) {
      cat("📄 Found:", path, "\n")
      
      # Read the file
      content <- readLines(path)
      
      # Backup
      backup <- paste0(path, ".backup.", format(Sys.time(), "%Y%m%d"))
      file.copy(path, backup)
      cat("💾 Backed up to:", backup, "\n")
      
      # Fix the content
      fixed <- FALSE
      for (i in seq_along(content)) {
        # Fix QMD generation lines
        if (grepl('"#let file_qtbl = \\\\"table_"', content[i])) {
          content[i] <- gsub(
            '"#let file_qtbl = \\\\"table_"',
            '"#let file_qtbl = \\\\"figs/table_"',
            content[i]
          )
          fixed <- TRUE
        }
        
        if (grepl('"#let file_fig = \\\\"fig_"', content[i])) {
          content[i] <- gsub(
            '"#let file_fig = \\\\"fig_"',
            '"#let file_fig = \\\\"figs/fig_"',
            content[i]
          )
          fixed <- TRUE
        }
      }
      
      if (fixed) {
        writeLines(content, path)
        cat("✅ Fixed DomainProcessorR6.R at source!\n")
        cat("   You'll need to reload the package/source the file.\n")
      }
      
      return(TRUE)
    }
  }
  
  cat("ℹ️  Could not find DomainProcessorR6.R to fix at source\n")
  cat("   But the QMD files have been fixed directly.\n")
  return(FALSE)
}

# Execute the fix
cat("This will fix the file path issue where Typst can't find images.\n")
cat("The error 'file not found (searched at .../table_iq.png)' will be resolved.\n\n")

# Apply the quick fix
apply_quick_fix()

# Try to fix the source file too
fix_source_file()

cat("\n✨ Done! Try rendering now:\n")
cat("   quarto render template.qmd --to typst\n")
