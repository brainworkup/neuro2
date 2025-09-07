# Load the neuro2 package
library(neuro2)

# Source workflow lock to prevent multiple executions
source("workflow_lock.R")

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
workflow <- neuro2::WorkflowRunnerR6$new(config)
result <- workflow$run()

# Print summary
workflow$print_summary(result)

# # Qwen generate report ----------------------------------------------------

# # 1. Process raw data into required format
# neuropsych_data <- paste0(
#   "### Cognitive Domains\n",
#   "- Memory: Impaired immediate/delayed recall (WMS-IV)\n",
#   "### Test Results\n",
#   "- CVLT-II: 5th percentile for learning slope\n",
#   "### Clinical Impressions\n",
#   "- Disorientation to time observed during interview"
# )

# # 2. Generate AI summary
# summary_bullets <- generate_neuropsych_summary(neuropsych_data)

# # 3. Inject into Quarto document (example)
# quarto_yaml <- c("---", "title: 'Neuropsych Report'", "editor: source", "---")

# report_content <- c(
#   "# Executive Summary",
#   summary_bullets,
#   "",
#   "# Full Assessment",
#   "...[rest of report]..."
# )

# # Write to .qmd file
# writeLines(c(quarto_yaml, report_content), "report.qmd")
