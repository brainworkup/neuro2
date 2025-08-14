# Source the required modules
source("R/workflow_utils.R")
source("R/workflow_config.R")
source("R/WorkflowRunnerR6.R")

# Load configuration (this will use default config.yml if no args provided)
config <- load_workflow_config("config.yml")

# Create and run the workflow
workflow <- WorkflowRunnerR6$new(config)
result <- workflow$run_workflow()

# Print summary
workflow$print_summary(result)
