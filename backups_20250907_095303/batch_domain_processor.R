#' Fixed Batch Domain Processor - Single Execution Guaranteed
#' 
#' Replace inst/scripts/batch_domain_processor.R with this version
#' This ensures each domain is processed exactly ONCE

# Prevent multiple executions
if (exists(".BATCH_PROCESSOR_RUNNING")) {
  message("Batch processor already running, exiting...")
  stop("Batch processor is already running", call. = FALSE)
}
.BATCH_PROCESSOR_RUNNING <- TRUE
on.exit(rm(.BATCH_PROCESSOR_RUNNING, envir = .GlobalEnv))

#' Main batch processing function - SINGLE LOOP ONLY
#' @param neurocog_data Neurocognitive data frame
#' @param neurobehav_data Neurobehavioral data frame  
#' @param output_dir Output directory for files
#' @param generate_assets Whether to generate tables and figures
#' @return List of processed domains
batch_process_domains <- function(
  neurocog_data = NULL,
  neurobehav_data = NULL,
  output_dir = ".",
  generate_assets = TRUE
) {
  
  # Setup
  message("\n========================================")
  message("BATCH DOMAIN PROCESSOR - FIXED VERSION")
  message("Time: ", Sys.time())
  message("========================================\n")
  
  # Load data if not provided
  if (is.null(neurocog_data)) {
    neurocog_data <- readr::read_csv("data/neurocog.csv", show_col_types = FALSE)
  }
  if (is.null(neurobehav_data)) {
    neurobehav_data <- readr::read_csv("data/neurobehav.csv", show_col_types = FALSE)
  }
  
  # Define ALL domains in ONE place - NO DUPLICATION
  all_domains <- list(
    list(
      key = "iq",
      name = "General Cognitive Ability",
      pheno = "iq",
      data_source = "neurocog",
      number = "01"
    ),
    list(
      key = "academics", 
      name = "Academic Skills",
      pheno = "academics",
      data_source = "neurocog",
      number = "02"
    ),
    list(
      key = "verbal",
      name = "Verbal/Language",
      pheno = "verbal",
      data_source = "neurocog",
      number = "03"
    ),
    list(
      key = "spatial",
      name = "Visual Perception/Construction",
      pheno = "spatial",
      data_source = "neurocog",
      number = "04"
    ),
    list(
      key = "memory",
      name = "Memory",
      pheno = "memory",
      data_source = "neurocog",
      number = "05"
    ),
    list(
      key = "executive",
      name = "Attention/Executive",
      pheno = "executive",
      data_source = "neurocog",
      number = "06"
    ),
    list(
      key = "motor",
      name = "Motor",
      pheno = "motor",
      data_source = "neurocog",
      number = "07"
    ),
    list(
      key = "social",
      name = "Social Cognition",
      pheno = "social",
      data_source = "neurocog",
      number = "08"
    ),
    list(
      key = "adhd",
      name = "ADHD",
      pheno = "adhd",
      data_source = "neurobehav",
      number = "09"
    ),
    list(
      key = "emotion",
      name = "Behavioral/Emotional/Social",
      pheno = "emotion",
      data_source = "neurobehav",
      number = "10"
    ),
    list(
      key = "validity",
      name = "Performance Validity",
      pheno = "validity",
      data_source = "neurocog",
      number = "13"
    )
  )
  
  # Track what we've processed - CRITICAL FOR PREVENTING DUPLICATES
  processed_domains <- list()
  processing_log <- data.frame(
    domain = character(),
    status = character(),
    time = character(),
    message = character(),
    stringsAsFactors = FALSE
  )
  
  # SINGLE LOOP - Process each domain EXACTLY ONCE
  message("Processing ", length(all_domains), " domains...\n")
  
  for (i in seq_along(all_domains)) {
    domain_config <- all_domains[[i]]
    domain_key <- domain_config$key
    
    # CRITICAL CHECK: Skip if already processed
    if (domain_key %in% names(processed_domains)) {
      message("  ⚠️  ", domain_key, " - Already processed, skipping!")
      next
    }
    
    # Progress indicator
    message(sprintf("[%d/%d] Processing %s...", i, length(all_domains), domain_key))
    
    # Select data source
    data_source <- if (domain_config$data_source == "neurocog") {
      neurocog_data
    } else {
      neurobehav_data
    }
    
    # Validate data exists for this domain
    domain_data <- data_source %>%
      dplyr::filter(domain == domain_config$name) %>%
      dplyr::filter(!is.na(percentile) | !is.na(score))
    
    if (nrow(domain_data) == 0) {
      message("  ✗ No data found for ", domain_key)
      processing_log <- rbind(processing_log, data.frame(
        domain = domain_key,
        status = "skipped",
        time = as.character(Sys.time()),
        message = "No data"
      ))
      next
    }
    
    # Process the domain ONCE
    tryCatch({
      # Create processor
      processor <- DomainProcessorR6$new(
        domains = domain_config$name,
        pheno = domain_config$pheno,
        input_file = paste0("data/", domain_config$data_source, ".csv")
      )
      
      # Set the number for file naming
      processor$number <- domain_config$number
      
      # Process domain
      processor$process()
      
      # Generate QMD file
      qmd_file <- paste0("_02-", domain_config$number, "_", domain_config$pheno, ".qmd")
      if (!file.exists(qmd_file)) {
        processor$generate_domain_qmd(qmd_file)
      }
      
      # Generate assets if requested
      if (generate_assets) {
        # Tables
        if (!file.exists(paste0("table_", domain_config$pheno, ".png"))) {
          processor$generate_table()
        }
        
        # Figures
        if (!file.exists(paste0("fig_", domain_config$pheno, "_subdomain.svg"))) {
          processor$generate_figure()
        }
      }
      
      # Mark as processed
      processed_domains[[domain_key]] <- processor
      
      # Log success
      processing_log <- rbind(processing_log, data.frame(
        domain = domain_key,
        status = "success",
        time = as.character(Sys.time()),
        message = paste("Processed", nrow(domain_data), "rows")
      ))
      
      message("  ✓ Complete")
      
    }, error = function(e) {
      message("  ✗ Error: ", e$message)
      processing_log <- rbind(processing_log, data.frame(
        domain = domain_key,
        status = "error",
        time = as.character(Sys.time()),
        message = e$message
      ))
    })
  }
  
  # Summary report
  message("\n========================================")
  message("BATCH PROCESSING COMPLETE")
  message("========================================")
  
  success_count <- sum(processing_log$status == "success")
  skip_count <- sum(processing_log$status == "skipped")
  error_count <- sum(processing_log$status == "error")
  
  message("Results:")
  message("  ✓ Success: ", success_count, " domains")
  if (skip_count > 0) {
    message("  ⚠️  Skipped: ", skip_count, " domains (no data)")
  }
  if (error_count > 0) {
    message("  ✗ Errors: ", error_count, " domains")
  }
  
  # Save processing log
  log_file <- file.path(output_dir, "batch_processing_log.csv")
  write.csv(processing_log, log_file, row.names = FALSE)
  message("\nLog saved to: ", log_file)
  
  return(list(
    processed = processed_domains,
    log = processing_log,
    summary = list(
      total = length(all_domains),
      success = success_count,
      skipped = skip_count,
      errors = error_count
    )
  ))
}

# Execute if running as script
if (!interactive()) {
  result <- batch_process_domains()
  message("\nBatch processing completed at ", Sys.time())
}