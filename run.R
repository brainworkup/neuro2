# Load the neuro2 package
library(neuro2)

# Source the required modules in dependency order
# Utils and config first (they have helper functions)
source("R/workflow_utils.R")
source("R/workflow_config.R")
source("R/workflow_data_processor.R") # Critical: this was missing!

# Source R6 classes (these may have interdependencies)
source("R/ScoreTypeCacheR6.R")
source("R/NeuropsychResultsR6.R") # Before DomainProcessor if it uses this
source("R/DomainProcessorR6.R")
source("R/DomainProcessorFactoryR6.R")
source("R/TableGTR6.R")
source("R/DotplotR6.R")

# Source the main workflow runner last (it depends on everything else)
source("R/WorkflowRunnerR6.R")

# Load configuration using internal function (with dot)
config <- .load_workflow_config("config.yml")

# Create and run the workflow
workflow <- WorkflowRunnerR6$new(config)
result <- workflow$run()

# Print summary
workflow$print_summary(result)
