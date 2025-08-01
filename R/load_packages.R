
#' Load all required packages for neuropsych reports
#'
#' This function loads the minimal set of packages needed for
#' report generation. Most data processing is handled by R6 classes.
#'
#' @param verbose Whether to print loading messages
#' @return Invisible NULL
#' @export
load_neuropsych_packages <- function(verbose = TRUE) {
  # Minimal packages needed for templates
  required_packages <- c(
    "knitr",     # For knitr options
    "here",      # For path management
    "readr",     # For reading CSV if needed
    "dplyr",     # For data manipulation
    "gt",        # For tables
    "neuro2"     # For R6 classes and report generation
  )
  
  # Load packages
  for (pkg in required_packages) {
    if (verbose) message("Loading ", pkg, "...")
    library(pkg, character.only = TRUE)
  }
  
  if (verbose) message("All packages loaded successfully!")
  invisible(NULL)
}

