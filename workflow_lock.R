
# Workflow lock to prevent multiple executions
if (exists(".WORKFLOW_LOCK") && .WORKFLOW_LOCK) {
  stop("Workflow is already running! Clear .WORKFLOW_LOCK to continue.")
}
.WORKFLOW_LOCK <- TRUE
on.exit(rm(.WORKFLOW_LOCK, envir = .GlobalEnv), add = TRUE)

