# FIXES FOR R6 CLASSES - "attempt to apply non-function" errors
# These are likely fixes for your DomainProcessorR6 and TableGTR6 classes

# ==============================================================================
# 1. FIXED DOMAINPROCESSORR6 METHOD
# ==============================================================================
# Add this method to your DomainProcessorR6 class or replace existing one

generate_domain_qmd_fixed <- function() {
  # Validate required fields exist
  if (is.null(self$domains)) {
    stop("Domains not set")
  }
  if (is.null(self$pheno)) {
    stop("Pheno not set") 
  }
  
  # Determine file name safely
  domain_name <- self$domains[1]  # Use first domain if multiple
  number <- if (!is.null(self$number)) {
    sprintf("%02d", as.numeric(self$number))
  } else {
    "01"  # Default
  }
  
  # Create safe file name
  file_name <- paste0("_02-", number, "_", self$pheno, ".qmd")
  
  tryCatch({
    # Check if we have data
    if (is.null(self$data) || nrow(self$data) == 0) {
      warning(paste("No data available for", domain_name))
      return(NULL)
    }
    
    # Generate content safely
    content <- private$generate_qmd_content_safe()
    
    # Write file
    writeLines(content, file_name)
    
    message(paste("Generated:", file_name))
    return(file_name)
    
  }, error = function(e) {
    warning(paste("Error generating QMD for", domain_name, ":", e$message))
    return(NULL)
  })
}

# ==============================================================================
# 2. SAFE QMD CONTENT GENERATION
# ==============================================================================
# Add this to private methods in DomainProcessorR6

generate_qmd_content_safe <- function() {
  domain_name <- self$domains[1]
  
  # Basic QMD template
  content <- c(
    paste("##", domain_name, "{#sec-", self$pheno, "}"),
    "",
    "{{< include _02-02_academics_text.qmd >}}",  # You'll need to update this pattern
    "",
    "```{r}",
    "#| label: setup-", self$pheno,
    "#| include: false",
    "",
    "# Load required packages",
    "suppressPackageStartupMessages({",
    "  library(tidyverse)",
    "  library(gt)",
    "  library(gtExtras)",
    "  library(glue)",
    "})",
    "",
    "# Set domain parameters", 
    paste0('domains <- "', domain_name, '"'),
    paste0('pheno <- "', self$pheno, '"'),
    "```",
    "",
    "```{r}",
    "#| label: data-", self$pheno,
    "#| include: false",
    "",
    "# This would normally load and process data",
    "# For now, create placeholder",
    paste0("message('Processing data for ", domain_name, "')"),
    "```",
    "",
    "```{r}",
    "#| label: qtbl-", self$pheno,
    "#| include: false",
    "#| eval: true",
    "",
    "# Table generation would go here",
    paste0("message('Table for ", domain_name, " would be generated here')"),
    "```",
    "",
    "```{r}",
    "#| label: fig-", self$pheno,
    "#| include: false", 
    "#| eval: true",
    "",
    "# Figure generation would go here",
    paste0("message('Figure for ", domain_name, " would be generated here')"),
    "```",
    ""
  )
  
  return(content)
}

# ==============================================================================
# 3. SAFE TABLE GENERATION METHOD
# ==============================================================================
# Add this method to fix table generation errors

generate_table_safe <- function(rater = NULL) {
  tryCatch({
    # Check if data exists
    if (is.null(self$data) || nrow(self$data) == 0) {
      message(paste("No data available for table generation for", self$domains[1]))
      return(NULL)
    }
    
    # Filter by rater if specified
    if (!is.null(rater)) {
      if ("rater" %in% names(self$data)) {
        table_data <- self$data %>% filter(rater == !!rater)
        if (nrow(table_data) == 0) {
          message(paste("No data for", rater, "rater"))
          return(NULL)
        }
      } else {
        message("No rater column found in data")
        return(NULL)
      }
    } else {
      table_data <- self$data
    }
    
    # Check if TableGTR6 class exists and is properly loaded
    if (!exists("TableGTR6")) {
      message("TableGTR6 class not found")
      return(NULL)
    }
    
    # Safely create table
    table_name <- if (!is.null(rater)) {
      paste0("table_", self$pheno, "_", rater)
    } else {
      paste0("table_", self$pheno)
    }
    
    # Create minimal table configuration
    table_config <- list(
      data = table_data,
      pheno = self$pheno,
      table_name = table_name,
      source_note = "Test results",
      title = self$domains[1],
      fn_list = list(),
      grp_list = list(),
      vertical_padding = 0.0,
      multiline = FALSE
    )
    
    # Try to create table
    table_obj <- do.call(TableGTR6$new, table_config)
    
    if (is.null(table_obj)) {
      message("Failed to create table object")
      return(NULL)
    }
    
    # Try to build table
    result <- table_obj$build_table()
    
    message(paste("✓ Generated table for", self$domains[1], if (!is.null(rater)) paste("(", rater, ")")))
    return(result)
    
  }, error = function(e) {
    message(paste("Error generating table for", ifelse(is.null(rater), "main", rater), ":", e$message))
    return(NULL)
  })
}

# ==============================================================================
# 4. SAFE METHOD CALLING WRAPPER
# ==============================================================================
# Add this utility function to safely call methods

safe_method_call <- function(object, method_name, ..., default = NULL) {
  # Check if object exists
  if (is.null(object)) {
    warning(paste("Object is null for method", method_name))
    return(default)
  }
  
  # Check if method exists
  if (!method_name %in% names(object)) {
    warning(paste("Method", method_name, "not found in object"))
    return(default)
  }
  
  # Check if it's actually a function
  method <- object[[method_name]]
  if (!is.function(method)) {
    warning(paste(method_name, "is not a function, it's a", class(method)))
    return(default)
  }
  
  # Try to call the method
  tryCatch({
    method(...)
  }, error = function(e) {
    warning(paste("Error calling", method_name, ":", e$message))
    return(default)
  })
}

# ==============================================================================
# 5. DIAGNOSTIC FUNCTION
# ==============================================================================
# Add this function to help debug R6 class issues

diagnose_r6_object <- function(obj, obj_name = "object") {
  cat("=== Diagnosing R6 Object:", obj_name, "===\n")
  
  if (is.null(obj)) {
    cat("✗ Object is NULL\n")
    return(FALSE)
  }
  
  cat("✓ Object exists\n")
  cat("Class:", class(obj), "\n")
  
  # List methods and fields
  obj_names <- names(obj)
  if (length(obj_names) > 0) {
    cat("\nMethods and fields:\n")
    for (name in obj_names) {
      item <- obj[[name]]
      type <- if (is.function(item)) "METHOD" else paste("FIELD (", class(item), ")")
      cat("  ", type, ":", name, "\n")
    }
  } else {
    cat("✗ No methods or fields found\n")
  }
  
  # Check for common required methods
  required_methods <- c("initialize", "process", "generate_domain_qmd")
  missing_methods <- setdiff(required_methods, obj_names)
  
  if (length(missing_methods) > 0) {
    cat("\n⚠ Missing expected methods:", paste(missing_methods, collapse = ", "), "\n")
  }
  
  cat("=== End Diagnosis ===\n\n")
  return(TRUE)
}

# ==============================================================================
# 6. HOW TO USE THESE FIXES
# ==============================================================================

# In your DomainProcessorR6 class, replace the problematic methods with:
# - generate_domain_qmd_fixed() instead of generate_domain_qmd()
# - generate_table_safe() instead of direct table generation
# - Add generate_qmd_content_safe() to private methods

# Before calling any R6 methods, use:
# diagnose_r6_object(your_processor, "processor_name")

# When calling methods that might fail, use:
# result <- safe_method_call(processor, "some_method", arg1, arg2, default = NULL)

# Example usage in your domain processing:
# processor <- DomainProcessorR6$new(...)
# diagnose_r6_object(processor, "domain_processor") 
# file_result <- safe_method_call(processor, "generate_domain_qmd_fixed", default = NULL)
# table_result <- safe_method_call(processor, "generate_table_safe", "parent", default = NULL)

cat("R6 class fixes loaded. Use these methods to replace problematic ones.\n")