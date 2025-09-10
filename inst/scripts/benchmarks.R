#!/usr/bin/env Rscript

# Lightweight micro-benchmarks for hot paths without heavy dependencies
library(neuro2)

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
  "Motor", "Social Cognition", "ADHD", "Emotional/Behavioral/Personality",
  "Adaptive Functioning", "Daily Living", "Performance Validity",
  # edge cases
  "emotional/behavioral/social", "UNKNOWN DOMAIN", "Social  Cognition"
)

# Reuse the private mapping via the system instance
rs <- NeuropsychReportSystemR6$new(config = list(domains = keys_input))

cat("\n== Mapping Benchmarks ==\n")
bench(".get_domain_key() mix", {
  for (nm in keys_input) {
    # Access the private method through the public wrapper via create_processor_configs
    # (this exercises the same path used in orchestration)
    invisible(rs$create_processor_configs(nm))
  }
}, reps = 250L)

# 2) Factory lookups
factory <- DomainProcessorFactoryR6$new()
cat("\n== Factory Benchmarks ==\n")
bench("get_processor_config('verbal')", factory$get_processor_config("verbal"), reps = 5000L)
bench("get_processor_config('adhd')", factory$get_processor_config("adhd"), reps = 5000L)

cat("\nDone.\n")
