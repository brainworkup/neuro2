# Domain Generation Module
# Handles generating domain-specific QMD files

generate_workflow_domains <- function(config) {
  source("R/workflow_utils.R")
  source("R/workflow_data_processor.R")

  log_message("Generating domain files...", "WORKFLOW")

  # Determine patient type
  patient_type <- determine_patient_type(config$patient$age)
  log_message(paste("Determined patient type:", patient_type), "DOMAINS")

  # Check for required R6 classes
  if (!check_domain_r6_files()) {
    log_message("Will use fallback domain generation method", "WARNING")
    return(run_fallback_domain_generation(config, patient_type))
  }

  # Check if data exists
  data_status <- check_data_exists(config)
  if (!data_status$neurocog) {
    log_message("No neurocog data files found", "DOMAINS")
    return(run_fallback_domain_generation(config, patient_type))
  }

  # Load R6 classes
  load_domain_r6_classes()

  # Process domains
  success <- process_all_domains(config, patient_type, data_status)

  # Check if essential files were generated
  if (!verify_essential_domain_files(patient_type)) {
    log_message("Some essential domain files are missing, running fallback", "DOMAINS")
    return(run_fallback_domain_generation(config, patient_type))
  }

  log_message("Domain generation complete", "DOMAINS")
  return(success)
}

check_domain_r6_files <- function() {
  source("R/workflow_utils.R")

  log_message("Checking for required R6 classes for domain processing...", "DOMAINS")

  r6_domain_files <- c(
    "R/NeuropsychResultsR6.R",
    "R/DomainProcessorR6.R",
    "R/TableGTR6.R",
    "R/DotplotR6.R"
  )

  missing_r6_files <- r6_domain_files[!file.exists(r6_domain_files)]

  if (length(missing_r6_files) > 0) {
    log_message("Some required R6 class files are missing:", "WARNING")
    for (file in missing_r6_files) {
      log_message(paste0("  - ", file), "WARNING")
    }
    return(FALSE)
  }

  log_message("All required R6 class files for domain processing are present", "DOMAINS")
  return(TRUE)
}

load_domain_r6_classes <- function() {
  source("R/NeuropsychResultsR6.R")
  source("R/DomainProcessorR6.R")
  source("R/TableGTR6.R")
  source("R/DotplotR6.R")
}

process_all_domains <- function(config, patient_type, data_status) {
  source("R/workflow_utils.R")

  tryCatch(
    {
      log_message("Using DomainProcessorR6 to generate domain files", "DOMAINS")

      # Get domains from neurocog data
      domains_data <- query_neuropsych(
        "SELECT DISTINCT domain FROM neurocog WHERE domain IS NOT NULL",
        config$data$output_dir
      )

      log_message(paste0("Found ", nrow(domains_data), " unique domains"), "DOMAINS")

      # Track processed domains
      processed_domains <- character()
      emotion_processed <- FALSE

      # Process neurocog domains
      for (i in seq_len(nrow(domains_data))) {
        domain <- domains_data$domain[i]
        result <- process_single_domain(
          domain, config, patient_type,
          processed_domains, emotion_processed, "neurocog"
        )
        processed_domains <- result$processed_domains
        emotion_processed <- result$emotion_processed
      }

      # Process neurobehav domains if data exists
      if (data_status$neurobehav) {
        behav_domains_data <- query_neuropsych(
          "SELECT DISTINCT domain FROM neurobehav WHERE domain IS NOT NULL",
          config$data$output_dir
        )

        for (i in seq_len(nrow(behav_domains_data))) {
          domain <- behav_domains_data$domain[i]
          result <- process_single_domain(
            domain, config, patient_type,
            processed_domains, emotion_processed, "neurobehav"
          )
          processed_domains <- result$processed_domains
          emotion_processed <- result$emotion_processed
        }
      }

      # List generated files
      list_generated_domain_files()

      return(TRUE)
    },
    error = function(e) {
      log_message(paste0("Error processing domains: ", e$message), "ERROR")
      log_message("Will use fallback domain generation method", "WARNING")
      return(FALSE)
    }
  )
}

process_single_domain <- function(domain, config, patient_type,
                                  processed_domains, emotion_processed,
                                  data_type = "neurocog") {
  source("R/workflow_utils.R")

  # Skip if already processed
  if (domain %in% processed_domains) {
    log_message(paste0("Skipping already processed domain: ", domain), "DOMAINS")
    return(list(processed_domains = processed_domains, emotion_processed = emotion_processed))
  }

  # Handle emotion domains
  emotion_domains <- c(
    "Behavioral/Emotional/Social",
    "Substance Use",
    "Psychosocial Problems",
    "Psychiatric Disorders",
    "Personality Disorders",
    "Emotional/Behavioral/Personality"
  )

  if (domain %in% emotion_domains) {
    if (!emotion_processed) {
      log_message("Processing consolidated emotion domain", "DOMAINS")
      emotion_processed <- TRUE
      processed_domains <- c(processed_domains, emotion_domains)
      domain <- "Behavioral/Emotional/Social"
    } else {
      log_message(
        paste0(
          "Skipping individual emotion domain: ", domain,
          " (already processed as consolidated emotion)"
        ),
        "DOMAINS"
      )
      return(list(processed_domains = processed_domains, emotion_processed = emotion_processed))
    }
  }

  # Get input file
  input_format <- get_data_format(config, data_type)
  input_file <- file.path(config$data$output_dir, paste0(data_type, ".", input_format))

  # Create domain processor
  domain_processor <- DomainProcessorR6$new(
    domains = domain,
    pheno = domain_to_pheno(domain),
    input_file = input_file,
    output_dir = config$data$output_dir
  )

  # Process the domain
  tryCatch(
    {
      output_file <- get_domain_output_file(domain, patient_type)

      domain_processor$process(
        generate_reports = TRUE,
        report_types = c("self"),
        generate_domain_files = TRUE
      )

      # Rename generated file if needed
      generated_file <- paste0(
        "_02-",
        domain_processor$get_domain_number(),
        "_",
        tolower(domain_processor$pheno),
        ".qmd"
      )

      if (generated_file != output_file && file.exists(generated_file)) {
        file.rename(generated_file, output_file)
      }

      processed_domains <- c(processed_domains, domain)
      log_message(paste0("Processed domain: ", domain), "DOMAINS")
    },
    error = function(e) {
      log_message(
        paste0("Error processing domain: ", domain, " - ", e$message),
        "ERROR"
      )
      log_message("Will try to continue with other domains", "WARNING")
    }
  )

  return(list(processed_domains = processed_domains, emotion_processed = emotion_processed))
}

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

  # Check if domain should be combined into emotion
  emotion_domains <- c(
    "Substance Use",
    "Psychosocial Problems",
    "Psychiatric Disorders",
    "Personality Disorders",
    "Emotional/Behavioral/Personality"
  )

  if (domain_name %in% emotion_domains) {
    return("emotion")
  }

  # Return mapped value or default
  pheno_value <- mapping[[domain_name]]
  if (is.null(pheno_value)) {
    if (grepl("Behav|Emot|Psych|Social|Substance|Personality", domain_name)) {
      return("emotion")
    }
    pheno_value <- tolower(gsub("[^a-zA-Z0-9]", "_", domain_name))
  }

  return(pheno_value)
}

get_domain_output_file <- function(domain_name, patient_type) {
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

  # Special handling for ADHD
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

  # Return mapped file or create default
  file_name <- domain_files[[domain_name]]
  if (is.null(file_name)) {
    safe_name <- tolower(gsub("[^a-zA-Z0-9]", "_", domain_name))
    file_name <- paste0("_02-", safe_name, ".qmd")
  }

  return(file_name)
}

list_generated_domain_files <- function() {
  source("R/workflow_utils.R")

  domain_files <- list.files(".", pattern = "_02-.*\\.qmd$")
  if (length(domain_files) > 0) {
    log_message("Generated domain files:", "DOMAINS")
    for (file in domain_files) {
      log_message(paste0("  - ", file), "DOMAINS")
    }
  } else {
    log_message("No domain files were generated", "WARNING")
  }
}

verify_essential_domain_files <- function(patient_type) {
  # Define essential domain files
  essential_files <- c(
    "_02-01_iq.qmd",
    "_02-02_academics.qmd",
    "_02-03_verbal.qmd",
    "_02-04_spatial.qmd",
    "_02-05_memory.qmd",
    "_02-06_executive.qmd",
    "_02-07_motor.qmd"
  )

  # Add patient-type specific files
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

  # Check existing files
  domain_files_generated <- list.files(".", pattern = "_02-.*\\.qmd$")
  missing_files <- essential_files[!essential_files %in% domain_files_generated]

  if (length(missing_files) > 0) {
    log_message(
      paste("Missing essential domain files:", paste(missing_files, collapse = ", ")),
      "DOMAINS"
    )
    return(FALSE)
  }

  return(TRUE)
}

run_fallback_domain_generation <- function(config, patient_type) {
  source("R/workflow_utils.R")

  # Source the domain generator module as a fallback
  if (file.exists("domain_generator_module.R")) {
    log_message("Running domain_generator_module.R to generate missing files", "DOMAINS")
    source("domain_generator_module.R")
    return(TRUE)
  }

  # Try other fallback scripts
  if (file.exists("neuro2_R6_update_workflow.R")) {
    log_message("Using neuro2_R6_update_workflow.R", "DOMAINS")
    source("neuro2_R6_update_workflow.R")
    return(TRUE)
  }

  log_message("No suitable domain generator found", "ERROR")
  return(FALSE)
}
