#!/usr/bin/env Rscript

# Lightweight profiling harness for neuro2
# - Prefers profvis if available, falls back to Rprof/summaryRprof

quiet_req <- function(pkg) requireNamespace(pkg, quietly = TRUE)

ensure <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, quiet_req, logical(1))]
  if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
}

# Try to load neuro2; if not installed (running in-source), source R/ files
if (!requireNamespace("neuro2", quietly = TRUE)) {
  message("neuro2 not installed; sourcing package files from R/ …")
  r_files <- Sys.glob(file.path("R", "*.R"))
  invisible(lapply(r_files, source))
} else {
  suppressPackageStartupMessages(library(neuro2))
}

suppressPackageStartupMessages({
  # profvis is optional; htmlwidgets needed to save HTML
  if (!quiet_req("profvis")) {
    message("profvis not found; will use base R profiling (Rprof)")
  } else if (!quiet_req("htmlwidgets")) {
    message("htmlwidgets not found; profvis HTML save will be skipped")
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
        "Motor", "Social Cognition", "ADHD/Executive Function", "Emotional/Behavioral/Social/Personality",
        "Adaptive Functioning", "Daily Living", "Validity"
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

  # 3) Optionally attempt generate_domain_files (off by default)
  # Enable by setting env var NEURO2_PROFILE_GENERATE=true
  run_gen <- isTRUE(as.logical(Sys.getenv("NEURO2_PROFILE_GENERATE", "FALSE")))
  if (run_gen) {
    try(rs$generate_domain_files(), silent = TRUE)
  }
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
  message("Using profvis (interactive HTML) — attempting to save under tmp/")
  if (!dir.exists("tmp")) dir.create("tmp", recursive = TRUE)
  ok <- FALSE
  err <- NULL
  p <- NULL
  tryCatch({ p <- run_profvis(); ok <- TRUE }, error = function(e) err <<- e)
  if (ok && quiet_req("htmlwidgets")) {
    html_file <- file.path("tmp", paste0("profvis_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".html"))
    save_ok <- FALSE
    tryCatch({ htmlwidgets::saveWidget(p, html_file, selfcontained = TRUE); save_ok <- TRUE }, error = function(e) err <<- e)
    if (save_ok) {
      message("Profile saved: ", html_file)
    } else {
      message("profvis run ok, but failed to save HTML (", err$message, ") — falling back to Rprof summary")
      run_rprof()
    }
  } else if (!ok) {
    message("profvis failed (", err$message, ") — falling back to Rprof summary")
    run_rprof()
  } else {
    message("profvis ran, but htmlwidgets missing — falling back to Rprof summary")
    run_rprof()
  }
} else {
  message("Using base R profiling (Rprof)")
  run_rprof()
}

message("Profiling complete at ", Sys.time())
