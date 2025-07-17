#!/usr/bin/env Rscript

# PARALLEL R6 WORKFLOW FOR MAXIMUM SPEED
# This script demonstrates how to use parallel processing with R6 classes

library(tidyverse)
library(R6)
library(future)
library(furrr)
library(tictoc)

# Source R6 classes
source("R/DotplotR6.R")
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")

# Set up parallel processing
# Use all available cores minus 1
plan(multisession, workers = availableCores() - 1)

message("⚡ PARALLEL R6 WORKFLOW FOR MAXIMUM SPEED")
message("=========================================\n")
message(paste("Using", availableCores() - 1, "parallel workers"))

# Function to process a single domain in parallel
process_domain_parallel <- function(domain, input_file = "data/neurocog.csv") {
  # Each worker needs to load R6 classes
  source("R/DomainProcessorR6.R")
  source("R/NeuropsychResultsR6.R")

  # Create processor
  processor <- DomainProcessorR6$new(
    domains = domain,
    pheno = gsub(" ", "_", tolower(domain)),
    input_file = input_file
  )

  # Process the domain
  processor$process(
    generate_reports = TRUE,
    report_types = c("self"),
    generate_domain_files = TRUE
  )

  return(list(domain = domain, data = processor$data, status = "completed"))
}

# Main parallel workflow
run_parallel_workflow <- function() {
  tic("Total workflow time")

  # Define domains to process
  domains <- c(
    "General Cognitive Ability",
    "Academic Skills",
    "Verbal/Language",
    "Visual Perception/Construction",
    "Memory",
    "Attention/Executive",
    "Motor",
    "Social Cognition",
    "ADHD",
    "Psychiatric Disorders"
  )

  message("\n📊 Processing domains in parallel...")
  tic("Domain processing")

  # Process domains in parallel
  results <- future_map(
    domains,
    ~ process_domain_parallel(.x),
    .progress = TRUE,
    .options = furrr_options(seed = TRUE)
  )

  toc()

  # Parallel visualization creation
  message("\n📈 Creating visualizations in parallel...")
  tic("Visualization creation")

  # Function to create visualization for each domain
  create_domain_viz <- function(domain_result) {
    if (is.null(domain_result$data) || nrow(domain_result$data) == 0) {
      return(NULL)
    }

    # Aggregate data
    plot_data <- domain_result$data |>
      group_by(subdomain) |>
      summarise(mean_z = mean(z, na.rm = TRUE)) |>
      filter(!is.na(mean_z) & !is.na(subdomain))

    if (nrow(plot_data) == 0) {
      return(NULL)
    }

    # Source DotplotR6 in each worker
    source("R/DotplotR6.R")

    # Create dotplot
    dotplot <- DotplotR6$new(
      data = plot_data,
      x = "mean_z",
      y = "subdomain",
      filename = paste0(
        "output/parallel_",
        domain_result$domain,
        "_subdomain.svg"
      )
    )

    return(dotplot$create_plot())
  }

  # Create visualizations in parallel
  plots <- future_map(results, ~ create_domain_viz(.x), .progress = TRUE)

  toc()

  # Create overall summary plot
  message("\n📊 Creating overall summary visualization...")
  tic("Summary visualization")

  # Combine all domain data
  all_data <- bind_rows(lapply(results, function(x) x$data))

  # Create domain summary
  domain_summary <- all_data |>
    group_by(domain) |>
    summarise(
      mean_z = mean(z, na.rm = TRUE),
      mean_percentile = mean(percentile, na.rm = TRUE)
    ) |>
    filter(!is.na(mean_z))

  # Create summary plot
  summary_plot <- DotplotR6$new(
    data = domain_summary,
    x = "mean_z",
    y = "domain",
    filename = "output/parallel_overall_summary.svg",
    theme = "fivethirtyeight",
    point_size = 8
  )

  summary_plot$create_plot()
  toc()

  # Parallel report generation
  message("\n📄 Generating reports in parallel...")
  tic("Report generation")

  # Function to generate text report for a domain
  generate_domain_report <- function(domain_result) {
    if (is.null(domain_result$data) || nrow(domain_result$data) == 0) {
      return(NULL)
    }

    # Source NeuropsychResultsR6 in each worker
    source("R/NeuropsychResultsR6.R")

    # Create results processor
    results_processor <- NeuropsychResultsR6$new(
      data = domain_result$data,
      file = paste0(
        "output/parallel_",
        gsub(" ", "_", tolower(domain_result$domain)),
        "_report.txt"
      )
    )

    results_processor$process()

    return(paste0("Report generated for ", domain_result$domain))
  }

  # Generate reports in parallel
  reports <- future_map(results, ~ generate_domain_report(.x), .progress = TRUE)

  toc()

  toc() # Total workflow time

  # Summary
  message("\n✅ Parallel workflow completed!")
  message(paste("Processed", length(domains), "domains"))
  message(paste("Generated", sum(!sapply(plots, is.null)), "visualizations"))
  message(paste("Created", sum(!sapply(reports, is.null)), "reports"))

  return(list(results = results, plots = plots, reports = reports))
}

# Comparison function: Sequential vs Parallel
compare_sequential_vs_parallel <- function() {
  message("\n🏁 COMPARING SEQUENTIAL VS PARALLEL PROCESSING")
  message("==============================================\n")

  # Test data
  domains <- c(
    "General Cognitive Ability",
    "Memory",
    "Attention/Executive",
    "Verbal/Language"
  )

  # Sequential processing
  message("🐌 Running sequential workflow...")
  tic("Sequential")

  sequential_results <- list()
  for (domain in domains) {
    processor <- DomainProcessorR6$new(
      domains = domain,
      pheno = gsub(" ", "_", tolower(domain)),
      input_file = "data/neurocog.csv"
    )
    processor$process()
    sequential_results[[domain]] <- processor
  }

  sequential_time <- toc()

  # Parallel processing
  message("\n⚡ Running parallel workflow...")
  tic("Parallel")

  parallel_results <- future_map(
    domains,
    ~ process_domain_parallel(.x),
    .progress = FALSE
  )

  parallel_time <- toc()

  # Calculate speedup
  sequential_ms <- as.numeric(sequential_time$toc - sequential_time$tic) * 1000
  parallel_ms <- as.numeric(parallel_time$toc - parallel_time$tic) * 1000
  speedup <- sequential_ms / parallel_ms

  message("\n📊 RESULTS:")
  message(paste("Sequential time:", round(sequential_ms, 2), "ms"))
  message(paste("Parallel time:", round(parallel_ms, 2), "ms"))
  message(paste("🚀 Speedup:", round(speedup, 2), "x faster"))
  message(paste(
    "Efficiency:",
    round(speedup / (availableCores() - 1) * 100, 1),
    "%"
  ))
}

# Advanced parallel patterns
advanced_parallel_patterns <- function() {
  message("\n🎯 ADVANCED PARALLEL PATTERNS WITH R6")
  message("=====================================\n")

  # Pattern 1: Chunked parallel processing
  message("📦 Pattern 1: Chunked Processing")

  # Create large dataset
  large_data <- expand_grid(
    domain = rep(c("Memory", "Executive", "Verbal"), 10),
    test = 1:1000
  ) |>
    mutate(
      score = rnorm(n(), 100, 15),
      percentile = pnorm(score, 100, 15) * 100
    )

  # Process in chunks
  chunk_size <- 5000
  chunks <- split(large_data, ceiling(seq_len(nrow(large_data)) / chunk_size))

  tic("Chunked processing")
  chunk_results <- future_map(
    chunks,
    function(chunk) {
      # Process chunk
      summary(chunk$score)
    },
    .progress = TRUE
  )
  toc()

  # Pattern 2: Nested parallelization
  message("\n🔄 Pattern 2: Nested Parallelization")

  # Outer parallel loop for domains
  nested_results <- future_map(unique(large_data$domain), function(domain) {
    domain_data <- filter(large_data, domain == !!domain)

    # Inner parallel loop for computations
    plan(sequential) # Switch to sequential for inner loop

    sub_results <- map(
      split(domain_data, cut(seq_len(nrow(domain_data)), 10)),
      ~ mean(.x$score)
    )

    plan(multisession) # Switch back

    return(list(domain = domain, results = sub_results))
  })

  # Pattern 3: Async report generation
  message("\n📄 Pattern 3: Asynchronous Report Generation")

  # Create promise-based workflow
  generate_async_report <- function(domain_data) {
    future({
      # Simulate heavy processing
      Sys.sleep(runif(1, 0.1, 0.5))

      # Generate report
      list(
        domain = unique(domain_data$domain),
        summary = summary(domain_data$score),
        timestamp = Sys.time()
      )
    })
  }

  # Launch async tasks
  async_futures <- map(
    split(large_data, large_data$domain),
    generate_async_report
  )

  # Collect results as they complete
  async_results <- value(async_futures)

  message("✅ Advanced patterns demonstrated")
}

# Main execution
if (interactive()) {
  # Run the main parallel workflow
  results <- run_parallel_workflow()

  # Compare sequential vs parallel
  compare_sequential_vs_parallel()

  # Demonstrate advanced patterns
  advanced_parallel_patterns()

  # Clean up
  plan(sequential)

  message("\n🎉 All parallel demonstrations complete!")
  message("💡 Remember to always clean up with plan(sequential)")
}
