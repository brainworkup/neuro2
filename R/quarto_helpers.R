# Helper functions for Quarto processing

# Safe readLines function that suppresses incomplete final line warnings
safe_readLines <- function(con, n = -1L, ok = TRUE, warn = FALSE, encoding = "unknown", skipNul = FALSE) {
  # Temporarily suppress warnings about incomplete final lines
  old_warn <- getOption("warn")
  options(warn = -1)
  on.exit(options(warn = old_warn))
  
  # Call the original readLines
  readLines(con = con, n = n, ok = ok, warn = warn, encoding = encoding, skipNul = skipNul)
}

# Override readLines in the global environment during Quarto processing
if (exists("QUARTO_PROJECT_DIR", envir = .GlobalEnv)) {
  assign("readLines", safe_readLines, envir = .GlobalEnv)
}