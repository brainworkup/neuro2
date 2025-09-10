#!/usr/bin/env Rscript

# Lightweight profiling harness for neuro2
# - Prefers profvis if available, falls back to Rprof/summaryRprof

quiet_req <- function(pkg) requireNamespace(pkg, quietly = TRUE)

ensure <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, quiet_req, logical(1))]
  if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  # profvis is optional
  if (!quiet_req("profvis")) {
    message("profvis not found; will use base R profiling (Rprof)")
  }
})

message("Starting profiling run at ", Sys.time())

# Minimal workload that exercises mapping and orchestration without heavy IO
workload <- function() {
  # 1) Build a factory and query several configs
  factory <- DomainProcessorFactoryR6$new()
  keys <- c("iq", "academics", "verbal", "spatial", "memory", "executive", "motor",
            "social", "adhd", "emotion", "adaptive", "daily_living", "validity")
  cfgs <- lapply(keys, factory$get_processor_config)

  # 2) Create a report system and map domain names -> configs
  rs <- NeuropsychReportSystemR6$new(
    config = list(
      domains = c(
        "General Cognitive Ability", "Academic Skills", "Verbal/Language",
        "Visual Perception/Construction", "Memory", "Attention/Executive",
        "Motor", "Social Cognition", "ADHD", "Emotional/Behavioral/Personality",
        "Adaptive Functioning", "Daily Living", "Performance Validity"
      ),
      data_files = list(
        neurocog = "data/neurocog.parquet",
        neurobehav = "data/neurobehav.parquet",
        neuropsych = "data/neuropsych.parquet",
        validity = "data/validity.parquet"
      )
    )
  )

  invisible(rs$create_processor_configs(rs$config$domains))

  # 3) Attempt generate_domain_files: should warn/skip missing files fast
  #    We keep warnings on; the point is to exercise orchestration cost.
  try(rs$generate_domain_files(), silent = TRUE)
}

run_profvis <- function() {
  profvis::profvis({ workload() })
}

run_rprof <- function() {
  prof_file <- tempfile("neuro2_profile_", fileext = ".out")
  utils::Rprof(prof_file, interval = 0.005)
  on.exit(utils::Rprof(NULL), add = TRUE)
  workload()
  utils::Rprof(NULL)
  summ <- summaryRprof(prof_file)
  cat("\nTop by total time:\n")
  print(head(summ$by.total, 15))
  cat("\nTop by self time:\n")
  print(head(summ$by.self, 15))
  cat("\nSample interval:", summ$sample.interval, "sec, total samples:", summ$sampling.time / summ$sample.interval, "\n")
}

if (quiet_req("profvis")) {
  message("Using profvis (interactive HTML) — saving to tmp/profvis.html")
  if (!dir.exists("tmp")) dir.create("tmp", recursive = TRUE)
  p <- run_profvis()
  html_file <- file.path("tmp", paste0("profvis_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".html"))
  htmlwidgets::saveWidget(p, html_file, selfcontained = TRUE)
  message("Profile saved: ", html_file)
} else {
  message("Using base R profiling (Rprof)")
  run_rprof()
}

message("Profiling complete at ", Sys.time())

