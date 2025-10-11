#' Fix QMD Chunk Options to Prevent Raw Data Rendering
#' 
#' This file provides functions to generate QMD chunks with proper options
#' to prevent raw data from appearing in the rendered output while still
#' allowing the LLM to use it as input.
#' 
#' @description The key is to use chunks that generate data for LLM input
#' but DON'T render their output in the final document.

#' Generate text processing chunk (for LLM input only, no output)
#' @param pheno Phenotype name
#' @param generate_for_llm If TRUE, generates output for LLM; if FALSE, assumes summary exists
#' @return Character string of R chunk code
generate_text_chunk <- function(pheno, generate_for_llm = TRUE) {
  if (generate_for_llm) {
    # This runs ONCE to generate data for LLM, but output is hidden
    paste0(
      "```{r}\n",
      "#| label: text-", pheno, "\n",
      "#| cache: true\n",
      "#| include: false\n",
      "#| output: false\n\n",  # <-- KEY: This suppresses output display
      
      "# Generate formatted text for LLM input only\n",
      "# This output will NOT appear in the rendered document\n",
      "if (nrow(", pheno, "_data) > 0) {\n",
      "  results_processor <- NeuropsychResultsR6$new(\n",
      "    data = ", pheno, "_data,\n",
      "    file = \"_text_", pheno, ".qmd\"\n",
      "  )\n",
      "  results_processor$process()\n",
      "}\n",
      "```\n\n"
    )
  } else {
    # After LLM has generated summary, this chunk doesn't need to run
    paste0(
      "```{r}\n",
      "#| label: text-", pheno, "\n",
      "#| eval: false\n\n",  # <-- KEY: Don't execute this chunk
      
      "# This chunk only runs to generate input for LLM\n",
      "# After summary is generated, it's disabled\n",
      "```\n\n"
    )
  }
}

#' Generate summary include block
#' @param text_file Name of the text file to include
#' @return Character string of QMD include directive
generate_summary_include <- function(text_file) {
  paste0(
    "{{< include ", text_file, " >}}\n\n"
  )
}

#' Generate complete domain QMD with proper chunk options
#' @param domain_name Display name of domain
#' @param pheno Short phenotype name
#' @param number Domain number (e.g., "01", "02")
#' @param has_llm_summary Whether LLM summary already exists
#' @return Complete QMD content as character string
generate_domain_qmd_fixed <- function(
  domain_name,
  pheno,
  number,
  has_llm_summary = FALSE
) {
  
  text_file <- paste0("_", number, "-", number, "_", pheno, "_text.qmd")
  
  qmd_content <- paste0(
    "## ", domain_name, " {#sec-", pheno, "}\n\n",
    
    # Include the LLM-generated summary (this is what should appear)
    generate_summary_include(text_file), 
    
    # Setup chunk (always runs, never displays)
    "```{r}\n",
    "#| label: setup-", pheno, "\n",
    "#| include: false\n\n",
    
    "library(neuro2)\n",
    "library(tidyverse)\n\n",
    
    "domains <- \"", domain_name, "\"\n",
    "```\n\n",
    
    # Data loading chunk (always runs, never displays)
    "```{r}\n",
    "#| label: data-", pheno, "\n", 
    "#| include: false\n\n",
    
    "processor <- DomainProcessorR6$new(\n",
    "  domains = domains,\n",
    "  pheno = \"", pheno, "\",\n",
    "  input_file = \"data/neurocog.parquet\"\n",
    ")\n",
    "processor$load_data()\n",
    "processor$filter_by_domain()\n",
    "processor$select_columns()\n",
    pheno, "_data <- processor$data\n",
    "```\n\n",
    
    # Text generation chunk (CRITICAL: proper options to hide output)
    generate_text_chunk(pheno, generate_for_llm = !has_llm_summary),
    
    # Table chunk (runs but doesn't display)
    "```{r}\n",
    "#| label: tbl-", pheno, "\n",
    "#| include: false\n\n",
    
    "if (nrow(", pheno, "_data) > 0) {\n",
    "  table_", pheno, " <- TableGTR6$new(\n",
    "    data = ", pheno, "_data,\n",
    "    pheno = \"", pheno, "\",\n",
    "    table_name = \"table_", pheno, "\"\n",
    "  )\n",
    "  tbl <- table_", pheno, "$build_table()\n",
    "  table_", pheno, "$save_table(tbl)\n",
    "}\n",
    "```\n\n",
    
    # Figure chunk (runs but doesn't display)
    "```{r}\n",
    "#| label: fig-", pheno, "\n",
    "#| include: false\n\n",
    
    "if (nrow(", pheno, "_data) > 0) {\n",
    "  fig_", pheno, " <- DotplotR6$new(\n",
    "    data = ", pheno, "_data,\n",
    "    x = \"z_mean_subdomain\",\n",
    "    y = \"subdomain\"\n",
    "  )\n",
    "  fig_", pheno, "$create_plot()\n",
    "}\n",
    "```\n\n",
    
    # Typst block for layout
    "```{=typst}\n",
    "#let title = \"", domain_name, "\"\n",
    "#let file_tbl = \"table_", pheno, ".png\"\n",
    "#let file_fig = \"fig_", pheno, ".svg\"\n",
    "#domain(title: [#title], file_tbl, file_fig)\n",
    "```\n"
  )
  
  return(qmd_content)
}

#' Update existing QMD file to fix chunk options
#' @param qmd_path Path to existing QMD file
#' @return Logical indicating success
fix_existing_qmd_chunks <- function(qmd_path) {
  if (!file.exists(qmd_path)) {
    warning("File not found: ", qmd_path)
    return(FALSE)
  }
  
  # Read existing content
  content <- readLines(qmd_path, warn = FALSE)
  
  # Find text generation chunks and fix them
  fixed_content <- character()
  in_text_chunk <- FALSE
  chunk_lines <- character()
  
  for (i in seq_along(content)) {
    line <- content[i]
    
    # Detect start of text generation chunk
    if (grepl("^```\\{r\\}\\s*$", line) && 
        i + 1 <= length(content) && 
        grepl("#\\|\\s*label:\\s*text-", content[i + 1])) {
      in_text_chunk <- TRUE
      chunk_lines <- line
      next
    }
    
    # Collect chunk lines
    if (in_text_chunk) {
      chunk_lines <- c(chunk_lines, line)
      
      # Check if chunk ends
      if (grepl("^```\\s*$", line)) {
        # Fix the chunk options
        fixed_chunk <- fix_text_chunk_options(chunk_lines)
        fixed_content <- c(fixed_content, fixed_chunk)
        in_text_chunk <- FALSE
        chunk_lines <- character()
        next
      }
    } else {
      fixed_content <- c(fixed_content, line)
    }
  }
  
  # Write fixed content
  writeLines(fixed_content, qmd_path)
  message("Fixed chunk options in: ", qmd_path)
  return(TRUE)
}

#' Fix chunk options for text generation chunks
#' @param chunk_lines Character vector of chunk lines
#' @return Fixed chunk lines
fix_text_chunk_options <- function(chunk_lines) {
  # Remove problematic options and add correct ones
  fixed <- character()
  
  for (line in chunk_lines) {
    # Skip results: asis (this is the culprit)
    if (grepl("#\\|\\s*results:\\s*asis", line)) {
      next
    }
    
    # If this is the label line, add our fixed options after it
    if (grepl("#\\|\\s*label:", line)) {
      fixed <- c(
        fixed,
        line,
        "#| cache: true",
        "#| include: false", 
        "#| output: false  # Suppress output display"
      )
    } else if (!grepl("#\\|\\s*(cache|include):", line)) {
      # Keep other lines that aren't cache/include (we already added those)
      fixed <- c(fixed, line)
    }
  }
  
  return(fixed)
}

#' Batch fix all QMD files in a directory
#' @param dir Directory containing QMD files
#' @param pattern Pattern to match QMD files (default: domain files)
#' @return Named logical vector of success/failure for each file
batch_fix_qmd_files <- function(
  dir = ".",
  pattern = "^_\\d{2}-\\d{2}_.*\\.qmd$"
) {
  qmd_files <- list.files(
    dir,
    pattern = pattern,
    full.names = TRUE
  )
  
  if (length(qmd_files) == 0) {
    message("No QMD files found matching pattern: ", pattern)
    return(logical(0))
  }
  
  message("Found ", length(qmd_files), " QMD files to fix")
  
  results <- sapply(qmd_files, function(f) {
    tryCatch({
      fix_existing_qmd_chunks(f)
    }, error = function(e) {
      warning("Error fixing ", f, ": ", e$message)
      FALSE
    })
  })
  
  # Summary
  n_success <- sum(results)
  message("\nFixed ", n_success, "/", length(results), " files successfully")
  
  return(results)
}

#' Quick fix for common chunk option mistakes
#' @description Replace common problematic patterns in QMD files
#' @param qmd_path Path to QMD file
#' @return Logical indicating if changes were made
quick_fix_chunk_options <- function(qmd_path) {
  if (!file.exists(qmd_path)) return(FALSE)
  
  content <- readLines(qmd_path, warn = FALSE)
  original <- content
  
  # Pattern 1: Remove results: asis from text chunks
  content <- gsub(
    "^(#\\|\\s*results:\\s*asis)\\s*$",
    "# REMOVED: results: asis (causes output to render)",
    content,
    perl = TRUE
  )
  
  # Pattern 2: Add output: false to text chunks if missing
  in_text_chunk <- FALSE
  has_output_false <- FALSE
  fixed_content <- character()
  
  for (i in seq_along(content)) {
    line <- content[i]
    
    if (grepl("#\\|\\s*label:\\s*text-", line)) {
      in_text_chunk <- TRUE
      has_output_false <- FALSE
      fixed_content <- c(fixed_content, line)
    } else if (in_text_chunk && grepl("#\\|\\s*output:\\s*false", line)) {
      has_output_false <- TRUE
      fixed_content <- c(fixed_content, line)
    } else if (in_text_chunk && grepl("^[^#]", line) && !has_output_false) {
      # First non-comment line after chunk header - insert output: false
      fixed_content <- c(
        fixed_content,
        "#| output: false  # Prevent raw data from rendering",
        line
      )
      in_text_chunk <- FALSE
    } else {
      fixed_content <- c(fixed_content, line)
      if (grepl("^```\\s*$", line)) {
        in_text_chunk <- FALSE
      }
    }
  }
  
  # Only write if changes were made
  if (!identical(original, fixed_content)) {
    writeLines(fixed_content, qmd_path)
    message("Applied quick fixes to: ", qmd_path)
    return(TRUE)
  }
  
  return(FALSE)
}

# Example usage and testing functions

#' Test the fix on a single domain
#' @examples
#' \dontrun{
#' # Fix a single file
#' fix_existing_qmd_chunks("_02-01_iq.qmd")
#' 
#' # Or use quick fix
#' quick_fix_chunk_options("_02-01_iq.qmd")
#' 
#' # Fix all domain files
#' batch_fix_qmd_files()
#' 
#' # Generate a new domain file with correct options
#' qmd_content <- generate_domain_qmd_fixed(
#'   domain_name = "Academic Skills",
#'   pheno = "academics", 
#'   number = "02",
#'   has_llm_summary = FALSE
#' )
#' writeLines(qmd_content, "_02-02_academics.qmd")
#' }
test_chunk_fix <- function() {
  # Create a test QMD with problematic chunks
  test_content <- c(
    "## Test Domain",
    "",
    "```{r}",
    "#| label: text-test",
    "#| cache: true",
    "#| include: false",
    "#| results: asis",  # <-- Problem
    "",
    "cat('This would render!')",
    "```"
  )
  
  test_file <- tempfile(fileext = ".qmd")
  writeLines(test_content, test_file)
  
  # Apply fix
  quick_fix_chunk_options(test_file)
  
  # Check result
  fixed <- readLines(test_file)
  
  # Should have removed results: asis and added output: false
  has_results_asis <- any(grepl("results:\\s*asis", fixed))
  has_output_false <- any(grepl("output:\\s*false", fixed))
  
  message("Test results:")
  message("  Removed 'results: asis': ", !has_results_asis)
  message("  Added 'output: false': ", has_output_false)
  
  if (!has_results_asis && has_output_false) {
    message("\n✓ Fix working correctly!")
  } else {
    message("\n✗ Fix may need adjustment")
  }
  
  # Clean up
  unlink(test_file)
  
  invisible(list(
    removed_results_asis = !has_results_asis,
    added_output_false = has_output_false
  ))
}
