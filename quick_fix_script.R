#!/usr/bin/env Rscript
# QUICK FIX SCRIPT FOR IMMEDIATE RELIEF
# Run this to fix the most critical issues

cat("🔧 Running neuro2 Quick Fix Script...\n")

# 1. Create missing text files that are causing render failures
create_missing_text_files <- function() {
  cat("📝 Creating missing text files...\n")

  # Find all domain QMD files
  domain_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$", full.names = TRUE)

  for (file in domain_files) {
    if (!file.exists(file)) next

    # Read file and find include directives
    content <- tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
    includes <- content[grepl("\\{\\{< include.*_text.*\\.qmd >\\}\\}", content)]

    for (include_line in includes) {
      # Extract text file name
      text_file <- gsub(".*include\\s+([^\\s}]+).*", "\\1", include_line)
      text_file <- trimws(text_file)

      if (!file.exists(text_file)) {
        cat(sprintf("  Creating: %s\n", text_file))

        # Extract domain info from filename
        parts <- strsplit(basename(text_file), "_")[[1]]
        domain_name <- if (length(parts) >= 2) parts[2] else "Assessment"
        rater_type <- if (length(parts) >= 4) parts[4] else NULL

        # Create minimal content
        title <- stringr::str_to_title(gsub("\\.qmd$", "", domain_name))
        if (!is.null(rater_type)) {
          title <- paste(title, "-", stringr::str_to_title(gsub("\\.qmd$", "", rater_type)), "Report")
        }

        placeholder_content <- c(
          paste0("# ", title),
          "",
          paste0("*", title, " content will be generated based on available data.*"),
          "",
          "Assessment results and interpretation will appear here when data is available.",
          ""
        )

        # Write the file
        tryCatch({
          writeLines(placeholder_content, text_file)
          cat(sprintf("    ✓ Created %s\n", text_file))
        }, error = function(e) {
          cat(sprintf("    ✗ Failed to create %s: %s\n", text_file, e$message))
        })
      }
    }
  }
}

# 2. Add data validation check to existing workflow
add_data_validation <- function() {
  cat("🔍 Adding data validation...\n")

  # Simple validation function
  validate_domain_simple <- function(domain_name, data_file) {
    if (!file.exists(data_file)) {
      return(list(valid = FALSE, message = paste("Data file not found:", data_file)))
    }

    tryCatch({
      data <- readr::read_csv(data_file, show_col_types = FALSE)

      if (!"domain" %in% names(data)) {
        return(list(valid = FALSE, message = "No domain column found"))
      }

      domain_data <- data %>%
        dplyr::filter(domain == domain_name) %>%
        dplyr::filter(!is.na(percentile) | !is.na(score))

      row_count <- nrow(domain_data)

      return(list(
        valid = row_count > 0,
        row_count = row_count,
        message = if (row_count > 0) {
          paste("Found", row_count, "rows for", domain_name)
        } else {
          paste("No data found for", domain_name)
        }
      ))
    }, error = function(e) {
      return(list(valid = FALSE, message = paste("Error reading data:", e$message)))
    })
  }

  # Test with current data
  cat("  Testing current data availability:\n")

  test_domains <- c(
    "General Cognitive Ability",
    "Academic Skills",
    "Verbal/Language",
    "Visual Perception/Construction",
    "Memory",
    "Attention/Executive",
    "Motor",
    "Social Cognition",
    "ADHD",
    "Behavioral/Emotional/Social"
  )

  neurocog_file <- "data/neurocog.csv"
  neurobehav_file <- "data/neurobehav.csv"

  for (domain in test_domains) {
    data_file <- if (domain %in% c("ADHD", "Behavioral/Emotional/Social")) {
      neurobehav_file
    } else {
      neurocog_file
    }

    validation <- validate_domain_simple(domain, data_file)
    status <- if (validation$valid) "✓" else "✗"
    cat(sprintf("    %s %s: %s\n", status, domain, validation$message))
  }
}

# 3. Fix incomplete QMD files
fix_incomplete_qmd_files <- function() {
  cat("📄 Fixing incomplete QMD files...\n")

  qmd_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$", full.names = TRUE)

  for (file in qmd_files) {
    # Check if file has incomplete final line
    content <- tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))

    if (length(content) > 0) {
      # Ensure file ends with newline
      last_line <- content[length(content)]
      if (nchar(last_line) > 0) {
        content <- c(content, "")
        writeLines(content, file)
        cat(sprintf("  ✓ Fixed incomplete final line in %s\n", basename(file)))
      }
    }
  }
}

# 4. Create a simple validation report
create_validation_report <- function() {
  cat("📊 Creating validation report...\n")

  report_file <- "validation_report.txt"

  report_content <- c(
    "neuro2 Package Validation Report",
    paste("Generated:", Sys.time()),
    "=" %>% rep(50) %>% paste(collapse = ""),
    "",
    "Data Files:",
    sprintf("  neurocog.csv exists: %s", file.exists("data/neurocog.csv")),
    sprintf("  neurobehav.csv exists: %s", file.exists("data/neurobehav.csv")),
    "",
    "Generated Domain Files:",
    paste("  ", list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$")),
    "",
    "Text Files Status:",
    paste("  ", list.files(".", pattern = "_text.*\\.qmd$")),
    "",
    "Recommendations:",
    "1. Only generate files for domains with actual data",
    "2. Implement score type caching to improve performance",
    "3. Add proper validation before file generation",
    "4. Create placeholder text files for missing includes",
    ""
  )

  writeLines(report_content, report_file)
  cat(sprintf("  ✓ Created %s\n", report_file))
}

# Run all fixes
main <- function() {
  cat("Starting quick fixes...\n\n")

  # Load required packages quietly
  suppressPackageStartupMessages({
    library(dplyr)
    library(readr)
    library(stringr)
  })

  # Run fixes
  create_missing_text_files()
  cat("\n")

  add_data_validation()
  cat("\n")

  fix_incomplete_qmd_files()
  cat("\n")

  create_validation_report()
  cat("\n")

  cat("🎉 Quick fixes complete!\n")
  cat("\nNext steps:\n")
  cat("1. Implement the full validation system from the artifacts above\n")
  cat("2. Update TableGTR6 to use score type caching\n")
  cat("3. Test rendering with: quarto render template.qmd\n")
  cat("4. Check validation_report.txt for detailed status\n")
}

# Run the script
if (interactive()) {
  main()
} else {
  main()
}
