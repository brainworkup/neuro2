#!/usr/bin/env Rscript

# Lightweight micro-benchmarks for hot paths without heavy dependencies
# Try to load neuro2; fall back to sourcing R/ files if running in-source
if (!requireNamespace("neuro2", quietly = TRUE)) {
  message("neuro2 not installed; sourcing package files from R/ …")
  r_files <- Sys.glob(file.path("R", "*.R"))
  invisible(lapply(r_files, source))
} else {
  suppressPackageStartupMessages(library(neuro2))
}

bench <- function(label, expr, reps = 1000L) {
  gc()
  t <- system.time(for (i in seq_len(reps)) { force(expr) })
  cat(sprintf("%-30s  %7d reps  user=%.3f  sys=%.3f  elapsed=%.3f\n",
              label, reps, t[["user.self"]], t[["sys.self"]], t[["elapsed"]]))
  invisible(t)
}

# 1) Domain key mapping
keys_input <- c(
  "General Cognitive Ability", "Academic Skills", "Verbal/Language",
  "Visual Perception/Construction", "Memory", "Attention/Executive",
  "Motor", "Social Cognition", "ADHD/Executive Function", "Emotional/Behavioral/Social/Personality",
  "Adaptive Functioning", "Daily Living", "Validity",
  # edge cases
  "emotional/behavioral/social", "UNKNOWN DOMAIN", "Social  Cognition"
)

# Resolve domain key mapping without instantiating the full report system
resolve_domain_key <- function(x) {
  # Prefer internal helper if available in current environment
  if (exists(".get_domain_key", mode = "function")) {
    return(.get_domain_key(x))
  }
  # Fall back to accessing the internal helper in the package namespace
  if ("neuro2" %in% loadedNamespaces()) {
    f <- try(get(".get_domain_key", envir = asNamespace("neuro2")), silent = TRUE)
    if (!inherits(f, "try-error") && is.function(f)) return(f(x))
  }
  # Minimal local fallback (covers common domains only)
  m <- c(
    "General Cognitive Ability" = "iq",
    "Academic Skills" = "academics",
    "Verbal/Language" = "verbal",
    "Visual Perception/Construction" = "spatial",
    "Memory" = "memory",
    "Attention/Executive" = "executive",
    "Motor" = "motor",
    "Social Cognition" = "social",
    "ADHD/Executive Function" = "adhd",
    "Emotional/Behavioral/Social/Personality" = "emotion",
    "Adaptive Functioning" = "adaptive",
    "Daily Living" = "daily_living",
    "Validity" = "validity"
  )
  m[[x]] %||% tolower(gsub("[^A-Za-z0-9]", "_", x))
}

cat("\n== Mapping Benchmarks ==\n")
bench("domain name -> key (mix)", {
  for (nm in keys_input) {
    invisible(resolve_domain_key(nm))
  }
}, reps = 1000L)

# 2) Factory lookups
factory <- DomainProcessorFactoryR6$new()
cat("\n== Factory Benchmarks ==\n")
bench("get_processor_config('verbal')", factory$get_processor_config("verbal"), reps = 5000L)
bench("get_processor_config('adhd')", factory$get_processor_config("adhd"), reps = 5000L)

cat("\nDone.\n")
