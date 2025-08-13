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
        "INFO",
        self$log_file
      )
    },

    # Step 1: Setup environment
    setup_environment = function() {
      source("R/workflow_setup.R")
      log_message("Step 1: Setting up environment...", "WORKFLOW", self$log_file)
      return(setup_workflow_environment(self$config))
    },

    # Step 2: Process data
    process_data = function() {
      source("R/workflow_data_processor.R")
      log_message("Step 2: Processing data...", "WORKFLOW", self$log_file)
      return(process_workflow_data(self$config))
    },

    # Step 3: Generate domain files
    generate_domains = function() {
      source("R/workflow_domain_generator.R")
      log_message("Step 3: Generating domain files...", "WORKFLOW", self$log_file)
      return(generate_workflow_domains(self$config))
    },

    # Step 4: Generate report
    generate_report = function() {
      source("R/workflow_report_generator.R")
      log_message("Step 4: Generating final report...", "WORKFLOW")
      return(generate_workflow_report(self$config))
    },

    # Run the entire workflow
    run_workflow = function() {
      source("R/workflow_utils.R")

      log_message(
        paste0("Starting unified workflow for patient: ", self$patient_name),
        "WORKFLOW",
        self$log_file
      )

      # Step 1: Setup environment
      if (!self$setup_environment()) {
        log_message("Environment setup failed", "ERROR", self$log_file)
        return(FALSE)
      }

      # Step 2: Process data
      if (!self$process_data()) {
        log_message("Data processing failed", "ERROR", self$log_file)
        return(FALSE)
      }

      # Step 3: Generate domain files
      if (!self$generate_domains()) {
        log_message("Domain generation failed", "ERROR", self$log_file)
        return(FALSE)
      }

      # Step 4: Generate report
      if (!self$generate_report()) {
        log_message("Report generation failed", "ERROR", self$log_file)
        return(FALSE)
      }

      log_message("Workflow completed successfully", "WORKFLOW", self$log_file)
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
