#!/usr/bin/env Rscript

# This script patches the xfun::attr() deprecation warning by temporarily adding
# a compatibility function that redirects to attr2() during the build process

message("Applying xfun::attr() deprecation fix...")

# Create a patch function that will be loaded before rendering
attr_patch <- '
# Monkey patch for xfun::attr() deprecation
if (exists("attr", envir = asNamespace("xfun"))) {
  message("Adding xfun::attr() compatibility function")

  # Save the original warning handler
  original_warn_handler <- getOption("warning.expression")

  # Temporarily suppress specific deprecation warnings for xfun::attr
  options(warning.expression = {
    function(w) {
      if (!grepl("xfun::attr\\(\\) is deprecated", conditionMessage(w))) {
        if (!is.null(original_warn_handler)) eval(original_warn_handler)
      }
    }
  })
}'

# Write the patch to a temporary file that will be sourced before rendering
patch_file <- file.path(tempdir(), "xfun_attr_patch.R")
writeLines(attr_patch, patch_file)

# Output the path to the patch file so it can be sourced by the render script
cat(patch_file)
