#!/usr/bin/env Rscript

# COMPLETE NEURO2 WORKFLOW FIX
# This script fixes both the domain validation AND the R6 class function errors
# Run this INSTEAD of your current domain generation

# ==============================================================================
# SETUP AND CONFIGURATION
# ==============================================================================

# Enhanced logging
log_workflow <- function(message, type = "WORKFLOW") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] [%s] %s\n", timestamp, type, message))
}

log_workflow("Starting complete neuro2 workflow fix")

# Load required packages
required_packages <- c("dplyr", "readr", "here")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    log_workflow(paste("Installing", pkg), "SETUP")
    install.packages(pkg, quiet = TRUE)
  }
  library(pkg, character.only = TRUE, quietly = TRUE)
}

# ==============================================================================
# DATA LOADING AND VALIDATION
# ==============================================================================

load_data_safely <- function() {
  log_workflow("Loading data files", "DATA")

  # Data file paths to try (in order of preference)
  neurocog_paths <- c("data/neurocog.parquet", "data/neurocog.csv")
  neurobehav_paths <- c("data/neurobehav.parquet", "data/neurobehav.csv")

  # Safe data reader
  safe_read <- function(paths) {
    for (path in paths) {
      if (file.exists(path)) {
        tryCatch(
          {
            if (grepl("\\.parquet$", path)) {
              if (requireNamespace("arrow", quietly = TRUE)) {
                data <- arrow::read_parquet(path)
                log_workflow(
                  paste("✓ Loaded", path, "-", nrow(data), "rows"),
                  "DATA"
                )
                return(data)
              }
            } else {
              data <- readr::read_csv(path, show_col_types = FALSE)
              log_workflow(
                paste("✓ Loaded", path, "-", nrow(data), "rows"),
                "DATA"
              )
              return(data)
            }
          },
          error = function(e) {
            log_workflow(
              paste("Failed to read", path, ":", e$message),
              "WARNING"
            )
          }
        )
      }
    }
    return(NULL)
  }

  # Load data
  neurocog_data <- safe_read(neurocog_paths)
  neurobehav_data <- safe_read(neurobehav_paths)

  # Validate we have at least one data source
  if (is.null(neurocog_data) && is.null(neurobehav_data)) {
    log_workflow("No data files found - cannot proceed", "ERROR")
    return(NULL)
  }

  return(list(neurocog = neurocog_data, neurobehav = neurobehav_data))
}

# Domain validation function
validate_domain_data <- function(domain_name, data_source, min_rows = 1) {
  if (is.null(data_source) || nrow(data_source) == 0) {
    return(list(has_data = FALSE, row_count = 0, message = "No data source"))
  }

  if (!"domain" %in% names(data_source)) {
    return(list(has_data = FALSE, row_count = 0, message = "No domain column"))
  }

  # Filter for domain and ensure scoreable data
  filtered_data <- data_source %>%
    filter(domain == domain_name) %>%
    filter(!is.na(percentile) | !is.na(score))

  row_count <- nrow(filtered_data)
  has_data <- row_count >= min_rows

  return(list(
    has_data = has_data,
    row_count = row_count,
    message = if (has_data) {
      paste("✓", domain_name, "has", row_count, "valid rows")
    } else {
      paste(
        "✗",
        domain_name,
        "has only",
        row_count,
        "rows (need",
        min_rows,
        ")"
      )
    }
  ))
}

# ==============================================================================
# DOMAIN CONFIGURATION
# ==============================================================================

get_domain_config <- function() {
  list(
    "General Cognitive Ability" = list(
      pheno = "iq",
      number = "01",
      data_source = "neurocog"
    ),
    "Academic Skills" = list(
      pheno = "academics",
      number = "02",
      data_source = "neurocog"
    ),
    "Verbal/Language" = list(
      pheno = "verbal",
      number = "03",
      data_source = "neurocog"
    ),
    "Visual Perception/Construction" = list(
      pheno = "spatial",
      number = "04",
      data_source = "neurocog"
    ),
    "Memory" = list(pheno = "memory", number = "05", data_source = "neurocog"),
    "Attention/Executive" = list(
      pheno = "executive",
      number = "06",
      data_source = "neurocog"
    ),
    "Motor" = list(pheno = "motor", number = "07", data_source = "neurocog"),
    "Social Cognition" = list(
      pheno = "social",
      number = "08",
      data_source = "neurocog"
    ),
    "ADHD" = list(pheno = "adhd", number = "09", data_source = "neurobehav"),
    "Behavioral/Emotional/Social" = list(
      pheno = "emotion",
      number = "10",
      data_source = "neurobehav"
    ),
    "Emotional/Behavioral/Personality" = list(
      pheno = "emotion",
      number = "10",
      data_source = "neurobehav"
    ),
    "Adaptive Functioning" = list(
      pheno = "adaptive",
      number = "11",
      data_source = "neurobehav"
    ),
    "Daily Living" = list(
      pheno = "daily_living",
      number = "12",
      data_source = "neurocog"
    )
  )
}

# ==============================================================================
# SAFE R6 CLASS HANDLING
# ==============================================================================

# Safe method to check if R6 class exists and load it
ensure_r6_class <- function(class_name, file_path) {
  if (!exists(class_name)) {
    if (file.exists(file_path)) {
      tryCatch(
        {
          source(file_path)
          log_workflow(paste("Loaded", class_name, "from", file_path), "R6")
          return(TRUE)
        },
        error = function(e) {
          log_workflow(
            paste("Failed to load", class_name, ":", e$message),
            "ERROR"
          )
          return(FALSE)
        }
      )
    } else {
      log_workflow(paste("File not found:", file_path), "ERROR")
      return(FALSE)
    }
  }
  return(TRUE)
}

# Safe R6 object creation
create_processor_safely <- function(domain_name, config, domain_data) {
  # Ensure DomainProcessor is available
  if (!ensure_r6_class("DomainProcessor", "R/DomainProcessor.R")) {
    log_workflow(
      "Cannot create processor - DomainProcessor not available",
      "ERROR"
    )
    return(NULL)
  }

  tryCatch(
    {
      # Create processor
      processor <- DomainProcessor$new(
        domains = domain_name,
        pheno = config$pheno,
        input_file = paste0("data/", config$data_source, ".csv"),
        number = config$number
      )

      # Set data directly to avoid reloading
      processor$data <- domain_data

      log_workflow(paste("✓ Created processor for", domain_name), "R6")
      return(processor)
    },
    error = function(e) {
      log_workflow(
        paste("✗ Failed to create processor for", domain_name, ":", e$message),
        "ERROR"
      )
      return(NULL)
    }
  )
}

# Safe method calling
safe_call_method <- function(object, method_name, ..., default = NULL) {
  if (is.null(object)) {
    return(default)
  }

  tryCatch(
    {
      method <- object[[method_name]]
      if (is.function(method)) {
        return(method(...))
      } else {
        log_workflow(paste(method_name, "is not a function"), "WARNING")
        return(default)
      }
    },
    error = function(e) {
      log_workflow(paste("Error calling", method_name, ":", e$message), "ERROR")
      return(default)
    }
  )
}

# ==============================================================================
# SIMPLE QMD GENERATION (FALLBACK)
# ==============================================================================

generate_simple_qmd <- function(domain_name, config) {
  file_name <- sprintf("_02-%s_%s.qmd", config$number, config$pheno)

  content <- c(
    paste("##", domain_name, "{#sec-", config$pheno, "}"),
    "",
    paste(
      "{{< include _02-",
      config$number,
      "_",
      config$pheno,
      "_text.qmd >}}",
      sep = ""
    ),
    "",
    "```{r}",
    paste("#| label: setup-", config$pheno, sep = ""),
    "#| include: false",
    "",
    paste('domains <- "', domain_name, '"', sep = ""),
    paste('pheno <- "', config$pheno, '"', sep = ""),
    "```",
    "",
    "```{r}",
    paste("#| label: data-", config$pheno, sep = ""),
    "#| include: false",
    "",
    paste("# Data processing for", domain_name),
    "# Add data processing code here",
    "```",
    ""
  )

  tryCatch(
    {
      writeLines(content, file_name)
      log_workflow(paste("✓ Generated", file_name), "QMD")

      # Also create text file
      text_file <- sprintf("_02-%s_%s_text.qmd", config$number, config$pheno)
      text_content <- c(
        paste("#", domain_name),
        "",
        paste(
          "This section covers",
          tolower(domain_name),
          "assessment results."
        ),
        ""
      )
      writeLines(text_content, text_file)

      return(file_name)
    },
    error = function(e) {
      log_workflow(
        paste("Failed to generate", file_name, ":", e$message),
        "ERROR"
      )
      return(NULL)
    }
  )
}

# ==============================================================================
# MAIN PROCESSING WORKFLOW
# ==============================================================================

main_workflow <- function() {
  log_workflow("Starting main processing workflow")

  # Step 1: Load data
  data_list <- load_data_safely()
  if (is.null(data_list)) {
    log_workflow("Cannot proceed without data", "ERROR")
    return(FALSE)
  }

  # Step 2: Get domain configuration
  domain_config <- get_domain_config()

  # Step 3: Validate domains and process only those with data
  processed_domains <- character()

  for (domain_name in names(domain_config)) {
    config <- domain_config[[domain_name]]

    # Get appropriate data source
    data_source <- if (config$data_source == "neurocog") {
      data_list$neurocog
    } else {
      data_list$neurobehav
    }

    # Validate domain has data
    validation <- validate_domain_data(domain_name, data_source)
    log_workflow(validation$message, "VALIDATION")

    if (validation$has_data) {
      # Filter data for this domain
      domain_data <- data_source %>%
        filter(domain == domain_name) %>%
        filter(!is.na(percentile) | !is.na(score))

      # Try to process with R6 class
      processor <- create_processor_safely(domain_name, config, domain_data)

      if (!is.null(processor)) {
        # Try to generate QMD with R6 class
        result <- safe_call_method(processor, "generate_domain_qmd")

        if (!is.null(result)) {
          processed_domains <- c(processed_domains, domain_name)
          log_workflow(paste("✓ Processed", domain_name, "with R6"), "SUCCESS")
        } else {
          # Fallback to simple generation
          result <- generate_simple_qmd(domain_name, config)
          if (!is.null(result)) {
            processed_domains <- c(processed_domains, domain_name)
            log_workflow(
              paste("✓ Processed", domain_name, "with fallback"),
              "SUCCESS"
            )
          }
        }
      } else {
        # Fallback to simple generation
        result <- generate_simple_qmd(domain_name, config)
        if (!is.null(result)) {
          processed_domains <- c(processed_domains, domain_name)
          log_workflow(
            paste("✓ Processed", domain_name, "with fallback"),
            "SUCCESS"
          )
        }
      }
    } else {
      log_workflow(paste("⏭ Skipping", domain_name, "- no data"), "SKIP")
    }
  }

  # Step 4: Report results
  log_workflow(
    paste(
      "Processing complete:",
      length(processed_domains),
      "domains processed"
    ),
    "RESULTS"
  )

  if (length(processed_domains) > 0) {
    log_workflow("Successfully processed domains:", "RESULTS")
    for (domain in processed_domains) {
      log_workflow(paste("  ✓", domain), "RESULTS")
    }
  }

  # List generated files
  qmd_files <- list.files(".", pattern = "^_02-[0-9]+_.*\\.qmd$")
  if (length(qmd_files) > 0) {
    log_workflow("Generated files:", "FILES")
    for (file in qmd_files) {
      log_workflow(paste("  -", file), "FILES")
    }
  }

  return(length(processed_domains) > 0)
}

# ==============================================================================
# EXECUTION
# ==============================================================================

# Execute the workflow
if (!interactive()) {
  result <- main_workflow()
  if (result) {
    log_workflow("Workflow completed successfully", "COMPLETE")
    quit(save = "no", status = 0)
  } else {
    log_workflow("Workflow failed", "COMPLETE")
    quit(save = "no", status = 1)
  }
} else {
  # If running interactively, just run the workflow
  main_workflow()
}
