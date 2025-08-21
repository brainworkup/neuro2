
.onLoad <- function(libname, pkgname) {
  # Set up conflicted package
  if (requireNamespace("conflicted", quietly = TRUE)) {
    # Register all package functions with the conflicted package
    conflicted::conflict_prefer_all(pkgname, quiet = TRUE)
  }
}
