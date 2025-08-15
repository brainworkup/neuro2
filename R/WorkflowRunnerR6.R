# WorkflowRunnerR6 Class
# Simplified R6 class for orchestrating the neuropsychological workflow

WorkflowRunnerR6 <- R6::R6Class(
  "WorkflowRunnerR6",
  public = list(
    # Properties
    config = NULL,
    patient_name = NULL,
    log_file = NULL,

    # Constructor
    initialize = function(config) {
      # Load utility functions
      source("R/workflow_utils.R")

      self$config <- config
      self$patient_name <- config$patient$name
      self$log_file <- "workflow.log"

      log_message(
        paste0("Initialized WorkflowRunner for patient: ", self$patient_name),
        "INFO"
      )
    },

    # Step 1: Setup environment
    setup_environment = function() {
      source("R/workflow_setup.R")
      log_message("Setting up environment...", "WORKFLOW")
      return(setup_workflow_environment(self$config))
    },

    # Step 2: Process data
    process_data = function() {
      source("R/workflow_data_processor.R")
      log_message("Processing data...", "WORKFLOW")
      return(process_workflow_data(self$config))
    },

    # Step 3: Generate domain files
    generate_domains = function() {
      source("R/workflow_domain_generator.R")
      log_message("Generating domain files...", "WORKFLOW")
      return(generate_workflow_domains(self$config))
    },

    # Step 4: Generate report
    generate_report = function() {
      source("R/workflow_report_generator.R")
      log_message("Generating final report...", "WORKFLOW")
      return(generate_workflow_report(self$config))
    },

    #' Run the complete neuropsychological workflow
    #'
    #' Executes all steps of the workflow in sequence:
    #' 1. Environment setup
    #' 2. Data processing
    #' 3. Domain file generation
    #' 4. Report generation
    #'
    #' @details
    #' Each step is logged and the workflow will stop if any step fails.
    #' The method returns TRUE if all steps complete successfully, FALSE otherwise.
    #'
    #' @return Logical indicating workflow success (TRUE) or failure (FALSE)
    #' @examples
    #' \dontrun{
    #' runner <- WorkflowRunnerR6$new(config)
    #' success <- runner$run_workflow()
    #' runner$print_summary(success)
    #' }
    run_workflow = function() {
      source("R/workflow_utils.R")

      log_message(
        paste0("Starting unified workflow for patient: ", self$patient_name),
        "WORKFLOW"
      )

      # Step 1: Setup environment
      log_message("Step 1: Setting up environment...", "WORKFLOW")
      if (!self$setup_environment()) {
        log_message("Environment setup failed", "ERROR")
        return(FALSE)
      }

      # Step 2: Process data
      log_message("Step 2: Processing data...", "WORKFLOW")
      if (!self$process_data()) {
        log_message("Data processing failed", "ERROR")
        return(FALSE)
      }

      # Step 3: Generate domain files
      log_message("Step 3: Generating domain files...", "WORKFLOW")
      if (!self$generate_domains()) {
        log_message("Domain generation failed", "ERROR")
        return(FALSE)
      }

      # Step 4: Generate report
      log_message("Step 4: Generating final report...", "WORKFLOW")
      if (!self$generate_report()) {
        log_message("Report generation failed", "ERROR")
        return(FALSE)
      }

      log_message("Workflow completed successfully", "WORKFLOW")
      return(TRUE)
    },

    # Print summary
    print_summary = function(success) {
      source("R/workflow_report_generator.R")

      if (success) {
        print_report_summary(self$config)
      } else {
        print_colored("❌ WORKFLOW FAILED", "red")
        print_colored("Check workflow.log for details", "red")
      }
    }
  )
)
