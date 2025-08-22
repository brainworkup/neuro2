# Load the neuro2 package
library(neuro2)

# Load configuration (this will use default config.yml if no args provided)
config <- load_workflow_config("config.yml")

# Create and run the workflow
workflow <- WorkflowRunnerR6$new(config)
result <- workflow$run_workflow()

# Print summary
workflow$print_summary(result)
