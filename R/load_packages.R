
#' Load all required packages for neuropsych reports
#'
#' This function checks that the minimal set of packages needed for
#' report generation are available. Most data processing is handled by R6 classes.
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
    "webshot2"   # For saving tables as images
  )
  
  # Check packages are available
  for (pkg in required_packages) {
    if (verbose) message("Checking ", pkg, "...")
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Package '", pkg, "' is required but not installed. Please install it with install.packages('", pkg, "')")
    }
  }
  
  if (verbose) message("All required packages are available!")
  invisible(NULL)
}
