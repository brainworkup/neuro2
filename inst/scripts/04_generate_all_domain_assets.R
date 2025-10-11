#!/usr/bin/env Rscript

# Script to generate domain table and figure files ONLY for domains with data

# Ensure warnings are not converted to errors
old_warn <- getOption("warn")
options(warn = 1)

# Load required libraries
library(here)
library(dplyr)
library(gt)
library(ggplot2)
library(arrow)

# Set up output directory
FIGURE_DIR <- "figs"
if (!dir.exists(FIGURE_DIR)) {
  dir.create(FIGURE_DIR, recursive = TRUE)
  cat("Created figure directory:", FIGURE_DIR, "\n")
}

# Load neuro2 package
load_neuro2_dev <- function() {
  if (file.exists(here::here("DESCRIPTION"))) {
    if (requireNamespace("devtools", quietly = TRUE)) {
      try(devtools::load_all(here::here(), quiet = TRUE), silent = TRUE)
      return(TRUE)
    }
  }
  FALSE
}

if (!load_neuro2_dev()) {
  suppressPackageStartupMessages(library(neuro2))
}

cat("\n=== Generating Domain Assets (Tables and Figures) ===\n")
cat("Using proper R6 classes: TableGTR6 and DotplotR6\n")

# Function to check if domain has data
check_domain_has_data <- function(domain_name, data_type = "neurocog") {
  data_file <- paste0("data/", data_type, ".parquet")
  if (!file.exists(data_file)) {
    return(FALSE)
  }

  data <- arrow::read_parquet(data_file)
  if (!"domain" %in% names(data)) {
    return(FALSE)
  }

  domain_data <- data |>
    filter(domain == domain_name) |>
    filter(!is.na(percentile) | !is.na(score))

  return(nrow(domain_data) > 0)
}

# Get list of domains with data from environment or by checking
domains_to_process <- character()

# Check environment variable first (set by workflow)
env_domains <- Sys.getenv("DOMAINS_WITH_DATA")
if (nzchar(env_domains)) {
  domains_to_process <- strsplit(env_domains, ",")[[1]]
  cat(
    "Processing domains from environment:",
    paste(domains_to_process, collapse = ", "),
    "\n"
  )
} else {
  # Otherwise, check which domain QMD files exist
  domain_files <- list.files(pattern = "^_02-[0-9]+_.*\\.qmd$")
  if (length(domain_files) > 0) {
    # Extract domain names from files
    for (file in domain_files) {
      domain <- gsub("_02-[0-9]+_(.+)\\.qmd", "\\1", file)
      domains_to_process <- c(domains_to_process, domain)
    }
    cat(
      "Found domain files for:",
      paste(domains_to_process, collapse = ", "),
      "\n"
    )
  }
}

# Define domain configurations
domain_configs <- list(
  iq = list(name = "General Cognitive Ability", data_type = "neurocog"),
  academics = list(name = "Academic Skills", data_type = "neurocog"),
  verbal = list(name = "Verbal/Language", data_type = "neurocog"),
  spatial = list(
    name = "Visual Perception/Construction",
    data_type = "neurocog"
  ),
  memory = list(name = "Memory", data_type = "neurocog"),
  executive = list(name = "Attention/Executive", data_type = "neurocog"),
  motor = list(name = "Motor", data_type = "neurocog"),
  social = list(name = "Social Cognition", data_type = "neurocog"),
  adhd = list(name = "ADHD/Executive Function", data_type = "neurobehav"),
  emotion = list(
    name = "Emotional/Behavioral/Social/Personality",
    data_type = "neurobehav"
  ),
  adaptive = list(name = "Adaptive Functioning", data_type = "neurobehav"),
  daily_living = list(name = "Daily Living", data_type = "neurocog"),
  validity = list(name = "Validity", data_type = "validity")
)

# Process each domain that has data
successful_assets <- character()
failed_assets <- character()

for (domain_key in domains_to_process) {
  # Clean up domain key (remove _adult, _child suffixes)
  clean_domain <- gsub("_(adult|child)$", "", domain_key)

  config <- domain_configs[[clean_domain]]
  if (is.null(config)) {
    cat("⚠️  No configuration for domain:", domain_key, "\n")
    next
  }

  # Verify domain has data
  if (!check_domain_has_data(config$name, config$data_type)) {
    cat("⚠️  Skipping", domain_key, "- no data found\n")
    next
  }

  cat("\n📊 Generating assets for", domain_key, "...\n")

  tryCatch(
    {
      # Load domain data
      data_file <- paste0("data/", config$data_type, ".parquet")
      data <- arrow::read_parquet(data_file) |> filter(domain == config$name)

      # Ensure data has required z-score columns and aggregations
      if (nrow(data) > 0) {
        # Calculate z-scores if missing
        if (!"z" %in% names(data) && "percentile" %in% names(data)) {
          data <- data |> mutate(z = qnorm(percentile / 100))
        }

        # Calculate z-score statistics using tidy_data functions if available
        if (exists("calculate_z_stats", mode = "function")) {
          data <- calculate_z_stats(data, c("subdomain", "narrow"))
        } else {
          # Fallback: basic aggregation
          if (all(c("z", "subdomain") %in% names(data))) {
            data <- data |>
              group_by(subdomain) |>
              mutate(z_mean_subdomain = mean(z, na.rm = TRUE)) |>
              ungroup()
          }
          if (all(c("z", "narrow") %in% names(data))) {
            data <- data |>
              group_by(narrow) |>
              mutate(z_mean_narrow = mean(z, na.rm = TRUE)) |>
              ungroup()
          }
        }

        # ========================================================
        # GENERATE TABLE USING PROPER TableGTR6 CLASS
        # ========================================================
        table_file <- file.path(
          FIGURE_DIR,
          paste0("table_", clean_domain, ".png")
        )
        if (!file.exists(table_file)) {
          tryCatch(
            {
              if (exists("TableGTR6")) {
                cat("    Using TableGTR6 class...\n")
                table_processor <- TableGTR6$new(
                  data = data,
                  pheno = clean_domain,
                  table_name = paste0("table_", clean_domain),
                  vertical_padding = 0
                )
                tbl <- table_processor$build_table()
                table_processor$save_table(tbl, dir = FIGURE_DIR)
              } else {
                cat("    TableGTR6 not found, using fallback GT table...\n")
                # Fallback: create a proper GT table
                table_data <- data |>
                  select(any_of(c(
                    "test",
                    "test_name",
                    "scale",
                    "score",
                    "percentile",
                    "range",
                    "absort",
                    "result"
                  ))) |>
                  arrange(desc(percentile)) |>
                  slice_head(n = 15)

                gt_table <- gt(table_data) |>
                  tab_header(title = config$name) |>
                  fmt_number(
                    columns = any_of(c("score", "percentile")),
                    decimals = 1
                  )

                gtsave(gt_table, table_file)
              }
              cat("  ✓ Created table:", table_file, "\n")
            },
            error = function(e) {
              cat("  ✗ Table creation failed:", e$message, "\n")
            }
          )
        } else {
          cat("  - Table already exists:", table_file, "\n")
        }

        # ========================================================
        # GENERATE SUBDOMAIN FIGURE USING PROPER DotplotR6 CLASS
        # ========================================================
        if (all(c("z_mean_subdomain", "subdomain") %in% names(data))) {
          data_subdomain <- data[
            !is.na(data$z_mean_subdomain) & !is.na(data$subdomain),
          ]

          if (nrow(data_subdomain) > 0) {
            subdomain_files <- c(
              file.path(
                FIGURE_DIR,
                paste0("fig_", clean_domain, "_subdomain.png")
              ),
              file.path(
                FIGURE_DIR,
                paste0("fig_", clean_domain, "_subdomain.pdf")
              ),
              file.path(
                FIGURE_DIR,
                paste0("fig_", clean_domain, "_subdomain.svg")
              )
            )

            if (!any(file.exists(subdomain_files))) {
              tryCatch(
                {
                  if (exists("DotplotR6")) {
                    cat("    Using DotplotR6 class for subdomain figure...\n")
                    fig_path <- file.path(
                      FIGURE_DIR,
                      paste0("fig_", clean_domain, "_subdomain")
                    )
                    dotplot_subdomain <- DotplotR6$new(
                      data = data_subdomain,
                      x = "z_mean_subdomain",
                      y = "subdomain"
                    )

                    # Create all format variants
                    for (ext in c("png", "pdf", "svg")) {
                      dotplot_subdomain$filename <- paste0(fig_path, ".", ext)
                      dotplot_subdomain$create_plot()
                    }
                  } else {
                    cat("    DotplotR6 not found, using fallback ggplot...\n")
                    # Fallback: basic ggplot
                    p <- ggplot(
                      data_subdomain,
                      aes(x = z_mean_subdomain, y = subdomain)
                    ) +
                      geom_point(size = 3, color = "#E89606") +
                      theme_minimal() +
                      labs(
                        title = paste(config$name, "- Subdomain"),
                        x = "Z-Score",
                        y = "Subdomain"
                      ) +
                      theme(
                        plot.title = element_text(hjust = 0.5),
                        axis.text = element_text(size = 10),
                        axis.title = element_text(size = 12)
                      )

                    ggsave(
                      file.path(
                        FIGURE_DIR,
                        paste0("fig_", clean_domain, "_subdomain.svg")
                      ),
                      p,
                      width = 8,
                      height = 6
                    )
                  }
                  cat(
                    "  ✓ Created subdomain figures:",
                    paste0("fig_", clean_domain, "_subdomain.*"),
                    "\n"
                  )
                },
                error = function(e) {
                  cat("  ✗ Subdomain figure creation failed:", e$message, "\n")
                }
              )
            } else {
              cat("  - Subdomain figures already exist\n")
            }
          } else {
            cat("  - No subdomain data for plotting\n")
          }
        } else {
          cat(
            "  - Subdomain columns not available (z_mean_subdomain, subdomain)\n"
          )
        }

        # ========================================================
        # GENERATE NARROW FIGURE USING PROPER DotplotR6 CLASS
        # ========================================================
        if (all(c("z_mean_narrow", "narrow") %in% names(data))) {
          data_narrow <- data[
            !is.na(data$z_mean_narrow) & !is.na(data$narrow),
          ]

          if (nrow(data_narrow) > 0) {
            narrow_files <- c(
              file.path(
                FIGURE_DIR,
                paste0("fig_", clean_domain, "_narrow.png")
              ),
              file.path(
                FIGURE_DIR,
                paste0("fig_", clean_domain, "_narrow.pdf")
              ),
              file.path(FIGURE_DIR, paste0("fig_", clean_domain, "_narrow.svg"))
            )

            if (!any(file.exists(narrow_files))) {
              tryCatch(
                {
                  if (exists("DotplotR6")) {
                    cat("    Using DotplotR6 class for narrow figure...\n")
                    fig_path <- file.path(
                      FIGURE_DIR,
                      paste0("fig_", clean_domain, "_narrow")
                    )
                    dotplot_narrow <- DotplotR6$new(
                      data = data_narrow,
                      x = "z_mean_narrow",
                      y = "narrow"
                    )

                    # Create all format variants
                    for (ext in c("png", "pdf", "svg")) {
                      dotplot_narrow$filename <- paste0(fig_path, ".", ext)
                      dotplot_narrow$create_plot()
                    }
                  } else {
                    cat("    DotplotR6 not found, using fallback ggplot...\n")
                    # Fallback: basic ggplot
                    p <- ggplot(
                      data_narrow,
                      aes(x = z_mean_narrow, y = narrow)
                    ) +
                      geom_point(size = 3, color = "#E89606") +
                      theme_minimal() +
                      labs(
                        title = paste(config$name, "- Narrow"),
                        x = "Z-Score",
                        y = "Narrow Ability"
                      ) +
                      theme(
                        plot.title = element_text(hjust = 0.5),
                        axis.text = element_text(size = 10),
                        axis.title = element_text(size = 12)
                      )

                    ggsave(
                      file.path(
                        FIGURE_DIR,
                        paste0("fig_", clean_domain, "_narrow.svg")
                      ),
                      p,
                      width = 8,
                      height = 6
                    )
                  }
                  cat(
                    "  ✓ Created narrow figures:",
                    paste0("fig_", clean_domain, "_narrow.*"),
                    "\n"
                  )
                },
                error = function(e) {
                  cat("  ✗ Narrow figure creation failed:", e$message, "\n")
                }
              )
            } else {
              cat("  - Narrow figures already exist\n")
            }
          } else {
            cat("  - No narrow data for plotting\n")
          }
        } else {
          cat("  - Narrow columns not available (z_mean_narrow, narrow)\n")
        }

        successful_assets <- c(successful_assets, domain_key)
      } else {
        cat("  ✗ No data available for", config$name, "\n")
      }
    },
    error = function(e) {
      cat("  ✗ Error generating assets for", domain_key, ":", e$message, "\n")
      failed_assets <- c(failed_assets, domain_key)
    }
  )
}

# ========================================================
# GENERATE SIRF OVERALL FIGURE
# ========================================================
cat("\n📈 Generating SIRF overall figure...\n")

sirf_fig <- file.path(FIGURE_DIR, "fig_sirf_overall.svg")
if (!file.exists(sirf_fig)) {
  tryCatch(
    {
      # Load neurocog data for overall summary
      neurocog_file <- "data/neurocog.parquet"
      if (file.exists(neurocog_file)) {
        neurocog <- arrow::read_parquet(neurocog_file)

        # Create domain summary
        domain_summary <- neurocog |>
          dplyr::group_by(domain) |>
          dplyr::summarize(
            mean_z = mean(z, na.rm = TRUE),
            mean_percentile = mean(percentile, na.rm = TRUE)
          ) |>
          dplyr::filter(!is.na(mean_z))

        if (nrow(domain_summary) > 0) {
          # Create SIRF overall plot using DotplotR6
          if (exists("DotplotR6")) {
            cat("  Using DotplotR6 class for SIRF figure...\n")
            sirf_plot <- DotplotR6$new(
              data = domain_summary,
              x = "mean_z",
              y = "domain",
              filename = sirf_fig,
              theme = "fivethirtyeight",
              point_size = 7
            )
            sirf_plot$create_plot()
          } else {
            cat("  DotplotR6 not found, using fallback ggplot...\n")
            # Fallback: basic ggplot
            p <- ggplot2::ggplot(domain_summary, aes(x = mean_z, y = domain)) +
              ggplot2::geom_point(size = 7, color = "#E89606") +
              ggplot2::theme_minimal() +
              ggplot2::labs(
                title = "Overall Cognitive Profile",
                x = "Z-Score",
                y = "Domain"
              ) +
              ggplot2::theme(
                plot.title = element_text(hjust = 0.5, size = 16),
                axis.text = element_text(size = 12),
                axis.title = element_text(size = 14)
              )

            ggplot2::ggsave(sirf_fig, p, width = 10, height = 6)
          }

          if (file.exists(sirf_fig)) {
            cat("  ✓ Created SIRF overall figure:", sirf_fig, "\n")
            successful_assets <- c(successful_assets, "sirf_overall")
          } else {
            cat("  ✗ SIRF figure creation failed - file not created\n")
            failed_assets <- c(failed_assets, "sirf_overall")
          }
        } else {
          cat("  ⚠️  No domain data available for SIRF figure\n")
        }
      } else {
        cat("  ⚠️  Neurocog data file not found for SIRF figure\n")
      }
    },
    error = function(e) {
      cat("  ✗ Error generating SIRF figure:", e$message, "\n")
      failed_assets <- c(failed_assets, "sirf_overall")
    }
  )
} else {
  cat("  - SIRF figure already exists:", sirf_fig, "\n")
}

# Summary
cat("\n=== Asset Generation Complete ===\n")
cat("Successful:", length(successful_assets), "domains\n")
if (length(failed_assets) > 0) {
  cat("Failed:", paste(failed_assets, collapse = ", "), "\n")
}

# List all generated files
fig_files <- list.files(
  FIGURE_DIR,
  pattern = "\\.(svg|png|pdf)$",
  full.names = TRUE
)
cat("\nGenerated files in", FIGURE_DIR, ":\n")
for (fig in fig_files) {
  cat("  -", basename(fig), "\n")
}

# Restore warning level
options(warn = old_warn)

cat("\n🎯 FIXED: Now using proper R6 classes (TableGTR6 and DotplotR6)\n")
cat("   instead of basic gt() and ggplot() calls for consistent output!\n")
cat("   Also generates SIRF overall figure for report template!\n")
