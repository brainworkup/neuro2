#!/usr/bin/env Rscript

# UNIFIED NEUROPSYCHOLOGICAL WORKFLOW RUNNER
# Main controller script for the neuropsychological report generation workflow
# This script orchestrates the entire workflow by calling each module in sequence

# Set up logging
log_file <- "workflow.log"
cat("NEURO2 UNIFIED WORKFLOW LOG\n", file = log_file)
cat(paste("Date:", Sys.time(), "\n\n"), file = log_file, append = TRUE)

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message, "\n")
  cat(log_entry, file = log_file, append = TRUE)
  cat(log_entry)
}

# Function to print colored messages in the console
print_colored <- function(message, color = "blue") {
  colors <- list(
    red = "\033[0;31m",
    green = "\033[0;32m",
    yellow = "\033[1;33m",
    blue = "\033[0;34m",
    reset = "\033[0m"
  )

  cat(paste0(colors[[color]], message, colors$reset, "\n"))
}

# Print header
print_colored(
  "🧠 NEUROPSYCHOLOGICAL REPORT GENERATION - UNIFIED WORKFLOW",
  "blue"
)
print_colored(
  "===========================================================",
  "blue"
)
print_colored("")

# Check for essential template files before starting
print_colored("Checking for essential template files...", "blue")
essential_files <- c(
  "template.qmd",
  "_quarto.yml",
  "_variables.yml",
  "config.yml"
)
missing_files <- character()

for (file in essential_files) {
  if (!file.exists(file)) {
    # Check if it exists in the template directory
    template_dir <- "inst/quarto/templates/typst-report"
    if (file.exists(file.path(template_dir, file))) {
      print_colored(
        paste0(
          "⚠️ Essential template file not found in working directory: ",
          file
        ),
        "yellow"
      )
      print_colored(
        paste0(
          "  This file exists in ",
          template_dir,
          " and will be copied during setup."
        ),
        "yellow"
      )
    } else {
      print_colored(
        paste0("⚠️ Essential template file not found: ", file),
        "red"
      )
      print_colored(
        paste0(
          "  This file is required and should be created before running the workflow."
        ),
        "red"
      )
      missing_files <- c(missing_files, file)
    }
  }
}

if (length(missing_files) > 0) {
  print_colored(
    "Some essential template files are missing. Would you like to copy them from the template directory? (y/n)",
    "yellow"
  )
  answer <- readline(prompt = "")

  if (tolower(answer) == "y") {
    template_dir <- "inst/quarto/templates/typst-report"
    for (file in missing_files) {
      source_file <- file.path(template_dir, file)
      if (file.exists(source_file)) {
        file.copy(source_file, file)
        print_colored(
          paste0("✓ Copied ", file, " from template directory"),
          "green"
        )
      } else {
        print_colored(
          paste0("⚠️ Could not find ", file, " in template directory"),
          "red"
        )
      }
    }
  }
}

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Default configuration file
config_file <- "config.yml"

# Check if config file is provided as argument
if (length(args) > 0) {
  if (args[1] == "--config" && length(args) > 1) {
    config_file <- args[2]
  } else {
    config_file <- args[1]
  }
}

# Load required packages
required_packages <- c("yaml", "R6", "dplyr", "readr", "here", "quarto")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    log_message(paste("Installing package:", pkg), "SETUP")
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE, quietly = TRUE)
}

# Load configuration
log_message(paste0("Loading configuration from: ", config_file), "CONFIG")

if (!file.exists(config_file)) {
  # Check if config.yml exists in template directory before creating default
  template_dir <- "inst/quarto/templates/typst-report"
  template_config_file <- file.path(template_dir, "config.yml")

  if (file.exists(template_config_file)) {
    log_message(
      "Configuration file not found. Copying from template directory.",
      "CONFIG"
    )
    file.copy(template_config_file, config_file)
    log_message(
      paste0("Copied template configuration file: ", config_file),
      "CONFIG"
    )
  } else {
    # Create default configuration if template doesn't exist
    log_message(
      "Configuration file not found. Creating default configuration.",
      "CONFIG"
    )

    default_config <- list(
      patient = list(
        name = "Biggie",
        age = 35,
        doe = format(Sys.Date(), "%Y-%m-%d")
      ),
      data = list(
        input_dir = "data-raw/csv",
        output_dir = "data",
        format = "all"
      ),
      processing = list(use_duckdb = TRUE, parallel = TRUE),
      report = list(
        template = "template.qmd",
        format = "neurotyp-adult-typst",
        output_dir = "output"
      )
    )

    yaml::write_yaml(default_config, config_file)
    log_message(
      paste0("Created default configuration file: ", config_file),
      "CONFIG"
    )
  }
}

config <- yaml::read_yaml(config_file)

# Display configuration
log_message("Configuration loaded successfully", "CONFIG")
log_message(paste0("Patient: ", config$patient$name), "CONFIG")
log_message(paste0("Age: ", config$patient$age), "CONFIG")
log_message(paste0("DOE: ", config$patient$doe), "CONFIG")

# Create the main workflow class
WorkflowRunner <- R6::R6Class(
  "WorkflowRunner",

  public = list(
    # Properties
    config = NULL,
    patient_name = NULL,

    # Constructor
    initialize = function(config) {
      self$config <- config
      self$patient_name <- config$patient$name
      log_message(paste0(
        "Initialized WorkflowRunner for patient: ",
        self$patient_name
      ))
    },

    # Step 1: Setup environment
    setup_environment = function() {
      log_message("Step 1: Setting up environment...", "WORKFLOW")

      # Source the setup_environment.R script
      if (file.exists("setup_environment.R")) {
        log_message("Running setup_environment.R", "SETUP")
        source("setup_environment.R")
      } else {
        log_message(
          "setup_environment.R not found. Creating directories manually.",
          "SETUP"
        )

        # Create necessary directories
        for (dir in c(
          self$config$data$input_dir,
          self$config$data$output_dir,
          self$config$report$output_dir
        )) {
          if (!dir.exists(dir)) {
            dir.create(dir, recursive = TRUE, showWarnings = FALSE)
            log_message(paste0("Created directory: ", dir), "SETUP")
          }
        }
      }

      # Copy template files from inst/quarto/templates/typst-report/ to working directory
      log_message("Copying template files to working directory...", "SETUP")

      # First try using system.file (for installed package)
      template_dir <- system.file(
        "quarto/templates/typst-report",
        package = "neuro2"
      )

      # If running from development environment, use local path
      if (template_dir == "") {
        template_dir <- "inst/quarto/templates/typst-report"
        log_message(
          paste0("Using development template directory: ", template_dir),
          "SETUP"
        )
      }

      # Check if template directory exists
      if (!dir.exists(template_dir)) {
        log_message(
          paste0("Template directory not found: ", template_dir),
          "ERROR"
        )
        # Try alternative locations
        alt_dirs <- c(
          "inst/quarto/templates/typst-report",
          "../inst/quarto/templates/typst-report",
          "../../inst/quarto/templates/typst-report"
        )

        for (alt_dir in alt_dirs) {
          if (dir.exists(alt_dir)) {
            template_dir <- alt_dir
            log_message(
              paste0("Found alternative template directory: ", template_dir),
              "SETUP"
            )
            break
          }
        }

        if (!dir.exists(template_dir)) {
          log_message(
            "Could not find template directory in any location",
            "ERROR"
          )
          return(FALSE)
        }
      }

      # List files in the template directory
      log_message(
        paste0("Listing files in template directory: ", template_dir),
        "SETUP"
      )
      dir_contents <- list.files(template_dir)
      log_message(
        paste0("Directory contents: ", paste(dir_contents, collapse = ", ")),
        "SETUP"
      )

      # Get list of template files
      template_files <- list.files(
        template_dir,
        pattern = "\\.(qmd|yml)$",
        full.names = TRUE
      )

      if (length(template_files) == 0) {
        log_message(
          paste0("No template files found in: ", template_dir),
          "ERROR"
        )
        return(FALSE)
      }

      log_message(
        paste0("Found ", length(template_files), " template files"),
        "SETUP"
      )

      # Copy each file to working directory if it doesn't already exist
      for (file in template_files) {
        dest_file <- basename(file)
        log_message(
          paste0("Processing template file: ", file, " -> ", dest_file),
          "SETUP"
        )

        if (!file.exists(dest_file)) {
          # Check if source file exists
          if (!file.exists(file)) {
            log_message(paste0("Source file does not exist: ", file), "ERROR")
            next
          }

          # Try to copy the file
          copy_result <- file.copy(file, dest_file)

          if (copy_result) {
            log_message(paste0("Copied template file: ", dest_file), "SETUP")
          } else {
            log_message(
              paste0("Failed to copy template file: ", dest_file),
              "ERROR"
            )
          }
        } else {
          log_message(
            paste0("Template file already exists: ", dest_file),
            "SETUP"
          )
        }
      }

      # Verify essential files exist after copying
      essential_files <- c(
        "template.qmd",
        "_quarto.yml",
        "_variables.yml",
        "config.yml"
      )
      missing_files <- character()

      for (file in essential_files) {
        if (!file.exists(file)) {
          missing_files <- c(missing_files, file)
        }
      }

      if (length(missing_files) > 0) {
        log_message(
          paste0(
            "Essential files still missing after copy: ",
            paste(missing_files, collapse = ", ")
          ),
          "ERROR"
        )

        # Last resort: try direct copy for each missing file
        for (file in missing_files) {
          source_file <- file.path(template_dir, file)
          if (file.exists(source_file)) {
            file.copy(source_file, file, overwrite = TRUE)
            log_message(paste0("Direct copy attempt for: ", file), "SETUP")
          }
        }
      }

      # Setup Quarto extensions
      log_message("Setting up Quarto extensions...", "SETUP")

      # First try using system.file (for installed package)
      extensions_dir <- system.file("quarto/_extensions", package = "neuro2")

      # If running from development environment, use local path
      if (extensions_dir == "") {
        extensions_dir <- "inst/quarto/_extensions"
        log_message(
          paste0("Using development extensions directory: ", extensions_dir),
          "SETUP"
        )
      }

      # Check if extensions directory exists
      if (!dir.exists(extensions_dir)) {
        log_message(
          paste0("Extensions directory not found: ", extensions_dir),
          "ERROR"
        )
        # Try alternative locations
        alt_dirs <- c(
          "inst/quarto/_extensions",
          "../inst/quarto/_extensions",
          "../../inst/quarto/_extensions"
        )

        for (alt_dir in alt_dirs) {
          if (dir.exists(alt_dir)) {
            extensions_dir <- alt_dir
            log_message(
              paste0(
                "Found alternative extensions directory: ",
                extensions_dir
              ),
              "SETUP"
            )
            break
          }
        }

        if (!dir.exists(extensions_dir)) {
          log_message(
            "Could not find extensions directory in any location",
            "ERROR"
          )
          # Continue anyway, as this might not be fatal
        }
      }

      if (dir.exists(extensions_dir)) {
        # Create _extensions directory in working directory if it doesn't exist
        if (!dir.exists("_extensions")) {
          dir.create("_extensions", recursive = TRUE, showWarnings = FALSE)
          log_message("Created _extensions directory", "SETUP")
        }

        # Copy brainworkup directory with all extensions
        brainworkup_dir <- file.path(extensions_dir, "brainworkup")
        if (dir.exists(brainworkup_dir)) {
          # Create brainworkup directory in _extensions if it doesn't exist
          if (!dir.exists("_extensions/brainworkup")) {
            dir.create(
              "_extensions/brainworkup",
              recursive = TRUE,
              showWarnings = FALSE
            )
            log_message("Created _extensions/brainworkup directory", "SETUP")
          }

          # List all extension directories
          extension_dirs <- list.dirs(
            brainworkup_dir,
            full.names = FALSE,
            recursive = FALSE
          )
          log_message(
            paste0(
              "Found extensions: ",
              paste(extension_dirs, collapse = ", ")
            ),
            "SETUP"
          )

          # Copy each extension directory
          for (ext_dir in extension_dirs) {
            src_dir <- file.path(brainworkup_dir, ext_dir)
            dest_dir <- file.path("_extensions/brainworkup", ext_dir)

            # Check if extension directory already exists
            if (!dir.exists(dest_dir)) {
              # Create the directory
              dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

              # Copy all files from the extension directory
              ext_files <- list.files(src_dir, full.names = TRUE)
              for (file in ext_files) {
                file.copy(file, dest_dir, recursive = TRUE)
              }
              log_message(paste0("Copied extension: ", ext_dir), "SETUP")
            } else {
              log_message(
                paste0("Extension already exists: ", ext_dir),
                "SETUP"
              )
            }
          }

          # Verify that the required extension exists
          required_extension <- gsub("-typst$", "", self$config$report$format)
          if (
            !dir.exists(file.path(
              "_extensions/brainworkup",
              required_extension
            ))
          ) {
            log_message(
              paste0("Required extension not found: ", required_extension),
              "WARNING"
            )
          } else {
            log_message(
              paste0("Required extension found: ", required_extension),
              "SETUP"
            )
          }
        } else {
          log_message(
            paste0(
              "Brainworkup extensions directory not found: ",
              brainworkup_dir
            ),
            "WARNING"
          )
        }
      }

      # Check for R6 class files
      r6_files <- c(
        "R/ReportTemplateR6.R",
        "R/NeuropsychResultsR6.R",
        "R/NeuropsychReportSystemR6.R",
        "R/DomainProcessorR6.R",
        "R/DotplotR6.R",
        "R/DuckDBProcessorR6.R"
      )

      missing_files <- r6_files[!file.exists(r6_files)]
      if (length(missing_files) > 0) {
        log_message("Some R6 class files are missing:", "WARNING")
        for (file in missing_files) {
          log_message(paste0("  - ", file), "WARNING")
        }
      } else {
        log_message("All required R6 class files are present", "SETUP")
      }

      # Check for CSV files
      csv_files <- list.files(self$config$data$input_dir, pattern = "\\.csv$")
      if (length(csv_files) == 0) {
        log_message(
          paste0("No CSV files found in ", self$config$data$input_dir),
          "WARNING"
        )
      } else {
        log_message(
          paste0(
            "Found ",
            length(csv_files),
            " CSV files in ",
            self$config$data$input_dir
          ),
          "SETUP"
        )
      }

      log_message("Environment setup complete", "SETUP")
      return(TRUE)
    },

    # Step 2: Process data
    process_data = function() {
      log_message("Step 2: Processing data...", "WORKFLOW")

      # Source the data processor module
      if (file.exists("data_processor_module.R")) {
        log_message("Running data_processor_module.R", "DATA")
        source("data_processor_module.R")
      } else {
        log_message(
          "data_processor_module.R not found. Using fallback processing.",
          "DATA"
        )

        # Fallback to using existing scripts
        if (
          self$config$processing$use_duckdb &&
            file.exists("R/duckdb_neuropsych_loader.R")
        ) {
          log_message("Using DuckDB data processor", "DATA")
          source("R/duckdb_neuropsych_loader.R")

          # Process the data
          load_data_duckdb(
            file_path = self$config$data$input_dir,
            output_dir = self$config$data$output_dir,
            output_format = self$config$data$format
          )
        } else if (file.exists("neuro2_duckdb_workflow.R")) {
          log_message("Using neuro2_duckdb_workflow.R", "DATA")
          source("neuro2_duckdb_workflow.R")
        } else {
          log_message("No suitable data processor found", "ERROR")
          return(FALSE)
        }
      }

      log_message("Data processing complete", "DATA")
      return(TRUE)
    },

    # Step 3: Generate domain files
    generate_domains = function() {
      log_message("Step 3: Generating domain files...", "WORKFLOW")

      # Check for required R6 classes
      log_message(
        "Checking for required R6 classes for domain processing...",
        "DOMAINS"
      )

      r6_domain_files <- c("R/NeuropsychResultsR6.R", "R/DomainProcessorR6.R")

      missing_r6_files <- r6_domain_files[!file.exists(r6_domain_files)]
      if (length(missing_r6_files) > 0) {
        log_message("Some required R6 class files are missing:", "WARNING")
        for (file in missing_r6_files) {
          log_message(paste0("  - ", file), "WARNING")
        }
        log_message("Will use fallback domain generation method", "WARNING")
      } else {
        log_message(
          "All required R6 class files for domain processing are present",
          "DOMAINS"
        )

        # Check if neurocog data exists
        neurocog_exists <- file.exists(file.path(
          self$config$data$output_dir,
          "neurocog.csv"
        )) ||
          file.exists(file.path(
            self$config$data$output_dir,
            "neurocog.parquet"
          )) ||
          file.exists(file.path(
            self$config$data$output_dir,
            "neurocog.feather"
          ))

        if (!neurocog_exists) {
          log_message("No neurocog data files found", "DOMAINS")
        } else {
          # Load the R6 classes
          source("R/NeuropsychResultsR6.R")
          source("R/DomainProcessorR6.R")

          # Get all unique domains from the neurocog data
          tryCatch(
            {
              log_message(
                "Using DomainProcessorR6 to generate domain files",
                "DOMAINS"
              )

              # Get the list of domains from the data
              domains_data <- query_neuropsych(
                "SELECT DISTINCT domain FROM neurocog WHERE domain IS NOT NULL",
                self$config$data$output_dir
              )

              log_message(
                paste0("Found ", nrow(domains_data), " unique domains"),
                "DOMAINS"
              )

              # Process each domain
              for (i in 1:nrow(domains_data)) {
                domain <- domains_data$domain[i]

                # Create a domain processor for this domain
                # Use the configured format (default is Parquet for better performance)
                input_format <- self$config$data$format
                if (is.null(input_format) || input_format == "all") {
                  # If format is "all", check which format exists
                  if (
                    file.exists(file.path(
                      self$config$data$output_dir,
                      "neurocog.parquet"
                    ))
                  ) {
                    input_format <- "parquet"
                  } else if (
                    file.exists(file.path(
                      self$config$data$output_dir,
                      "neurocog.csv"
                    ))
                  ) {
                    input_format <- "csv"
                  } else if (
                    file.exists(file.path(
                      self$config$data$output_dir,
                      "neurocog.feather"
                    ))
                  ) {
                    input_format <- "feather"
                  } else {
                    input_format <- "parquet" # fallback
                  }
                }

                input_file <- file.path(
                  self$config$data$output_dir,
                  paste0("neurocog.", input_format)
                )

                # Function to determine patient type (adult or child) based on age
                determine_patient_type <- function() {
                  # Get patient age from config
                  age <- self$config$patient$age

                  # Default to child if age is not specified
                  if (is.null(age)) {
                    return("child")
                  }

                  # Determine type based on age
                  if (age >= 18) {
                    return("adult")
                  } else {
                    return("child")
                  }
                }

                # Get patient type
                patient_type <- determine_patient_type()
                log_message(
                  paste("Determined patient type:", patient_type),
                  "DOMAINS"
                )

                # Map domain names to the correct pheno values
                domain_to_pheno <- function(domain_name) {
                  mapping <- list(
                    "General Cognitive Ability" = "iq",
                    "Academic Skills" = "academics",
                    "Verbal/Language" = "verbal",
                    "Visual Perception/Construction" = "spatial",
                    "Memory" = "memory",
                    "Attention/Executive" = "executive",
                    "Motor" = "motor",
                    "ADHD" = "adhd",
                    "Behavioral/Emotional/Social" = "emotion"
                  )

                  # Check if the domain should be combined into emotion.parquet
                  emotion_domains <- c(
                    "Substance Use",
                    "Psychosocial Problems",
                    "Psychiatric Disorders",
                    "Personality Disorders"
                  )

                  if (domain_name %in% emotion_domains) {
                    return("emotion")
                  }

                  # Return the mapped pheno value or a default based on the domain name
                  pheno_value <- mapping[[domain_name]]
                  if (is.null(pheno_value)) {
                    # Check if this is a behavioral domain that should map to emotion
                    if (
                      grepl(
                        "Behav|Emot|Psych|Social|Substance|Personality",
                        domain_name
                      )
                    ) {
                      return("emotion")
                    }

                    # Default to a safe version of the domain name
                    pheno_value <- tolower(gsub(
                      "[^a-zA-Z0-9]",
                      "_",
                      domain_name
                    ))
                  }

                  return(pheno_value)
                }

                # Function to get the appropriate output file name based on domain and patient type
                get_output_file <- function(domain_name) {
                  # Basic domain file mapping
                  domain_files <- list(
                    "General Cognitive Ability" = "_02-01_iq.qmd",
                    "Academic Skills" = "_02-02_academics.qmd",
                    "Verbal/Language" = "_02-03_verbal.qmd",
                    "Visual Perception/Construction" = "_02-04_spatial.qmd",
                    "Memory" = "_02-05_memory.qmd",
                    "Attention/Executive" = "_02-06_executive.qmd",
                    "Motor" = "_02-07_motor.qmd",
                    "Social Cognition" = "_02-08_social.qmd"
                  )

                  # Special handling for ADHD domain
                  if (domain_name == "ADHD") {
                    if (patient_type == "adult") {
                      return("_02-09_adhd_adult.qmd")
                    } else {
                      return("_02-09_adhd_child.qmd")
                    }
                  }

                  # Special handling for emotion domains
                  emotion_domains <- c(
                    "Behavioral/Emotional/Social",
                    "Substance Use",
                    "Psychosocial Problems",
                    "Psychiatric Disorders",
                    "Personality Disorders"
                  )

                  if (domain_name %in% emotion_domains) {
                    if (patient_type == "adult") {
                      return("_02-10_emotion_adult.qmd")
                    } else {
                      return("_02-10_emotion_child.qmd")
                    }
                  }

                  # Return the mapped file name or create a default one
                  file_name <- domain_files[[domain_name]]
                  if (is.null(file_name)) {
                    # Create a safe file name from the domain
                    safe_name <- tolower(gsub("[^a-zA-Z0-9]", "_", domain_name))
                    file_name <- paste0("_02-", safe_name, ".qmd")
                  }

                  return(file_name)
                }

                domain_processor <- DomainProcessorR6$new(
                  domains = domain,
                  pheno = domain_to_pheno(domain),
                  input_file = input_file,
                  output_dir = self$config$data$output_dir
                )

                # Process the domain and generate files
                tryCatch(
                  {
                    # Get the appropriate output file name for this domain
                    output_file <- get_output_file(domain)

                    # Process the domain with the appropriate output file
                    # First set the output file name
                    output_file_name <- output_file
                    # Then process the domain (without passing output_file parameter)
                    domain_processor$process(
                      generate_reports = TRUE,
                      report_types = c("self"),
                      generate_domain_files = TRUE
                    )
                    # If needed, rename the generated file to match the expected output file
                    generated_file <- paste0(
                      "_02-",
                      domain_processor$get_domain_number(),
                      "_",
                      tolower(domain_processor$pheno),
                      ".qmd"
                    )
                    if (
                      generated_file != output_file_name &&
                        file.exists(generated_file)
                    ) {
                      file.rename(generated_file, output_file_name)
                    }
                    log_message(paste0("Processed domain: ", domain), "DOMAINS")
                  },
                  error = function(e) {
                    log_message(
                      paste0(
                        "Error processing domain: ",
                        domain,
                        " - ",
                        e$message
                      ),
                      "ERROR"
                    )
                    log_message(
                      "Will try to continue with other domains",
                      "WARNING"
                    )
                  }
                )
              }

              # Also check neurobehav data for additional domains
              if (
                file.exists(file.path(
                  self$config$data$output_dir,
                  "neurobehav.csv"
                )) ||
                  file.exists(file.path(
                    self$config$data$output_dir,
                    "neurobehav.parquet"
                  )) ||
                  file.exists(file.path(
                    self$config$data$output_dir,
                    "neurobehav.feather"
                  ))
              ) {
                behav_domains_data <- query_neuropsych(
                  "SELECT DISTINCT domain FROM neurobehav WHERE domain IS NOT NULL",
                  self$config$data$output_dir
                )

                # Process behavioral domains
                for (i in 1:nrow(behav_domains_data)) {
                  domain <- behav_domains_data$domain[i]

                  # Skip if already processed
                  if (domain %in% domains_data$domain) {
                    next
                  }

                  # Create a domain processor for this domain
                  # Use the configured format (default is Parquet for better performance)
                  input_format <- self$config$data$format
                  if (is.null(input_format) || input_format == "all") {
                    # If format is "all", check which format exists
                    if (
                      file.exists(file.path(
                        self$config$data$output_dir,
                        "neurobehav.parquet"
                      ))
                    ) {
                      input_format <- "parquet"
                    } else if (
                      file.exists(file.path(
                        self$config$data$output_dir,
                        "neurobehav.csv"
                      ))
                    ) {
                      input_format <- "csv"
                    } else if (
                      file.exists(file.path(
                        self$config$data$output_dir,
                        "neurobehav.feather"
                      ))
                    ) {
                      input_format <- "feather"
                    } else {
                      input_format <- "parquet" # fallback
                    }
                  }

                  input_file <- file.path(
                    self$config$data$output_dir,
                    paste0("neurobehav.", input_format)
                  )

                  domain_processor <- DomainProcessorR6$new(
                    domains = domain,
                    pheno = domain_to_pheno(domain),
                    input_file = input_file,
                    output_dir = self$config$data$output_dir
                  )

                  # Process the domain and generate files
                  tryCatch(
                    {
                      # Get the appropriate output file name for this domain
                      output_file <- get_output_file(domain)

                      # Process the domain with the appropriate output file
                      # First set the output file name
                      output_file_name <- output_file
                      # Then process the domain (without passing output_file parameter)
                      domain_processor$process(
                        generate_reports = TRUE,
                        report_types = c("self"),
                        generate_domain_files = TRUE
                      )
                      # If needed, rename the generated file to match the expected output file
                      generated_file <- paste0(
                        "_02-",
                        domain_processor$get_domain_number(),
                        "_",
                        tolower(domain_processor$pheno),
                        ".qmd"
                      )
                      if (
                        generated_file != output_file_name &&
                          file.exists(generated_file)
                      ) {
                        file.rename(generated_file, output_file_name)
                      }
                      log_message(
                        paste0("Processed behavioral domain: ", domain),
                        "DOMAINS"
                      )
                    },
                    error = function(e) {
                      log_message(
                        paste0(
                          "Error processing behavioral domain: ",
                          domain,
                          " - ",
                          e$message
                        ),
                        "ERROR"
                      )
                      log_message(
                        "Will try to continue with other domains",
                        "WARNING"
                      )
                    }
                  )
                }
              }

              # List generated domain files
              domain_files <- list.files(".", pattern = "_02-.*\\.qmd$")
              if (length(domain_files) > 0) {
                log_message("Generated domain files:", "DOMAINS")
                for (file in domain_files) {
                  log_message(paste0("  - ", file), "DOMAINS")
                }
              } else {
                log_message("No domain files were generated", "WARNING")
              }
            },
            error = function(e) {
              log_message(
                paste0("Error processing domains: ", e$message),
                "ERROR"
              )
              log_message(
                "Will use fallback domain generation method",
                "WARNING"
              )
            }
          )
        }
      }

      # Check which domain files have been generated
      domain_files_generated <- list.files(".", pattern = "_02-.*\\.qmd$")
      log_message(
        paste(
          "Domain files already generated:",
          paste(domain_files_generated, collapse = ", ")
        ),
        "DOMAINS"
      )

      # Check if we need to run the domain generator module
      # Only run it if essential domain files are missing

      # Define essential domain files based on patient type
      patient_type <- determine_patient_type()

      # Basic essential files that should always be present
      essential_files <- c(
        "_02-01_iq.qmd",
        "_02-02_academics.qmd",
        "_02-03_verbal.qmd",
        "_02-04_spatial.qmd",
        "_02-05_memory.qmd",
        "_02-06_executive.qmd",
        "_02-07_motor.qmd"
      )

      # Add ADHD and emotion files based on patient type
      if (patient_type == "adult") {
        essential_files <- c(
          essential_files,
          "_02-09_adhd_adult.qmd",
          "_02-10_emotion_adult.qmd"
        )
      } else {
        essential_files <- c(
          essential_files,
          "_02-09_adhd_child.qmd",
          "_02-10_emotion_child.qmd"
        )
      }

      # Check if any essential files are missing
      missing_files <- essential_files[
        !essential_files %in% domain_files_generated
      ]

      if (length(missing_files) > 0) {
        log_message(
          paste(
            "Missing essential domain files:",
            paste(missing_files, collapse = ", ")
          ),
          "DOMAINS"
        )

        # Source the domain generator module as a fallback
        if (file.exists("domain_generator_module.R")) {
          log_message(
            "Running domain_generator_module.R to generate missing files",
            "DOMAINS"
          )
          source("domain_generator_module.R")
        } else {
          log_message(
            "domain_generator_module.R not found. Using fallback domain generation.",
            "DOMAINS"
          )

          # Fallback to using existing scripts
          if (file.exists("neuro2_R6_update_workflow.R")) {
            log_message("Using neuro2_R6_update_workflow.R", "DOMAINS")
            source("neuro2_R6_update_workflow.R")
          } else {
            log_message("No suitable domain generator found", "ERROR")
            return(FALSE)
          }
        }
      } else {
        log_message(
          "All essential domain files already generated, skipping domain_generator_module.R",
          "DOMAINS"
        )
      }

      log_message("Domain generation complete", "DOMAINS")
      return(TRUE)
    },

    # Step 4: Generate report
    generate_report = function() {
      log_message("Step 4: Generating final report...", "WORKFLOW")

      # Source the report generator module
      if (file.exists("report_generator_module.R")) {
        log_message("Running report_generator_module.R", "REPORT")
        source("report_generator_module.R")
      } else {
        log_message(
          "report_generator_module.R not found. Using Quarto directly.",
          "REPORT"
        )

        # Check if template.qmd exists with detailed logging
        template_file <- self$config$report$template
        log_message(
          paste0("Checking for template file: ", template_file),
          "REPORT"
        )
        log_message(paste0("Current working directory: ", getwd()), "REPORT")

        if (file.exists(template_file)) {
          log_message(paste0("Template file found: ", template_file), "REPORT")
          # Get file info for additional verification
          file_info <- file.info(template_file)
          log_message(paste0("File size: ", file_info$size, " bytes"), "REPORT")
          log_message(paste0("Last modified: ", file_info$mtime), "REPORT")
        } else {
          # Check if the file exists in the template directory
          template_dir <- "inst/quarto/templates/typst-report"
          alt_template_path <- file.path(template_dir, template_file)

          if (file.exists(alt_template_path)) {
            log_message(
              paste0(
                "Template found in template directory: ",
                alt_template_path
              ),
              "REPORT"
            )
            log_message(
              "Copying template file to working directory...",
              "REPORT"
            )
            file.copy(alt_template_path, template_file)

            if (file.exists(template_file)) {
              log_message("Template file copied successfully", "REPORT")
            } else {
              log_message(
                paste0(
                  "Failed to copy template file from: ",
                  alt_template_path
                ),
                "ERROR"
              )
              return(FALSE)
            }
          } else {
            log_message(
              paste0("Template file not found: ", template_file),
              "ERROR"
            )
            log_message(paste0("Also checked: ", alt_template_path), "ERROR")
            return(FALSE)
          }
        }

        # Render the report
        log_message(
          paste0("Rendering ", self$config$report$template, " with Quarto"),
          "REPORT"
        )
        quarto::quarto_render(
          input = self$config$report$template,
          output_format = self$config$report$format
        )
      }

      # Check if report was generated
      report_file <- gsub("\\.qmd$", ".pdf", self$config$report$template)
      if (file.exists(report_file)) {
        log_message(
          paste0("Report generated successfully: ", report_file),
          "REPORT"
        )
      } else {
        report_file <- gsub("\\.qmd$", ".html", self$config$report$template)
        if (file.exists(report_file)) {
          log_message(
            paste0("Report generated successfully: ", report_file),
            "REPORT"
          )
        } else {
          log_message("Report generation failed", "ERROR")
          return(FALSE)
        }
      }

      log_message("Report generation complete", "REPORT")
      return(TRUE)
    },

    # Run the entire workflow
    run_workflow = function() {
      log_message(
        paste0("Starting unified workflow for patient: ", self$patient_name),
        "WORKFLOW"
      )

      # Step 1: Setup environment
      if (!self$setup_environment()) {
        log_message("Environment setup failed", "ERROR")
        return(FALSE)
      }

      # Step 2: Process data
      if (!self$process_data()) {
        log_message("Data processing failed", "ERROR")
        return(FALSE)
      }

      # Step 3: Generate domain files
      if (!self$generate_domains()) {
        log_message("Domain generation failed", "ERROR")
        return(FALSE)
      }

      # Step 4: Generate report
      if (!self$generate_report()) {
        log_message("Report generation failed", "ERROR")
        return(FALSE)
      }

      log_message("Workflow completed successfully", "WORKFLOW")
      return(TRUE)
    }
  )
)

# Create and run the workflow
workflow <- WorkflowRunner$new(config)
result <- workflow$run_workflow()

# Print summary
if (result) {
  print_colored("🎉 WORKFLOW COMPLETE!", "green")
  print_colored("Generated files:", "green")

  # List generated files
  if (dir.exists(config$data$output_dir)) {
    data_files <- list.files(
      config$data$output_dir,
      pattern = "\\.(csv|parquet|feather|arrow)$"
    )
    for (file in data_files) {
      print_colored(paste0("  📊 ", file), "green")
    }
  }

  # List domain files
  domain_files <- list.files(".", pattern = "_02-.*\\.qmd$")
  if (length(domain_files) > 0) {
    print_colored("\nGenerated domain sections:", "green")
    for (file in domain_files) {
      print_colored(paste0("  📝 ", file), "green")
    }
  }

  # Check for final report
  report_file <- gsub("\\.qmd$", ".pdf", config$report$template)
  if (file.exists(report_file)) {
    print_colored(paste0("\n🎯 Final report: ", report_file), "green")
  } else {
    report_file <- gsub("\\.qmd$", ".html", config$report$template)
    if (file.exists(report_file)) {
      print_colored(paste0("\n🎯 Final report: ", report_file), "green")
    }
  }
} else {
  print_colored("❌ WORKFLOW FAILED", "red")
  print_colored("Check workflow.log for details", "red")
}

# Exit with appropriate status code
if (result) {
  quit(status = 0)
} else {
  quit(status = 1)
}
