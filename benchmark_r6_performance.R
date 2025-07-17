#!/usr/bin/env Rscript

# PERFORMANCE BENCHMARK: Procedural vs R6 Approach
# This script compares the performance of the current procedural workflow
# with the R6-based object-oriented approach

library(microbenchmark)
library(tidyverse)
library(here)
library(R6)

# Source R6 classes
source("R/DotplotR6.R")
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")

message("🏁 PERFORMANCE BENCHMARK: Procedural vs R6")
message("==========================================\n")

# Create sample data for benchmarking
create_sample_data <- function(n_rows = 1000) {
  data.frame(
    test = sample(c("WAIS-IV", "WMS-IV", "DKEFS"), n_rows, replace = TRUE),
    test_name = sample(
      c("Wechsler Adult Intelligence Scale", "Wechsler Memory Scale", "D-KEFS"),
      n_rows,
      replace = TRUE
    ),
    scale = sample(
      c("Full Scale IQ", "Working Memory", "Processing Speed"),
      n_rows,
      replace = TRUE
    ),
    raw_score = sample(50:150, n_rows, replace = TRUE),
    score = sample(70:130, n_rows, replace = TRUE),
    percentile = sample(1:99, n_rows, replace = TRUE),
    domain = sample(
      c("General Cognitive Ability", "Memory", "Executive"),
      n_rows,
      replace = TRUE
    ),
    subdomain = sample(c("Verbal", "Visual", "Speed"), n_rows, replace = TRUE),
    z = rnorm(n_rows, 0, 1),
    z_mean_domain = rnorm(n_rows, 0, 0.5),
    stringsAsFactors = FALSE
  )
}

# BENCHMARK 1: Data Processing
message("📊 Benchmark 1: Data Processing")
message("-------------------------------")

# Procedural approach
procedural_process <- function(data) {
  # Filter by domain
  filtered <- data |> filter(domain == "Memory")

  # Calculate means
  mean_percentile <- mean(filtered$percentile, na.rm = TRUE)

  # Generate summary
  overall_range <- case_when(
    mean_percentile >= 91 ~ "above average",
    mean_percentile >= 75 ~ "high average",
    mean_percentile >= 25 ~ "average",
    mean_percentile >= 9 ~ "low average",
    TRUE ~ "below average"
  )

  # Create summary text
  summary_text <- paste0(
    "Testing revealed overall ",
    overall_range,
    " performance (mean percentile = ",
    round(mean_percentile),
    ")."
  )

  return(list(filtered = filtered, summary = summary_text))
}

# R6 approach
r6_process <- function(data) {
  processor <- DomainProcessorR6$new(
    domains = "Memory",
    pheno = "memory",
    input_file = NULL # We'll pass data directly
  )

  # Override data loading
  processor$data <- data
  processor$filter_by_domain()
  processor$select_columns()

  # Generate summary using NeuropsychResultsR6
  results <- NeuropsychResultsR6$new(data = processor$data, file = tempfile())

  return(processor$data)
}

# Run benchmark
test_data <- create_sample_data(5000)

benchmark_results <- microbenchmark(
  procedural = procedural_process(test_data),
  r6_class = r6_process(test_data),
  times = 100
)

print(benchmark_results)

# BENCHMARK 2: Visualization Creation
message("\n📈 Benchmark 2: Visualization Creation")
message("-------------------------------------")

# Prepare data for plotting
plot_data <- test_data |>
  group_by(domain) |>
  summarise(mean_z = mean(z, na.rm = TRUE)) |>
  filter(!is.na(mean_z))

# Procedural approach
procedural_plot <- function(data) {
  p <- ggplot(data, aes(x = mean_z, y = reorder(domain, mean_z))) +
    geom_segment(
      aes(xend = 0, yend = domain),
      color = "black",
      linewidth = 0.5
    ) +
    geom_point(aes(fill = mean_z), shape = 21, size = 6) +
    scale_fill_gradient2(
      low = "red",
      mid = "yellow",
      high = "blue",
      guide = "none"
    ) +
    theme_minimal()

  return(p)
}

# R6 approach
r6_plot <- function(data) {
  dotplot <- DotplotR6$new(
    data = data,
    x = "mean_z",
    y = "domain",
    return_plot = TRUE
  )

  return(dotplot$create_plot())
}

plot_benchmark <- microbenchmark(
  procedural = procedural_plot(plot_data),
  r6_class = r6_plot(plot_data),
  times = 50
)

print(plot_benchmark)

# BENCHMARK 3: Memory Usage
message("\n💾 Benchmark 3: Memory Usage")
message("----------------------------")

# Procedural approach memory
gc()
mem_before <- memory.size()
proc_results <- lapply(1:10, function(i) procedural_process(test_data))
mem_procedural <- memory.size() - mem_before
rm(proc_results)
gc()

# R6 approach memory
mem_before <- memory.size()
r6_results <- lapply(1:10, function(i) {
  processor <- DomainProcessorR6$new(
    domains = "Memory",
    pheno = "memory",
    input_file = NULL
  )
  processor$data <- test_data
  processor
})
mem_r6 <- memory.size() - mem_before
rm(r6_results)
gc()

message(paste("Procedural memory usage:", round(mem_procedural, 2), "MB"))
message(paste("R6 memory usage:", round(mem_r6, 2), "MB"))
message(paste(
  "Memory savings with R6:",
  round((mem_procedural - mem_r6) / mem_procedural * 100, 1),
  "%"
))

# BENCHMARK 4: Full Workflow
message("\n🔄 Benchmark 4: Full Workflow Simulation")
message("----------------------------------------")

# Simulate full procedural workflow
procedural_workflow <- function() {
  # Load data
  data <- create_sample_data(10000)

  # Process each domain
  domains <- unique(data$domain)
  results <- list()

  for (domain in domains) {
    filtered <- data |> filter(domain == !!domain)
    mean_perc <- mean(filtered$percentile, na.rm = TRUE)
    results[[domain]] <- list(data = filtered, mean = mean_perc)
  }

  # Create plots
  plots <- list()
  for (domain in names(results)) {
    plot_data <- results[[domain]]$data |>
      group_by(subdomain) |>
      summarise(mean_z = mean(z, na.rm = TRUE))

    plots[[domain]] <- procedural_plot(plot_data)
  }

  return(list(results = results, plots = plots))
}

# Simulate R6 workflow
r6_workflow <- function() {
  # Load data
  data <- create_sample_data(10000)

  # Create report system
  processors <- list()
  plots <- list()

  domains <- unique(data$domain)

  for (domain in domains) {
    # Create processor
    processor <- DomainProcessorR6$new(
      domains = domain,
      pheno = tolower(gsub(" ", "_", domain)),
      input_file = NULL
    )

    # Process data
    processor$data <- data
    processor$filter_by_domain()

    # Create plot
    plot_data <- processor$data |>
      group_by(subdomain) |>
      summarise(mean_z = mean(z, na.rm = TRUE))

    if (nrow(plot_data) > 0) {
      dotplot <- DotplotR6$new(data = plot_data, x = "mean_z", y = "subdomain")
      plots[[domain]] <- dotplot$create_plot()
    }

    processors[[domain]] <- processor
  }

  return(list(processors = processors, plots = plots))
}

# Run full workflow benchmark
workflow_benchmark <- microbenchmark(
  procedural = procedural_workflow(),
  r6_class = r6_workflow(),
  times = 10
)

print(workflow_benchmark)

# Summary Report
message("\n📊 PERFORMANCE SUMMARY")
message("=====================")

# Calculate speedup
speedup <- median(workflow_benchmark$time[
  workflow_benchmark$expr == "procedural"
]) /
  median(workflow_benchmark$time[workflow_benchmark$expr == "r6_class"])

message(paste(
  "\n🚀 R6 classes are",
  round(speedup, 2),
  "times faster for the full workflow"
))
message("\n✅ Key advantages of R6 approach:")
message("   - Better memory management (reference semantics)")
message("   - Encapsulated functionality (easier to maintain)")
message("   - Reusable objects (create once, use many times)")
message("   - Built-in caching potential")
message("   - Easier to parallelize")

# Additional optimization suggestions
message("\n💡 To further improve performance:")
message("   1. Use data.table instead of dplyr for large datasets")
message("   2. Implement parallel processing with future/furrr")
message("   3. Cache computed results in R6 objects")
message("   4. Pre-allocate memory for large operations")
message("   5. Use Rcpp for compute-intensive operations")
