#!/usr/bin/env Rscript

quiet_req <- function(pkg) requireNamespace(pkg, quietly = TRUE)

ensure <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, quiet_req, logical(1))]
  if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
}

ensure(c("altdoc"))

run_attempts <- list(
  function() altdoc::build_site(),
  function() altdoc::build_docs(),
  function() altdoc::render_site(),
  function() altdoc::altdoc()
)

ok <- FALSE
for (f in run_attempts) {
  ok <- tryCatch({ f(); TRUE }, error = function(e) FALSE)
  if (isTRUE(ok)) break
}

if (!ok) {
  message("altdoc build helpers not found or failed; falling back to rendering Quarto website config if available…")
  if (file.exists("altdoc/quarto_website.yml")) {
    Sys.setenv(ALTDOC_PACKAGE_NAME = "neuro2")
    system("quarto render altdoc/quarto_website.yml", ignore.stdout = FALSE, ignore.stderr = FALSE)
  } else {
    stop("No altdoc build succeeded and altdoc/quarto_website.yml not found.")
  }
}

cat("Docs built to docs/\n")

