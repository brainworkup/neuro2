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
  # Create default configuration if it doesn't exist
  log_message(
    "Configuration file not found. Creating default configuration.",
    "CONFIG"
  )

  default_config <- list(
    patient = list(
      name = "Patient Name",
      age = 35,
      doe = format(Sys.Date(), "%Y-%m-%d")
    ),
    data = list(
      input_dir = "data-raw/csv",
      output_dir = "data",
      format = "parquet"
    ),
    processing = list(use_duckdb = TRUE, parallel = TRUE),
    report = list(
      template = "template.qmd",
      format = "typst-pdf",
      output_dir = "output"
    )
  )

  yaml::write_yaml(default_config, config_file)
  log_message(
    paste0("Created default configuration file: ", config_file),
    "CONFIG"
  )
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

      # Check for R6 class files
      r6_files <- c(
        "R/ReportTemplateR6.R",
        "R/NeuropsychResultsR6.R",
        "R/NeuropsychReportSystemR6.R",
        "R/IQReportGeneratorR6.R",
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

      # Check for template QMD files and create them if needed
      log_message("Checking for required template QMD files...", "DOMAINS")

      # Define domain templates mapping based on official domain definitions
      domain_templates <- list(
        # 1. General Cognitive Ability (domain_iq)
        "General Cognitive Ability" = list(
          file = "_02-01_iq_text.qmd",
          title = "IQ Text Template",
          content = '---
title: "IQ Text Template"
format: html
---

## Intellectual Functioning

The patient was administered the Wechsler Intelligence Scale. Overall intellectual functioning was in the {{iq_range}} range (Full Scale IQ = {{fsiq}}).

### Verbal Comprehension
Verbal comprehension abilities were {{vci_desc}} (VCI = {{vci}}).

### Perceptual Reasoning
Perceptual reasoning abilities were {{pri_desc}} (PRI = {{pri}}).

### Working Memory
Working memory abilities were {{wmi_desc}} (WMI = {{wmi}}).

### Processing Speed
Processing speed abilities were {{psi_desc}} (PSI = {{psi}}).'
        ),
        
        # 2. Academic Skills (domain_academics)
        "Academic Skills" = list(
          file = "_02-02_academic_text.qmd",
          title = "Academic Skills Assessment Template",
          content = '---
title: "Academic Skills Assessment Template"
format: html
---

## Academic Skills

The patient was administered academic skills assessments. Overall academic skills were in the {{academic_range}} range.

### Reading
Reading abilities were {{reading_desc}} (Score = {{reading_score}}).

### Mathematics
Mathematics abilities were {{math_desc}} (Score = {{math_score}}).

### Written Expression
Written expression abilities were {{writing_desc}} (Score = {{writing_score}}).'
        ),
        
        # 3. Verbal/Language (domain_verbal)
        "Verbal/Language" = list(
          file = "_02-03_verbal_text.qmd",
          title = "Verbal and Language Assessment Template",
          content = '---
title: "Verbal and Language Assessment Template"
format: html
---

## Verbal and Language Functioning

The patient was administered verbal and language assessments. Overall verbal/language functioning was in the {{verbal_range}} range.

### Expressive Language
Expressive language abilities were {{expressive_desc}} (Score = {{expressive_score}}).

### Receptive Language
Receptive language abilities were {{receptive_desc}} (Score = {{receptive_score}}).

### Verbal Fluency
Verbal fluency abilities were {{verbal_fluency_desc}} (Score = {{verbal_fluency_score}}).'
        ),
        
        # 4. Visual Perception/Construction (domain_spatial)
        "Visual Perception/Construction" = list(
          file = "_02-04_visuospatial_text.qmd",
          title = "Visual Perception and Construction Assessment Template",
          content = '---
title: "Visual Perception and Construction Assessment Template"
format: html
---

## Visual Perception and Construction

The patient was administered visual-spatial assessments. Overall visual perception and construction abilities were in the {{visuospatial_range}} range.

### Visual Processing
Visual processing abilities were {{visual_processing_desc}} (Score = {{visual_processing_score}}).

### Spatial Reasoning
Spatial reasoning abilities were {{spatial_reasoning_desc}} (Score = {{spatial_reasoning_score}}).

### Visual Construction
Visual construction abilities were {{visual_construction_desc}} (Score = {{visual_construction_score}}).'
        ),
        
        # 5. Memory (domain_memory)
        "Memory" = list(
          file = "_02-05_memory_text.qmd",
          title = "Memory Assessment Template",
          content = '---
title: "Memory Assessment Template"
format: html
---

## Memory Functioning

The patient was administered memory assessments. Overall memory functioning was in the {{memory_range}} range.

### Immediate Memory
Immediate memory abilities were {{immediate_memory_desc}} (Score = {{immediate_memory_score}}).

### Delayed Memory
Delayed memory abilities were {{delayed_memory_desc}} (Score = {{delayed_memory_score}}).

### Working Memory
Working memory abilities were {{working_memory_desc}} (Score = {{working_memory_score}}).

### Visual Memory
Visual memory abilities were {{visual_memory_desc}} (Score = {{visual_memory_score}}).

### Verbal Memory
Verbal memory abilities were {{verbal_memory_desc}} (Score = {{verbal_memory_score}}).'
        ),
        
        # 6. Attention/Executive (domain_executive)
        "Attention/Executive" = list(
          file = "_02-06_executive_text.qmd",
          title = "Attention and Executive Functions Assessment Template",
          content = '---
title: "Attention and Executive Functions Assessment Template"
format: html
---

## Attention and Executive Functioning

The patient was administered attention and executive function assessments. Overall executive functioning was in the {{executive_range}} range.

### Attention
Attention abilities were {{attention_desc}} (Score = {{attention_score}}).

### Processing Speed
Processing speed was {{processing_speed_desc}} (Score = {{processing_speed_score}}).

### Cognitive Flexibility
Cognitive flexibility was {{cognitive_flexibility_desc}} (Score = {{cognitive_flexibility_score}}).

### Inhibition
Inhibition abilities were {{inhibition_desc}} (Score = {{inhibition_score}}).

### Planning
Planning abilities were {{planning_desc}} (Score = {{planning_score}}).'
        ),
        
        # 7. Motor (domain_motor)
        "Motor" = list(
          file = "_02-07_motor_text.qmd",
          title = "Motor Assessment Template",
          content = '---
title: "Motor Assessment Template"
format: html
---

## Motor Functioning

The patient was administered motor assessments. Overall motor functioning was in the {{motor_range}} range.

### Fine Motor
Fine motor abilities were {{fine_motor_desc}} (Score = {{fine_motor_score}}).

### Gross Motor
Gross motor abilities were {{gross_motor_desc}} (Score = {{gross_motor_score}}).

### Motor Speed
Motor speed was {{motor_speed_desc}} (Score = {{motor_speed_score}}).

### Motor Coordination
Motor coordination was {{motor_coordination_desc}} (Score = {{motor_coordination_score}}).'
        ),
        
        # 8. Social Cognition (domain_social)
        "Social Cognition" = list(
          file = "_02-08_social_cognition_text.qmd",
          title = "Social Cognition Assessment Template",
          content = '---
title: "Social Cognition Assessment Template"
format: html
---

## Social Cognition

The patient was administered social cognition assessments. Overall social cognition was in the {{social_cognition_range}} range.

### Social Perception
Social perception abilities were {{social_perception_desc}} (Score = {{social_perception_score}}).

### Theory of Mind
Theory of mind abilities were {{theory_of_mind_desc}} (Score = {{theory_of_mind_score}}).

### Emotion Recognition
Emotion recognition abilities were {{emotion_recognition_desc}} (Score = {{emotion_recognition_score}}).'
        ),
        
        # 9. ADHD (domain_adhd_adult and domain_adhd_child)
        "ADHD" = list(
          file = "_02-09_adhd_text.qmd",
          title = "ADHD Assessment Template",
          content = '---
title: "ADHD Assessment Template"
format: html
---

## ADHD Symptoms

The patient was administered ADHD assessments. Overall ADHD symptomatology was in the {{adhd_range}} range.

### Inattention
Inattention symptoms were {{inattention_desc}} (Score = {{inattention_score}}).

### Hyperactivity/Impulsivity
Hyperactivity/impulsivity symptoms were {{hyperactivity_desc}} (Score = {{hyperactivity_score}}).

### Executive Functioning
ADHD-related executive functioning was {{adhd_executive_desc}} (Score = {{adhd_executive_score}}).'
        ),
        
        # 10. Emotional/Behavioral/Personality domains
        "Emotional/Behavioral/Personality" = list(
          file = "_02-10_emotional_behavioral_text.qmd",
          title = "Emotional and Behavioral Assessment Template",
          content = '---
title: "Emotional and Behavioral Assessment Template"
format: html
---

## Emotional, Behavioral, and Personality Functioning

The patient was administered emotional and behavioral assessments. Overall emotional and behavioral functioning was in the {{emotional_range}} range.

### Externalizing Problems
Externalizing behaviors were {{externalizing_desc}} (Score = {{externalizing_score}}).

### Internalizing Problems
Internalizing behaviors were {{internalizing_desc}} (Score = {{internalizing_score}}).

### Personality Features
Personality features were {{personality_desc}} (Score = {{personality_score}}).'
        ),
        
        # Additional domains from domain_emotion_adult and domain_emotion_child
        "Psychiatric Disorders" = list(
          file = "_02-11_psychiatric_text.qmd",
          title = "Psychiatric Assessment Template",
          content = '---
title: "Psychiatric Assessment Template"
format: html
---

## Psychiatric Functioning

The patient was administered psychiatric assessments. Overall psychiatric functioning was in the {{psychiatric_range}} range.

### Anxiety
Anxiety symptoms were {{anxiety_desc}} (Score = {{anxiety_score}}).

### Depression
Depression symptoms were {{depression_desc}} (Score = {{depression_score}}).

### Other Psychiatric Symptoms
Other psychiatric symptoms were {{other_psychiatric_desc}} (Score = {{other_psychiatric_score}}).'
        ),
        
        "Personality Disorders" = list(
          file = "_02-12_personality_text.qmd",
          title = "Personality Assessment Template",
          content = '---
title: "Personality Assessment Template"
format: html
---

## Personality Functioning

The patient was administered personality assessments. Overall personality functioning was in the {{personality_range}} range.

### Borderline Features
Borderline features were {{borderline_desc}} (Score = {{borderline_score}}).

### Antisocial Features
Antisocial features were {{antisocial_desc}} (Score = {{antisocial_score}}).

### Other Personality Features
Other personality features were {{other_personality_desc}} (Score = {{other_personality_score}}).'
        ),
        
        "Substance Use" = list(
          file = "_02-13_substance_text.qmd",
          title = "Substance Use Assessment Template",
          content = '---
title: "Substance Use Assessment Template"
format: html
---

## Substance Use

The patient was administered substance use assessments.

### Alcohol Use
Alcohol use was {{alcohol_desc}} (Score = {{alcohol_score}}).

### Drug Use
Drug use was {{drug_desc}} (Score = {{drug_score}}).

### Substance Use Impact
Impact of substance use was {{substance_impact_desc}} (Score = {{substance_impact_score}}).'
        ),
        
        "Psychosocial Problems" = list(
          file = "_02-14_psychosocial_text.qmd",
          title = "Psychosocial Assessment Template",
          content = '---
title: "Psychosocial Assessment Template"
format: html
---

## Psychosocial Functioning

The patient was administered psychosocial assessments.

### Social Environment
Social environment was {{social_env_desc}} (Score = {{social_env_score}}).

### Treatment Considerations
Treatment considerations were {{treatment_desc}} (Score = {{treatment_score}}).

### Interpersonal Functioning
Interpersonal functioning was {{interpersonal_desc}} (Score = {{interpersonal_score}}).'
        ),
        
        "Behavioral/Emotional/Social" = list(
          file = "_02-15_behavioral_text.qmd",
          title = "Behavioral Assessment Template",
          content = '---
title: "Behavioral Assessment Template"
format: html
---

## Behavioral, Emotional, and Social Functioning

The patient was administered behavioral and emotional assessments. Overall behavioral functioning was in the {{behavioral_range}} range.

### Externalizing Problems
Externalizing behaviors were {{externalizing_desc}} (Score = {{externalizing_score}}).

### Internalizing Problems
Internalizing behaviors were {{internalizing_desc}} (Score = {{internalizing_score}}).

### Adaptive Skills
Adaptive skills were {{adaptive_desc}} (Score = {{adaptive_score}}).'
        ),
        
        # 11. Adaptive Functioning (domain_adaptive)
        "Adaptive Functioning" = list(
          file = "_02-16_adaptive_text.qmd",
          title = "Adaptive Functioning Assessment Template",
          content = '---
title: "Adaptive Functioning Assessment Template"
format: html
---

## Adaptive Functioning

The patient was administered adaptive functioning assessments. Overall adaptive functioning was in the {{adaptive_range}} range.

### Conceptual Skills
Conceptual adaptive skills were {{conceptual_desc}} (Score = {{conceptual_score}}).

### Social Skills
Social adaptive skills were {{social_adaptive_desc}} (Score = {{social_adaptive_score}}).

### Practical Skills
Practical adaptive skills were {{practical_desc}} (Score = {{practical_score}}).'
        ),
        
        # 12. Daily Living (domain_daily_living)
        "Daily Living" = list(
          file = "_02-17_daily_living_text.qmd",
          title = "Daily Living Assessment Template",
          content = '---
title: "Daily Living Assessment Template"
format: html
---

## Daily Living Skills

The patient was administered daily living skills assessments. Overall daily living skills were in the {{daily_living_range}} range.

### Self-Care
Self-care abilities were {{self_care_desc}} (Score = {{self_care_score}}).

### Home Living
Home living abilities were {{home_living_desc}} (Score = {{home_living_score}}).

### Community Use
Community use abilities were {{community_use_desc}} (Score = {{community_use_score}}).'
        )
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
        file.exists(file.path(self$config$data$output_dir, "neurocog.feather"))

      if (!neurocog_exists) {
        log_message("No neurocog data files found", "DOMAINS")
      } else {
        # Get all unique domains from the neurocog data
        tryCatch(
          {
            domains_data <- query_neuropsych(
              "SELECT DISTINCT domain FROM neurocog WHERE domain IS NOT NULL",
              self$config$data$output_dir
            )

            log_message(
              paste0("Found ", nrow(domains_data), " unique domains"),
              "DOMAINS"
            )

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

              # Combine domains
              domains_data <- unique(rbind(domains_data, behav_domains_data))
              log_message(
                paste0("Found ", nrow(domains_data), " total unique domains"),
                "DOMAINS"
              )
            }

            # Create templates for each domain that has data
            created_templates <- c()

            for (i in 1:nrow(domains_data)) {
              domain <- domains_data$domain[i]

              # Check if we have a template for this domain
              if (domain %in% names(domain_templates)) {
                template_info <- domain_templates[[domain]]

                # Check if the template file already exists
                if (file.exists(template_info$file)) {
                  log_message(
                    paste0(
                      "Template for domain '",
                      domain,
                      "' already exists: ",
                      template_info$file
                    ),
                    "DOMAINS"
                  )
                } else {
                  log_message(
                    paste0("Creating template for domain: ", domain),
                    "DOMAINS"
                  )
                  writeLines(template_info$content, template_info$file)
                  log_message(paste0("Created ", template_info$file), "DOMAINS")
                  created_templates <- c(created_templates, template_info$file)
                }
              } else {
                log_message(
                  paste0("No template defined for domain: ", domain),
                  "WARNING"
                )
              }
            }

            # Check for domains that might be in subdomains but not in main domains
            special_domains <- c(
              "Memory",
              "Executive Function",
              "Language",
              "Visual-Spatial",
              "Motor"
            )

            for (special_domain in special_domains) {
              if (!(special_domain %in% domains_data$domain)) {
                # Check if it exists as a subdomain
                subdomain_query <- paste0(
                  "SELECT COUNT(*) as count FROM neurocog WHERE subdomain = '",
                  special_domain,
                  "'"
                )

                subdomain_data <- query_neuropsych(
                  subdomain_query,
                  self$config$data$output_dir
                )

                if (subdomain_data$count > 0) {
                  log_message(
                    paste0(
                      "Found data for '",
                      special_domain,
                      "' in subdomains"
                    ),
                    "DOMAINS"
                  )

                  # Create template if it doesn't exist
                  if (special_domain %in% names(domain_templates)) {
                    template_info <- domain_templates[[special_domain]]

                    if (!file.exists(template_info$file)) {
                      log_message(
                        paste0(
                          "Creating template for subdomain: ",
                          special_domain
                        ),
                        "DOMAINS"
                      )
                      writeLines(template_info$content, template_info$file)
                      log_message(
                        paste0("Created ", template_info$file),
                        "DOMAINS"
                      )
                      created_templates <- c(
                        created_templates,
                        template_info$file
                      )
                    }
                  }
                }
              }
            }

            # Display summary of created templates
            if (length(created_templates) > 0) {
              print_colored(
                "Some template QMD files are missing. Creating them now:",
                "yellow"
              )
              for (template in created_templates) {
                print_colored(paste0("  - Creating ", template), "yellow")
              }
              print_colored("Template QMD files created successfully.", "green")
            } else {
              print_colored(
                "All required template QMD files already exist.",
                "green"
              )
            }
          },
          error = function(e) {
            log_message(paste0("Error querying domains: ", e$message), "ERROR")
          }
        )
      }

      # Source the domain generator module
      if (file.exists("domain_generator_module.R")) {
        log_message("Running domain_generator_module.R", "DOMAINS")
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

        # Check if template.qmd exists
        if (!file.exists(self$config$report$template)) {
          log_message(
            paste0(self$config$report$template, " not found"),
            "ERROR"
          )
          return(FALSE)
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
